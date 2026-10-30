#include "core/backendoutput.h"
#include "core/output.h"
#include "core/renderloop.h"
#include "effect/effect.h"
#include "effect/effecthandler.h"
#include "effect/effectwindow.h"
#include "wayland/layershell_v1.h"
#include "wayland/surface.h"
#include "wayland_server.h"
#include "window.h"
#include "workspace.h"

#include <QDBusConnection>
#include <QPointer>
#include <QQmlEngine>
#include <QVector2D>

#include <algorithm>
#include <optional>

using namespace std::chrono_literals;

namespace KWin
{

static LogicalOutput *primaryScreen()
{
    return workspace()->outputOrder().value(0);
}

// How far the windows have stepped back behind one of the shell's layer surfaces, 0 in front and 1 all the way back:
// they step back while it holds the keyboard and come forward once it hands the keyboard over or goes.
struct Retreat {
    // The surface's namespace, and the shell's rule for where the windows are a while after they set off.
    const char *scope;
    const char *rule;
    QPointer<LayerSurfaceV1Interface> surface;
    bool keyboard = false;
    bool handOverUnconfirmed = false;
    std::optional<std::chrono::nanoseconds> setOffAt;
    std::chrono::nanoseconds elapsed = 0ns;
    qreal from = 0;
    qreal to = 0;
    qreal progress = 0;

    bool moving() const
    {
        return progress != to;
    }

    bool active() const
    {
        return progress > 0 || to > 0;
    }
};

// A window that far back.
struct Look {
    qreal scale = 1;
    qreal brightness = 1;
};

// The windows on the primary screen step back while the Start is open, smaller about the screen's centre and dimmed,
// and the Start's surface fades in over them with its glass and blur. As the session is left, the windows on every
// screen step back the same way behind a clear surface. Either surface sets them off by taking the keyboard and brings
// them forward by handing it over. How far and how fast come from the shell's Rekta module.
class FadeBackEffect : public Effect
{
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.rekta.FadeBack")

public:
    FadeBackEffect();
    ~FadeBackEffect() override;

    void prePaintScreen(ScreenPrePaintData &data) override;
    void postPaintScreen() override;
    void prePaintWindow(RenderView *view, EffectWindow *w, WindowPrePaintData &data) override;
    bool paintWindow(const RenderTarget &renderTarget, const RenderViewport &viewport, EffectWindow *w, int mask,
                     const Region &deviceRegion, WindowPaintData &data) override;
    bool isActive() const override;

public Q_SLOTS:
    // The Start's tempo as the shell has it; the windows take it as they next set off. Only a tempo the Start can
    // have counts: above 0 and at most Rekta's own.
    Q_SCRIPTABLE void setStartTempo(double tempo);

private:
    void watch(LayerSurfaceV1Interface *layer);
    void follow(Retreat &retreat, LayerSurfaceV1Interface *layer);
    void committed(Retreat &retreat, bool keyboard);
    void head(Retreat &retreat, qreal target);
    void tearDown(Retreat &retreat);
    void advance(Retreat &retreat, std::chrono::nanoseconds presentation);
    qreal progress(const Retreat &retreat) const;
    Look look(qreal progress) const;
    void step();
    void fadeStart(qreal opacity) const;
    bool stepsBack(const EffectWindow *w) const;
    bool moving() const;

    template<typename... Args>
    qreal rule(const char *name, Args... args) const
    {
        double result = 0;
        QMetaObject::invokeMethod(m_rules, name, qReturnArg(result), double(args)...);
        return result;
    }

