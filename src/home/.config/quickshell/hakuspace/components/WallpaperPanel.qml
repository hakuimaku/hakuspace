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
    readonly property real carouselHeight: Math.min(modelData.height * 0.46, 520)

    screen: modelData
    anchors { top: true; bottom: true; left: true; right: true }
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "hakuspace-wallpaper"
    WlrLayershell.keyboardFocus: panelOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0
    color: "transparent"
    visible: panelOpen

    // The carousel and its floating mode switch receive pointer input.
    mask: Region {
        Region { item: carouselHost }
        Region { item: carousel.modeSwitchHitRegion }
    }

    Component.onDestruction: UiState.forceCloseWallpaperIfScreen(modelData.name)

    onPanelClosingChanged: {
        if (!panelOpen) return
        if (panelClosing)
            carousel.beginCloseAnimation()
        else if (carousel.closing)
            carousel.cancelCloseAnimation()
    }

    Item {
        id: keyHandler
        anchors.fill: parent
        focus: root.panelOpen
        Keys.onEscapePressed: {
            UiState.closeWallpaper()
            event.accepted = true
        }
        Keys.onLeftPressed: event => {
            if (!carousel.interactionReady) { event.accepted = true; return }
            if (event.modifiers & Qt.ControlModifier)
                carousel.switchKind("static")
            else
                carousel.selectPrevious()
            event.accepted = true
        }
        Keys.onRightPressed: event => {
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
            onApplyAccepted: UiState.closeWallpaper()
            onCloseAnimationFinished: UiState.finishCloseWallpaper(root.modelData.name)
        }
    }
}
