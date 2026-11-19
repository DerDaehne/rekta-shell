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
    if (value.startsWith("file:///"))
        return value;
    // A provider's id that is itself a URL is a theme lookup of that URL, which can only fail.
    if (value.startsWith("image://"))
        return value.includes("://", "image://".length) ? "" : value;
    return /^[a-zA-Z][a-zA-Z0-9+.-]*:/.test(value) || value.includes("/") ? "" : themed(value);
}
