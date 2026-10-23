import QtQuick
import Quickshell
import "../../services"
import "WindowNavigatorGeometry.js" as Geometry

Item {
    id: root
    required property real reveal
    required property bool pointerNavigation
    opacity: reveal
    // Fade the ribbon at its final size.
    Rectangle {
        id: ribbon
        anchors.centerIn: parent
        width: Math.min(root.width - 2 * (Theme.pad + 8), row.implicitWidth + 40)
        height: 104
        radius: height / 2
        color: Theme.surface
        clip: true
        Flickable {
            id: viewport
            anchors { fill: parent; margins: 20 }
            contentWidth: row.implicitWidth
            contentHeight: height
            interactive: false
            clip: true
            // Follow the selected capsule even when many applications exceed the output.
            contentX: {
                var item = tiles.itemAt(WindowNavigator.selectedIndex)
                return item ? Math.max(0, Math.min(contentWidth - width, item.x + item.width / 2 - width / 2)) : 0
            }
            Row {
                id: row
                spacing: Theme.gap + 10
                Repeater {
                    id: tiles
                    model: WindowNavigator.sessionWindows.length
                    delegate: Rectangle {
                        id: tile
                        required property int index
                        readonly property var modelData: WindowNavigator.sessionWindows[index]
                        readonly property bool selected: index === WindowNavigator.selectedIndex
                        width: Geometry.ribbonWidth(selected, root.width)
                        height: 64
                        radius: selected ? Theme.largeRadius : height / 2
                        color: selected ? Theme.fg : Theme.hoverMuted
                        border.width: modelData.urgent ? 2 : 0
                        border.color: Theme.fg
                        clip: true
                        Behavior on width {
                            NumberAnimation {
                                duration: HAnimation.normal
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: HAnimation.dashboardOpenCurve
                            }
                        }
                        Behavior on radius { NumberAnimation { duration: HAnimation.fast } }
                        Image {
        sourceSize: Qt.size(Math.max(1, Math.ceil(width * 2)), Math.max(1, Math.ceil(height * 2)))
                            x: 16; anchors.verticalCenter: parent.verticalCenter
                            width: 32; height: 32
                            source: Quickshell.iconPath(tile.modelData.icon, "application-x-executable")
                            fillMode: Image.PreserveAspectFit
                        }
                        Text {
                            anchors.centerIn: parent
                            width: Math.max(0, parent.width - 128)
                            horizontalAlignment: Text.AlignHCenter
                            text: tile.modelData.title
                            color: tile.selected ? Theme.surface : Theme.fg
                            font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize
                            elide: Text.ElideRight
                            textFormat: Text.PlainText
                            visible: tile.width > 64
                        }
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            onPositionChanged: if (containsMouse && root.pointerNavigation) WindowNavigator.select(tile.index)
                            onClicked: { WindowNavigator.select(tile.index); WindowNavigator.commit() }
                        }
                        Accessible.role: Accessible.Button
                        Accessible.name: modelData.appName + ": " + modelData.title
                        Accessible.onPressAction: { WindowNavigator.select(index); WindowNavigator.commit() }
                    }
                }
            }
        }
    }
}
