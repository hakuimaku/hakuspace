import QtQuick
import "../flare" as Flare
import "../../services"

Item {
    id: root

    property real bodyWidth: 0
    property real bodyHeight: 0
    property real flareRadius: Theme.tipRadius
    property real screenWidth: 1920
    property real screenHeight: 1080
    property color surfaceColor: Theme.barColor
    property real cornerRadius: Theme.radius + 8

    // The Flare body ends at bodyWidth - flareRadius so the right ear
    // finishes exactly at bodyWidth (staying strictly inside envelope).
    readonly property real bodyEnd: Math.max(0, bodyWidth - flareRadius)
    readonly property real earRadius: flareSurface.earEndRadius

    width: bodyWidth
    height: bodyHeight

    Flare.FlareSurface {
        id: flareSurface
        anchors.fill: parent
        start: 0
        end: root.bodyEnd
        currentHeight: root.bodyHeight
        bounds: ({ start: 0, end: root.screenWidth })
        r: root.flareRadius
        rf: 0
        bottomRadius: root.cornerRadius
        surfaceColor: root.surfaceColor
    }
}
