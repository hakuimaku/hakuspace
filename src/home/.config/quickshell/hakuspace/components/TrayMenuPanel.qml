import QtQuick
import "../services"
import "base"

FlarePanelWindow {
    id: root
    readonly property var menuState: UiState.trayMenu
    panelOpen: UiState.activePanel === "tray" && menuState !== null
               && menuState.screenName === modelData.name
    anchorX: menuState ? menuState.anchorX : 0
    anchorWidth: menuState ? menuState.anchorWidth : 0
    panelComponent: menuComponent
    panelProps: ({ menuHandle: menuState ? menuState.handle : null,
                   maxHeight: root.maxPanelContentHeight })
    panelKey: menuState ? menuState.item : null
    onDismissed: UiState.closeTrayMenu()

    Component {
        id: menuComponent
        MenuContent { onDismissed: UiState.closeTrayMenu() }
    }
}
