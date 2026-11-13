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

#include <QAction>
#include <QDBusConnection>
#include <QHash>
#include <QPointer>
#include <QQmlEngine>
#include <QVector2D>

#include <algorithm>
#include <optional>
#include <utility>

using namespace std::chrono_literals;

namespace KWin
{

static LogicalOutput *primaryScreen()
{
    return workspace()->outputOrder().value(0);
}

// The splash by its program, as KWin's own login effect knows it: the layer surface that names it is gone by the time
// it closes, and may have come before this effect loaded. Nix runs a wrapped program as .<name>-wrapped.
static bool isSplash(const EffectWindow *w)
{
    const QString program = w->window()->resourceName();
    return program == QLatin1StringView("ksplashqml") || program == QLatin1StringView(".ksplashqml-wrapped");
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
    // The time since they set off from `from` towards `to`: from `base` on, running forward (1), held (0) or back (-1).
    std::chrono::nanoseconds base = 0ns;
    int pace = 1;
    std::chrono::nanoseconds elapsed = 0ns;
    qreal from = 0;
    qreal to = 0;
    qreal progress = 0;

    // Forward to `to`, held where they are, or back the way they came to `from`.
    qreal heading() const
    {
        return pace > 0 ? to : pace < 0 ? from : progress;
    }

    bool moving() const
    {
        return progress != heading();
    }

    bool active() const
    {
        return progress > 0 || heading() > 0;
    }
};

// Three fingers swiping one way on the touchpad. KWin triggers the action as they let go, and also as it drops the swipe,
// before it has moved, for heading the other way.
struct TouchpadSwipe {
    QAction letGo;
    bool moving = false;
};

// A window that far back.
struct Look {
    qreal scale = 1;
    qreal brightness = 1;
};

// The splash's windows, held after ksplashqml has closed them while they fade.
struct Splash {
    QHash<EffectWindow *, EffectWindowDeletedRef> windows;
    std::optional<std::chrono::nanoseconds> closedAt;
    qreal opacity = 1;
};

// The windows on the primary screen step back while the Start is open, smaller about the screen's centre and dimmed,
// and the Start's surface fades in over them with its glass and blur. As the session is left, the windows on every
// screen step back the same way behind a clear surface. Either surface sets them off by taking the keyboard and brings
// them forward by handing it over. After login the splash fades onto the shell's ground. How far and how fast come
// from the shell's Rekta module.
//
// A finger swiping up from the bottom edge of the primary screen opens the Start: the effect holds that edge while the
// Start is gone, tells the shell over D-Bus how far up the finger has come and when it lets go, and the shell sets the
// windows on the opening's timeline; a finger drawing the open Start down, which the shell has itself, sets them on the
// closing's. KWin swallows a second finger and reports a cancelled touch as a release. Three fingers swiping up on the
// touchpad do what that finger does, and swiping down what the finger drawing the Start down does: the effect tells
// the shell how far of KWin's whole swipe they have come and when they let go.
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
    // The windows behind the Start stand `elapsed` ms into its opening and go on from there: on (1), held (0) or back
    // to its beginning (-1).
    Q_SCRIPTABLE void setStartAt(double elapsed, int pace);
    // The same on their way forward as the Start closes back, from all the way back.
    Q_SCRIPTABLE void setStartOutAt(double elapsed, int pace);
    // The session bar's surface shows by `opacity` from now on, and KWin's blur behind it by its square.
    Q_SCRIPTABLE void setSessionOpacity(double opacity);

Q_SIGNALS:
    // A finger on the bottom edge of the primary screen is `distance` px above where it set down.
    Q_SCRIPTABLE void fingerMoved(double distance);
    Q_SCRIPTABLE void fingerLetGo();
    // Three fingers on the touchpad `progress` of their way up or down, KWin's whole swipe being 1, and as they let go.
    Q_SCRIPTABLE void touchpadUp(double progress);
    Q_SCRIPTABLE void touchpadUpLetGo();
    Q_SCRIPTABLE void touchpadDown(double progress);
    Q_SCRIPTABLE void touchpadDownLetGo();

private:
    void watch(LayerSurfaceV1Interface *layer);
    void follow(Retreat &retreat, LayerSurfaceV1Interface *layer);
    void committed(Retreat &retreat, bool keyboard, bool takesInput);
    void head(Retreat &retreat, qreal target);
    void run(Retreat &retreat, std::chrono::nanoseconds from, int pace);
    void setStartOn(qreal from, qreal to, double elapsed, int pace);
    void tearDown(Retreat &retreat);
    void advance(Retreat &retreat, std::chrono::nanoseconds presentation);
    qreal progress(const Retreat &retreat) const;
    Look look(qreal progress) const;
    void step();
    void fadeStart(qreal opacity) const;
    void fadeSession() const;
    bool stepsBack(const EffectWindow *w) const;
    bool moving() const;
    void holdSplash(EffectWindow *w);
    void fadeSplash(std::chrono::nanoseconds presentation);
    bool fading() const;
    void holdEdge();
    void fingerAt(const QPointF &delta, LogicalOutput *output);
    void letGo();
    void takeSwipe(SwipeDirection direction, TouchpadSwipe &swipe, void (FadeBackEffect::*moved)(double),
                   void (FadeBackEffect::*letGo)());

