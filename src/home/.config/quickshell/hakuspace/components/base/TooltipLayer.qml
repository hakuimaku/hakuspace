import QtQuick
import QtQuick.Window
import "../../services"
import "../flare"

Item {
    id: root
    width: parent.width
    height: parent.tipAreaH
    
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
        contentProps: ({ payload: TooltipManager.current, maxWidth: 400 })
        contentKey: TooltipManager.current ? TooltipManager.current.target : null
        maxWidth: 400
    }
    
    Component {
        id: textComp
        Text {
            property var payload: null
            property real maxWidth: 400
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
