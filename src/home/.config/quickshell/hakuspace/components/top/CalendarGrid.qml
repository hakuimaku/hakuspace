import QtQuick
import Quickshell
import "../../services"

Item {
    id: root
    readonly property bool reducedMotion: Quickshell.env("HAKUSPACE_REDUCED_MOTION") === "1"
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
    property bool selectable: false
    property string selectedDateKey: ""
    property var markedDateKeys: ({})

    signal previousMonthRequested()
    signal nextMonthRequested()
    signal resetMonthRequested()
    signal dateSelected(string dateKey)

    function dateKeyFor(year, monthIndex, day) {
        var m = monthIndex + 1
        return year + "-" + (m < 10 ? "0" + m : String(m)) + "-" + (day < 10 ? "0" + day : String(day))
    }

    readonly property date firstDay: new Date(currentDate.getFullYear(), currentDate.getMonth() + monthOffset, 1)
    readonly property int mondayOffset: (firstDay.getDay() + 6) % 7
    readonly property int daysInMonth: new Date(firstDay.getFullYear(), firstDay.getMonth() + 1, 0).getDate()

    readonly property real headerHeight: showHeader ? (showNavControls ? Math.max(34, title.implicitHeight) : title.implicitHeight) : 0
    readonly property real availableGridHeight: Math.max(0, maxHeight - headerHeight - weekdayRow.implicitHeight - Theme.gap * 2)
    readonly property real cellWidth: Math.min(preferredCellWidth, Math.max(16, maxWidth / 7))
    readonly property real cellHeight: Math.max(14, Math.min(preferredCellHeight, availableGridHeight / 6))

    property int _lastMonthOffset: 0
    property real _monthSlideX: 0
    property real _monthOpacity: 1.0

    Component.onCompleted: _lastMonthOffset = monthOffset

    onMonthOffsetChanged: {
        var dir = monthOffset > _lastMonthOffset ? 1 : (monthOffset < _lastMonthOffset ? -1 : 0)
        _lastMonthOffset = monthOffset
        if (dir !== 0 && root.showNavControls && !root.reducedMotion) {
            monthSwitchAnim.stop()
            monthSlideAnim.from = dir * 18
            monthSwitchAnim.start()
        }
    }

    ParallelAnimation {
        id: monthSwitchAnim
        NumberAnimation {
            id: monthSlideAnim
            target: root
            property: "_monthSlideX"
            from: 18
            to: 0
            duration: HAnimation.dashboardWidgetSwitchDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: HAnimation.dashboardWidgetSwitchCurve
        }
        NumberAnimation {
            target: root
            property: "_monthOpacity"
            from: 0.25
            to: 1.0
            duration: HAnimation.dashboardWidgetSwitchDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: HAnimation.dashboardWidgetSwitchCurve
        }
    }

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
            width: 32
            height: 32
            radius: 16
            color: root.selectable ? "transparent" : (prevMouse.containsMouse ? Theme.hoverMuted : "transparent")
            scale: (root.selectable && prevMouse.containsMouse && !root.reducedMotion) ? 1.05 : 1.0
            Behavior on color { ColorAnimation { duration: HAnimation.fast } }
            Behavior on scale {
                enabled: !root.reducedMotion
                NumberAnimation {
                    duration: prevMouse.containsMouse ? HAnimation.buttonHoverDuration : HAnimation.buttonReleaseDuration
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: prevMouse.containsMouse ? HAnimation.buttonHoverCurve : HAnimation.buttonReleaseCurve
                }
            }

            Text {
                anchors.centerIn: parent
                text: "󰅁"
                font.family: Theme.iconFontFamily
                font.pixelSize: 19
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
            opacity: root._monthOpacity
            transform: Translate { x: root._monthSlideX * 0.5 }

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
            width: 32
            height: 32
            radius: 16
            color: root.selectable ? "transparent" : (resetMouse.containsMouse ? Theme.hoverMuted : "transparent")
            scale: (root.selectable && resetMouse.containsMouse && !root.reducedMotion) ? 1.05 : 1.0
            Behavior on color { ColorAnimation { duration: HAnimation.fast } }
            Behavior on scale {
                enabled: !root.reducedMotion
                NumberAnimation {
                    duration: resetMouse.containsMouse ? HAnimation.buttonHoverDuration : HAnimation.buttonReleaseDuration
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: resetMouse.containsMouse ? HAnimation.buttonHoverCurve : HAnimation.buttonReleaseCurve
                }
            }

            Text {
                anchors.centerIn: parent
                text: "󰑐"
                font.family: Theme.iconFontFamily
                font.pixelSize: 18
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
            width: 32
            height: 32
            radius: 16
            color: root.selectable ? "transparent" : (nextMouse.containsMouse ? Theme.hoverMuted : "transparent")
            scale: (root.selectable && nextMouse.containsMouse && !root.reducedMotion) ? 1.05 : 1.0
            Behavior on color { ColorAnimation { duration: HAnimation.fast } }
            Behavior on scale {
                enabled: !root.reducedMotion
                NumberAnimation {
                    duration: nextMouse.containsMouse ? HAnimation.buttonHoverDuration : HAnimation.buttonReleaseDuration
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: nextMouse.containsMouse ? HAnimation.buttonHoverCurve : HAnimation.buttonReleaseCurve
                }
            }

            Text {
                anchors.centerIn: parent
                text: "󰅂"
                font.family: Theme.iconFontFamily
                font.pixelSize: 19
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
        opacity: root._monthOpacity
        transform: Translate { x: root._monthSlideX }

        Repeater {
            model: 42
            Item {
                id: cellItem
                width: root.cellWidth
                height: root.cellHeight
                readonly property int day: index - root.mondayOffset + 1
                readonly property bool isValidDay: day > 0 && day <= root.daysInMonth
                readonly property string dateKey: isValidDay ? root.dateKeyFor(root.firstDay.getFullYear(), root.firstDay.getMonth(), day) : ""
                readonly property bool today: isValidDay
                    && root.firstDay.getFullYear() === root.currentDate.getFullYear()
                    && root.firstDay.getMonth() === root.currentDate.getMonth()
                    && day === root.currentDate.getDate()
                readonly property bool isSelected: root.selectable && isValidDay && root.selectedDateKey === dateKey
                readonly property bool hasMarker: isValidDay && !!(root.markedDateKeys && root.markedDateKeys[dateKey])
                readonly property bool isHovered: (root.dayHoverEnabled || root.selectable) && isValidDay && dayMouse.containsMouse
                readonly property real markerDiameter: Math.min(parent.width - 2, Math.max(16, root.cellHeight - 2))

                z: (root.selectable && isHovered) ? 2 : 0
                scale: (root.selectable && isHovered && !root.reducedMotion) ? 1.05 : 1.0
                Behavior on scale {
                    enabled: !root.reducedMotion
                    NumberAnimation {
                        duration: cellItem.isHovered ? HAnimation.buttonHoverDuration : HAnimation.buttonReleaseDuration
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: cellItem.isHovered ? HAnimation.buttonHoverCurve : HAnimation.buttonReleaseCurve
                    }
                }

                // Circular day highlight indicator for selected date and today.
                Rectangle {
                    id: dayHighlight
                    anchors.centerIn: parent
                    width: cellItem.markerDiameter
                    height: cellItem.markerDiameter
                    radius: cellItem.markerDiameter / 2
                    visible: root.selectable ? (cellItem.isSelected || cellItem.today)
                        : (cellItem.today || cellItem.isSelected || cellItem.isHovered)
                    color: root.selectable
                        ? (cellItem.isSelected ? Theme.accent : Theme.surfaceSubtle(1.25))
                        : (cellItem.today ? Theme.accent
                            : (cellItem.isSelected ? Theme.surfaceHighlight(1.35) : Theme.surfaceHighlight(1.25)))
                    scale: (!root.selectable && cellItem.isHovered && !cellItem.today && !cellItem.isSelected) ? 1.08 : 1.0
                    border.width: root.selectable ? 0 : ((cellItem.isSelected && !cellItem.today) ? 1 : 0)
                    border.color: Theme.accent

                    Behavior on color {
                        enabled: !root.reducedMotion
                        ColorAnimation { duration: HAnimation.fast }
                    }
                    Behavior on scale { NumberAnimation { duration: HAnimation.buttonHoverDuration } }
                }

                Text {
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: cellItem.hasMarker ? -2 : 0
                    text: cellItem.isValidDay ? cellItem.day : ""
                    color: root.selectable
                        ? (cellItem.isSelected ? Theme.onAccentColor : (cellItem.today ? Theme.accent : Theme.fg))
                        : (cellItem.today ? Theme.onAccentColor : Theme.fg)
                    font.family: Theme.fontFamily
                    font.pixelSize: {
                        if (root.cellHeight > 24) return Theme.fontSize
                        if (root.cellHeight >= 20) return Theme.fontSize - 1
                        return Math.max(10, root.cellHeight - 5)
                    }
                    font.weight: (cellItem.today || cellItem.isSelected) ? Font.Bold : (!root.selectable && cellItem.isHovered ? Font.DemiBold : Font.Normal)
                }

                Rectangle {
                    id: taskDot
                    visible: cellItem.hasMarker
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: dayHighlight.bottom
                    anchors.bottomMargin: 2
                    width: 4
                    height: 4
                    radius: 2
                    color: root.selectable
                        ? (cellItem.isSelected ? Theme.onAccentColor : Theme.accent)
                        : (cellItem.today ? Theme.onAccentColor : Theme.accent)
                }

                MouseArea {
                    id: dayMouse
                    anchors.fill: parent
                    hoverEnabled: (root.dayHoverEnabled || root.selectable) && cellItem.isValidDay
                    enabled: (root.dayHoverEnabled || root.selectable) && cellItem.isValidDay
                    cursorShape: ((root.dayHoverEnabled || root.selectable) && cellItem.isValidDay) ? Qt.PointingHandCursor : Qt.ArrowCursor
                    acceptedButtons: Qt.LeftButton
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
                    onClicked: {
                        if (root.selectable && cellItem.isValidDay) {
                            DashboardTooltip.dismiss()
                            root.dateSelected(cellItem.dateKey)
                        }
                    }
                }
            }
        }
    }
}
