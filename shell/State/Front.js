.pragma library

// The window in front on `screen`: the one last activated there that is not minimised and stands on `desktop`. It
// stays in front while another screen or a surface of the shell has the keyboard; only another window activated on
// the same screen takes its place. Each of `windows` has isOn(screen), minimized, onAllDesktops, desktops (ids) and
// lastActivated (ms, 0 when never seen activated).
function windowOn(windows, screen, desktop) {
    return windows.filter(window => window.isOn(screen) && !window.minimized
        && (window.onAllDesktops || window.desktops.includes(desktop)))
        .reduce((front, window) => front === null || window.lastActivated > front.lastActivated ? window : front, null);
}
