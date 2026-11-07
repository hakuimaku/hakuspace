import QtQuick
import QtQuick.Window
import "../../services"
import "../flare"

Item {
    id: root
    readonly property var horizontalBounds: ScreenGeometry.horizontalBounds(width)
    width: parent.width
    // Side tooltips share the same content and calendar components.
    property bool leftAttached: false
    property string screenName: ""
    property real sideAttachmentX: ScreenGeometry.contentLeftEdge
    property bool bottomAttached: false
    property real tipAreaHeight: 180
    height: tipAreaHeight
    property real minimumTooltipWidth: 0
    readonly property real maxTooltipWidth: Math.min(Math.max(500, minimumTooltipWidth), Math.max(0, horizontalBounds.end - horizontalBounds.start - (leftAttached ? sideAttachmentX : 0)))
    readonly property real horizontalPadding: 22
    readonly property real maxTextWidth: Math.max(0, maxTooltipWidth - horizontalPadding * 2)
    // Hug the physical content edges instead of creating a detached inset shelf.
    readonly property var sideBounds: ({start: ScreenGeometry.topBorderThickness,
        end: Math.max(ScreenGeometry.topBorderThickness, height - ScreenGeometry.bottomReservation(screenName))})
    readonly property real maxSideContentHeight: Math.max(1, sideBounds.end - sideBounds.start - 24)
    readonly property Item anchorTarget: menuShown ? menuAnchor : TooltipManager.current ? TooltipManager.current.target : null
    property bool menuShown: false
    property Item menuAnchor: null
    property var menuHandle: null
    readonly property real menuMaxHeight: Math.max(0, height - 16)
    property alias menuStart: flare.start
    property alias menuEnd: flare.end
    property alias menuHeight: flare.currentHeight
    // Allocate the target body before opening while retaining the animated closing extent.
    readonly property real surfaceHeight: Math.max(flare.currentHeight, flare.naturalContentHeight + flare.verticalPadding * 2)
    signal menuDismissed()
    
    property var windowRoot: {
        var p = root;
        while(p && p.parent) p = p.parent;
        return p;
    }
    visible: menuShown || TooltipManager.activeBar === windowRoot
    
    FlareHost {
        id: flare
        attach: root.leftAttached ? FlareHost.Left : root.bottomAttached ? FlareHost.Bottom : FlareHost.Top
        x: root.leftAttached ? root.sideAttachmentX : 0
        width: root.width - x
        height: root.height
        anchorItem: root.leftAttached ? null : root.anchorTarget
        // Mapping the rectangle also handles a rotated wallpaper toolbar exactly once.
        anchorRect: root.leftAttached && root.anchorTarget ? root.anchorTarget.mapToItem(root, 0, 0, root.anchorTarget.width, root.anchorTarget.height) : null
        hostRect: ({x: 0, y: 0, width: root.width, height: root.height})
        wBounds: root.leftAttached ? root.sideBounds : ScreenGeometry.horizontalBounds(width)
        shown: root.menuShown || (TooltipManager.shown && root.visible)
        content: root.menuShown ? menuComp : (TooltipManager.current ? (TooltipManager.current.component || textComp) : null)
        contentProps: root.menuShown
            ? ({ menuHandle: root.menuHandle, maxHeight: root.menuMaxHeight })
            : root.leftAttached ? ({payload: TooltipManager.current, maxWidth: root.maxTextWidth, maxHeight: root.maxSideContentHeight})
                : ({ payload: TooltipManager.current, maxWidth: root.maxTextWidth })
        contentKey: root.menuShown ? root.menuHandle : (TooltipManager.current ? TooltipManager.current.target : null)
        maxWidth: root.menuShown ? 320 : root.maxTooltipWidth
        horizontalPadding: root.horizontalPadding
        verticalPadding: root.menuShown ? 8 : 12
        contentFadeDuration: 0
    }

    Component {
        id: menuComp
        MenuContent { onDismissed: root.menuDismissed() }
    }
    
    Component {
        id: textComp
        Item {
            property var payload: null
            property real maxWidth: root.maxTextWidth
            property real maxHeight: Number.MAX_VALUE
            implicitWidth: Math.min(label.implicitWidth, maxWidth)
            implicitHeight: Math.min(label.implicitHeight, maxHeight)
            Flickable {
                anchors.fill: parent
                contentWidth: width; contentHeight: label.implicitHeight
                interactive: contentHeight > height
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                Text {
                    id: label
                    width: parent.width
                    text: payload && payload.text ? payload.text : ""
                    color: Theme.accent
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                }
            }
        }
    }
}
