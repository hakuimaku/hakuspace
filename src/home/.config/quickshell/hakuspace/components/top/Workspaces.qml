import QtQuick
import Quickshell
import "../"
import "../../services"

Row {
    spacing: 6
    Repeater {
        model: 5
        delegate: Rectangle {
            width: Theme.fontSize * 2
            height: Theme.fontSize * 1.8
            radius: Theme.radiusSm
            color: index === 0 ? Theme.surfaceHi : Theme.surface
            opacity: index === 0 ? 1.0 : 0.6
            Text {
                anchors.centerIn: parent
                text: index + 1
                color: index === 0 ? Theme.onAccentColor : Theme.fg
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                font.weight: Font.Bold
            }
        }
    }
}
