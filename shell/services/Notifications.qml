import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import Notices
import Rekta

// The session's notification server: it owns org.freedesktop.Notifications, and the board makes toasts and the list of
// what it receives. Quickshell keeps no time; the board ends each notification. A press on a notification without a
// default action, or on a row of the list that ran out, brings its app forward: its window, or else the app started
// from its desktop entry. Sounds play as in Plasma.
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

    // The desktop file ID of the app a notification comes from: the entry its hint names, else the one its name fits.
    function appIdOf(desktopEntry: string, appName: string): string {
        const entry = DesktopEntries.heuristicLookup(desktopEntry || appName);
        return entry?.id ?? desktopEntry.replace(/\.desktop$/, "");
    }

    function bringForward(desktopEntry: string, appName: string) {
        const entry = DesktopEntries.heuristicLookup(desktopEntry || appName);
        const id = entry?.id ?? desktopEntry;
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
        appOf: (desktopEntry, appName) => notifications.appIdOf(desktopEntry, appName)
        iconUrl: name => name === "" || name.includes("://") ? name : Quickshell.iconPath(name, true)

        onAppWanted: (desktopEntry, appName) => notifications.bringForward(desktopEntry, appName)
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
