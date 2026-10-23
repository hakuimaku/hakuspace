import QtQuick
import Quickshell
import Quickshell.Wayland
import "../services"
import "flare" as Flare
import "wallpaper" as Wallpaper

PanelWindow {
    id: root
    required property var modelData
    // The solid sidebar grows from the right edge and retains input until its flares close.
    readonly property bool panelOpen: UiState.activePanel === "wallpaper" && UiState.wallpaperScreenName === modelData.name
    readonly property bool closing: panelOpen && UiState.wallpaperCloseRequested
    readonly property real browserWidth: Math.min(520, modelData.width - ScreenGeometry.leftInset - ScreenGeometry.rightInset)
    // Match the Rounded Screen ceiling after the TopBar's exclusive reservation.
    readonly property real attachmentY: ChromeLayout.topBarMode ? Theme.topBarHeight : ScreenGeometry.topBorderThickness
    readonly property real attachmentBottom: modelData.height - ScreenGeometry.bottomInset - ScreenGeometry.taskbarReservation()
    readonly property real browserHeight: Math.max(0, attachmentBottom - attachmentY)
    property real expansion: 0
    readonly property real contentReveal: Math.max(0, Math.min(1, expansion))
    // Every entry point opens the sidebar independently from the right screen edge.
    readonly property var currentRect: ({x: width - ScreenGeometry.rightInset - browserWidth * expansion,
        y: attachmentY, width: browserWidth * expansion, height: browserHeight})
    readonly property Item browserItem: browserLoader.item
    screen: modelData
    anchors { top: true; bottom: true; left: true; right: true }
    WlrLayershell.layer: ShellTransitionState.chromeOverlayLayer
    WlrLayershell.namespace: "hakuspace-wallpaper-browser"
    WlrLayershell.keyboardFocus: panelOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0
    color: "transparent"
    visible: panelOpen
    mask: Region { width: root.panelOpen ? root.width : 0; height: root.panelOpen ? root.height : 0 }
    // Keep the sidebar's opening and closing motion independent of its launcher.
    function animate() {
        expansionAnimation.stop()
        expansionAnimation.duration = closing ? HAnimation.hakuMenuCloseDuration : HAnimation.hakuMenuOpenDuration
        expansionAnimation.easing.bezierCurve = closing ? HAnimation.hakuMenuCloseCurve : HAnimation.hakuMenuOpenCurve
        expansionAnimation.to = panelOpen && !closing ? 1 : 0
        expansionAnimation.start()
    }
    onPanelOpenChanged: if (panelOpen) { expansion = 0; animate() }
    onClosingChanged: animate()
    Component.onDestruction: UiState.forceCloseWallpaperIfScreen(modelData.name)
    NumberAnimation {
        id: expansionAnimation
        target: root; property: "expansion"
        easing.type: Easing.BezierSpline
        onFinished: if (root.closing) UiState.finishCloseWallpaper(root.modelData.name)
    }
    Rectangle { anchors.fill: parent; color: "black"; opacity: root.contentReveal * 0.08 }
    MouseArea { anchors.fill: parent; onClicked: UiState.closeWallpaper() }
    // Mirrored flares join the left edge to the Rounded Screen ceiling and floor.
    PanelWindow {
        screen: root.modelData
        anchors { top: true; bottom: true; left: true; right: true }
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "hakuspace-wallpaper-flare"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore
        exclusiveZone: 0
        color: "transparent"
        visible: root.panelOpen
        mask: Region { width: 0; height: 0 }
        Repeater {
            model: [Flare.FlareHost.Top, Flare.FlareHost.Bottom]
            delegate: Flare.FlareSurface {
                required property int modelData
                objectName: modelData === Flare.FlareHost.Top ? "wallpaperTopFlare" : "wallpaperBottomFlare"
                width: root.width
                y: root.currentRect.y + (bottomAttached ? root.currentRect.height : 0)
                attach: modelData
                start: root.currentRect.x
                end: start + root.currentRect.width
                currentHeight: root.currentRect.height / 2 + 1
                bounds: ScreenGeometry.horizontalBounds(root.width)
                r: (Theme.largeRadius + 8) * root.contentReveal
                bottomRadius: 0
                rf: Theme.hugRadius
                surfaceColor: Theme.surface
            }
        }
    }
    Rectangle {
        x: root.currentRect.x
        y: root.currentRect.y
        width: root.currentRect.width
        height: root.currentRect.height
        color: Theme.surface
        clip: true
        MouseArea { anchors.fill: parent; onClicked: {} }
        Loader {
            id: browserLoader
            width: root.browserWidth; height: root.browserHeight
            anchors.right: parent.right
            active: root.panelOpen
            opacity: Math.max(0, (root.contentReveal - 0.2) / 0.8)
            enabled: root.expansion > 0.95 && !root.closing
            onLoaded: item.forceActiveFocus()
            sourceComponent: Wallpaper.WallpaperBrowser {
                reveal: root.contentReveal
                onCloseRequested: UiState.closeWallpaper()
                onSettingsRequested: { UiState.settingsGroup = "Wallpaper"; UiState.openSettings(root.modelData.name) }
            }
        }
    }
}
