import QtQuick
import "../../services"

Item {
    id: root
    property Item anchorItem: null
    property bool shown: false
    property Component content: null
    property var contentProps: ({})
    property var contentKey: null
    property real maxWidth: 360
    
    enum AttachMode { Top, Left, Right, Bottom }
    property int attach: FlareHost.Top
    
    property alias start: morph.mStart
    property alias end: morph.mEnd
    property alias currentHeight: morph.mHeight
    property alias hugging: morph.hugging
    signal settled(bool isShown)
    
    property var wBounds: FlareEdges.getBounds(root.width)
    
    FlareMorph {
        id: morph
        anchorItem: root.anchorItem
        shown: root.shown
        contentW: contentItem.naturalWidth
        contentH: contentItem.naturalHeight
        bounds: root.wBounds
        maxW: root.maxWidth
        snap: 2 * Theme.tipHugRadius
        onSettled: function(s) { root.settled(s); contentItem.settle(s); }
    }
    
    FlareSurface {
        id: surface
        start: morph.mStart
        end: morph.mEnd
        currentHeight: morph.mHeight
        bounds: root.wBounds
        r: Theme.tipRadius
        rf: Theme.tipHugRadius
        surfaceColor: Theme.barColor
        
        FlareContent {
            id: contentItem
            shown: root.shown
            anchors.centerIn: parent
            contentComponent: root.content
            contentProps: root.contentProps
            contentKey: root.contentKey
            maxWidth: root.maxWidth
        }
    }
}
