import QtQuick
import "../../services"

Item {
    id: root

    property real railWidth: 48
    property real railHeight: 0
    width: railWidth
    height: Math.max(0, railHeight)
    clip: true

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

    // Rotated "--- The Hikaide ---" subtitle vertically centered in the remaining rail below the name
    Item {
        id: subtitleContainer
        anchors.top: nameText.bottom
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right

        Item {
            id: verticalTagBox
            anchors.centerIn: parent
            width: 24
            height: Math.max(90, Math.min(Math.max(90, parent.height - 16), tagText.implicitWidth + 12))

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
}
