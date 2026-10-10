import QtQuick
import QtQuick.Effects
import "../../services"

Item {
    id: root

    property real diameter: 148

    signal requestBack()
    signal requestChangeAvatar()

    width: diameter
    height: diameter

    // Base background surface matching Hikai aesthetic
    Rectangle {
        id: baseSurface
        anchors.fill: parent
        radius: width / 2
        color: Theme.surface
    }

    // Unmasked source image with bounded decode size and PreserveAspectCrop
    Image {
        id: avatarImage
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        source: Avatar.hasAvatar ? (Avatar.source + (Avatar.revision > 0 ? ("?rev=" + Avatar.revision) : "")) : ""
        sourceSize.width: Math.max(1, Math.round(root.diameter * 2))
        sourceSize.height: Math.max(1, Math.round(root.diameter * 2))
        visible: false
        layer.enabled: true
        asynchronous: true
    }

    // Dedicated circular alpha mask layer
    Item {
        id: avatarMask
        anchors.fill: parent
        visible: false
        layer.enabled: true

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: "white"
        }
    }

    // Hardware-accelerated true circular masking
    MultiEffect {
        id: avatarEffect
        anchors.fill: parent
        source: avatarImage
        visible: avatarImage.status === Image.Ready
        maskEnabled: true
        maskSource: avatarMask
        maskThresholdMin: 0.5
        maskSpreadAtMin: 0.025
        maskThresholdMax: 1.0
        maskSpreadAtMax: 0.0
    }

    // Fallback glyph visual when no avatar is set or decode fails
    Item {
        id: fallbackVisual
        anchors.fill: parent
        visible: !Avatar.hasAvatar || avatarImage.status !== Image.Ready

        Column {
            anchors.centerIn: parent
            spacing: 4

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "󰮯"
                color: Theme.accent
                font.family: Theme.fontFamily
                font.pixelSize: Math.max(30, Math.round(root.diameter * 0.26))
                font.weight: Font.Bold
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Avatar"
                color: Theme.fgDim
                font.family: Theme.fontFamily
                font.pixelSize: Math.max(10, Theme.fontSize - 2)
                font.weight: Font.Medium
            }
        }
    }

    // Border and accent hover ring
    Rectangle {
        id: borderRing
        anchors.fill: parent
        radius: width / 2
        color: "transparent"
        border.width: 2
        border.color: avatarArea.hovered ? Theme.accent : Qt.lighter(Theme.hoverMuted, 1.45)
        z: 20

        Behavior on border.color { ColorAnimation { duration: HAnimation.fast } }
    }

    // Pointer interaction: Left click -> Back; Right click -> Change
    MouseArea {
        id: avatarArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        z: 30

        onClicked: mouse => {
            if (mouse.button === Qt.LeftButton) {
                root.requestBack()
            } else if (mouse.button === Qt.RightButton) {
                root.requestChangeAvatar()
            }
        }
    }
}
