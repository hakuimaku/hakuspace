import QtQuick
import QtQuick.Window
import "../../services"
import "../flare"

Item {
    id: root
    width: parent.width
    property real tipAreaHeight: 160
    height: tipAreaHeight
    readonly property real maxTooltipWidth: Math.min(500, Math.max(0, width - FlareEdges.thickness * 2))
    readonly property real horizontalPadding: 22
    readonly property real maxTextWidth: Math.max(0, maxTooltipWidth - horizontalPadding * 2)
    property bool menuShown: false
    property Item menuAnchor: null
    property var menuHandle: null
    readonly property real menuMaxHeight: Math.max(0, height - 16)
    property alias menuStart: flare.start
    property alias menuEnd: flare.end
    property alias menuHeight: flare.currentHeight
    signal menuDismissed()
    
    property var windowRoot: {
        var p = root;
        while(p && p.parent) p = p.parent;
        return p;
    }
    visible: menuShown || TooltipManager.activeBar === windowRoot
    
    FlareHost {
        id: flare
        anchors.fill: parent
        anchorItem: root.menuShown ? root.menuAnchor : (TooltipManager.current ? TooltipManager.current.target : null)
        shown: root.menuShown || (TooltipManager.shown && root.visible)
        content: root.menuShown ? menuComp : (TooltipManager.current ? (TooltipManager.current.component || textComp) : null)
        contentProps: root.menuShown
            ? ({ menuHandle: root.menuHandle, maxHeight: root.menuMaxHeight })
            : ({ payload: TooltipManager.current, maxWidth: root.maxTextWidth })
        contentKey: root.menuShown ? root.menuHandle : (TooltipManager.current ? TooltipManager.current.target : null)
        maxWidth: root.menuShown ? 320 : root.maxTooltipWidth
        horizontalPadding: root.horizontalPadding
    }

    Component {
        id: menuComp
        MenuContent { onDismissed: root.menuDismissed() }
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
