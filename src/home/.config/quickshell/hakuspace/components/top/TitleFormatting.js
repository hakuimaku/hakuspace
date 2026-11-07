.pragma library

// Keep Unicode code points intact when abbreviating the shared title label.
function shorten(value, limit) {
    var characters = Array.from(value || "")
    return characters.length > limit ? characters.slice(0, Math.max(0, limit - 1)).join("") + "…" : characters.join("")
}

// Empty WM titles retain the application identity or the shell placeholder.
function title(value, appClass) { return value || appClass || "...hakushell..." }

// Both orientations share the existing application glyph mapping.
function icon(appClass) {
    var name = (appClass || "").toLowerCase()
    if (name.includes("kitty") || name.includes("terminal")) return ""
    if (["firefox", "browser", "chrome", "zen"].some(value => name.includes(value))) return ""
    if (name.includes("code")) return "󰨞"
    if (name.includes("discord")) return ""
    if (name.includes("spotify")) return ""
    if (name.includes("thunar") || name.includes("file")) return ""
    return ""
}
