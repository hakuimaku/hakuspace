import QtQuick
import "../../services"
import "../top"

Item {
    id: root

    property int monthOffset: 0

    CalendarGrid {
        id: grid
        anchors.centerIn: parent
        maxWidth: root.width
        maxHeight: root.height
        preferredCellWidth: Math.min(42, Math.floor(root.width / 7))
        preferredCellHeight: 32
        showNavControls: true
        currentDate: Clock.date
        monthOffset: root.monthOffset

        onPreviousMonthRequested: root.monthOffset--
        onNextMonthRequested: root.monthOffset++
        onResetMonthRequested: root.monthOffset = 0
    }
}
