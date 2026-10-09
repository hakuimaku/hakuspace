import QtQuick
import QtQuick.Window
import "../../services"
import "../flare"

Item {
    id: root
    width: parent.width
    height: parent.tipAreaH
    readonly property real maxTooltipWidth: Math.min(500, Math.max(0, width - FlareEdges.thickness * 2))
    readonly property real horizontalPadding: 22
    readonly property real maxTextWidth: Math.max(0, maxTooltipWidth - horizontalPadding * 2)
    
    property var windowRoot: {
        var p = root;
        while(p && p.parent) p = p.parent;
        return p;
    }
    visible: TooltipManager.activeBar === windowRoot
    
    FlareHost {
        anchors.fill: parent
        anchorItem: TooltipManager.current ? TooltipManager.current.target : null
        shown: TooltipManager.shown && root.visible
        content: TooltipManager.current ? (TooltipManager.current.component || textComp) : null
        contentProps: ({ payload: TooltipManager.current, maxWidth: root.maxTextWidth })
        contentKey: TooltipManager.current ? TooltipManager.current.target : null
        maxWidth: root.maxTooltipWidth
        horizontalPadding: root.horizontalPadding
    }
    
    Component {
        id: textComp
        Text {
            property var payload: null
            property real maxWidth: root.maxTextWidth
            width: implicitWidth > maxWidth ? maxWidth : implicitWidth
            text: payload && payload.text ? payload.text : ""
            color: Theme.accent
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
        }
    }
}
