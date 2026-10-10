import QtQuick
import "../../services"

Rectangle {
    id: root

    radius: Theme.radius
    color: Theme.surface
    border.width: 1
    border.color: Qt.lighter(Theme.hoverMuted, 1.25)
    clip: true

    Row {
        id: contentRow
        anchors.centerIn: parent
        spacing: Math.max(14, Math.round(Theme.pad * 1.5))

        Text {
            id: timeText
            text: Clock.date ? Clock.date.toLocaleString(Qt.locale(), "HH:mm") : ""
            font.family: Theme.fontFamily
            font.pixelSize: Math.round(Theme.fontSize * 2.0)
            font.weight: Font.Bold
            color: Theme.fg
            anchors.verticalCenter: parent.verticalCenter
        }

        Column {
            id: dateCol
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            readonly property real maxTextWidth: Math.max(60, root.width - timeText.implicitWidth - contentRow.spacing - 32)

            Text {
                id: weekdayText
                text: Clock.date ? Clock.date.toLocaleString(Qt.locale(), "dddd") : ""
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                font.weight: Font.Bold
                color: Theme.fg
                width: Math.min(implicitWidth, dateCol.maxTextWidth)
                elide: Text.ElideRight
            }

            Text {
                id: calendarDateText
                text: Clock.date ? Clock.date.toLocaleString(Qt.locale(), "dd/MM/yyyy") : ""
                font.family: Theme.fontFamily
                font.pixelSize: Math.max(10, Theme.fontSize - 2)
                font.weight: Font.Normal
                color: Theme.fgDim
                width: Math.min(implicitWidth, dateCol.maxTextWidth)
                elide: Text.ElideRight
            }
        }
    }
}
