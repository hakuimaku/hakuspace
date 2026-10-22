import QtQuick
import "../../services"
import "WindowNavigatorGeometry.js" as Geometry

Item {
    id: root
    required property real reveal
    required property bool pointerNavigation
    opacity: reveal
    // Use the shell's frame and status reservations on either chrome layout.
    readonly property real inset: Math.max(Theme.pad * 3, ScreenGeometry.roundedRadius) + 16
    readonly property real topInset: ScreenGeometry.bottomAttached ? inset : Theme.topBarHeight + inset
    readonly property real bottomInset: ScreenGeometry.bottomAttached ? ScreenGeometry.taskbarHeight + inset : inset
    readonly property var cards: Geometry.layout(Math.max(0, width - 2 * inset),
        Math.max(0, height - topInset - bottomInset), WindowNavigator.sessionWindows.length, Theme.pad * 2 + 16)

    // Route arrows by actual card centers, including the centered incomplete row.
    function navigate(key) {
        var direction = key === Qt.Key_Left ? "left" : key === Qt.Key_Right ? "right"
            : key === Qt.Key_Up ? "up" : key === Qt.Key_Down ? "down" : ""
        if (direction) WindowNavigator.select(Geometry.neighbor(cards, WindowNavigator.selectedIndex, direction))
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.76)
    }
    Repeater {
        model: WindowNavigator.sessionWindows.length
        delegate: WindowCard {
            required property int index
            readonly property var modelData: WindowNavigator.sessionWindows[index]
            readonly property var bounds: root.cards[index] || {x: 0, y: 0, width: 0, height: 0}
            windowEntry: modelData
            selected: index === WindowNavigator.selectedIndex
            x: root.inset + bounds.x
            y: root.topInset + bounds.y
            width: bounds.width
            height: bounds.height
            onHovered: if (root.pointerNavigation) WindowNavigator.select(index)
            onChosen: { WindowNavigator.select(index); WindowNavigator.commit() }
        }
    }
}
