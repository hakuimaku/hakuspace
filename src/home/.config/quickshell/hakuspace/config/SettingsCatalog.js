.pragma library

// Presentation metadata leaves persistence and validation with the existing stores.
var categories = ["Look", "Shell", "Wallpaper", "Power & Session", "Capture", "Advanced", "About"]
var general = [
    {key: "family", id: "font-family", store: "theme", category: "General", label: "Font family", summary: "Choose a monospace font for HakuSpace.", control: "choice", restartPolicy: "live", synonyms: "typeface typography"},
    {key: "size", id: "font-size", store: "theme", category: "General", label: "Font size", summary: "Adjust the text size used by HakuSpace.", control: "number", min: 8, max: 32, step: 1, unit: "px", restartPolicy: "live", synonyms: "text typography"},
    {key: "WELCOME_MSG", category: "General", label: "Welcome message", summary: "Show a welcome message when your desktop starts.", control: "switch", restartPolicy: "next-session"},
    {key: "NIGHT_LIGHT_TEMPERATURE", category: "General", label: "Night light warmth", summary: "Lower temperatures give the screen a warmer tint when Night Light is on.", control: "number", min: 1000, max: 6500, step: 100, unit: "K", synonyms: "display temperature blue light"},
    {key: "SCREENSHOT_DIR", category: "General", label: "Screenshot folder", summary: "Save new screenshots in this folder.", control: "path"},
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
    {key: "RAM_THRESHOLD_MB", category: "Session", label: "RAM warning threshold", summary: "Flag apps using at least this much RAM in the exit dialog.", control: "number", min: 0, max: 2048, step: 1, unit: "MB"},
    {key: "EXIT_APP_LIST_USER", category: "Session", label: "Apps to close on exit", summary: "Ask these applications to close before ending your desktop session (avoid zombie processes).", control: "list", entryLabel: "Application name"}
].map(function(item) {
    return Object.assign({id: item.key, store: "general", restartPolicy: "next-action", summary: "", synonyms: ""}, item)
})
// Canonical defaults match the distributed setting.sh template.
var generalDefaults = {
    family: "monospace", size: 14, WELCOME_MSG: true, NIGHT_LIGHT_TEMPERATURE: 4000,
    SCREENSHOT_DIR: "$HOME/Pictures/Screenshots", WALL_DIR: "$HOME/Pictures/Wallpapers",
    WALL_MPV_DIR: "$HOME/Videos/Wallpapers", WALL_INTERVAL: 300,
    ACCENT_COLOR_BASED_ON_WALLPAPER: true, ACCENT_COLOR_MODE: "vivid",
    AWWW_OPTS: "--transition-type random --transition-step 90 --transition-fps 60",
    SCREENREC_SAVE_DIR: "$HOME/Videos", REC_COMMAND: "wl-screenrec", REC_OPTS: "--max-fps 60",
    HAKU_CLOCK_FONT_SIZE: 10, HAKU_GENERAL_FONT_SIZE: 11, HAKU_TERMINAL_FONT_SIZE: 14,
    RAM_THRESHOLD_MB: 300, EXIT_APP_LIST_USER: []
}
general = general.map(function(item) {
    var category = ({General: "Look", Appearance: "Look", Recording: "Capture", Session: "Power & Session"})[item.category] || item.category
    if (item.key === "WELCOME_MSG") category = "Shell"
    if (item.key === "NIGHT_LIGHT_TEMPERATURE") category = "Power & Session"
    if (item.key === "SCREENSHOT_DIR") category = "Capture"
    if (["AWWW_OPTS", "REC_OPTS"].includes(item.key)) category = "Advanced"
    return Object.assign(item, {category: category, provider: item.store, group: item.key === "WELCOME_MSG" ? "Startup" : category,
        defaultValue: generalDefaults[item.key], persistMode: "auto", effectMode: item.store === "theme" ? "live" : item.restartPolicy,
        dependsOn: item.key === "ACCENT_COLOR_MODE" ? [{id: "ACCENT_COLOR_BASED_ON_WALLPAPER", equals: true, behavior: "disable"}] : [],
        availability: {shell: ["hikai", "classic"], wm: ["hyprland", "niri", "mango"]},
        keywords: item.synonyms.split(" "), resettable: true, unit: item.unit || (item.control === "number" ? "px" : "")})
})
// Shell and Wallpaper descriptors point directly into their existing store snapshots.
var preferences = [
    {"id": "colorMode", "provider": "shell", "section": "appearance", "key": "colorMode", "category": "Look", "group": "Theme", "label": "Theme Mode", "summary": "Use a dark or light appearance for shell panels and controls.", "defaultValue": "dark", "control": "choice", "options": [{"value": "dark", "label": "Dark"}, {"value": "light", "label": "Light"}]},
    {"id": "surface", "provider": "shell", "section": "appearance", "key": "surfaceTone", "category": "Look", "group": "Theme", "label": "Surface tone", "summary": "Choose the background tone used by shell panels.", "defaultValue": "dark", "control": "choice", "options": [{"value": "ink", "label": "Ink / Pure white"}, {"value": "dark", "label": "Dark / White"}, {"value": "soft", "label": "Soft / Gray white"}]},
    {"id": "radius", "provider": "shell", "section": "appearance", "key": "baseRadius", "category": "Look", "group": "Shape", "label": "Shell radius", "summary": "Round the corners of shell panels and controls.", "defaultValue": 12, "control": "number", "min": 4, "max": 24, "unit": "px"},
    {"id": "shell.roundedScreen.radius", "provider": "shell", "section": "roundedScreen", "key": "radius", "category": "Look", "group": "Rounded Screen", "label": "Screen corner radius", "summary": "Round the outer corners of the desktop frame.", "defaultValue": 20, "control": "number", "min": 0, "max": 24, "unit": "px"},
    {"id": "shell.roundedScreen.borderThickness", "provider": "shell", "section": "roundedScreen", "key": "borderThickness", "category": "Look", "group": "Rounded Screen", "label": "Screen border", "summary": "Set the width of the border around the desktop.", "defaultValue": 4, "control": "number", "min": 0, "max": 6, "unit": "px"},
    {"id": "shell.topbar.workspaces", "provider": "shell", "section": "topbar", "key": "workspaces", "category": "Shell", "group": "Top Bar", "label": "Workspaces", "summary": "Show workspace indicators on the status bar.", "defaultValue": true, "control": "switch"},
    {"id": "shell.topbar.windowTitle", "provider": "shell", "section": "topbar", "key": "windowTitle", "category": "Shell", "group": "Top Bar", "label": "Window title", "summary": "Show the title of the focused window on the status bar.", "defaultValue": true, "control": "switch"},
    {"id": "shell.topbar.center", "provider": "shell", "section": "topbar", "key": "center", "category": "Shell", "group": "Top Bar", "label": "Center module", "summary": "Show media and system information in the center of Top Bar.", "defaultValue": true, "control": "switch"},
    {"id": "shell.topbar.cava", "provider": "shell", "section": "topbar", "key": "cava", "category": "Shell", "group": "Top Bar", "label": "Cava", "summary": "Show the audio visualizer beside the center module.", "defaultValue": true, "control": "switch"},
    {"id": "shell.topbar.tray", "provider": "shell", "section": "topbar", "key": "tray", "category": "Shell", "group": "Top Bar", "label": "System tray", "summary": "Show application tray icons on the status bar.", "defaultValue": true, "control": "switch"},
    {"id": "shell.topbar.quickControls", "provider": "shell", "section": "topbar", "key": "quickControls", "category": "Shell", "group": "Top Bar", "label": "Quick controls", "summary": "Show shortcuts for appearance, audio and battery controls.", "defaultValue": true, "control": "switch"},
    {"id": "shell.topbar.powerProfile", "provider": "shell", "section": "topbar", "key": "powerProfile", "category": "Shell", "group": "Top Bar", "label": "Power Profile Daemon", "summary": "Show the power profile control when supported by the system.", "defaultValue": true, "control": "switch"},
    {"id": "shell.topbar.wallpaperWorkspace", "provider": "shell", "section": "topbar", "key": "wallpaperWorkspace", "category": "Shell", "group": "Top Bar", "label": "Wallpaper Workspace", "summary": "Show the button that opens the wallpaper browser.", "defaultValue": true, "control": "switch"},
    {"id": "shell.topbar.recorder", "provider": "shell", "section": "topbar", "key": "recorder", "category": "Shell", "group": "Top Bar", "label": "Recorder", "summary": "Show the screen recording control on the status bar.", "defaultValue": true, "control": "switch"},
    {"id": "shell.topbar.clock", "provider": "shell", "section": "topbar", "key": "clock", "category": "Shell", "group": "Top Bar", "label": "Clock", "summary": "Show the date and time on the status bar.", "defaultValue": true, "control": "switch"},
    {"id": "shell.topbar.notifications", "provider": "shell", "section": "topbar", "key": "notifications", "category": "Shell", "group": "Top Bar", "label": "Notifications", "summary": "Show the notification indicator and notification center button.", "defaultValue": true, "control": "switch"},
    {"id": "shell.dock.iconSize", "provider": "shell", "section": "dock", "key": "iconSize", "category": "Shell", "group": "App Bar", "label": "Icon size", "summary": "Set the app icon size in Taskbar and Dockbar.", "defaultValue": 36, "control": "number", "min": 24, "max": 72, "step": 4, "unit": "px"},
    {"id": "shell.dock.hoverLift", "provider": "shell", "section": "dock", "key": "hoverLift", "category": "Shell", "group": "App Bar", "label": "Hover lift", "summary": "Raise app icons by this distance when hovered.", "defaultValue": 14, "control": "number", "min": 0, "max": 48, "step": 1, "unit": "px"},
    {"id": "shell.dock.hoverScale", "provider": "shell", "section": "dock", "key": "hoverScale", "category": "Shell", "group": "App Bar", "label": "Hover scale", "summary": "Enlarge app icons by this percentage when hovered.", "defaultValue": 0, "control": "number", "min": 0, "max": 100, "step": 1, "unit": "%"},
    {"id": "shell.dock.showTrash", "provider": "shell", "section": "dock", "key": "showTrash", "category": "Shell", "group": "App Bar", "label": "Show Trash", "summary": "Show the Trash shortcut beside app icons.", "defaultValue": true, "control": "switch"},
    {"id": "shell.dock.showDevices", "provider": "shell", "section": "dock", "key": "showDevices", "category": "Shell", "group": "App Bar", "label": "Show mounted devices", "summary": "Show shortcuts to mounted storage devices beside app icons.", "defaultValue": true, "control": "switch"},
    {"id": "shell.dock.visibilityMode", "provider": "shell", "section": "dock", "key": "visibilityMode", "category": "Shell", "group": "Dockbar", "label": "Dockbar visibility", "summary": "Keep Dockbar visible or reveal it when the pointer approaches.", "defaultValue": "autohide", "control": "choice", "options": [{"value": "autohide", "label": "Auto hide"}, {"value": "always", "label": "Always visible"}], "dependsOn": [{"id": "layout", "equals": "topbar", "behavior": "disable", "action": "layout"}]},
    {"id": "shell.dock.exclusiveSpace", "provider": "shell", "section": "dock", "key": "exclusiveSpace", "category": "Shell", "group": "Dockbar", "label": "Reserve screen space", "summary": "Reserve space for Dockbar so windows do not cover it.", "defaultValue": false, "control": "switch", "dependsOn": [{"id": "layout", "equals": "topbar", "behavior": "disable", "action": "layout"}]},
    {"id": "idle-enabled", "provider": "shell", "section": "idle", "key": "enabled", "category": "Power & Session", "group": "Idle policy", "label": "Idle management", "summary": "Run the dim, lock, screen-off and suspend sequence after inactivity.", "defaultValue": true, "control": "switch"},
    {"id": "idle-dimEnabled", "provider": "shell", "section": "idle", "key": "dimEnabled", "category": "Power & Session", "group": "Idle policy", "label": "Screen dim", "summary": "Lower screen brightness after the dim interval.", "defaultValue": true, "control": "switch"},
    {"id": "idle-dimTimeout", "provider": "shell", "section": "idle", "key": "dimTimeout", "category": "Power & Session", "group": "Idle policy", "label": "Dim after", "summary": "Wait this long after activity stops before dimming the screen.", "defaultValue": 300, "control": "duration", "min": 10, "max": 86400, "step": 10, "unit": "s", "dependsOn": [{"id": "idle-dimEnabled", "equals": true, "behavior": "disable"}]},
    {"id": "idle-dimPercent", "provider": "shell", "section": "idle", "key": "dimPercent", "category": "Power & Session", "group": "Idle policy", "label": "Dim brightness", "summary": "Lower screen brightness to this percentage while idle.", "defaultValue": 10, "control": "number", "min": 1, "max": 100, "step": 1, "unit": "%"},
    {"id": "idle-lockEnabled", "provider": "shell", "section": "idle", "key": "lockEnabled", "category": "Power & Session", "group": "Idle policy", "label": "Lock session", "summary": "Lock the session at the lock milestone in the idle sequence.", "defaultValue": true, "control": "switch"},
    {"id": "idle-lockTimeout", "provider": "shell", "section": "idle", "key": "lockTimeout", "category": "Power & Session", "group": "Idle policy", "label": "Lock after dim", "summary": "Wait this long after the dim stage before locking the session.", "defaultValue": 120, "control": "duration", "min": 10, "max": 86400, "step": 10, "unit": "s", "dependsOn": [{"id": "idle-lockEnabled", "equals": true, "behavior": "disable"}]},
    {"id": "idle-displayOffEnabled", "provider": "shell", "section": "idle", "key": "displayOffEnabled", "category": "Power & Session", "group": "Idle policy", "label": "Turn displays off", "summary": "Turn the displays off at the screen-off milestone.", "defaultValue": true, "control": "switch"},
    {"id": "idle-displayOffTimeout", "provider": "shell", "section": "idle", "key": "displayOffTimeout", "category": "Power & Session", "group": "Idle policy", "label": "Screen off after lock", "summary": "Wait this long after the lock stage before turning displays off.", "defaultValue": 120, "control": "duration", "min": 10, "max": 86400, "step": 10, "unit": "s", "dependsOn": [{"id": "idle-displayOffEnabled", "equals": true, "behavior": "disable"}]},
    {"id": "idle-suspendEnabled", "provider": "shell", "section": "idle", "key": "suspendEnabled", "category": "Power & Session", "group": "Idle policy", "label": "Suspend", "summary": "Suspend the computer at the final idle milestone.", "defaultValue": true, "control": "switch"},
    {"id": "idle-suspendTimeout", "provider": "shell", "section": "idle", "key": "suspendTimeout", "category": "Power & Session", "group": "Idle policy", "label": "Suspend after screen off", "summary": "Wait this long after the screen-off stage before suspending.", "defaultValue": 600, "control": "duration", "min": 10, "max": 86400, "step": 10, "unit": "s", "dependsOn": [{"id": "idle-suspendEnabled", "equals": true, "behavior": "disable"}]},
    {"id": "idle-respectAppInhibitors", "provider": "shell", "section": "idle", "key": "respectAppInhibitors", "category": "Power & Session", "group": "Idle policy", "label": "Respect application inhibitors", "summary": "Let applications delay idle actions while they request to stay awake.", "defaultValue": true, "control": "switch"},
    {"id": "idle-inhibitOnAudio", "provider": "shell", "section": "idle", "key": "inhibitOnAudio", "category": "Power & Session", "group": "Idle policy", "label": "Keep awake while audio is playing", "summary": "Pause the idle countdown while audio is playing.", "defaultValue": false, "control": "switch"},
    {"id": "wallpaper.playback.profile", "provider": "wallpaper", "section": "playback", "key": "profile", "category": "Wallpaper", "group": "Video playback", "label": "Video quality", "summary": "Choose the quality and resource use of prepared video wallpapers.", "defaultValue": "screen", "control": "choice", "options": [{"value": "low-memory", "label": "Save memory"}, {"value": "screen", "label": "Match screen"}, {"value": "original", "label": "Original quality"}]},
    {"id": "wallpaper.playback.hardwareDecode", "provider": "wallpaper", "section": "playback", "key": "hardwareDecode", "category": "Wallpaper", "group": "Video playback", "label": "Video decoder", "summary": "Choose how wallpaper videos are decoded. Restart Hikai to apply.", "defaultValue": "auto", "control": "choice", "effectMode": "restart-hikai", "options": [{"value": "auto", "label": "Automatic"}, {"value": "prefer", "label": "Prefer hardware"}, {"value": "software", "label": "Software"}]},
    {"id": "wallpaper.playback.pauseWhenFullscreen", "provider": "wallpaper", "section": "playback", "key": "pauseWhenFullscreen", "category": "Wallpaper", "group": "Video playback", "label": "Pause over fullscreen windows", "summary": "Pause video wallpaper while a fullscreen window covers the screen.", "defaultValue": true, "control": "switch"},
    {"id": "wallpaper.playback.unloadWhenHidden", "provider": "wallpaper", "section": "playback", "key": "unloadWhenHidden", "category": "Wallpaper", "group": "Video playback", "label": "Free memory when hidden", "summary": "Release the video player after the wallpaper has been hidden for a while.", "defaultValue": true, "control": "switch"},
    {"id": "wallpaper.playback.unloadDelaySec", "provider": "wallpaper", "section": "playback", "key": "unloadDelaySec", "category": "Wallpaper", "group": "Video playback", "label": "Free hidden video after", "summary": "Wait this long before releasing the hidden video player.", "defaultValue": 20, "control": "duration", "min": 1, "max": 600, "step": 1, "unit": "s", "dependsOn": [{"id": "wallpaper.playback.unloadWhenHidden", "equals": true, "behavior": "disable"}]},
    {"id": "wallpaper.playback.loop", "provider": "wallpaper", "section": "playback", "key": "loop", "category": "Wallpaper", "group": "Video playback", "label": "Loop video", "summary": "Replay the wallpaper video when it ends.", "defaultValue": true, "control": "switch"},
    {"id": "wallpaper.proxy.buildPolicy", "provider": "wallpaper", "section": "proxy", "key": "buildPolicy", "category": "Wallpaper", "group": "Video preparation", "label": "Prepare videos", "summary": "Choose when video wallpapers are prepared for playback.", "defaultValue": "on-select", "control": "choice", "options": [{"value": "on-select", "label": "When selected"}, {"value": "background", "label": "In background"}, {"value": "manual", "label": "Only when I ask"}]},
    {"id": "wallpaper.proxy.maxCacheMiB", "provider": "wallpaper", "section": "proxy", "key": "maxCacheMiB", "category": "Wallpaper", "group": "Video preparation", "label": "Cache limit", "summary": "Set the disk-space budget for the wallpaper cache.", "defaultValue": 4096, "control": "number", "min": 64, "max": 65536, "step": 64, "unit": "MiB"},
    {"id": "wallpaper.browser.filter", "provider": "wallpaper", "section": "browser", "key": "filter", "category": "Wallpaper", "group": "Browser", "label": "Default filter", "summary": "Choose whether the wallpaper browser starts with images or videos.", "defaultValue": "static", "control": "choice", "options": [{"value": "static", "label": "Images"}, {"value": "video", "label": "Videos"}]},
    {"id": "wallpaper.browser.sort", "provider": "wallpaper", "section": "browser", "key": "sort", "category": "Wallpaper", "group": "Browser", "label": "Sort order", "summary": "Sort wallpapers by name or by their most recent modification time.", "defaultValue": "name", "control": "choice", "options": [{"value": "name", "label": "Name A–Z"}, {"value": "name-desc", "label": "Name Z–A"}, {"value": "newest", "label": "Newest first"}]},
    {"id": "wallpaper.browser.showMetadata", "provider": "wallpaper", "section": "browser", "key": "showMetadata", "category": "Wallpaper", "group": "Browser", "label": "Show source metadata", "summary": "Show source media details in the wallpaper browser.", "defaultValue": true, "control": "switch"}
].map(function(item) {
    return Object.assign({store: item.provider, persistMode: "auto", effectMode: "live", dependsOn: [],
        availability: {shell: ["hikai"], wm: ["hyprland", "niri", "mango"]}, keywords: [], resettable: true, summary: ""}, item)
})
// Runtime requests retain their state files and use explicit controller targets.
var runtime = [
    {id: "layout", key: "layout", label: "Shell layout", summary: "Choose a top status bar with optional Dockbar or a combined bottom Taskbar.", group: "Layout", control: "choice", defaultValue: "topbar", options: [{value: "topbar", label: "Top Bar"}, {value: "taskbar", label: "Taskbar"}]},
    {id: "dockbar", key: "dockbar", label: "Enable Dockbar", summary: "Show a separate app dock when using the Top Bar layout.", group: "Dockbar", control: "switch", defaultValue: false, dependsOn: [{id: "layout", equals: "topbar", behavior: "disable", action: "layout"}]},
    {id: "cava", key: "cava", label: "Cava Underbar", summary: "Show an audio visualizer along the desktop edge.", group: "Cava Underbar", control: "switch", defaultValue: false},
    {id: "cava-color", key: "cavaColor", label: "Color mode", summary: "Draw the visualizer with the surface color or the accent color.", group: "Cava Underbar", control: "choice", defaultValue: "accent", options: [{value: "surface", label: "Surface"}, {value: "accent", label: "Accent"}]},
    {id: "cava-dynamic", key: "cavaDynamic", label: "Dynamic position", summary: "Follow the active bar when choosing the visualizer edge.", group: "Cava Underbar", control: "switch", defaultValue: false},
    {id: "cava-position", key: "cavaPosition", label: "Fixed position", summary: "Choose a fixed top or bottom edge for the audio visualizer.", group: "Cava Underbar", control: "choice", defaultValue: "top", options: [{value: "top", label: "Top"}, {value: "bottom", label: "Bottom"}], dependsOn: [{id: "cava", equals: true, behavior: "collapse"}, {id: "cava-dynamic", equals: false, behavior: "hide"}]},
    {id: "cava-height", key: "cavaHeight", label: "Layer height", summary: "Set the height of the desktop audio visualizer.", group: "Cava Underbar", control: "number", defaultValue: 72, min: 32, max: 300, step: 1, unit: "px"},
    {id: "idle-keep-awake", key: "keepAwake", category: "Power & Session", label: "Keep Awake", summary: "Prevent automatic dimming, locking, screen-off and suspend.", group: "Keep Awake", control: "switch", defaultValue: false, resettable: false}
].map(function(item) {
    return Object.assign({provider: "runtime-state", store: "runtime-state", category: "Shell", persistMode: "auto", effectMode: "live",
        dependsOn: item.key.indexOf("cava") === 0 && item.key !== "cava" ? [{id: "cava", equals: true, behavior: "collapse"}] : [],
        availability: {shell: ["hikai"], wm: ["hyprland", "niri", "mango"]}, keywords: [], summary: "", resettable: true}, item)
})
var sections = []
// Feature switches lead the provider-backed options within each group.
var descriptors = runtime.concat(preferences, general)
// Resolve one stable identifier for rendering and search.
function descriptor(id) { return descriptors.find(function(item) { return item.id === id }) }
// Build a navigable breadcrumb without coupling metadata to a toolkit.
function breadcrumb(item) { return [item.category, item.group, item.label].filter(function(value, index, values) { return values.indexOf(value) === index }).join(" › ") }
// Search every preference, key and breadcrumb in the single catalog.
function search(query) {
    if (!query.trim()) return []
    var words = query.trim().toLowerCase().split(/\s+/)
    return descriptors.filter(function(item) {
        var text = [breadcrumb(item), item.summary, item.synonyms || "", item.key, item.keywords.join(" ")].join(" ").toLowerCase()
        return words.every(function(word) { return text.indexOf(word) >= 0 })
    })
}
// Resolve visibility independently from the provider's business validation.
function dependencyState(item, read) {
    var state = {visible: true, enabled: true, reason: "", action: ""}
    for (var rule of item.dependsOn) {
        if (read(rule.id) === rule.equals) continue
        if (rule.behavior === "hide" || rule.behavior === "collapse") state.visible = false
        else { state.enabled = false; state.reason = rule.action === "layout" ? "Available with Top Bar layout" : "Enable " + (descriptor(rule.id) || {label: rule.id}).label + " first"; state.action = rule.action || "" }
    }
    return state
}
// Canonicalize home paths only for equality and presentation.
function equal(item, left, right, home) {
    if (item.control === "path") return folderPath(left, home) === folderPath(right, home)
    return JSON.stringify(left) === JSON.stringify(right)
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

// Stage editing is specialized; the catalog remains the source of reset and search metadata.
preferences.forEach(function(item) { if (item.section === "idle" && /^(dim|lock|displayOff|suspend)(Enabled|Timeout)$/.test(item.key)) item.group = "Idle timeline" })

// Wallpaper rotation uses the same readable duration editor as idle intervals.
general.forEach(function(item) { if (item.key === "WALL_INTERVAL") item.control = "duration" })

// Group names follow the navigation hierarchy rather than storage boundaries.
general.forEach(function(item) {
    if (["ACCENT_COLOR_BASED_ON_WALLPAPER", "ACCENT_COLOR_MODE"].includes(item.key)) item.group = "Theme"
    else if (item.category === "Look") item.group = "Typography"
    else if (item.key === "NIGHT_LIGHT_TEMPERATURE") item.group = "Night Light"
    else if (item.category === "Power & Session") item.group = "Session Exit"
    else if (item.category === "Wallpaper") item.group = "Folders & rotation"
    else if (["SCREENSHOT_DIR", "SCREENREC_SAVE_DIR"].includes(item.key)) item.group = "Folders"
    else if (item.category === "Capture") item.group = "Recorder"
    else if (item.category === "Advanced") item.group = "Extra arguments"
})
// Theme Mode leads Look, followed by wallpaper accent and surface tone.
var lookOrder = ["colorMode", "ACCENT_COLOR_BASED_ON_WALLPAPER", "ACCENT_COLOR_MODE", "surface"]
// Preserve declared row order even on JavaScript engines with an unstable sort.
var declaredOrder = descriptors.map(function(item) { return item.id })
descriptors.sort(function(a, b) {
    if (a.category !== b.category) return categories.indexOf(a.category) - categories.indexOf(b.category)
    var priority = a.category === "Look" ? (lookOrder.includes(a.id) ? lookOrder.indexOf(a.id) : 99) - (lookOrder.includes(b.id) ? lookOrder.indexOf(b.id) : 99) : 0
    return priority || declaredOrder.indexOf(a.id) - declaredOrder.indexOf(b.id)
})
// Order presentation groups independently of provider dispatch.
function groups(category) {
    var names = descriptors.filter(function(d) { return d.category === category }).map(function(d) { return d.group }).filter(function(v, i, a) { return a.indexOf(v) === i })
    var preferred = ({Look: ["Theme", "Shape", "Rounded Screen", "Typography"], Shell: ["Layout", "Top Bar", "App Bar", "Dockbar", "Cava Underbar", "Startup"], Wallpaper: ["Folders & rotation", "Video playback", "Video preparation", "Browser"], "Power & Session": ["Keep Awake", "Night Light", "Idle timeline", "Idle policy", "Session Exit"], Capture: ["Folders", "Recorder"]})[category] || names
    return preferred.filter(function(name) { return names.includes(name) }).concat(names.filter(function(name) { return !preferred.includes(name) }))
}
