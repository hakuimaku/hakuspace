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
    // RoundedScreen owns the only left exclusive zone; this drawing plane stays stable.
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "hakuspace-leftbar"
    color: "transparent"
    visible: ChromeLayout.leftBarMode
    contentItem.visible: ChromeLayout.leftBarMode
    mask: Region { item: bar }

    Rectangle {
        id: bar
        width: ScreenGeometry.leftBarWidth
        height: parent.height
        color: Theme.surface
        Bar.LeftStatusModules {
            anchors.fill: parent
            screenName: root.modelData.name
            ownerWindow: root
        }
    }
    TooltipLayer {
        anchors.fill: parent
        leftAttached: true
        screenName: root.modelData.name
    }
}
