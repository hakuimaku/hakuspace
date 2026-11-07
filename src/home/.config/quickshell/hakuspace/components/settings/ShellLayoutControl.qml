import QtQuick
import "../../services"

Column {
    id: root
    // Taskbar remains reachable while the status-edge row disappears from keyboard traversal.
    property Item shortcutTarget: null
    spacing: Theme.spaceSm
    SettingsSwitch {
        width: parent.width
        text: "Taskbar Mode"
        checked: ChromeLayout.taskbarMode
        shortcutTarget: root.shortcutTarget
        enabled: AppState.shellBackend === "hikai" && ShellSettingsStore.ready && !SettingsCoordinator.busy
        onToggled: value => SettingsCoordinator.set("layout", value ? "taskbar" : ShellSettingsStore.statusEdge === "left" ? "leftbar" : "topbar")
    }
    StatusEdgeControl { width: parent.width; shortcutTarget: root.shortcutTarget }
    Text {
        width: parent.width
        visible: ChromeLayout.taskbarMode && !!SettingsCoordinator.runtimeError
        text: SettingsCoordinator.runtimeError
        color: Theme.danger
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize - 2
        wrapMode: Text.Wrap
    }
}