    template<typename... Args>
    qreal rule(const char *name, Args... args) const
    {
        double result = 0;
        QMetaObject::invokeMethod(m_rules, name, qReturnArg(result), double(args)...);
        return result;
    }

    QObject *m_rules;
    Retreat m_start{"rekta-start", "progress"};
    Retreat m_leave{"rekta-leave", "leaveProgress"};
    Look m_onPrimary;
    Look m_elsewhere;
    Splash m_splash;
    // KWin types it a dock all the same, ignoring the case; the shell writes the bar's and the key map's "dock".
    static constexpr const char *sessionScope = "DOCK";
    QPointer<LayerSurfaceV1Interface> m_session;
    qreal m_sessionOpacity = 1;
    // KWin triggers it as the finger on the edge lets go.
    QAction m_finger;
    bool m_fingerDown = false;
    bool m_edgeHeld = false;
    TouchpadSwipe m_swipeUp;
    TouchpadSwipe m_swipeDown;
};

FadeBackEffect::FadeBackEffect()
    : m_rules(effects->qmlEngine()->singletonInstance<QObject *>("Rekta", "FadeBack"))
{
    if (!m_rules) {
        qWarning("rekta-fadeback: the Rekta module is not on KWin's QML import path");
        return;
    }
    // ponytail: a surface made before the effect loads goes unseen until the shell makes it anew; the rekta session loads
    // the effect before the shell starts.
    QDBusConnection::sessionBus().registerObject(QStringLiteral("/RektaFadeBack"), this, QDBusConnection::ExportScriptableContents);
    connect(waylandServer()->findChild<LayerShellV1Interface *>(), &LayerShellV1Interface::surfaceCreated,
            this, &FadeBackEffect::watch);
    connect(effects, &EffectsHandler::windowClosed, this, &FadeBackEffect::holdSplash);
    connect(&m_finger, &QAction::triggered, this, &FadeBackEffect::letGo);
    holdEdge();
    // ponytail: KWin runs every swipe of a finger count and direction together; with more than one row of virtual
    // desktops its own three fingers up and down switch the desktop as well, and nothing in its config turns that off.
    // The shell follows no desktops; should it matter, take another finger count or direction here.
    takeSwipe(SwipeDirection::Up, m_swipeUp, &FadeBackEffect::touchpadUp, &FadeBackEffect::touchpadUpLetGo);
    takeSwipe(SwipeDirection::Down, m_swipeDown, &FadeBackEffect::touchpadDown, &FadeBackEffect::touchpadDownLetGo);
}

FadeBackEffect::~FadeBackEffect()
{
    fadeStart(1);
    m_sessionOpacity = 1;
    fadeSession();
}

void FadeBackEffect::watch(LayerSurfaceV1Interface *layer)
{
    for (Retreat *retreat : {&m_start, &m_leave}) {
        if (layer->scope() == QLatin1StringView(retreat->scope)) {
            follow(*retreat, layer);
        }
    }
    // Set again on every commit: KWin makes the surface's window anew, at full opacity, as an output changes.
    if (layer->scope() == QLatin1StringView(sessionScope)) {
        m_session = layer;
        connect(layer->surface(), &SurfaceInterface::committed, this, &FadeBackEffect::fadeSession);
        fadeSession();
    }
}

