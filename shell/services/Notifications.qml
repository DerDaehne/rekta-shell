import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import Notices
import Rekta

// The session's notification server: it owns org.freedesktop.Notifications, and the board makes toasts and the list of
// what it receives. Quickshell keeps no time; the board ends each notification. A press on a notification without a
// default action brings its app forward: its window, or else the app started from its desktop entry. Sounds play as in
// Plasma.
// ponytail: no xdg-activation token goes with an action (Quickshell never sends ActivationToken), so an app on Wayland
// may not raise itself on its default action; send one once the shell has a Wayland module of its own.
Scope {
    id: notifications

    required property Toaster toaster
    required property Windows windows
    required property Launcher launcher
    property bool quiet: false
    readonly property NoticeBoard board: noticeBoard
    property string soundTheme: "ocean"

    function bringForward(notification: Notification) {
        const entry = DesktopEntries.heuristicLookup(notification.desktopEntry || notification.appName);
        const id = entry?.id ?? notification.desktopEntry;
        const window = Array.from(windows.all).find(other => other.appId === id);
        if (window)
            window.activate();
        else if (entry)
            launcher.launch(entry);
    }

    function play(notification: Notification) {
        const command = Sound.command(notification.hints, soundTheme);
        if (command.length > 0)
            Quickshell.execDetached(command);
    }

    NotificationServer {
        actionsSupported: true
        imageSupported: true
        keepOnReload: true

        onNotification: notification => {
            notification.tracked = true;
            noticeBoard.arrive(notification);
        }
    }

    NoticeBoard {
        id: noticeBoard

        toaster: notifications.toaster
        quiet: notifications.quiet
        iconUrl: name => name === "" || name.includes("://") ? name : Quickshell.iconPath(name, true)

        onAppWanted: notification => notifications.bringForward(notification)
        onSounding: notification => notifications.play(notification)
    }

    FileView {
        path: `${Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config"}/kdeglobals`
        watchChanges: true
        printErrors: false

        onFileChanged: reload()
        onLoaded: notifications.soundTheme = Sound.theme(text())
        onLoadFailed: notifications.soundTheme = "ocean"
    }
}