    QObject *m_rules;
    double m_startTempo = 0;
    Retreat m_start{"rekta-start", "progress"};
    Retreat m_leave{"rekta-leave", "leaveProgress"};
    Look m_onPrimary;
    Look m_elsewhere;
};

FadeBackEffect::FadeBackEffect()
    : m_rules(effects->qmlEngine()->singletonInstance<QObject *>("Rekta", "FadeBack"))
{
    if (!m_rules) {
        qWarning("rekta-fadeback: the Rekta module is not on KWin's QML import path");
        return;
    }
    m_startTempo = m_rules->property("startTempo").toDouble();
    // ponytail: a surface made before the effect loads goes unseen until the shell makes it anew, and the Start's tempo
    // until the shell starts anew or the setting changes; the rekta session loads the effect before the shell starts.
    QDBusConnection::sessionBus().registerObject(QStringLiteral("/RektaFadeBack"), this, QDBusConnection::ExportScriptableSlots);
    connect(waylandServer()->findChild<LayerShellV1Interface *>(), &LayerShellV1Interface::surfaceCreated,
            this, &FadeBackEffect::watch);
}

FadeBackEffect::~FadeBackEffect()
{
    fadeStart(1);
}

void FadeBackEffect::watch(LayerSurfaceV1Interface *layer)
{
    for (Retreat *retreat : {&m_start, &m_leave}) {
        if (layer->scope() == QLatin1StringView(retreat->scope)) {
            follow(*retreat, layer);
        }
    }
}

void FadeBackEffect::follow(Retreat &retreat, LayerSurfaceV1Interface *layer)
{
    retreat.surface = layer;
    retreat.keyboard = false;
    // Qt hides a window by destroying its layer surface and committing once more on the wl_surface, which outlives it.
    connect(layer->surface(), &SurfaceInterface::committed, this, [this, &retreat, layer = QPointer(layer)] {
        if (layer) {
            committed(retreat, layer->acceptsFocus());
        }
    });
    // KWin forgets the keyboard of a surface that goes, unmapped or destroyed, without a word.
    connect(layer->surface(), &SurfaceInterface::unmapped, this, [this, &retreat] {
        tearDown(retreat);
    });
    connect(layer, &LayerSurfaceV1Interface::aboutToBeDestroyed, this, [this, &retreat] {
        tearDown(retreat);
    });
}

// To ask for the keyboard anew, a surface goes without it for a single commit. So a hand-over holds the windows where
// they are until the surface's next commit still goes without.
void FadeBackEffect::committed(Retreat &retreat, bool keyboard)
{
    const bool changed = keyboard != retreat.keyboard;
    retreat.keyboard = keyboard;
    retreat.handOverUnconfirmed = changed && !keyboard;
    if (changed) {
        head(retreat, keyboard ? 1 : 0);
    }
}

void FadeBackEffect::setStartTempo(double tempo)
{
    if (tempo > 0 && tempo <= 1) {
        m_startTempo = tempo;
    }
}

void FadeBackEffect::head(Retreat &retreat, qreal target)
{
    // The Start's windows change their tempo only as they set off, never on the way.
    if (&retreat == &m_start) {
        m_rules->setProperty("startTempo", m_startTempo);
    }
    retreat.from = retreat.progress;
    retreat.to = target;
    retreat.setOffAt.reset();
    retreat.elapsed = 0ns;
    step();
    effects->addRepaintFull();
}

void FadeBackEffect::tearDown(Retreat &retreat)
{
    retreat.keyboard = false;
    retreat.handOverUnconfirmed = false;
    retreat.from = 0;
    retreat.to = 0;
    step();
    effects->addRepaintFull();
}

// The time since the frame the windows set off in, as the primary screen presents its frames. KWin's AnimationClock
// counts whole milliseconds per frame, which would stretch a motion by a sixth at 144 Hz.
void FadeBackEffect::advance(Retreat &retreat, std::chrono::nanoseconds presentation)
{
    if (!retreat.moving()) {
        return;
    }
    if (!retreat.setOffAt) {
        retreat.setOffAt = presentation;
    }
    retreat.elapsed = presentation - *retreat.setOffAt;
}

// Under reduced motion the windows stand where they head at once. The Start draws nothing after its hand-over there, so
// the hand-over holds them for a frame only. ponytail: a re-ask slower than a frame still shows under reduced motion;
// hold until the next commit there too once the Start draws a frame after its hand-over.
qreal FadeBackEffect::progress(const Retreat &retreat) const
{
    const bool reducedMotion = effects->animationTimeFactor() == 0;
    if (retreat.handOverUnconfirmed && !(reducedMotion && retreat.elapsed > 0ns)) {
        return retreat.from;
    }
    if (reducedMotion) {
        return retreat.to;
    }
    const double elapsed = std::chrono::duration<double, std::milli>(retreat.elapsed).count();
    return rule(retreat.rule, retreat.from, retreat.to, elapsed);
}

Look FadeBackEffect::look(qreal progress) const
{
    return {rule("scale", progress), rule("brightness", progress)};
}

// The windows on the primary screen stand as far back as the further of the two has taken them.
void FadeBackEffect::step()
{
    m_start.progress = progress(m_start);
    m_leave.progress = progress(m_leave);
    m_onPrimary = look(std::max(m_start.progress, m_leave.progress));
    m_elsewhere = look(m_leave.progress);
    fadeStart(m_start.progress);
}

// The window's own opacity, not the paint data's: KWin's blur follows it as well, and it holds once the effect rests
// at 0, until the shell has emptied the surface. ponytail: the glass goes with p, the blur with p² (KWin squares the
// opacity); should the blur lag visibly, set √p here and have the shell fade its glass by √p too.
void FadeBackEffect::fadeStart(qreal opacity) const
{
    if (Window *start = m_start.surface ? waylandServer()->findWindow(m_start.surface->surface()) : nullptr) {
        start->setOpacity(opacity);
    }
}

// KWin gives a layer surface of a namespace it does not know the type of a normal window; only its class tells.
bool FadeBackEffect::stepsBack(const EffectWindow *w) const
{
    const bool layer = w->window()->inherits("KWin::LayerShellV1Window");
    const bool behind = w->screen() && (w->screen() == primaryScreen() || m_leave.active());
    return !layer && !w->isLockScreen() && !w->isInputMethod() && behind;
}

bool FadeBackEffect::moving() const
{
    return m_start.moving() || m_leave.moving();
}

void FadeBackEffect::prePaintScreen(ScreenPrePaintData &data)
{
    if (moving() && data.screen == primaryScreen()) {
        const auto presentation = data.screen->backendOutput()->renderLoop()->nextPresentationTimestamp();
        advance(m_start, presentation);
        advance(m_leave, presentation);
        step();
    }
    effects->prePaintScreen(data);
}

void FadeBackEffect::postPaintScreen()
{
    if (moving()) {
        effects->addRepaintFull();
    }
    effects->postPaintScreen();
}

void FadeBackEffect::prePaintWindow(RenderView *view, EffectWindow *w, WindowPrePaintData &data)
{
    if (stepsBack(w)) {
        data.setTransformed();
    }
    effects->prePaintWindow(view, w, data);
}

bool FadeBackEffect::paintWindow(const RenderTarget &renderTarget, const RenderViewport &viewport, EffectWindow *w,
                                 int mask, const Region &deviceRegion, WindowPaintData &data)
{
    if (stepsBack(w)) {
        const Look &look = w->screen() == primaryScreen() ? m_onPrimary : m_elsewhere;
        // KWin scales a window about its top left corner; the shift moves that to its screen's centre.
        const QPointF centre = w->screen()->geometryF().center();
        data *= QVector2D(look.scale, look.scale);
        data += (centre - w->pos()) * (1 - look.scale);
        data.multiplyBrightness(look.brightness);
    }
    return effects->paintWindow(renderTarget, viewport, w, mask, deviceRegion, data);
}

bool FadeBackEffect::isActive() const
{
    return m_start.active() || m_leave.active();
}

KWIN_EFFECT_FACTORY(FadeBackEffect, "metadata.json")

} // namespace KWin

#include "fadeback.moc"
