#include "effect/effect.h"
#include "input.h"
#include "input_event.h"
#include "input_event_spy.h"

#include <QDBusConnection>

namespace KWin
{

// Tells the shell over D-Bus when Meta goes down with no other modifier, and when that ends: Meta comes up, or another
// key, a pointer button or the wheel comes first. That is KWin's own rule for a shortcut of modifiers alone, so the
// shell's Meta shortcut fires on release exactly when ended() follows alone() through Meta's release. It draws nothing.
class MetaHoldEffect : public Effect, public InputEventSpy
{
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.kde.rekta.MetaHold")

public:
    MetaHoldEffect()
    {
        QDBusConnection::sessionBus().registerObject(QStringLiteral("/RektaMetaHold"), this,
                                                     QDBusConnection::ExportScriptableSignals);
        input()->installInputEventSpy(this);
    }

    bool isActive() const override
    {
        return false;
    }

    void keyboardKey(KeyboardKeyEvent *event) override
    {
        if (event->state == KeyboardKeyState::Repeated) {
            return;
        }
        const bool metaDown = isMeta(event->key) && event->state == KeyboardKeyState::Pressed;
        if (metaDown && (event->modifiersRelevantForGlobalShortcuts & ~Qt::MetaModifier) == Qt::NoModifier) {
            m_alone = true;
            Q_EMIT alone();
            return;
        }
        end();
    }

    void pointerButton(PointerButtonEvent *) override
    {
        end();
    }

    void pointerAxis(PointerAxisEvent *) override
    {
        end();
    }

Q_SIGNALS:
    Q_SCRIPTABLE void alone();
    Q_SCRIPTABLE void ended();

private:
    static bool isMeta(Qt::Key key)
    {
        return key == Qt::Key_Meta || key == Qt::Key_Super_L || key == Qt::Key_Super_R;
    }

    void end()
    {
        if (!m_alone) {
            return;
        }
        m_alone = false;
        Q_EMIT ended();
    }

    bool m_alone = false;
};

KWIN_EFFECT_FACTORY(MetaHoldEffect, "metadata.json")

} // namespace KWin

#include "metahold.moc"
