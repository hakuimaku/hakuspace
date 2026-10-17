import QtQuick
import "../flare" as Flare
import "../../services"

Item {
    id: root

    property real bodyWidth: 0
    property real bodyHeight: 0
    property real sideInset: ScreenGeometry.leftInset
    property real attachmentY: ScreenGeometry.flareTopY
    property real bottomFlareReach: Theme.hugRadius
    property real flareRadius: Theme.largeRadius + 8
    property real screenWidth: 1920
    property real screenHeight: 1080
    property color surfaceColor: Theme.surface
    property real cornerRadius: Theme.largeRadius + 8

    readonly property var horizontalBounds: ScreenGeometry.horizontalBounds(screenWidth)

    // The Flare body ends at bodyWidth - flareRadius so the right ear
    // finishes exactly at bodyWidth (staying strictly inside envelope).
    readonly property real bodyEnd: Math.max(0, bodyWidth - flareRadius)
    readonly property real earRadius: flareSurface.earEndRadius
    readonly property real flareBodyHeight: Math.max(0, bodyHeight - attachmentY - bottomFlareReach)

    width: bodyWidth
    height: bodyHeight

    // 1. Top bridge connecting screen top / TopBar origin to the attachmentY seam.
    // It spans the full envelope width so the right ear attaches smoothly at attachmentY.
    Rectangle {
        id: topBridge
        x: 0
        y: 0
        width: root.bodyWidth
        height: root.attachmentY
        color: root.surfaceColor
        z: 1
    }

    // 2. Left border bridge connecting screen left edge to RoundedScreen inner side seam
    Rectangle {
        id: leftBorderBridge
        x: 0
        y: 0
        width: root.sideInset
        height: root.bodyHeight
        color: root.surfaceColor
        z: 1
    }

    // 3. Shared FlareSurface starting at the attachmentY seam below TopBar.
    // Anchored at the shared side inset on the left to seamlessly hug the RoundedScreen border.
    Flare.FlareSurface {
        id: flareSurface
        x: 0
        y: root.attachmentY
        width: root.bodyWidth
        height: Math.max(0, root.bodyHeight - root.attachmentY)
        start: root.sideInset
        end: root.bodyEnd
        currentHeight: root.flareBodyHeight
        bounds: root.horizontalBounds
        r: root.flareRadius
        rf: root.bottomFlareReach
        bottomRadius: root.cornerRadius
        surfaceColor: root.surfaceColor
        z: 2
    }
}
