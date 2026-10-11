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
        preferredCellWidth: Math.min(48, Math.floor((root.width - 24) / 7))
        preferredCellHeight: Math.min(36, Math.max(26, Math.floor((root.height - 60) / 6)))
        showNavControls: true
        currentDate: Clock.date
        monthOffset: root.monthOffset
        dayHoverEnabled: true

        onPreviousMonthRequested: root.monthOffset--
        onNextMonthRequested: root.monthOffset++
        onResetMonthRequested: root.monthOffset = 0
    }
}
