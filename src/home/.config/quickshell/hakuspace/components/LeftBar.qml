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
    // RoundedScreen owns the only left exclusive zone; bound width to rail + tooltip headroom.
    anchors { top: true; bottom: true; left: true }
    implicitWidth: Math.min(root.modelData ? root.modelData.width : 580, Math.ceil(ScreenGeometry.contentLeftEdge + 500 + ScreenGeometry.borderThickness * 2))
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "hakuspace-leftbar"
    readonly property bool statusActive: BarTransitionState.hostActive ? (BarTransitionState.visualEdge === "left") : ChromeLayout.leftBarMode
    color: "transparent"
    visible: BarTransitionState.leftWindowMapped
    contentItem.visible: root.statusActive
    mask: Region { item: root.statusActive ? bar : null }

    Rectangle {
        id: bar
        visible: root.statusActive
        width: ScreenGeometry.leftBarWidth
        height: parent.height
        color: Theme.surface
        Bar.LeftStatusModules {
            anchors.fill: parent
            screenName: root.modelData.name
            ownerWindow: root
            opacity: BarTransitionState.hostActive ? BarTransitionState.modulesOpacity : 1
        }
    }
    TooltipLayer {
        anchors.fill: parent
        leftAttached: true
        screenName: root.modelData.name
    }
}
