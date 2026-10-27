pragma Singleton
import QtQuick
import Quickshell

QtObject {
    id: root

    // Paths are relative to the directory containing shell.qml.
    readonly property string stateDir: Quickshell.shellPath("../../../.local/state/hakuspace/state")

    // Canonical paths shared by watchers and menu indicators.
    readonly property string stateIdleInhibited: stateDir + "/[system].idle-inhibit.enabled"
    readonly property string stateShellBackend: stateDir + "/[shell].backend"
    readonly property string stateDesktopWaybarRequested: stateDir + "/[desktop].waybar.requested"
    readonly property string stateDesktopTaskbarRequested: stateDir + "/[desktop].taskbar.requested"
    readonly property string stateDesktopDockbarRequested: stateDir + "/[desktop].dockbar.requested"
    readonly property string stateDesktopIconsEnabled: stateDir + "/[desktop].icons.enabled"
    readonly property string stateWallpaperCurrent: stateDir + "/[desktop].wallpaper.current.json"
    readonly property string stateWallpaperRuntime: stateDir + "/[desktop].wallpaper.runtime.json"
    readonly property string stateThemeOpaqueEnabled: stateDir + "/[theme].opaque.enabled"
    readonly property string stateCavaEnabled: stateDir + "/[cava].enabled"
    readonly property string stateCavaPosition: stateDir + "/[cava].position"
    readonly property string stateCavaDynamicPosition: stateDir + "/[cava].dynamic-position"
    readonly property string stateCavaColorMode: stateDir + "/[cava].color-mode"
    readonly property string stateCavaHeight: stateDir + "/[cava].height"
    readonly property string themeDir: Quickshell.shellPath("../../../.local/state/hakuspace/theme")
    readonly property string binDir: Quickshell.shellPath("../../../.local/bin")
    readonly property string cavaConfig: Quickshell.shellPath("../../cava/config_waybar")
}
