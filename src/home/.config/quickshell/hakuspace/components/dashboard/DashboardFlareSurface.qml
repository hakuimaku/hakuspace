import QtQuick
import QtQuick.Shapes
import "../flare" as Flare
import "../../services"

Item {
    id: root

    property bool leftAttached: false
    property real leftSeam: ScreenGeometry.leftChromeWidth
    property string screenName: ""
    property real topInset: ScreenGeometry.topBorderThickness
    property bool bottomAttached: false
    property real bodyWidth: 0
    property real bodyHeight: 0
    property real sideInset: ScreenGeometry.leftInset
    property real attachmentY: Theme.topBarHeight
    property real bottomFlareReach: Theme.hugRadius
    property real flareRadius: Theme.largeRadius + 8
    property real screenWidth: 1920
    property real screenHeight: 1080
    property color surfaceColor: Theme.surface
    property real cornerRadius: Theme.largeRadius + 8
    property real morphProgress: 1.0

    readonly property var horizontalBounds: ScreenGeometry.horizontalBounds(screenWidth)

    // The Flare body ends at bodyWidth - flareRadius so the right ear
    // finishes exactly at bodyWidth (staying strictly inside envelope).
    readonly property real bodyEnd: Math.max(0, bodyWidth - flareRadius)
    readonly property real earRadius: flareSurface.earEndRadius
    readonly property real flareBodyHeight: Math.max(0, bodyHeight - (bottomAttached ? 0 : attachmentY) - bottomFlareReach)

    width: bodyWidth
    height: bodyHeight

    // 1. Top bridge connecting screen top / TopBar origin to the attachmentY seam.
    // It spans the full envelope width so the right ear attaches smoothly at attachmentY.
    Rectangle {
        id: topBridge
        visible: !root.bottomAttached
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
        y: root.bottomAttached ? -root.bodyHeight : 0
        width: root.leftAttached ? root.leftSeam : root.sideInset
        height: root.bodyHeight
        color: root.surfaceColor
        z: 1
    }

    // 3. Shared FlareSurface starting at the attachmentY seam below TopBar.
    // Anchored at the shared side inset on the left to seamlessly hug the RoundedScreen border.
    Flare.FlareSurface {
        id: flareSurface
        attach: root.bottomAttached ? Flare.FlareHost.Bottom : Flare.FlareHost.Top
        x: 0
        y: root.bottomAttached ? 0 : root.attachmentY
        width: root.bodyWidth
        height: Math.max(0, root.bodyHeight - root.attachmentY)
        start: root.leftAttached ? root.leftSeam : root.sideInset
        end: root.bodyEnd
        currentHeight: root.flareBodyHeight
        bounds: root.horizontalBounds
        r: root.flareRadius
        rf: root.bottomFlareReach
        bottomStartRadiusOverride: root.leftAttached ? 0 : -1
        bottomRadius: root.cornerRadius
        surfaceColor: root.surfaceColor
        z: 2
    }

    // 4. Flare ear connecting Dashboard bottom edge smoothly to Leftbar
    Shape {
        id: leftbarBottomEar
        visible: root.leftAttached && root.morphProgress > 0.05
        opacity: Math.max(0, Math.min(1, (root.morphProgress - 0.05) / 0.65))
        x: root.leftSeam - 1
        y: (root.attachmentY + root.flareBodyHeight) - 1
        width: root.bottomFlareReach + 1
        height: root.bottomFlareReach + 1
        preferredRendererType: Shape.CurveRenderer
        z: 3

        ShapePath {
            fillColor: root.surfaceColor
            strokeColor: "transparent"
            PathSvg {
                path: "M 0 0 L " + (root.bottomFlareReach + 1) + " 0 A " + (root.bottomFlareReach + 1) + " " + (root.bottomFlareReach + 1) + " 0 0 0 0 " + (root.bottomFlareReach + 1) + " Z"
            }
        }
    }
}
