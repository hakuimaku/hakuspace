import QtQuick
import "../services"
import "base"
import "appbar"

FlarePanelWindow {
    id: root
    readonly property var menuState: UiState.appMenu
    panelOpen: UiState.activePanel === "appMenu" && menuState !== null
               && menuState.screenName === modelData.name
    forceBottomAttached: true
    anchorRect: menuState ? menuState.anchorRect : null
    panelComponent: menuComponent
    panelProps: ({ app: menuState ? menuState.app : null,
                   screenName: modelData.name })
    panelKey: menuState ? menuState.app : null
    onDismissed: UiState.closeAppMenu()

    Component {
        id: menuComponent
        AppBarMenuContent {
            onDismissed: UiState.closeAppMenu()
        }
    }
}
