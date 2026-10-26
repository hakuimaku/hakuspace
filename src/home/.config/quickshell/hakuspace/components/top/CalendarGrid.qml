import QtQuick
import "../../services"

Item {
    id: root
    property date currentDate: new Date()
    property int monthOffset: 0
    property var payload: null
    property real maxWidth: 360
    property real maxHeight: 144
    property real preferredCellWidth: Math.max(28, Theme.fontSize * 2)
    property real preferredCellHeight: Math.max(17, Theme.fontSize * 1.25)
    property bool showNavControls: false
    property bool showHeader: true
    property bool dayHoverEnabled: false

    signal previousMonthRequested()
    signal nextMonthRequested()
    signal resetMonthRequested()

    readonly property date firstDay: new Date(currentDate.getFullYear(), currentDate.getMonth() + monthOffset, 1)
    readonly property int mondayOffset: (firstDay.getDay() + 6) % 7
    readonly property int daysInMonth: new Date(firstDay.getFullYear(), firstDay.getMonth() + 1, 0).getDate()

    readonly property real headerHeight: showHeader ? (showNavControls ? Math.max(26, title.implicitHeight) : title.implicitHeight) : 0
    readonly property real availableGridHeight: Math.max(0, maxHeight - headerHeight - weekdayRow.implicitHeight - Theme.gap * 2)
    readonly property real cellWidth: Math.min(preferredCellWidth, Math.max(16, maxWidth / 7))
    readonly property real cellHeight: Math.max(14, Math.min(preferredCellHeight, availableGridHeight / 6))

    implicitWidth: cellWidth * 7
    implicitHeight: (showHeader ? (headerHeight + Theme.gap) : 0) + weekdayRow.implicitHeight + Theme.gap + cellHeight * 6

    Item {
        id: headerRow
        visible: root.showHeader
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        width: root.cellWidth * 7
        height: root.headerHeight

        Rectangle {
            id: prevBtn
            visible: root.showNavControls
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: 24
            height: 24
            radius: 12
            color: prevMouse.containsMouse ? Theme.hoverMuted : "transparent"
            Behavior on color { ColorAnimation { duration: HAnimation.fast } }

            Text {
                anchors.centerIn: parent
                text: "‹"
                font.family: Theme.fontFamily
                font.pixelSize: 16
                color: Theme.fg
            }

            MouseArea {
                id: prevMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton
                onEntered: if (root.dayHoverEnabled) DashboardTooltip.show(prevBtn, "Previous month")
                onExited: if (root.dayHoverEnabled) DashboardTooltip.hide(prevBtn)
                onClicked: { DashboardTooltip.dismiss(); root.previousMonthRequested() }
            }
        }

        Item {
            id: titleContainer
            anchors.centerIn: parent
            width: title.implicitWidth
            height: title.implicitHeight

            Text {
                id: title
                anchors.centerIn: parent
                text: root.firstDay.toLocaleString(Qt.locale(), "MMMM yyyy")
                color: Theme.accent
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                font.weight: Font.Bold
            }

            MouseArea {
                id: titleMouse
                anchors.fill: parent
                hoverEnabled: true
                enabled: root.showNavControls && root.monthOffset !== 0
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                acceptedButtons: Qt.LeftButton
                onEntered: if (root.dayHoverEnabled && enabled) DashboardTooltip.show(titleContainer, "Click to reset to current month")
                onExited: if (root.dayHoverEnabled) DashboardTooltip.hide(titleContainer)
                onClicked: { DashboardTooltip.dismiss(); root.resetMonthRequested() }
            }
        }

        Rectangle {
            id: resetBtn
            visible: root.showNavControls && root.monthOffset !== 0
            anchors.left: titleContainer.right
            anchors.leftMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            width: 22
            height: 22
            radius: 11
            color: resetMouse.containsMouse ? Theme.hoverMuted : "transparent"
            Behavior on color { ColorAnimation { duration: HAnimation.fast } }

            Text {
                anchors.centerIn: parent
                text: "↺"
                font.family: Theme.fontFamily
                font.pixelSize: 13
                color: resetMouse.containsMouse ? Theme.accent : Theme.fgDim
                Behavior on color { ColorAnimation { duration: HAnimation.fast } }
            }

            MouseArea {
                id: resetMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton
                onEntered: if (root.dayHoverEnabled) DashboardTooltip.show(resetBtn, "Reset to current month")
                onExited: if (root.dayHoverEnabled) DashboardTooltip.hide(resetBtn)
                onClicked: { DashboardTooltip.dismiss(); root.resetMonthRequested() }
            }
        }

        Rectangle {
            id: nextBtn
            visible: root.showNavControls
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 24
            height: 24
            radius: 12
            color: nextMouse.containsMouse ? Theme.hoverMuted : "transparent"
            Behavior on color { ColorAnimation { duration: HAnimation.fast } }

            Text {
                anchors.centerIn: parent
                text: "›"
                font.family: Theme.fontFamily
                font.pixelSize: 16
                color: Theme.fg
            }

            MouseArea {
                id: nextMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton
                onEntered: if (root.dayHoverEnabled) DashboardTooltip.show(nextBtn, "Next month")
                onExited: if (root.dayHoverEnabled) DashboardTooltip.hide(nextBtn)
                onClicked: { DashboardTooltip.dismiss(); root.nextMonthRequested() }
            }
        }
    }

    Row {
        id: weekdayRow
        anchors.top: root.showHeader ? headerRow.bottom : parent.top
        anchors.topMargin: root.showHeader ? Theme.gap : 0
        anchors.horizontalCenter: parent.horizontalCenter
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
        id: monthGrid
        anchors.top: weekdayRow.bottom
        anchors.topMargin: Theme.gap
        anchors.horizontalCenter: parent.horizontalCenter
        columns: 7
        Repeater {
            model: 42
            Item {
                id: cellItem
                width: root.cellWidth
                height: root.cellHeight
                readonly property int day: index - root.mondayOffset + 1
                readonly property bool isValidDay: day > 0 && day <= root.daysInMonth
                readonly property bool today: isValidDay
                    && root.firstDay.getFullYear() === root.currentDate.getFullYear()
                    && root.firstDay.getMonth() === root.currentDate.getMonth()
                    && day === root.currentDate.getDate()
                readonly property bool isHovered: root.dayHoverEnabled && isValidDay && dayMouse.containsMouse
                readonly property real markerDiameter: Math.min(parent.width - 2, Math.max(16, root.cellHeight - 2))

                // Circular day highlight indicator for current date and hovered cell.
                Rectangle {
                    anchors.centerIn: parent
                    width: cellItem.markerDiameter
                    height: cellItem.markerDiameter
                    radius: cellItem.markerDiameter / 2
                    visible: cellItem.today || cellItem.isHovered
                    color: cellItem.today ? Theme.accent : Theme.surfaceHighlight(1.25)
                    scale: (cellItem.isHovered && !cellItem.today) ? 1.08 : 1.0
                    border.width: 0

                    // Animates day marker highlight color on hover.
                    Behavior on color { ColorAnimation { duration: HAnimation.fast } }
                    // Animates day marker scale slightly on hover.
                    Behavior on scale { NumberAnimation { duration: HAnimation.buttonHoverDuration } }
                }

                Text {
                    anchors.centerIn: parent
                    text: cellItem.isValidDay ? cellItem.day : ""
                    color: cellItem.today ? Theme.onAccentColor : (cellItem.isHovered ? Theme.fg : Theme.fg)
                    font.family: Theme.fontFamily
                    font.pixelSize: {
                        if (root.cellHeight > 24) return Theme.fontSize
                        if (root.cellHeight >= 20) return Theme.fontSize - 1
                        return Math.max(10, root.cellHeight - 5)
                    }
                    font.weight: cellItem.today ? Font.Bold : (cellItem.isHovered ? Font.DemiBold : Font.Normal)
                }

                MouseArea {
                    id: dayMouse
                    anchors.fill: parent
                    hoverEnabled: root.dayHoverEnabled && cellItem.isValidDay
                    enabled: root.dayHoverEnabled && cellItem.isValidDay
                    cursorShape: (root.dayHoverEnabled && cellItem.isValidDay) ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onEntered: {
                        if (root.dayHoverEnabled && cellItem.isValidDay) {
                            var d = new Date(root.firstDay.getFullYear(), root.firstDay.getMonth(), cellItem.day)
                            var text = d.toLocaleDateString(Qt.locale(), Locale.LongFormat)
                            if (cellItem.today) text += " (Today)"
                            DashboardTooltip.show(cellItem, text)
                        }
                    }
                    onExited: {
                        if (root.dayHoverEnabled) {
                            DashboardTooltip.hide(cellItem)
                        }
                    }
                }
            }
        }
    }
}
