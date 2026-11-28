import QtQuick
import Quickshell
import "../../services"

Item {
    id: root

    property real railWidth: 48
    property real railHeight: 0
    property bool pinned: false
    readonly property bool reducedMotion: Quickshell.env("HAKUSPACE_REDUCED_MOTION") === "1"

    signal pinToggled()

    width: railWidth
    height: Math.max(0, railHeight)
    clip: false

    // Name is positioned immediately below the avatar
    Text {
        id: nameText
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.max(0, parent.width - 8)
        horizontalAlignment: Text.AlignHCenter
        text: UserIdentity.displayName
        font.family: Theme.fontFamily
        font.pixelSize: Math.max(12, Theme.fontSize + 1)
        font.weight: Font.Bold
        color: Theme.fg
        elide: Text.ElideRight
    }

    // Rotated "--- The Hikaide ---" subtitle vertically centered in the remaining rail above Pin
    Item {
        id: subtitleContainer
        anchors.top: nameText.bottom
        anchors.bottom: pinBtn.top
        anchors.bottomMargin: 8
        anchors.left: parent.left
        anchors.right: parent.right
        clip: true
        opacity: Math.max(0, Math.min(1, (height - 16) / 32))
        visible: opacity > 0.001

        Item {
            id: verticalTagBox
            anchors.centerIn: parent
            width: 24
            height: Math.min(Math.max(0, parent.height - 8), tagText.implicitWidth + 12)

            Text {
                id: tagText
                anchors.centerIn: parent
                text: UserIdentity.subtitle
                font.family: Theme.fontFamily
                font.pixelSize: Math.max(9, Theme.fontSize - 3)
                font.weight: Font.Medium
                color: Theme.workspaceDot
                rotation: -90
                transformOrigin: Item.Center
            }
        }
    }

    Rectangle {
        id: pinBtn
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 4
        anchors.horizontalCenter: parent.horizontalCenter
        width: 36
        height: 36
        radius: 18
        border.width: 0
        color: root.pinned ? Theme.accent : Theme.surfaceSubtle(1.25)
        scale: (pinMouse.containsMouse && !root.reducedMotion) ? 1.05 : 1.0

        Behavior on color {
            enabled: !root.reducedMotion
            ColorAnimation { duration: HAnimation.fast }
        }
        Behavior on scale {
            enabled: !root.reducedMotion
            NumberAnimation {
                duration: pinMouse.containsMouse ? HAnimation.buttonHoverDuration : HAnimation.buttonReleaseDuration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: pinMouse.containsMouse ? HAnimation.buttonHoverCurve : HAnimation.buttonReleaseCurve
            }
        }

        Text {
            anchors.centerIn: parent
            text: "󰐃"
            font.family: Theme.iconFontFamily
            font.pixelSize: 18
            color: root.pinned ? Theme.onAccentColor : Theme.fgDim

            Behavior on color {
                enabled: !root.reducedMotion
                ColorAnimation { duration: HAnimation.fast }
            }
        }

        MouseArea {
            id: pinMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton
            onEntered: DashboardTooltip.show(pinBtn, root.pinned ? "Unpin dashboard" : "Pin dashboard", "right")
            onExited: DashboardTooltip.hide(pinBtn)
            onClicked: {
                DashboardTooltip.dismiss()
                root.pinToggled()
            }
        }
    }
}
