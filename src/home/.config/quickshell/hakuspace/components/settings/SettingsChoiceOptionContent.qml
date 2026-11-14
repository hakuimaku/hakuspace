import QtQuick
import QtQuick.Layouts
import "../../services"

RowLayout {
    id: rowContent
    required property string iconText
    required property string titleText
    required property string subtitleText
    required property color titleColor
    required property color subtitleColor
    property bool richLayout: false
    property string titleObjectName: ""
    property int titleWeight: Font.Normal
    spacing: Theme.spaceMd

    Text {
        id: iconItem
        visible: rowContent.iconText.length > 0
        Layout.preferredWidth: visible ? Math.max(20, Math.round(Theme.fontSize * 1.4)) : 0
        Layout.alignment: Qt.AlignVCenter
        horizontalAlignment: Text.AlignHCenter
        text: rowContent.iconText
        color: rowContent.titleColor
        font.family: Theme.iconFontFamily
        font.pixelSize: Theme.fontSize + 2
    }

    Text {
        objectName: rowContent.titleObjectName
        Layout.alignment: Qt.AlignVCenter
        Layout.fillWidth: !subtitleItem.visible
        Layout.minimumWidth: 0
        Layout.maximumWidth: subtitleItem.visible ? Math.max(0, rowContent.width * 0.65) : rowContent.width
        text: rowContent.titleText
        color: rowContent.titleColor
        font.family: Theme.fontFamily
        font.pixelSize: rowContent.richLayout ? Theme.fontSize : Theme.fontSize - 1
        font.weight: rowContent.titleWeight
        elide: rowContent.richLayout ? Text.ElideRight : Text.ElideMiddle
    }

    Text {
        id: subtitleItem
        visible: rowContent.subtitleText.length > 0
        Layout.alignment: Qt.AlignVCenter
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        text: rowContent.subtitleText
        color: rowContent.subtitleColor
        font.family: Theme.fontFamily
        font.pixelSize: Math.max(10, Theme.fontSize - 2)
        elide: Text.ElideMiddle
    }
}
