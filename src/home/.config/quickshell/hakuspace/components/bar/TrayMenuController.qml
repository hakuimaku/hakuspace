import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import "../../services"

Item {
    id: root
    // Forward native menus to the window that actually owns the tray anchor.
    required property var ownerWindow
    required property string screenName
    property var trayMenuItem: null
    property Item trayMenuAnchor: null
    property string lastTrayFallbackReason: ""
    readonly property int trayRowCount: trayOpener.children.values.length
    onTrayRowCountChanged: {
        if (trayMenuItem && trayRowCount > 0) menuSettled.restart()
    }

    // Cleans up active tray popup state and stops pending resolution timers.
    function closeTrayMenu() {
        menuTimeout.stop()
        menuSettled.stop()
        trayMenuItem = null
        trayMenuAnchor = null
    }

    // Falls back to native platform context menu or secondary activation for tray item.
    function platformMenu(item, anchor, reason) {
        lastTrayFallbackReason = reason
        if (!item || !anchor) return
        if (item.hasMenu) {
            var point = anchor.mapToItem(null, 0, ScreenGeometry.bottomAttached ? 0 : anchor.height)
            item.display(root.ownerWindow, point.x, point.y)
        } else {
            item.secondaryActivate()
        }
    }

    // Handles tray item click: opens native menu, dismisses existing, or prepares custom popup.
    function requestTrayMenu(item, anchor) {
        if (UiState.trayMenu && UiState.trayMenu.item === item) {
            UiState.closeTrayMenu()
            return
        }
        if (trayMenuItem === item) {
            closeTrayMenu()
            return
        }
        closeTrayMenu()
        if (UiState.activePanel !== "") UiState.activePanel = ""
        UiState.closeTrayMenu()
        if (!item || !item.hasMenu || !item.menu) {
            platformMenu(item, anchor, "no menu handle")
            return
        }
        TooltipManager.dismiss()
        trayMenuItem = item
        trayMenuAnchor = anchor
        menuTimeout.restart()
        if (trayRowCount > 0) menuSettled.restart()
    }

    // Dispatches request to open custom flare tray menu panel anchored to tray item.
    function openTrayPanel() {
        if (!trayMenuItem || !trayMenuAnchor) return
        var item = trayMenuItem
        var anchor = trayMenuAnchor
        var anchorRect = ScreenGeometry.itemRect(anchor)
        closeTrayMenu()
        UiState.openTrayMenu(item, item.menu, root.screenName, anchorRect)
    }

    // Evaluates loaded tray menu rows and opens tray menu once content has populated.
    function resolveTrayMenu() {
        if (!trayMenuItem) return
        var rows = trayOpener.children.values
        if (!rows || rows.length === 0) return
        menuTimeout.stop()
        openTrayPanel()
    }

    QsMenuOpener {
        id: trayOpener
        menu: root.trayMenuItem ? root.trayMenuItem.menu : null
    }

    Timer {
        id: menuSettled
        interval: 100
        onTriggered: root.resolveTrayMenu()
    }

    Timer {
        id: menuTimeout
        interval: 1500
        onTriggered: {
            if (!root.trayMenuItem) return
            root.resolveTrayMenu()
            if (!root.trayMenuItem) return
            var item = root.trayMenuItem
            var anchor = root.trayMenuAnchor
            root.closeTrayMenu()
            root.platformMenu(item, anchor, "root menu empty after 1500 ms")
        }
    }

    Connections {
        target: SystemTray.items
        function onObjectRemovedPre(object, index) {
            if (object === root.trayMenuItem) root.closeTrayMenu()
            UiState.closeTrayMenuIfItem(object)
        }
    }

    Connections {
        target: ShellSettingsStore
        // Clear pending and open tray ownership before the hidden row can be reused.
        function onShowTrayChanged() {
            if (ShellSettingsStore.showTray) return
            root.closeTrayMenu()
            UiState.closeTrayMenuIfScreen(root.screenName)
        }
        function onValuesChanged() {
            if (TooltipManager.activeBar === root.ownerWindow) TooltipManager.dismiss()
        }
    }

    Connections {
        target: UiState
        function onActivePanelChanged() {
            if (UiState.activePanel !== "") root.closeTrayMenu()
        }
    }

    Connections {
        target: ChromeLayout
        function onTaskbarModeChanged() { root.closeTrayMenu() }
    }
    Component.onDestruction: {
        closeTrayMenu()
        UiState.closeTrayMenuIfScreen(screenName)
    }
}
