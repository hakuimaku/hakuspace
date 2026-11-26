.pragma library

// Current shell preference document version.
var shellSchemaVersion = 12

// Return independent nested defaults for each store snapshot.
function shellDefaults() {
    return {version: shellSchemaVersion, chrome: {statusEdge: "top", notificationPopupPosition: "center", actionLayerAnimation: "scale", hakuMenuHoverScale: "1.05", hakuMenuTabStyle: "underline", navigationOpenTrigger: "hover", hakuMenuOpenTrigger: "hover"}, appearance: {baseRadius: 12, surfaceTone: "dark", colorMode: "dark"},
        idle: {enabled: true, dimEnabled: true, dimTimeout: 300, dimPercent: 10,
            lockEnabled: true, lockTimeout: 30, displayOffEnabled: true, displayOffTimeout: 30,
            suspendEnabled: true, suspendTimeout: 300, respectAppInhibitors: true, inhibitOnAudio: false},
        roundedScreen: {radius: 20, borderThickness: 4},
        dock: {visibilityMode: "autohide", exclusiveSpace: false, iconSize: 36, hoverLift: 14, hoverScale: 0,
            showTrash: true, showDevices: true},
        topbar: {workspaces: true, windowTitle: true, center: true, cava: true, cavaStyle: "box", tray: true,
            quickControls: true, drawerOptions: true, clock: true, notifications: true,
            centerPromptEnabled: true, centerPromptInterval: 300, centerPromptDuration: 10,
            centerPromptList: [
                "System nominal. Ready when you are!",
                "May your coffee be strong and your builds green :)",
                "Still procrastinating, or is this 'research'? o_O",
                "Hydrate. Unclench your jaw. Fix your posture. :O",
                "Time for a sip of water. Stay hydrated. :D",
                "Blink more. Give your eyes a quick rest. :(",
                "Posture check: sit up straight, drop shoulders. ^_^"
            ]}}
}
