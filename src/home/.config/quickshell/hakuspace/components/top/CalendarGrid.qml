import QtQuick
import "../../services"

Item {
    id: root
    property date currentDate: new Date()
    property int monthOffset: 0
    property var payload: null
    property real maxWidth: 360
    property real maxHeight: 144
    readonly property date firstDay: new Date(currentDate.getFullYear(), currentDate.getMonth() + monthOffset, 1)
    readonly property int mondayOffset: (firstDay.getDay() + 6) % 7
    readonly property int daysInMonth: new Date(firstDay.getFullYear(), firstDay.getMonth() + 1, 0).getDate()
    readonly property real cellWidth: Math.min(Math.max(28, Theme.fontSize * 2), Math.max(16, maxWidth / 7))
    readonly property real cellHeight: Math.max(14, Math.min(Math.max(17, Theme.fontSize * 1.25),
        (maxHeight - title.implicitHeight - weekdayRow.implicitHeight - Theme.gap * 2) / 6))
    implicitWidth: cellWidth * 7
    implicitHeight: title.implicitHeight + Theme.gap + weekdayRow.implicitHeight + Theme.gap + cellHeight * 6

    Text {
        id: title
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        text: root.firstDay.toLocaleString(Qt.locale(), "MMMM yyyy")
        color: Theme.accent
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        font.weight: Font.Bold
    }

    Row {
        id: weekdayRow
        anchors.top: title.bottom
        anchors.topMargin: Theme.gap
        Repeater {
            model: 7
            Text {
                width: root.cellWidth
                horizontalAlignment: Text.AlignHCenter
                text: new Date(2024, 0, 1 + index).toLocaleString(Qt.locale(), "ddd")
                color: Theme.fgDim
                font.family: Theme.fontFamily
                font.pixelSize: Math.max(10, Theme.fontSize - 3)
            }
        }
    }

    Grid {
        anchors.top: weekdayRow.bottom
        anchors.topMargin: Theme.gap
        columns: 7
        Repeater {
            model: 42
            Item {
                width: root.cellWidth
                height: root.cellHeight
                readonly property int day: index - root.mondayOffset + 1
                readonly property bool today: day > 0 && day <= root.daysInMonth
                    && root.firstDay.getFullYear() === root.currentDate.getFullYear()
                    && root.firstDay.getMonth() === root.currentDate.getMonth()
                    && day === root.currentDate.getDate()

                Rectangle {
                    anchors.centerIn: parent
                    width: Math.min(parent.width - 2, root.cellHeight)
                    height: width
                    radius: width / 2
                    visible: parent.today
                    color: Theme.surface
                    border.width: 1
                    border.color: Theme.accent
                }
                Text {
                    anchors.centerIn: parent
                    text: parent.day > 0 && parent.day <= root.daysInMonth ? parent.day : ""
                    color: parent.today ? Theme.accent : Theme.fg
                    font.family: Theme.fontFamily
                    font.pixelSize: Math.min(Math.max(11, Theme.fontSize - 1), root.cellHeight - 2)
                    font.weight: parent.today ? Font.Bold : Font.Normal
                }
            }
        }
    }
}
