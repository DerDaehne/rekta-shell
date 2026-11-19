.pragma library

// What another program may make the shell draw: a picture it names (a notification's icon, a tray item's or a player's
// cover) never makes the shell fetch anything. The Desktop Notifications specification allows a theme icon name, a
// `file://` URI or an absolute path; the shell's own image providers (`image://`) stand for pictures it made itself.
// Any other scheme (http, https, ftp, data) gives no picture. `themed` turns a plain icon name into a source, or "".
function source(value, themed = () => "") {
    if (typeof value !== "string" || value === "")
        return "";
    if (value.startsWith("/") && !value.startsWith("//"))
        return "file://" + value.split("/").map(encodeURIComponent).join("/");
    if (value.startsWith("file:///") || value.startsWith("image://"))
        return value;
    return /^[a-zA-Z][a-zA-Z0-9+.-]*:/.test(value) || value.includes("/") ? "" : themed(value);
}
