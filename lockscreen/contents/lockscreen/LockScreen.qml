import QtQuick
import org.kde.kirigami as Kirigami
import org.kde.kscreenlocker as ScreenLocker
import org.kde.plasma.private.keyboardindicator as KeyboardIndicator
import org.kde.plasma.private.sessions as Sessions
import org.kde.plasma.workspace.keyboardlayout as Keyboards
import Rekta

// The lock screen kscreenlocker_greet loads, once per monitor. It only hands the greeter's context and Plasma's
// modules to the parts beside it, LockFace (what is shown) and Unlock (how PAM is asked), and quits the greeter once
// the session is unlocked. Its opaque face covers the wallpaper the greeter puts below it.
Item {
    id: root

    // Written by the greeter once the first frame is shown.
    property bool viewVisible: false

    // The greeter's context properties, read in this one place.
    // qmllint disable unqualified
    readonly property var pam: authenticator
    readonly property string userName: kscreenlocker_userName
    // qmllint enable unqualified

    // KWin hands KDE's animation speed to QML only through Kirigami's units, which turn "instant" into 1 ms.
    Binding {
        target: Prefs
        property: "systemReducedMotion"
        value: Kirigami.Units.longDuration <= 1
    }

    // Which monitor the pointer is on; the keyboard follows it there.
    ScreenLocker.ActiveScreenMonitor {
        id: monitor

        window: root.Window.window
        // kscreenlocker's type info names this type without its C++ namespace, so qmllint cannot find it.
        lockscreenState: ScreenLocker.LockscreenState // qmllint disable missing-type
        onActiveChanged: {
            if (active)
                root.Window.window.requestActivate();
        }
    }

    KeyboardIndicator.KeyState {
        id: capsLockState

        key: Qt.Key_CapsLock
    }

    Keyboards.KeyboardLayout {
        id: keyboardLayout
    }

    Sessions.SessionManagement {
        id: sessionManagement
    }

    Unlock {
        id: unlock

        authenticator: root.pam
        viewVisible: root.viewVisible
        capsLock: capsLockState.locked
        onRejected: face.reject()
        onUnlocked: Qt.quit()
    }

    LockFace {
        id: face

        anchors.fill: parent
        // Until the pointer enters a monitor, the one with the keyboard is the user's, and a single one always.
        active: Application.screens.length === 1 || monitor.active || root.Window.active
        userName: root.userName
        checking: unlock.checking
        error: unlock.error
        info: unlock.info
        capsLock: capsLockState.locked
        layouts: Array.from(keyboardLayout.layoutsList, layout => layout.shortName)
        layoutIndex: keyboardLayout.layout
        canSwitchUser: sessionManagement.canSwitchUser
        onSubmitted: secret => unlock.submit(secret)
        onLayoutChosen: index => keyboardLayout.layout = index
        onSwitchUser: sessionManagement.switchUser()
    }
}
