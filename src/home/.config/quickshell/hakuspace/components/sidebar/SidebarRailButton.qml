import QtQuick
import "../../services"

SidebarMorphButton {
    id: root
    property string tooltip: ""
    property Item tooltipHost: null
    radius: width / 2
    fontSize: Math.round(width * 0.45)
    selectedOverridesHover: false

    Rectangle {
        parent: root.tooltipHost || root
        visible: root.hovered && root.tooltip.length > 0
        x: root.hovered ? root.mapToItem(parent, root.width + 12, root.height / 2).x : -1000
        y: root.hovered ? root.mapToItem(parent, root.width + 12, root.height / 2).y - height / 2 : -1000
        width: tip.implicitWidth + 18
        height: tip.implicitHeight + 10
        radius: Theme.radius
        color: Theme.surface
        border.color: Theme.hoverMuted
        border.width: 1
        z: 100
        Text {
            id: tip
            anchors.centerIn: parent
            text: root.tooltip
            color: Theme.fg
            font.family: Theme.fontFamily
            font.pixelSize: Math.max(10, Theme.fontSize - 3)
        }
    }
}
