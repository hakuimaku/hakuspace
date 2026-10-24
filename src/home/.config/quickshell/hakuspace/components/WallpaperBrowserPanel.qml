import QtQuick
import Quickshell
import Quickshell.Wayland
import "../services"
import "flare" as Flare
import "wallpaper" as Wallpaper

PanelWindow {
    id: root
    // Release only after the surface has finished its visual close.
    readonly property bool releaseReady: !panelOpen && expansion === 0 && !expansionAnimation.running
    required property var modelData
    // The sidebar and flares slide together while their owner retains the close sequence.
    readonly property bool panelOpen: UiState.activePanel === "wallpaper" && UiState.wallpaperScreenName === modelData.name
    readonly property bool closing: panelOpen && UiState.wallpaperCloseRequested
    readonly property real browserWidth: Math.min(520, modelData.width - ScreenGeometry.leftInset - ScreenGeometry.rightInset)
    // Match the Rounded Screen ceiling after the TopBar's exclusive reservation.
    readonly property real attachmentY: ChromeLayout.topBarMode ? Theme.topBarHeight : ScreenGeometry.topBorderThickness
    readonly property real attachmentBottom: modelData.height - ScreenGeometry.bottomInset - ScreenGeometry.taskbarReservation()
    readonly property real browserHeight: Math.max(0, attachmentBottom - attachmentY)
    property real expansion: 0
    readonly property real contentReveal: Math.max(0, Math.min(1, expansion))
    // Clear the outer flare ear completely before releasing the window.
    readonly property real slideDistance: browserWidth + ScreenGeometry.rightInset + Theme.largeRadius + 8
    // Translate a fixed-size body instead of resizing the browser's clipping rectangle.
    readonly property var currentRect: ({x: width - ScreenGeometry.rightInset - browserWidth + slideDistance * (1 - contentReveal),
        y: attachmentY, width: browserWidth, height: browserHeight})
    readonly property Item browserItem: browserLoader.item
    screen: modelData
    anchors { top: true; bottom: true; left: true; right: true }
    WlrLayershell.layer: ShellTransitionState.chromeOverlayLayer
    WlrLayershell.namespace: "hakuspace-wallpaper-browser"
    WlrLayershell.keyboardFocus: panelOpen && UiState.ownsInteraction("wallpaper", modelData.name) ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    // Observe presses before delegates handle them, then pass the event through.
    MouseArea {
        anchors.fill: parent
        z: 10000
        enabled: root.panelOpen && !UiState.nativeDialogOpen
        acceptedButtons: Qt.AllButtons
        onPressed: mouse => { UiState.claimInteraction("wallpaper", root.modelData.name); mouse.accepted = false }
    }
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0
    color: "transparent"
    visible: panelOpen || expansion > 0
    mask: Region { width: root.panelOpen ? root.width : 0; height: root.panelOpen ? root.height : 0 }
    // Keep the sidebar's opening and closing motion independent of its launcher.
    function animate() {
        if (!root) return
        expansionAnimation.stop()
        var opening = panelOpen && !closing
        if (expansion === (opening ? 1 : 0)) return
        expansionAnimation.duration = opening ? HAnimation.normal : HAnimation.fast
        expansionAnimation.easing.bezierCurve = opening ? HAnimation.moduleCurve : HAnimation.tooltipCurve
        expansionAnimation.to = opening ? 1 : 0
        expansionAnimation.start()
    }
    onPanelOpenChanged: Qt.callLater(animate)
    onClosingChanged: Qt.callLater(animate)
    Component.onCompleted: Qt.callLater(animate)
    // A retired surface must not close its replacement on the same output.
    Component.onDestruction: {
        if (!ShellTransitionState.chromeEnabled || !Quickshell.screens.includes(modelData))
            UiState.forceCloseWallpaperIfScreen(modelData.name)
    }
    NumberAnimation {
        id: expansionAnimation
        target: root; property: "expansion"
        easing.type: Easing.BezierSpline
        onFinished: if (root.closing) UiState.finishCloseWallpaper(root.modelData.name)
    }
    Rectangle { anchors.fill: parent; color: "black"; opacity: root.contentReveal * 0.08 }
    MouseArea { anchors.fill: parent; onClicked: UiState.closeWallpaper() }
    // One clipped drawing plane keeps the chassis, flares and thumbnails on the same frame.
    Item {
        anchors.fill: parent
        clip: true
        Rectangle {
            id: sidebar
            x: root.currentRect.x
            y: root.currentRect.y
            width: root.currentRect.width
            height: root.currentRect.height
            color: Theme.surface
            // Keep the resting silhouette fixed while the whole sidebar translates.
            Repeater {
                model: [Flare.FlareHost.Top, Flare.FlareHost.Bottom]
                delegate: Flare.FlareSurface {
                    required property int modelData
                    objectName: modelData === Flare.FlareHost.Top ? "wallpaperTopFlare" : "wallpaperBottomFlare"
                    width: sidebar.width
                    y: bottomAttached ? sidebar.height : 0
                    attach: modelData
                    start: 0
                    end: sidebar.width
                    currentHeight: sidebar.height / 2 + 1
                    bounds: ({start: ScreenGeometry.leftInset - (root.width - ScreenGeometry.rightInset - root.browserWidth),
                        end: root.browserWidth})
                    r: Theme.giantRadius + 8
                    bottomRadius: 0
                    rf: Theme.hugRadius
                    surfaceColor: Theme.surface
                }
            }
            MouseArea { anchors.fill: parent; onClicked: {} }
            Loader {
                id: browserLoader
                anchors.fill: parent
                clip: true
                active: root.panelOpen || root.expansion > 0
                enabled: root.panelOpen && root.expansion > 0.95 && !root.closing
                onLoaded: if (root.panelOpen && !root.closing) item.forceActiveFocus()
                sourceComponent: Wallpaper.WallpaperBrowser {
                    onCloseRequested: UiState.closeWallpaper()
                    onSettingsRequested: { UiState.settingsGroup = "Wallpaper"; UiState.openSettings(root.modelData.name) }
                }
            }
        }
    }
}
