import QtQuick
import Quickshell
import "../../services"
import "../base"

Item {
    id: root

    property bool hovered: false
    readonly property bool reducedMotion: Quickshell.env("HAKUSPACE_REDUCED_MOTION") === "1"

    implicitHeight: Theme.fontSize * 1.8
    implicitWidth: contentRow.implicitWidth + Theme.pad * 2
    width: implicitWidth
    height: implicitHeight

    onVisibleChanged: {
        if (!visible) {
            hovered = false
            hoverTooltip.active = false
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.radius
        color: root.hovered ? Theme.surfaceHi : Theme.surface

        Behavior on color {
            enabled: !root.reducedMotion
            ColorAnimation { duration: HAnimation.fast }
        }
    }

    Row {
        id: contentRow
        anchors.centerIn: parent
        spacing: Theme.gap

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: FocusTimer.running ? "󱎫" : "󰏤"
            font.family: Theme.iconFontFamily
            font.pixelSize: Theme.fontSize
            color: root.hovered ? Theme.onAccentColor : (FocusTimer.running ? Theme.accent : Theme.fgDim)

            Behavior on color {
                enabled: !root.reducedMotion
                ColorAnimation { duration: HAnimation.fast }
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: FocusTimer.formattedTime
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            font.weight: Font.Bold
            color: root.hovered ? Theme.onAccentColor : (FocusTimer.running ? Theme.accent : Theme.fgDim)

            Behavior on color {
                enabled: !root.reducedMotion
                ColorAnimation { duration: HAnimation.fast }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onEntered: {
            root.hovered = true
            hoverTooltip.active = true
        }
        onExited: {
            root.hovered = false
            hoverTooltip.active = false
        }
        onClicked: mouse => {
            hoverTooltip.active = false
            if (mouse.button === Qt.LeftButton) {
                FocusTimer.toggle()
            } else if (mouse.button === Qt.RightButton) {
                FocusTimer.reset()
            }
        }
    }

    HTooltip {
        id: hoverTooltip
        target: root
        text: "Focus timer · Left click: Pause/Resume · Right click: Reset"
    }
}
