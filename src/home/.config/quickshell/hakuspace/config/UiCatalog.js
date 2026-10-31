.pragma library

// HakuMenu

// Static hakuMenuModes presentation entries.
var hakuMenuModes = [
    { key: "general", icon: "󰀻", label: "General" },
    { key: "drun", icon: "󰍉", label: "Drun" },
    { key: "theme", icon: "", label: "Theme" }
]

// Static hakuMenuGeneralItems presentation entries.
var hakuMenuGeneralItems = [
    { label: "Wifi", icon: "󰖩", command: ["nm-connection-editor"] },
    { label: "Bluetooth", icon: "󰂯", command: ["blueman-manager"] },
    { label: "Disk Manager", icon: "󰋊", command: ["gparted"] },
    { label: "Storage Manager", icon: "󰃢", command: ["kitty", "--class", "ncdu", "-e", "sudo", "ncdu", "/"] },
    { label: "Audio Control", icon: "", command: ["pavucontrol"] }
]

// Static hakuMenuThemeItems presentation entries.
var hakuMenuThemeItems = [
    { label: "Change Theme", icon: "", action: "Change Theme", toggle: false, showState: false, statePath: "", stateKind: "bool" },
    { label: "Change Wallpaper", icon: "󰏜", action: "Change Wallpaper", toggle: false, showState: false, statePath: "", stateKind: "bool" },
    { label: "Taskbar Mode", icon: "󰐃", action: "Taskbar Mode", toggle: true, showState: true, chromeKey: "taskbar" },
    { label: "Cava Underbar", icon: "󰝚", action: "Cava Underbar", toggle: true, showState: true, stateKey: "stateCavaEnabled", stateKind: "bool" },
    { label: "Cava Dynamic Position", icon: "󰝚", action: "Cava Dynamic Position", toggle: true, showState: true, stateKey: "stateCavaDynamicPosition", stateKind: "bool" },
    { label: "Cava Color Mode", icon: "󰝚", action: "Cava Color Mode", toggle: true, showState: true, stateKey: "stateCavaColorMode", stateKind: "cavaColor" },
    { label: "Desktop Icons", icon: "", action: "Desktop Icons", toggle: true, showState: true, stateKey: "stateDesktopIconsEnabled", stateKind: "bool" },
    { label: "Dockbar", icon: "󰧨", action: "Dockbar", toggle: true, showState: true, chromeKey: "dockbar" },
    { label: "Auto Random Wallpaper", icon: "", action: "Auto Random Wallpaper", toggle: true, showState: true, stateKey: "randomWallpaper", stateKind: "bool" },
    { label: "Dark / Light Mode", icon: "󰔎", action: "colorMode", toggle: true, showState: true, stateKind: "colorMode" },
    { label: "", icon: "󰆧", action: "", toggle: true, showState: false, stateKey: "stateShellBackend", stateKind: "backend", backendSwitch: true }
]

// Action Menu

// Static actionMenuThemeItems presentation entries.
var actionMenuThemeItems = [
    {
        id: "font",
        icon: "",
        label: "Font family",
        secondaryKey: "fontFamily",
        page: "pages/ThemeFontPage.qml"
    },
    {
        id: "size",
        icon: "",
        label: "Font size",
        secondaryKey: "fontSize", secondarySuffix: " px",
        page: "pages/ThemeFontSizePage.qml"
    },
    {
        id: "accent",
        icon: "",
        label: "Accent color",
        secondaryKey: "accent",
        page: "pages/ThemeAccentPage.qml"
    },
    {
        id: "niriAnimation",
        icon: "󰤕",
        label: "Niri Animation",
        secondary: "Window transitions",
        page: "pages/NiriAnimationPage.qml"
    }
]

