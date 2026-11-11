import QtQuick
import "../../services"
import "../../config/UiCatalog.js" as UiCatalog

Column {
    id: root
    // Both surfaces show confirmed topology; failed writes never move the selected segment.
    property Item shortcutTarget: null
    readonly property bool available: AppState.shellBackend === "hikai"
    visible: available
    spacing: Theme.spaceXs
    SettingsSegmentedControl {
        width: parent.width
        options: UiCatalog.statusBarLayouts
        value: ChromeLayout.taskbarMode ? "taskbar" : ChromeLayout.leftBarMode ? "leftbar" : "topbar"
        shortcutTarget: root.shortcutTarget
        enabled: ShellSettingsStore.ready && !SettingsCoordinator.busy
        onChosen: value => SettingsCoordinator.set("layout", value)
    }
    Text {
        width: parent.width
        visible: !!SettingsCoordinator.runtimeError
        text: SettingsCoordinator.runtimeError
        color: Theme.danger
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize - 2
        wrapMode: Text.Wrap
    }
}
