.pragma library

// Current shell preference document version.
var shellSchemaVersion = 10

// Return independent nested defaults for each store snapshot.
function shellDefaults() {
    return {version: shellSchemaVersion, appearance: {baseRadius: 12, surfaceTone: "dark", colorMode: "dark"},
        idle: {enabled: true, dimEnabled: true, dimTimeout: 300, dimPercent: 10,
            lockEnabled: true, lockTimeout: 120, displayOffEnabled: true, displayOffTimeout: 120,
            suspendEnabled: true, suspendTimeout: 600, respectAppInhibitors: true, inhibitOnAudio: false},
        roundedScreen: {radius: 20, borderThickness: 4},
        dock: {visibilityMode: "autohide", exclusiveSpace: false, iconSize: 36, hoverLift: 14, hoverScale: 0,
            showTrash: true, showDevices: true},
        topbar: {workspaces: true, windowTitle: true, center: true, cava: true, tray: true,
            quickControls: true, powerProfile: true, wallpaperWorkspace: true, recorder: true, clock: true, notifications: true}}
}
