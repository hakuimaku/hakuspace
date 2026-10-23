import QtQuick
import Quickshell
import Quickshell.Wayland
import "../services"
import "bar" as Bar
import "base"

PanelWindow {
    id: root
    required property var modelData
    screen: modelData

    property real barH: Theme.topBarHeight
    property real tipAreaH: 180
    // The wallpaper sidebar clears only the right module lane on its output.
    readonly property bool wallpaperOverlayOpen: ChromeLayout.topBarMode && UiState.activePanel === "wallpaper"
        && UiState.wallpaperScreenName === modelData.name
    // Keep a stable drawing plane while tooltip and OSD geometry animates inside it.
    anchors { top: true; bottom: true; left: true; right: true }
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "hakuspace-bar"

    // Keep visuals and live tooltip anchors screen-local on every compositor.
    exclusionMode: ExclusionMode.Ignore
    // Reserve the upper chassis separately from the full-width visual window.
    PanelWindow {
        screen: root.modelData
        anchors { top: true; left: true; right: true }
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "hakuspace-bar-reservation"
        color: "transparent"
        implicitHeight: root.barH
        exclusiveZone: root.barH
        visible: root.visible
        mask: Region {}
    }

    color: "transparent"
    visible: ChromeLayout.topStatusBarVisible

    mask: Region { item: barBg }

    // Primary background chassis and container of the top status bar.
    Rectangle {
        id: barBg
        width: parent.width
        height: root.barH
        color: Theme.surface
        border.width: Theme.borderWidth
        border.color: Theme.border

        Bar.StatusModules {
            objectName: "topbarModules"
            showRightCluster: !root.wallpaperOverlayOpen
            ownerWindow: root
            screenName: root.modelData.name
        }
    }

    Bar.LevelOsdBridge {
        id: osdSurface
        y: ScreenGeometry.chromeAttachmentY(root.modelData.height)
    }

    SafeZoneDebugOverlay {
        anchors.fill: parent
        screenWidth: root.modelData.width
        screenHeight: root.modelData.height
        anchorRect: TooltipManager.current ? ScreenGeometry.itemRect(TooltipManager.current.target) : null
        localizedAnchorRect: anchorRect
        flareStart: osdSurface.start
        flareEnd: osdSurface.end
    }

    TooltipLayer {
        id: tooltipLayer
        y: Theme.topBarHeight
        tipAreaHeight: root.tipAreaH
    }
}
