import QtQuick
import Quickshell
import "../../services"

Rectangle {
    id: root
    width: Math.max(implicitWidth, height)
    height: Theme.fontSize * 2
    radius: Theme.radiusSm
    color: mouseArea.containsMouse || mouseArea.pressed ? Theme.surfaceHi : Theme.surface
    
    property alias text: label.text
    signal clicked()
    
    Text {
        id: label
        anchors.centerIn: parent
        color: mouseArea.containsMouse || mouseArea.pressed ? Theme.onAccentColor : Theme.fg
        font.family: Theme.font
        font.pixelSize: Theme.fontSize
    }
    
    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
