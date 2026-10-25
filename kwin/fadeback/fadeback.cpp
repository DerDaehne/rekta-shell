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

#include <QPointer>
#include <QQmlEngine>
#include <QVector2D>

#include <optional>

using namespace std::chrono_literals;

namespace KWin
{

static LogicalOutput *primaryScreen()
{
    return workspace()->outputOrder().value(0);
}

// The windows on the primary screen step back while the Start is open, smaller about the screen's centre and dimmed,
// and the Start's surface fades in over them with its glass and blur. The Start opens by taking the keyboard and hands
// over by giving it back. How far and how fast come from the shell's Rekta module.
class FadeBackEffect : public Effect
{
public:
    FadeBackEffect();
    ~FadeBackEffect() override;

    void prePaintScreen(ScreenPrePaintData &data) override;
    void postPaintScreen() override;
    void prePaintWindow(RenderView *view, EffectWindow *w, WindowPrePaintData &data) override;
    bool paintWindow(const RenderTarget &renderTarget, const RenderViewport &viewport, EffectWindow *w, int mask,
                     const Region &deviceRegion, WindowPaintData &data) override;
    bool isActive() const override;

private:
    void watch(LayerSurfaceV1Interface *layer);
    void startCommitted(bool keyboard);
    void head(qreal target);
    void tearDown();
    void advance(std::chrono::nanoseconds presentation);
    qreal progress() const;
    void step();
    void fadeStart(qreal opacity) const;
    bool stepsBack(const EffectWindow *w) const;

    template<typename... Args>
    qreal rule(const char *name, Args... args) const
    {
        double result = 0;
        QMetaObject::invokeMethod(m_rules, name, qReturnArg(result), double(args)...);
        return result;
    }

    QObject *m_rules;
    QPointer<LayerSurfaceV1Interface> m_start;
    bool m_keyboard = false;
    bool m_handOverUnconfirmed = false;
    std::optional<std::chrono::nanoseconds> m_setOffAt;
    std::chrono::nanoseconds m_elapsed = 0ns;
    qreal m_from = 0;
    qreal m_to = 0;
    qreal m_progress = 0;
    qreal m_scale = 1;
    qreal m_brightness = 1;
};

FadeBackEffect::FadeBackEffect()
    : m_rules(effects->qmlEngine()->singletonInstance<QObject *>("Rekta", "FadeBack"))
{
    if (!m_rules) {
        qWarning("rekta-fadeback: the Rekta module is not on KWin's QML import path");
        return;
    }
    // ponytail: a Start surface made before the effect loads goes unseen until the shell makes it anew; the rekta
    // session loads the effect before the shell starts.
    connect(waylandServer()->findChild<LayerShellV1Interface *>(), &LayerShellV1Interface::surfaceCreated,
            this, &FadeBackEffect::watch);
}

FadeBackEffect::~FadeBackEffect()
{
    fadeStart(1);
}

void FadeBackEffect::watch(LayerSurfaceV1Interface *layer)
{
    if (layer->scope() != QLatin1StringView("rekta-start")) {
        return;
    }
    m_start = layer;
    m_keyboard = false;
    // Qt hides a window by destroying its layer surface and committing once more on the wl_surface, which outlives it.
    connect(layer->surface(), &SurfaceInterface::committed, this, [this, layer = QPointer(layer)] {
        if (layer) {
            startCommitted(layer->acceptsFocus());
        }
    });
    // KWin forgets the keyboard of a surface that goes, unmapped or destroyed, without a word.
    connect(layer->surface(), &SurfaceInterface::unmapped, this, &FadeBackEffect::tearDown);
    connect(layer, &LayerSurfaceV1Interface::aboutToBeDestroyed, this, &FadeBackEffect::tearDown);
}

// To ask for the keyboard anew, the Start goes without it for a single commit. So a hand-over holds the windows where
// they are until the Start's next commit still goes without.
void FadeBackEffect::startCommitted(bool keyboard)
{
    const bool changed = keyboard != m_keyboard;
    m_keyboard = keyboard;
    m_handOverUnconfirmed = changed && !keyboard;
    if (changed) {
        head(keyboard ? 1 : 0);
    }
}

void FadeBackEffect::head(qreal target)
{
    m_from = m_progress;
    m_to = target;
    m_setOffAt.reset();
    m_elapsed = 0ns;
    step();
    effects->addRepaintFull();
}

void FadeBackEffect::tearDown()
{
    m_keyboard = false;
    m_handOverUnconfirmed = false;
    m_from = 0;
    m_to = 0;
    step();
    effects->addRepaintFull();
}

// The time since the frame the windows set off in, as the primary screen presents its frames. KWin's AnimationClock
// counts whole milliseconds per frame, which would stretch a motion by a sixth at 144 Hz.
void FadeBackEffect::advance(std::chrono::nanoseconds presentation)
{
    if (!m_setOffAt) {
        m_setOffAt = presentation;
    }
    m_elapsed = presentation - *m_setOffAt;
    step();
}

// Under reduced motion the windows stand where they head at once. The Start draws nothing after its hand-over there, so
// the hand-over holds them for a frame only. ponytail: a re-ask slower than a frame still shows under reduced motion;
// hold until the next commit there too once the Start draws a frame after its hand-over.
qreal FadeBackEffect::progress() const
{
    const bool reducedMotion = effects->animationTimeFactor() == 0;
    if (m_handOverUnconfirmed && !(reducedMotion && m_elapsed > 0ns)) {
        return m_from;
    }
    if (reducedMotion) {
        return m_to;
    }
    return rule("progress", m_from, m_to, std::chrono::duration<double, std::milli>(m_elapsed).count());
}

void FadeBackEffect::step()
{
    m_progress = progress();
    m_scale = rule("scale", m_progress);
    m_brightness = rule("brightness", m_progress);
    fadeStart(m_progress);
}

// The window's own opacity, not the paint data's: KWin's blur follows it as well, and it holds once the effect rests
// at 0, until the shell has emptied the surface.
void FadeBackEffect::fadeStart(qreal opacity) const
{
    if (Window *start = m_start ? waylandServer()->findWindow(m_start->surface()) : nullptr) {
        start->setOpacity(opacity);
    }
}

// KWin gives a layer surface of a namespace it does not know the type of a normal window; only its class tells.
bool FadeBackEffect::stepsBack(const EffectWindow *w) const
{
    const bool layer = w->window()->inherits("KWin::LayerShellV1Window");
    return !layer && !w->isLockScreen() && !w->isInputMethod() && w->screen() == primaryScreen();
}

void FadeBackEffect::prePaintScreen(ScreenPrePaintData &data)
{
    if (m_progress != m_to && data.screen == primaryScreen()) {
        advance(data.screen->backendOutput()->renderLoop()->nextPresentationTimestamp());
    }
    effects->prePaintScreen(data);
}

void FadeBackEffect::postPaintScreen()
{
    if (m_progress != m_to) {
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
        // KWin scales a window about its top left corner; the shift moves that to the screen's centre.
        const QPointF centre = w->screen()->geometryF().center();
        data *= QVector2D(m_scale, m_scale);
        data += (centre - w->pos()) * (1 - m_scale);
        data.multiplyBrightness(m_brightness);
    }
    return effects->paintWindow(renderTarget, viewport, w, mask, deviceRegion, data);
}

bool FadeBackEffect::isActive() const
{
    return m_progress > 0 || m_to > 0;
}

KWIN_EFFECT_FACTORY(FadeBackEffect, "metadata.json")

} // namespace KWin

#include "fadeback.moc"
