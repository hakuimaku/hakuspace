import QtQuick
import "../../services"

Item {
    id: root

    property real railWidth: 148
    width: railWidth

    Column {
        id: col
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width
        spacing: 8

        Text {
            id: nameText
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: UserIdentity.displayName
            font.family: Theme.fontFamily
            font.pixelSize: Math.max(12, Theme.fontSize + 1)
            font.weight: Font.Bold
            color: Theme.fg
            elide: Text.ElideRight
        }

        Item {
            id: verticalTagBox
            anchors.horizontalCenter: parent.horizontalCenter
            width: 24
            height: Math.max(100, Math.min(180, tagText.implicitWidth + 12))

            Text {
                id: tagText
                anchors.centerIn: parent
                text: UserIdentity.subtitle
                font.family: Theme.fontFamily
                font.pixelSize: Math.max(9, Theme.fontSize - 3)
                font.weight: Font.Medium
                color: Theme.fgDim
                rotation: 90
                transformOrigin: Item.Center
            }
        }
    }
}
