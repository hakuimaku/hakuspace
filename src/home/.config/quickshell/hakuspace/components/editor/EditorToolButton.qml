import QtQuick
import "../../services"

Item {
    id: root

    property string text: ""
    property string tooltipText: ""
    property bool selected: false
    property bool enabled: true
    property bool compact: false
    property bool italic: false
    property bool bold: false
    property string fontFamily: Theme.fontFamily
    property real customWidth: 0
    property real customHeight: 0
    property bool tooltipAlignRight: false

    signal triggered()

    readonly property real defaultWidth: compact ? 22 : 30
    readonly property real defaultHeight: compact ? 22 : 30

    width: customWidth > 0 ? customWidth : defaultWidth
    height: customHeight > 0 ? customHeight : defaultHeight

    property bool tooltipShown: false

    Timer {
        id: hoverTimer
        interval: 350
        onTriggered: {
            if (mouseArea.containsMouse && root.tooltipText.length > 0) {
                root.tooltipShown = true
            }
        }
    }

    Rectangle {
        id: buttonBody
        anchors.fill: parent
        radius: root.compact ? 4 : 6
        color: !root.enabled ? "transparent"
               : (root.selected
                  ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.22)
                  : (mouseArea.pressed
                     ? Qt.darker(Theme.hoverMuted, 1.15)
                     : (mouseArea.containsMouse ? Theme.hoverMuted : "transparent")))
        border.width: root.selected ? 1 : 0
        border.color: Theme.accent
        opacity: root.enabled ? 1.0 : 0.4
        scale: mouseArea.pressed && root.enabled ? 0.94 : 1.0

        Behavior on color { ColorAnimation { duration: HAnimation.buttonHoverDuration } }
        Behavior on scale {
            NumberAnimation {
                duration: mouseArea.pressed ? HAnimation.buttonPressDuration : HAnimation.buttonReleaseDuration
                easing.bezierCurve: mouseArea.pressed ? HAnimation.buttonPressCurve : HAnimation.buttonReleaseCurve
            }
        }

        Text {
            anchors.centerIn: parent
            text: root.text
            font.family: root.fontFamily
            font.bold: root.bold || root.selected
            font.italic: root.italic
            font.pixelSize: root.compact
                            ? Math.max(10, Theme.fontSize - 3)
                            : Math.max(12, Theme.fontSize - 1)
            color: root.selected ? Theme.accent : (mouseArea.containsMouse ? Theme.fg : Theme.fgDim)

            Behavior on color { ColorAnimation { duration: HAnimation.buttonHoverDuration } }
        }

        MouseArea {
            id: mouseArea
            anchors.fill: parent
            enabled: root.enabled
            hoverEnabled: true
            cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            acceptedButtons: Qt.LeftButton
            onEntered: hoverTimer.restart()
            onExited: {
                hoverTimer.stop()
                root.tooltipShown = false
            }
            onClicked: root.triggered()
        }
    }

    // Tooltip bubble
    Rectangle {
        id: tooltipBubble
        visible: root.tooltipShown && root.tooltipText.length > 0 && opacity > 0.01
        opacity: (root.tooltipShown && root.tooltipText.length > 0) ? 1.0 : 0.0
        anchors.top: parent.bottom
        anchors.topMargin: 6
        anchors.right: root.tooltipAlignRight ? parent.right : undefined
        anchors.horizontalCenter: root.tooltipAlignRight ? undefined : parent.horizontalCenter
        width: tooltipLabel.implicitWidth + 14
        height: tooltipLabel.implicitHeight + 8
        radius: Theme.radius
        color: Theme.surface
        border.width: 1
        border.color: Qt.lighter(Theme.hoverMuted, 1.45)
        z: 300

        Behavior on opacity {
            NumberAnimation {
                duration: 160
                easing.bezierCurve: HAnimation.tooltipCurve
            }
        }

        Text {
            id: tooltipLabel
            anchors.centerIn: parent
            text: root.tooltipText
            font.family: Theme.fontFamily
            font.pixelSize: Math.max(10, Theme.fontSize - 3)
            font.weight: Font.Medium
            color: Theme.fg
        }
    }
}
