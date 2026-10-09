import QtQuick
import Quickshell
import Quickshell.Wayland
import "../services"
import "base"

Rectangle {
    id: root
    property string text: ""
    property string icon: ""
    property bool isAccent: false
    property bool hovered: false
    property bool muted: false
    property bool urgent: false
    property bool blink: false
    property string tooltip: ""
    property int borderWidth: 0
    property string borderColor: "transparent"
    property int blinkDuration: HAnimation.normal

    signal clicked()
    signal rightClicked()
    signal scrolled(int delta)

    color: {
        if (urgent) return "#ff3333";
        if (isAccent) return hovered ? "#000000" : Theme.accent;
        return hovered ? Theme.surfaceHi : "transparent";
    }
    
    radius: Theme.radiusSm
    border.width: borderWidth
    border.color: borderColor
    
    implicitHeight: Theme.fontSize * 1.8
    implicitWidth: Math.max(implicitHeight, row.implicitWidth + Theme.pad * 2 + (hovered ? 20 : 0))

    SequentialAnimation on opacity {
        running: root.blink
        loops: Animation.Infinite
        NumberAnimation { to: 0.5; duration: root.blinkDuration; easing.type: Easing.InOutQuad }
        NumberAnimation { to: 1.0; duration: root.blinkDuration; easing.type: Easing.InOutQuad }
    }
    
    // Normal opacity fallback when not blinking
    onBlinkChanged: {
        if (!blink) opacity = muted ? 0.5 : 1.0
    }
    onMutedChanged: {
        if (!blink) opacity = muted ? 0.5 : 1.0
    }
    Component.onCompleted: opacity = muted ? 0.5 : 1.0
    
    Behavior on implicitWidth {
        NumberAnimation { duration: HAnimation.normal; easing.bezierCurve: HAnimation.moduleCurve }
    }
    Behavior on color {
        ColorAnimation { duration: HAnimation.normal; easing.bezierCurve: HAnimation.moduleCurve }
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: Theme.gap
        
        Text {
            id: iconLabel
            visible: root.icon !== ""
            text: root.icon
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            font.weight: Font.Bold
            color: root.urgent ? "#ffffff" : (root.isAccent ? (root.hovered ? Theme.surfaceHi : Theme.onAccentColor)
                                 : (root.hovered ? Theme.onAccentColor : Theme.fg))
            Behavior on color { ColorAnimation { duration: HAnimation.normal } }
        }
        
        Text {
            id: textLabel
            visible: root.text !== ""
            text: root.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            font.weight: Font.Bold
            color: root.urgent ? "#ffffff" : (root.isAccent ? (root.hovered ? Theme.surfaceHi : Theme.onAccentColor)
                                 : (root.hovered ? Theme.onAccentColor : Theme.fg))
            Behavior on color { ColorAnimation { duration: HAnimation.normal } }
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onEntered: {
            root.hovered = true
            if (root.tooltip !== "") {
                tooltipObj.active = true
            }
        }
        onExited: {
            root.hovered = false
            tooltipObj.active = false
        }
        onClicked: (mouse) => {
            if (mouse.button === Qt.LeftButton) root.clicked();
            else if (mouse.button === Qt.RightButton) root.rightClicked();
        }
        onWheel: (wheel) => {
            root.scrolled(wheel.angleDelta.y);
        }
    }
    
    HTooltip {
        id: tooltipObj
        target: root
        text: root.tooltip
    }
}
