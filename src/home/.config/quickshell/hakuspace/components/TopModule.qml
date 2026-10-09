import QtQuick
import Quickshell
import "../services"

Rectangle {
    id: root
    property string text: ""
    property bool isAccent: false
    property bool hovered: false

    signal clicked()
    signal rightClicked()
    signal scrolled(int delta)

    color: isAccent ? (hovered ? "#000000" : Theme.surfaceHi) 
                    : (hovered ? Theme.surfaceHi : Theme.surface)
    
    radius: Theme.radiusSm
    
    // Default size constraints
    implicitHeight: Theme.fontSize * 1.8
    implicitWidth: Math.max(implicitHeight, textLabel.implicitWidth + Theme.pad * 2)

    Text {
        id: textLabel
        anchors.centerIn: parent
        text: root.text
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        font.weight: Font.Bold
        color: root.isAccent ? (root.hovered ? Theme.surfaceHi : Theme.onAccentColor)
                             : (root.hovered ? Theme.onAccentColor : Theme.fg)
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onEntered: root.hovered = true
        onExited: root.hovered = false
        onClicked: (mouse) => {
            if (mouse.button === Qt.LeftButton) root.clicked();
            else if (mouse.button === Qt.RightButton) root.rightClicked();
        }
        onWheel: (wheel) => {
            root.scrolled(wheel.angleDelta.y);
        }
    }
}
