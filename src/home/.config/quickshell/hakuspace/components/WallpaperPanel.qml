import QtQuick
import Quickshell
import Quickshell.Wayland
import "../services"
import "hakumenu" as HakuMenu

// Standalone Hikai wallpaper changer surface.
// W3.5 intentionally keeps the existing W2/W3 carousel presentation intact,
// but detaches it from HakuMenu so W4/W5 can be debugged in isolation.
PanelWindow {
    id: root
    required property var modelData

    readonly property bool panelOpen: UiState.activePanel === "wallpaper"
                                      && UiState.wallpaperScreenName === modelData.name
    readonly property bool panelClosing: panelOpen && UiState.wallpaperCloseRequested
    readonly property real carouselWidth: Math.min(modelData.width * 0.58, 980)
    readonly property real carouselHeight: Math.min(modelData.height * 0.52, 560)

    screen: modelData
    anchors { top: true; bottom: true; left: true; right: true }
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "hakuspace-wallpaper"
    WlrLayershell.keyboardFocus: panelOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0
    color: "transparent"
    visible: panelOpen

    // Fullscreen input mask while panel is open / closing animation is running.
    mask: Region {
        width: root.panelOpen ? root.modelData.width : 0
        height: root.panelOpen ? root.modelData.height : 0
    }

    Component.onDestruction: UiState.forceCloseWallpaperIfScreen(modelData.name)

    onPanelClosingChanged: {
        if (!panelOpen) return
        if (panelClosing)
            carousel.beginCloseAnimation()
        else if (carousel.closing)
            carousel.cancelCloseAnimation()
    }

    // Dim modal scrim behind wallpaper UI
    Rectangle {
        id: scrim
        anchors.fill: parent
        color: Theme.scrim
        opacity: 0.22 * carousel.openOpacity * carousel.closeOpacity
    }

    // Outside-dismiss layer: clicking outside the centered controls closes the panel
    MouseArea {
        id: outsideDismiss
        anchors.fill: parent
        enabled: root.panelOpen && !root.panelClosing
        acceptedButtons: Qt.LeftButton
        onClicked: UiState.closeWallpaper()
    }

    Item {
        id: keyHandler
        anchors.fill: parent
        focus: root.panelOpen && !carousel.searchFocused
        Keys.onTabPressed: event => {
            carousel.focusSearch()
            event.accepted = true
        }
        Keys.onEscapePressed: event => {
            UiState.closeWallpaper()
            event.accepted = true
        }
        Keys.onLeftPressed: event => {
            if (carousel.searchFocused) return
            if (!carousel.interactionReady) { event.accepted = true; return }
            if (event.modifiers & Qt.ControlModifier)
                carousel.switchKind("static")
            else
                carousel.selectPrevious()
            event.accepted = true
        }
        Keys.onRightPressed: event => {
            if (carousel.searchFocused) return
            if (!carousel.interactionReady) { event.accepted = true; return }
            if (event.modifiers & Qt.ControlModifier)
                carousel.switchKind("lively")
            else
                carousel.selectNext()
            event.accepted = true
        }
        Keys.onReturnPressed: event => {
            if (!carousel.interactionReady) { event.accepted = true; return }
            if (carousel.acceptSelected())
                event.accepted = true
        }
        Keys.onEnterPressed: event => {
            if (!carousel.interactionReady) { event.accepted = true; return }
            if (carousel.acceptSelected())
                event.accepted = true
        }
    }

    Item {
        id: carouselHost
        anchors.centerIn: parent
        width: root.carouselWidth
        height: root.carouselHeight

        HakuMenu.WallpaperCarousel {
            id: carousel
            anchors.fill: parent
            visible: root.panelOpen
            onRequestFocusCarousel: keyHandler.forceActiveFocus()
            onApplyAccepted: UiState.closeWallpaper()
            onCloseAnimationFinished: UiState.finishCloseWallpaper(root.modelData.name)
        }
    }
}
