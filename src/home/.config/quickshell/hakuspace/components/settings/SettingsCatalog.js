// Presentation metadata leaves persistence and validation with the existing stores.
var categories = ["General", "Appearance", "Desktop", "Wallpaper", "Recording", "Session", "Configuration", "About"]
var general = [
    {key: "family", id: "font-family", store: "theme", category: "General", label: "Font family", summary: "Choose a monospace font for HakuSpace.", control: "choice", restartPolicy: "live", synonyms: "typeface typography"},
    {key: "size", id: "font-size", store: "theme", category: "General", label: "Font size", summary: "Adjust the text size used by HakuSpace.", control: "number", min: 8, max: 32, step: 1, unit: "px", restartPolicy: "live", synonyms: "text typography"},
    {key: "WELCOME_MSG", category: "General", label: "Welcome message", summary: "Show a welcome message when your desktop starts.", control: "switch", restartPolicy: "next-session"},
    {key: "NIGHT_LIGHT_TEMPERATURE", category: "General", label: "Night light warmth", summary: "Lower temperatures give the screen a warmer tint when Night Light is on.", control: "number", min: 1000, max: 6500, step: 100, unit: "K", synonyms: "display temperature blue light"},
    {key: "SCREENSHOT_DIR", category: "General", label: "Screenshot folder", control: "path"},
    {key: "WALL_DIR", category: "Wallpaper", label: "Image wallpaper folder", summary: "Find image wallpapers in this folder.", control: "path"},
    {key: "WALL_MPV_DIR", category: "Wallpaper", label: "Video wallpaper folder", summary: "Find video wallpapers in this folder.", control: "path"},
    {key: "WALL_INTERVAL", category: "Wallpaper", label: "Change wallpaper every", summary: "Delay for script-driven wallpaper rotation; Hikai does not start rotation automatically.", control: "number", min: 1, max: 86400, step: 1, unit: "s"},
    {key: "ACCENT_COLOR_BASED_ON_WALLPAPER", category: "Appearance", label: "Accent from wallpaper", summary: "Use a color from your wallpaper for highlights.", control: "switch"},
    {key: "ACCENT_COLOR_MODE", category: "Appearance", label: "Wallpaper accent color", summary: "Choose which color becomes your highlight.", control: "choice", options: [{value: "vivid", label: "Vivid"}, {value: "dominant", label: "Dominant"}, {value: "brightest", label: "Brightest"}, {value: "saturated", label: "Saturated"}]},
    {key: "AWWW_OPTS", category: "Wallpaper", label: "Wallpaper transition options", summary: "Customize awww arguments for image wallpapers.", control: "text"},
    {key: "SCREENREC_SAVE_DIR", category: "Recording", label: "Recording folder", summary: "Save screen recordings in this folder.", control: "path"},
    {key: "REC_COMMAND", category: "Recording", label: "Recorder command", summary: "Customize wl-screenrec command path.", control: "text"},
    {key: "REC_OPTS", category: "Recording", label: "Recording options", summary: "Customize additional wl-screenrec options.", control: "text"},
    {key: "HAKU_CLOCK_FONT_SIZE", category: "Appearance", label: "Widget clock size", summary: "Clock font size for the Haku widget.", control: "number", min: 1, max: 256, step: 1},
    {key: "HAKU_GENERAL_FONT_SIZE", category: "Appearance", label: "Widget text size", summary: "Text font size for the Haku widget.", control: "number", min: 1, max: 256, step: 1},
    {key: "HAKU_TERMINAL_FONT_SIZE", category: "Appearance", label: "Widget terminal size", summary: "Terminal font size for the Haku widget.", control: "number", min: 1, max: 256, step: 1},
    {key: "WAYBAR_MODE_USER", category: "Appearance", label: "Custom Waybar themes", summary: "Classic only. Add theme folder names from ~/hakucfg/config/waybar; each needs config and style.css.", control: "list", entryLabel: "Theme folder name"},
    {key: "RAM_THRESHOLD_MB", category: "Session", label: "Memory warning threshold", summary: "Warn before exiting when applications use more memory than this.", control: "number", min: 1, max: 131072, step: 1, unit: "MB"},
    {key: "EXIT_APP_LIST_USER", category: "Session", label: "Apps to close on exit", summary: "Ask these applications to close before ending your desktop session (avoid zombie processes).", control: "list", entryLabel: "Application name"}
].map(function(item) {
    return Object.assign({id: item.key, store: "general", restartPolicy: "next-action", summary: "", synonyms: ""}, item)
})
// Section descriptors also make existing Shell and Wallpaper controls searchable.
var sections = [
    {id: "layout", store: "shell", category: "Appearance", label: "Shell layout", summary: "Choose a top bar or bottom taskbar.", section: "Layout", synonyms: "dock position"},
    {id: "colorMode", store: "shell", category: "Appearance", label: "Theme Mode", summary: "Choose Dark or Light for Hikai.", section: "Appearance", synonyms: "light dark white color mode"},
    {id: "radius", store: "shell", category: "Appearance", label: "Shell radius", summary: "Adjust the roundness of shell surfaces.", section: "Appearance"},
    {id: "rounded", store: "shell", category: "Appearance", label: "Screen corners and border", summary: "Adjust the rounded screen frame.", section: "Rounded Screen"},
    {id: "surface", store: "shell", category: "Appearance", label: "Surface style", summary: "Choose ink, dark, soft, pure white, white or gray white surfaces.", section: "Surface"},
    {id: "topbar", store: "shell", category: "Desktop", label: "Top Bar modules", summary: "Show clocks, workspaces and system controls.", section: "Top Bar"},
    {id: "appbar", store: "shell", category: "Desktop", label: "App Bar", summary: "Adjust icons, hover size, trash and mounted devices.", section: "App Bar"},
    {id: "dockbar", store: "shell", category: "Desktop", label: "Dockbar", summary: "Choose visibility and reserved space.", section: "Dockbar"},
    {id: "cava", store: "shell", category: "Desktop", label: "Audio visualizer", summary: "Adjust Cava Underbar height, color and position.", section: "Cava Underbar", synonyms: "music waves"},
    {id: "videoQuality", store: "wallpaper", category: "Wallpaper", label: "Video quality", summary: "Save memory, match screen, or play original quality.", section: "Video playback", synonyms: "resolution profile"},
    {id: "videoDecoder", store: "wallpaper", category: "Wallpaper", label: "Video decoder", summary: "Choose automatic, hardware or software decoding.", section: "Video playback"},
    {id: "hiddenVideo", store: "wallpaper", category: "Wallpaper", label: "When wallpaper is hidden", summary: "Pause playback or free video memory.", section: "Video playback"},
    {id: "prepare", store: "wallpaper", category: "Wallpaper", label: "Prepare videos", summary: "Prepare when selected, in background, or only when requested.", section: "Video preparation"},
    {id: "cache", store: "wallpaper", category: "Wallpaper", label: "Video cache", summary: "Limit storage and clear unused prepared videos.", section: "Video cache"}
].map(function(item) { return Object.assign({restartPolicy: "live", control: "section", synonyms: ""}, item) })

// Search includes every preference and its storage key.
function search(query) {
    var words = query.trim().toLowerCase().split(/\s+/)
    if (!query.trim()) return []
    return general.concat(sections).filter(function(item) {
        var text = [item.label, item.summary, item.synonyms, item.category, item.key || ""].join(" ").toLowerCase()
        return words.every(function(word) { return text.indexOf(word) >= 0 })
    })
}

// Keep every configuration file available, with the active compositor first.
function configFiles(files, wm) {
    var active = "wm/" + ({hyprland: "hyprland-custom.lua", niri: "niri-custom.kdl", mango: "mango-custom.conf"}[wm] || "")
    return files.slice().sort(function(a, b) { return a.id === active ? -1 : b.id === active ? 1 : a.id.localeCompare(b.id) })
}

// Expand the supported home prefixes without evaluating arbitrary shell text.
function folderPath(value, home) {
    var path = String(value || home)
    for (var prefix of ["~", "$HOME", "${HOME}"]) {
        if (path === prefix || path.indexOf(prefix + "/") === 0) return home + path.substring(prefix.length)
    }
    return path
}