// Static accentPresets presentation entries.
var accentPresets = [
    { isPicker: true, label: "Pick Color", secondary: "[Press Enter]", icon: "󰈊", hex: "" },
    { isPicker: false, label: "Slate Blue", secondary: "#7288AE", icon: "", hex: "#7288AE" },
    { isPicker: false, label: "Green", secondary: "#A2CB8B", icon: "", hex: "#A2CB8B" },
    { isPicker: false, label: "Peach", secondary: "#FFB399", icon: "", hex: "#FFB399" },
    { isPicker: false, label: "Yellow", secondary: "#EFBF04", icon: "", hex: "#EFBF04" },
    { isPicker: false, label: "Pink", secondary: "#F9B2D7", icon: "", hex: "#F9B2D7" },
    { isPicker: false, label: "White", secondary: "#FFFFFF", icon: "", hex: "#FFFFFF" },
    { isPicker: false, label: "Grey", secondary: "#BFC9D1", icon: "", hex: "#BFC9D1" }
]

// Offered font sizes in their visual order.
var fontSizePresets = [10, 12, 14, 16, 18]

// Power menu actions in their display order.
var actionMenuPowerActions = [
    { id: "suspend", icon: "󰒲", label: "Suspend", danger: false },
    { id: "reboot", icon: "󰑐", label: "Reboot", danger: true },
    { id: "poweroff", icon: "󰐥", label: "Poweroff", danger: true },
    { id: "hibernate", icon: "󰒲", label: "Hibernate", danger: false },
    { id: "lock", icon: "󰌾", label: "Lock", danger: false },
    { id: "logout", icon: "󰍃", label: "Logout", danger: false }
]

// Recording modes resolved by the existing recording handlers.
var actionMenuRecordModes = [
    {
        id: "system-audio",
        icon: "󰕧",
        label: "Only Sound",
        secondary: "Screen + System Audio",
        isSubmenu: false
    },
    {
        id: "mic-system",
        icon: "󰍬",
        label: "Micro and Sound",
        secondary: "Screen + Mic + System",
        isSubmenu: true
    },
    {
        id: "no-audio",
        icon: "󰕭",
        label: "No Sound",
        secondary: "Video Only",
        isSubmenu: false
    }
]

// Sidebar

// Utility rail tools in their display order.
var sidebarTools = [
    { key: "quickActions", icon: "󰀻", label: "Quick Actions" },
    { key: "clipboard", icon: "󰅌", label: "Clipboard" },
    { key: "tempNote", icon: "󰏫", label: "Temp Note" },
    { key: "taskManager", icon: "󰍛", label: "Task Manager" }
]

// Quick action metadata; availability and state remain runtime-owned.
var sidebarQuickActions = [
    { key: "wifi", icon: "󰤨", label: "Wi-Fi", toggle: true },
    { key: "bluetooth", icon: "󰂯", label: "Bluetooth", toggle: true },
    { key: "idleInhibit", icon: "󰈈", label: "Keep Awake", toggle: true },
    { key: "nightLight", icon: "󰖔", label: "Night Light", toggle: true },
    { key: "dockbar", icon: "󰐃", label: "Dockbar", toggle: true },
    { key: "desktopIcons", icon: "󰀻", label: "Desktop Icons", toggle: true },
    { key: "cava", icon: "󰝚", label: "Cava Underbar", toggle: true },
    { key: "settings", icon: "󰒓", label: "Settings", toggle: false }
]

// Dashboard

// Widget identity and titles; QML retains implementation components.
var dashboardWidgets = [
    {
        key: "calendar",
        title: "Calendar"
    },
    {
        key: "bio",
        title: "Bio"
    }
]

// Wallpaper

// Wallpaper media kinds in their tab order.
var wallpaperKinds = [
    {id: "static", name: "Images"},
    {id: "video", name: "Lively"}
]

// Video quality labels and preset identifiers.
var wallpaperVideoProfiles = [
    {label: "720p", shortLabel: "720p", description: "Save memory: 720p / 24 fps", value: "low-memory"},
    {label: "Screen", shortLabel: "Fit", description: "Match screen quality", value: "screen"},
    {label: "Original", shortLabel: "Full", description: "Original video quality", value: "original"}
]
