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
        preferredCellWidth: Math.min(72, Math.max(30, Math.floor((root.width - 16) / 7)))
        preferredCellHeight: Math.min(54, Math.max(28, Math.floor((root.height - 72) / 6)))
        showNavControls: true
        currentDate: Clock.date
        monthOffset: root.monthOffset
        dayHoverEnabled: true
        selectable: true
        selectedDateKey: AgendaStore.selectedDateKey
        markedDateKeys: AgendaStore.markedDateKeys

        onPreviousMonthRequested: root.monthOffset--
        onNextMonthRequested: root.monthOffset++
        onResetMonthRequested: {
            root.monthOffset = 0
            AgendaStore.selectToday()
        }
        onDateSelected: dateKey => {
            AgendaStore.selectDate(dateKey)
            AgendaStore.setFilterMode("day")
        }
    }
}