void FadeBackEffect::follow(Retreat &retreat, LayerSurfaceV1Interface *layer)
{
    retreat.surface = layer;
    retreat.keyboard = false;
    // Qt hides a window by destroying its layer surface and committing once more on the wl_surface, which outlives it.
    connect(layer->surface(), &SurfaceInterface::committed, this, [this, &retreat, layer = QPointer(layer)] {
        if (layer) {
            committed(retreat, layer->acceptsFocus(), !layer->surface()->input().isEmpty());
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

// To ask for the keyboard anew, a surface goes without it for a single commit and goes on taking input. So a hand-over
// holds the windows where they are until the surface's next commit still goes without, unless the surface takes no
// input any more: then it has gone, as the Start does at once under reduced motion.
void FadeBackEffect::committed(Retreat &retreat, bool keyboard, bool takesInput)
{
    const bool changed = keyboard != retreat.keyboard;
    retreat.keyboard = keyboard;
    retreat.handOverUnconfirmed = changed && !keyboard && takesInput;
    if (changed) {
        head(retreat, keyboard ? 1 : 0);
    }
}

void FadeBackEffect::setStartAt(double elapsed, int pace)
{
    setStartOn(0, 1, elapsed, pace);
}

void FadeBackEffect::setStartOutAt(double elapsed, int pace)
{
    setStartOn(1, 0, elapsed, pace);
}

void FadeBackEffect::setStartOn(qreal from, qreal to, double elapsed, int pace)
{
    if (!(elapsed >= 0) || pace < -1 || pace > 1) {
        return;
    }
    m_start.from = from;
    m_start.to = to;
    run(m_start, std::chrono::duration_cast<std::chrono::nanoseconds>(std::chrono::duration<double, std::milli>(elapsed)), pace);
}

// Windows already bound there, as a finger's opening holds them, go on from where they stand rather than anew.
void FadeBackEffect::head(Retreat &retreat, qreal target)
{
    if (target == retreat.to) {
        run(retreat, retreat.elapsed, 1);
        return;
    }
    retreat.from = retreat.progress;
    retreat.to = target;
    run(retreat, 0ns, 1);
}

void FadeBackEffect::run(Retreat &retreat, std::chrono::nanoseconds from, int pace)
{
    retreat.base = from;
    retreat.pace = pace;
    retreat.elapsed = from;
    retreat.setOffAt.reset();
    step();
    effects->addRepaintFull();
}

void FadeBackEffect::tearDown(Retreat &retreat)
{
    retreat.keyboard = false;
    retreat.handOverUnconfirmed = false;
    retreat.pace = 1;
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
    retreat.elapsed = std::max(0ns, retreat.base + retreat.pace * (presentation - *retreat.setOffAt));
}

// Under reduced motion the windows stand where they head at once.
qreal FadeBackEffect::progress(const Retreat &retreat) const
{
    if (retreat.handOverUnconfirmed) {
        return retreat.progress;
    }
    if (effects->animationTimeFactor() == 0) {
        return retreat.heading();
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
    holdEdge();
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

void FadeBackEffect::setSessionOpacity(double opacity)
{
    if (!(opacity >= 0 && opacity <= 1)) {
        return;
    }
    m_sessionOpacity = opacity;
    fadeSession();
}

// The window's own opacity, as for the Start: KWin's blur follows it, by its square.
void FadeBackEffect::fadeSession() const
{
    if (Window *session = m_session ? waylandServer()->findWindow(m_session->surface()) : nullptr) {
        session->setOpacity(m_sessionOpacity);
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

// Once ksplashqml has closed the splash, it fades onto the shell's ground, which stands under it by then; under
// reduced motion it goes at once.
void FadeBackEffect::holdSplash(EffectWindow *w)
{
    if (!isSplash(w) || effects->animationTimeFactor() == 0) {
        return;
    }
    if (!fading()) {
        m_splash = {};
    }
    m_splash.windows.insert(w, EffectWindowDeletedRef(w));
    effects->addRepaintFull();
}

// Timed as the windows are, from the frame it starts to fade in; every screen's splash fades alike.
void FadeBackEffect::fadeSplash(std::chrono::nanoseconds presentation)
{
    if (!fading()) {
        return;
    }
    if (!m_splash.closedAt) {
        m_splash.closedAt = presentation;
    }
    const double elapsed = std::chrono::duration<double, std::milli>(presentation - *m_splash.closedAt).count();
    m_splash.opacity = rule("splashOpacity", elapsed);
}

bool FadeBackEffect::fading() const
{
    return !m_splash.windows.isEmpty();
}

// The edge is the Start's way in only while the Start is gone, so a finger at the bottom of the open Start reaches the
// Start; a finger swiping keeps it until it lets go. The edge alone sets nothing in motion.
void FadeBackEffect::holdEdge()
{
    const bool wanted = m_fingerDown || !m_start.active();
    if (wanted == m_edgeHeld) {
        return;
    }
    m_edgeHeld = wanted;
    if (!wanted) {
        effects->unregisterTouchBorder(ElectricBottom, &m_finger);
        return;
    }
    // KWin holds the bottom edge of every screen with nothing below it; only the primary screen's opens the Start.
    effects->registerRealtimeTouchBorder(ElectricBottom, &m_finger, [this](ElectricBorder, const QPointF &delta, LogicalOutput *output) {
        fingerAt(delta, output);
    });
}

void FadeBackEffect::fingerAt(const QPointF &delta, LogicalOutput *output)
{
    if (output != primaryScreen()) {
        return;
    }
    m_fingerDown = true;
    Q_EMIT fingerMoved(-delta.y());
}

// KWin may still be handing the release along the edge, so it is freed only on the event loop's next turn. The shell
// may answer nothing, the Start having opened all the way while the finger held.
void FadeBackEffect::letGo()
{
    if (!m_fingerDown) {
        return;
    }
    m_fingerDown = false;
    Q_EMIT fingerLetGo();
    QMetaObject::invokeMethod(this, &FadeBackEffect::holdEdge, Qt::QueuedConnection);
}

// Holding the swipe sets nothing in motion; only the shell, answering, does.
void FadeBackEffect::takeSwipe(SwipeDirection direction, TouchpadSwipe &swipe, void (FadeBackEffect::*moved)(double),
                               void (FadeBackEffect::*letGo)())
{
    effects->registerTouchpadSwipeShortcut(direction, 3, &swipe.letGo, [this, &swipe, moved](qreal progress) {
        swipe.moving = true;
        Q_EMIT(this->*moved)(progress);
    });
    connect(&swipe.letGo, &QAction::triggered, this, [this, &swipe, letGo] {
        if (std::exchange(swipe.moving, false)) {
            Q_EMIT(this->*letGo)();
        }
    });
}

void FadeBackEffect::prePaintScreen(ScreenPrePaintData &data)
{
    if (data.screen == primaryScreen()) {
        const auto presentation = data.screen->backendOutput()->renderLoop()->nextPresentationTimestamp();
        if (moving()) {
            advance(m_start, presentation);
            advance(m_leave, presentation);
            step();
        }
        fadeSplash(presentation);
    }
    effects->prePaintScreen(data);
}

void FadeBackEffect::postPaintScreen()
{
    if (fading() && m_splash.opacity <= 0) {
        m_splash.windows.clear();
    }
    if (moving() || fading()) {
        effects->addRepaintFull();
    }
    effects->postPaintScreen();
}

void FadeBackEffect::prePaintWindow(RenderView *view, EffectWindow *w, WindowPrePaintData &data)
{
    if (stepsBack(w)) {
        data.setTransformed();
    }
    if (m_splash.windows.contains(w)) {
        data.setTranslucent();
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
    if (m_splash.windows.contains(w)) {
        data.multiplyOpacity(m_splash.opacity);
    }
    return effects->paintWindow(renderTarget, viewport, w, mask, deviceRegion, data);
}

bool FadeBackEffect::isActive() const
{
    return m_start.active() || m_leave.active() || fading();
}

KWIN_EFFECT_FACTORY(FadeBackEffect, "metadata.json")

} // namespace KWin

#include "fadeback.moc"
