pragma Singleton
import QtQuick
import Quickshell

QtObject {
    id: root

    readonly property string home: Quickshell.env("HOME") || ""
    readonly property string configDir: home + "/.config/hakuspace"
    readonly property string stateDir: home + "/.local/state/hakuspace/state"
    readonly property string themeDir: home + "/.local/state/hakuspace/theme"
    readonly property string binDir: home + "/.local/bin"
    readonly property string runtimeDir: Quickshell.env("XDG_RUNTIME_DIR") || ("/run/user/" + Quickshell.env("UID"))
}
