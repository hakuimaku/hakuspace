pragma Singleton
import QtQuick
import Quickshell

QtObject {
    id: root

    // Paths are relative to the directory containing shell.qml.
    readonly property string stateDir: Quickshell.shellPath("../../../.local/state/hakuspace/state")
    readonly property string themeDir: Quickshell.shellPath("../../../.local/state/hakuspace/theme")
    readonly property string binDir: Quickshell.shellPath("../../../.local/bin")
    readonly property string cavaConfig: Quickshell.shellPath("../../cava/config_waybar")
    readonly property string roundedScreenConfig: Quickshell.shellPath("../../../hakucfg/config/rounded-screen.conf")
}
