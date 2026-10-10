import QtQuick
import "../flare" as Flare
import "../../services"

Item {
    id: root

    property real bodyWidth: 0
    property real bodyHeight: 0
    property real frameThickness: FlareEdges.thickness
    property real frameTop: FlareEdges.topOriginY
    property real bottomFlareReach: Theme.tipHugRadius
    property real flareRadius: Theme.tipRadius
    property real screenWidth: 1920
    property real screenHeight: 1080
    property color surfaceColor: Theme.barColor
    property real cornerRadius: Theme.radius + 8

    readonly property var frameBounds: FlareEdges.getBounds(screenWidth)

    // The Flare body ends at bodyWidth - flareRadius so the right ear
    // finishes exactly at bodyWidth (staying strictly inside envelope).
    readonly property real bodyEnd: Math.max(0, bodyWidth - flareRadius)
    readonly property real earRadius: flareSurface.earEndRadius
    readonly property real flareBodyHeight: Math.max(0, bodyHeight - frameTop - bottomFlareReach)

    width: bodyWidth
    height: bodyHeight

    // 1. Top bridge connecting screen top / TopBar origin to the frameTop seam.
    // It spans the full envelope width so the right ear attaches smoothly at frameTop.
    Rectangle {
        id: topBridge
        x: 0
        y: 0
        width: root.bodyWidth
        height: root.frameTop + 1 // 1px overlap covers subpixel antialiasing hairline
        color: root.surfaceColor
        z: 1
    }

    // 2. Left border bridge connecting screen left edge to RoundedScreen inner seam (4px)
    Rectangle {
        id: leftBorderBridge
        x: 0
        y: 0
        width: root.frameThickness
        height: root.bodyHeight
        color: root.surfaceColor
        z: 1
    }

    // 3. Shared FlareSurface starting at the frameTop seam below TopBar.
    // Anchored at frameThickness (4px) on the left to seamlessly hug the RoundedScreen border.
    Flare.FlareSurface {
        id: flareSurface
        x: 0
        y: root.frameTop
        width: root.bodyWidth
        height: Math.max(0, root.bodyHeight - root.frameTop)
        start: root.frameThickness
        end: root.bodyEnd
        currentHeight: root.flareBodyHeight
        bounds: root.frameBounds
        r: root.flareRadius
        rf: root.bottomFlareReach
        bottomRadius: root.cornerRadius
        surfaceColor: root.surfaceColor
        z: 2
    }
}
