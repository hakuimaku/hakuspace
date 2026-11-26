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

    readonly property bool statusActive: BarTransitionState.hostActive ? (BarTransitionState.visualEdge === "top") : ChromeLayout.topStatusBarVisible
    contentItem.visible: root.statusActive

    property real barH: Theme.topBarHeight
    property real tipAreaH: 220
    // Bound the drawing plane to bar + tooltip/OSD headroom while keeping screen-origin (0, 0).
    anchors { top: true; left: true; right: true }
    implicitHeight: Math.ceil(root.barH + root.tipAreaH)
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
        visible: ChromeLayout.topStatusBarVisible
        mask: Region {}
    }

    color: "transparent"
    visible: BarTransitionState.topWindowMapped

    mask: Region { item: root.statusActive ? barBg : null }

    // Primary background chassis and container of the top status bar.
    Rectangle {
        id: barBg
        visible: root.statusActive
        width: parent.width
        height: root.barH
        color: Theme.surface
        border.width: Theme.borderWidth
        border.color: Theme.border

        Bar.StatusModules {
            objectName: "topbarModules"
            ownerWindow: root
            screenName: root.modelData.name
            opacity: BarTransitionState.hostActive ? BarTransitionState.modulesOpacity : 1
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
