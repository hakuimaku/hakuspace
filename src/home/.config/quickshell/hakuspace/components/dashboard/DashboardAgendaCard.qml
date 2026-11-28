import QtQuick
import Quickshell
import "../../services"
import "../motion" as Motion

Rectangle {
    id: root

    radius: Theme.largeRadius
    color: Theme.surfaceSubtle(1.6)
    border.width: 0
    clip: true

    property bool active: false
    readonly property bool reducedMotion: Quickshell.env("HAKUSPACE_REDUCED_MOTION") === "1"

    onActiveChanged: if (active) AgendaStore.ensureLoaded()
    Component.onCompleted: if (active) AgendaStore.ensureLoaded()

    readonly property var taskItems: {
        // Bind explicitly to AgendaStore state so list updates immediately on edits or date switches.
        var _i = AgendaStore.items
        var _d = AgendaStore.selectedDateKey
        var _m = AgendaStore.filterMode
        return AgendaStore.visibleItems()
    }

    function parseDateKey(dateKey) {
        if (!dateKey || dateKey.length !== 10) return null
        var parts = dateKey.split("-")
        if (parts.length !== 3) return null
        var y = parseInt(parts[0], 10)
        var m = parseInt(parts[1], 10)
        var d = parseInt(parts[2], 10)
        if (!isFinite(y) || !isFinite(m) || !isFinite(d)) return null
        return new Date(y, m - 1, d)
    }

    function formatShortDate(dateKey) {
        var dt = parseDateKey(dateKey)
        if (!dt) return dateKey || ""
        return dt.toLocaleString(Qt.locale(), "d MMM")
    }

    function formatHeaderTitle() {
        if (AgendaStore.filterMode === "all") return "All Tasks"
        var key = AgendaStore.selectedDateKey || AgendaStore.todayKey()
        var dt = parseDateKey(key)
        if (!dt) return key
        if (key === AgendaStore.todayKey()) {
            return "Today · " + dt.toLocaleString(Qt.locale(), "d MMM")
        }
        return dt.toLocaleString(Qt.locale(), "ddd, d MMM")
    }

    function submitTask() {
        var text = inputField.text.trim()
        if (text.length === 0) return
        var targetDate = AgendaStore.filterMode === "day"
            ? (AgendaStore.selectedDateKey || AgendaStore.todayKey())
            : ""
        if (AgendaStore.addItem(text, targetDate)) {
            inputField.text = ""
        }
    }

    readonly property int cardPadX: Math.max(14, Math.round(Theme.pad * 1.25))
    readonly property int cardPadY: Math.max(10, Math.round(Theme.pad * 0.9))
    readonly property real hoverInsetX: Math.max(cardPadX, Math.ceil(width * 0.03) + 4)

    property real _listAnimY: 0
    property real _listAnimOpacity: 1.0

    function _playListTransition() {
        if (root.reducedMotion) return
        listSwitchAnim.stop()
        listSwitchAnim.start()
    }

    Connections {
        target: AgendaStore
        function onFilterModeChanged() { root._playListTransition() }
        function onSelectedDateKeyChanged() { root._playListTransition() }
    }

    ParallelAnimation {
        id: listSwitchAnim
        NumberAnimation {
            target: root
            property: "_listAnimY"
            from: 10
            to: 0
            duration: HAnimation.normal
            easing.type: Easing.BezierSpline
            easing.bezierCurve: HAnimation.moduleCurve
        }
        NumberAnimation {
            target: root
            property: "_listAnimOpacity"
            from: 0.3
            to: 1.0
            duration: HAnimation.normal
            easing.type: Easing.BezierSpline
            easing.bezierCurve: HAnimation.moduleCurve
        }
    }

    Item {
        id: headerArea
        anchors.top: parent.top
        anchors.topMargin: root.cardPadY
        anchors.left: parent.left
        anchors.leftMargin: root.hoverInsetX
        anchors.right: parent.right
        anchors.rightMargin: root.hoverInsetX
        height: 38

        Row {
            id: titleRow
            anchors.left: parent.left
            anchors.right: segmentedControl.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6

            Text {
                id: headerTitle
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, Math.max(0, titleRow.width - (jumpTodayBtn.visible ? jumpTodayBtn.width + titleRow.spacing : 0)))
                text: root.formatHeaderTitle()
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize + 1
                font.weight: Font.Bold
                color: Theme.fg
                elide: Text.ElideRight
            }

            Rectangle {
                id: jumpTodayBtn
                visible: AgendaStore.filterMode === "day" && AgendaStore.selectedDateKey !== AgendaStore.todayKey()
                anchors.verticalCenter: parent.verticalCenter
                width: 32
                height: 32
                radius: 16
                color: "transparent"
                scale: (jumpTodayMouse.containsMouse && !root.reducedMotion) ? 1.05 : 1.0

                Behavior on scale {
                    enabled: !root.reducedMotion
                    NumberAnimation {
                        duration: jumpTodayMouse.containsMouse ? HAnimation.buttonHoverDuration : HAnimation.buttonReleaseDuration
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: jumpTodayMouse.containsMouse ? HAnimation.buttonHoverCurve : HAnimation.buttonReleaseCurve
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: "󰑐"
                    font.family: Theme.iconFontFamily
                    font.pixelSize: 18
                    color: Theme.fgDim
                }

                MouseArea {
                    id: jumpTodayMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton
                    onEntered: DashboardTooltip.show(jumpTodayBtn, "Jump to today")
                    onExited: DashboardTooltip.hide(jumpTodayBtn)
                    onClicked: {
                        DashboardTooltip.dismiss()
                        AgendaStore.selectToday()
                    }
                }
            }
        }

        Rectangle {
            id: segmentedControl
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 116
            height: 30
            radius: Theme.radius
            color: Theme.surface

            Item {
                id: segmentedLane
                anchors.fill: parent
                anchors.margins: 2

                Motion.SelectionPill {
                    id: filterPill
                    z: 0
                    coordinateSpace: segmentedLane
                    targetIndex: AgendaStore.filterMode === "day" ? 0 : 1
                    slotCount: 2
                    slotSpacing: 2
                    normalColor: Theme.accent
                    duration: root.reducedMotion ? 0 : HAnimation.spatial
                    fadeEnabled: false
                }

                Row {
                    anchors.fill: parent
                    spacing: 2
                    z: 1

                    Repeater {
                        model: [
                            { key: "day", label: "Day" },
                            { key: "all", label: "All" }
                        ]

                        delegate: Item {
                            required property var modelData
                            required property int index
                            readonly property bool selected: AgendaStore.filterMode === modelData.key

                            width: Math.max(0, (segmentedLane.width - 2) / 2)
                            height: segmentedLane.height

                            Text {
                                anchors.centerIn: parent
                                text: modelData.label
                                font.family: Theme.fontFamily
                                font.pixelSize: Math.max(11, Theme.fontSize - 1)
                                font.weight: selected ? Font.DemiBold : Font.Normal
                                color: selected ? Theme.onAccentColor : Theme.fgDim
                                scale: (segMouse.containsMouse && !root.reducedMotion) ? 1.05 : 1.0

                                Behavior on color {
                                    enabled: !root.reducedMotion
                                    ColorAnimation {
                                        duration: HAnimation.selectionMorphDuration
                                        easing.type: Easing.BezierSpline
                                        easing.bezierCurve: HAnimation.selectionMorphCurve
                                    }
                                }
                                Behavior on scale {
                                    enabled: !root.reducedMotion
                                    NumberAnimation {
                                        duration: segMouse.containsMouse ? HAnimation.buttonHoverDuration : HAnimation.buttonReleaseDuration
                                        easing.type: Easing.BezierSpline
                                        easing.bezierCurve: segMouse.containsMouse ? HAnimation.buttonHoverCurve : HAnimation.buttonReleaseCurve
                                    }
                                }
                            }

                            MouseArea {
                                id: segMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                acceptedButtons: Qt.LeftButton
                                onClicked: {
                                    DashboardTooltip.dismiss()
                                    AgendaStore.setFilterMode(modelData.key)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Rectangle {
        id: errorBanner
        visible: AgendaStore.error.length > 0
        anchors.top: headerArea.bottom
        anchors.topMargin: 6
        anchors.left: parent.left
        anchors.leftMargin: root.hoverInsetX
        anchors.right: parent.right
        anchors.rightMargin: root.hoverInsetX
        height: visible ? 30 : 0
        radius: Theme.radius
        color: Theme.surface

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.right: retryBtn.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            text: AgendaStore.error
            font.family: Theme.fontFamily
            font.pixelSize: Math.max(11, Theme.fontSize - 1)
            color: Theme.danger
            elide: Text.ElideRight
        }

        Rectangle {
            id: retryBtn
            anchors.right: parent.right
            anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            width: retryLabel.implicitWidth + 14
            height: 22
            radius: Theme.radius
            color: "transparent"
            scale: (retryMouse.containsMouse && !root.reducedMotion) ? 1.05 : 1.0

            Behavior on scale {
                enabled: !root.reducedMotion
                NumberAnimation {
                    duration: retryMouse.containsMouse ? HAnimation.buttonHoverDuration : HAnimation.buttonReleaseDuration
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: retryMouse.containsMouse ? HAnimation.buttonHoverCurve : HAnimation.buttonReleaseCurve
                }
            }

            Text {
                id: retryLabel
                anchors.centerIn: parent
                text: "Retry"
                font.family: Theme.fontFamily
                font.pixelSize: Math.max(10, Theme.fontSize - 2)
                font.weight: Font.DemiBold
                color: Theme.danger
            }

            MouseArea {
                id: retryMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton
                onClicked: AgendaStore.reload()
            }
        }
    }

    Item {
        id: bodyArea
        anchors.top: errorBanner.visible ? errorBanner.bottom : headerArea.bottom
        anchors.topMargin: 8
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: footerWell.top
        anchors.bottomMargin: 8
        clip: true

        ListView {
            id: taskList
            anchors.fill: parent
            topMargin: 6
            bottomMargin: 6
            model: root.taskItems
            spacing: 4
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            opacity: root._listAnimOpacity
            transform: Translate { y: root._listAnimY }
            onMovementStarted: DashboardTooltip.dismiss()

            WheelHandler {
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: event => {
                    event.accepted = false
                    DashboardTooltip.dismiss()
                }
            }

            delegate: Item {
                id: taskDelegate
                required property var modelData
                width: ListView.view ? ListView.view.width : 0
                height: 40
                z: rowItem.rowHovered ? 2 : 0

                Rectangle {
                    id: rowItem
                    readonly property var itemData: taskDelegate.modelData
                    readonly property bool isDone: !!itemData.done
                    readonly property bool rowHovered: rowHover.hovered || checkMouse.containsMouse || deleteMouse.containsMouse

                    anchors.centerIn: parent
                    width: Math.max(0, parent.width - root.hoverInsetX * 2)
                    height: parent.height
                    radius: Theme.radius
                    color: "transparent"
                    transformOrigin: Item.Center
                    scale: (rowHovered && !root.reducedMotion) ? 1.05 : 1.0

                    Behavior on scale {
                        enabled: !root.reducedMotion
                        NumberAnimation {
                            duration: rowItem.rowHovered ? HAnimation.buttonHoverDuration : HAnimation.buttonReleaseDuration
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: rowItem.rowHovered ? HAnimation.buttonHoverCurve : HAnimation.buttonReleaseCurve
                        }
                    }

                    HoverHandler {
                        id: rowHover
                        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    }

                    Rectangle {
                        id: checkbox
                        anchors.left: parent.left
                        anchors.leftMargin: 6
                        anchors.verticalCenter: parent.verticalCenter
                        width: 20
                        height: 20
                        radius: 5
                        color: rowItem.isDone ? Theme.accent : "transparent"
                        border.width: rowItem.isDone ? 0 : 1.5
                        border.color: checkMouse.containsMouse ? Theme.accent : Theme.fgMuted
                        scale: (checkMouse.containsMouse && !root.reducedMotion) ? 1.05 : 1.0

                        Behavior on color {
                            enabled: !root.reducedMotion
                            ColorAnimation { duration: HAnimation.fast }
                        }
                        Behavior on scale {
                            enabled: !root.reducedMotion
                            NumberAnimation {
                                duration: checkMouse.containsMouse ? HAnimation.buttonHoverDuration : HAnimation.buttonReleaseDuration
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: checkMouse.containsMouse ? HAnimation.buttonHoverCurve : HAnimation.buttonReleaseCurve
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: rowItem.isDone
                            text: "󰄬"
                            font.family: Theme.iconFontFamily
                            font.pixelSize: 14
                            color: Theme.onAccentColor
                        }

                        MouseArea {
                            id: checkMouse
                            anchors.fill: parent
                            anchors.margins: -5
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton
                            onClicked: AgendaStore.toggleItem(rowItem.itemData.id)
                        }
                    }

                    Text {
                        id: titleText
                        anchors.left: checkbox.right
                        anchors.leftMargin: 10
                        anchors.right: dateBadge.visible ? dateBadge.left : deleteBtn.left
                        anchors.rightMargin: 6
                        anchors.verticalCenter: parent.verticalCenter
                        text: rowItem.itemData.title || ""
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                        font.strikeout: rowItem.isDone
                        color: rowItem.isDone ? Theme.fgMuted : Theme.fg
                        elide: Text.ElideRight
                    }

                    Text {
                        id: dateBadge
                        visible: AgendaStore.filterMode === "all" && !!rowItem.itemData.date && rowItem.itemData.date.length > 0
                        anchors.right: deleteBtn.left
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.formatShortDate(rowItem.itemData.date)
                        font.family: Theme.fontFamily
                        font.pixelSize: Math.max(10, Theme.fontSize - 2)
                        color: Theme.fgDim
                    }

                    Rectangle {
                        id: deleteBtn
                        anchors.right: parent.right
                        anchors.rightMargin: 4
                        anchors.verticalCenter: parent.verticalCenter
                        width: 30
                        height: 30
                        radius: 15
                        color: "transparent"
                        opacity: rowItem.rowHovered ? 1.0 : 0.0
                        visible: opacity > 0.01
                        scale: (deleteMouse.containsMouse && !root.reducedMotion) ? 1.05 : 1.0

                        Behavior on opacity {
                            enabled: !root.reducedMotion
                            NumberAnimation { duration: HAnimation.fast }
                        }
                        Behavior on scale {
                            enabled: !root.reducedMotion
                            NumberAnimation {
                                duration: deleteMouse.containsMouse ? HAnimation.buttonHoverDuration : HAnimation.buttonReleaseDuration
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: deleteMouse.containsMouse ? HAnimation.buttonHoverCurve : HAnimation.buttonReleaseCurve
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "󰆴"
                            font.family: Theme.iconFontFamily
                            font.pixelSize: 17
                            color: deleteMouse.containsMouse ? Theme.danger : Theme.fgMuted

                            Behavior on color {
                                enabled: !root.reducedMotion
                                ColorAnimation { duration: HAnimation.fast }
                            }
                        }

                        MouseArea {
                            id: deleteMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: rowItem.rowHovered
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton
                            onClicked: AgendaStore.removeItem(rowItem.itemData.id)
                        }
                    }
                }
            }
        }

        Text {
            anchors.centerIn: parent
            visible: taskList.count === 0 && !AgendaStore.loading
            width: Math.max(0, parent.width - root.hoverInsetX * 2)
            horizontalAlignment: Text.AlignHCenter
            text: AgendaStore.filterMode === "day" ? "No tasks for this day" : "No tasks yet"
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            color: Theme.fgMuted
            wrapMode: Text.WordWrap
        }
    }

    Rectangle {
        id: footerWell
        anchors.left: parent.left
        anchors.leftMargin: root.hoverInsetX
        anchors.right: parent.right
        anchors.rightMargin: root.hoverInsetX
        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.cardPadY
        height: Math.max(42, Theme.comfortableControlHeight)
        radius: Theme.radius
        color: Theme.surface
        border.width: inputField.activeFocus ? 1 : 0
        border.color: Theme.accent

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.right: addBtn.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            visible: inputField.text.length === 0 && !inputField.inputMethodComposing
            text: "Add task…"
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            color: Theme.fgMuted
            elide: Text.ElideRight
        }

        TextInput {
            id: inputField
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.right: addBtn.left
            anchors.rightMargin: 8
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            verticalAlignment: TextInput.AlignVCenter
            clip: true
            readOnly: false
            maximumLength: 300
            selectByMouse: true
            color: Theme.fg
            selectionColor: Theme.accent
            selectedTextColor: Theme.onAccentColor
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            onAccepted: root.submitTask()
        }

        Rectangle {
            id: addBtn
            readonly property bool canAdd: inputField.text.trim().length > 0
            anchors.right: parent.right
            anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            width: 32
            height: 32
            radius: Math.max(6, Theme.radius - 2)
            color: canAdd ? Theme.accent : "transparent"
            scale: (addMouse.containsMouse && canAdd && !root.reducedMotion) ? 1.05 : 1.0

            Behavior on color {
                enabled: !root.reducedMotion
                ColorAnimation { duration: HAnimation.fast }
            }
            Behavior on scale {
                enabled: !root.reducedMotion
                NumberAnimation {
                    duration: addMouse.containsMouse ? HAnimation.buttonHoverDuration : HAnimation.buttonReleaseDuration
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: addMouse.containsMouse ? HAnimation.buttonHoverCurve : HAnimation.buttonReleaseCurve
                }
            }

            Text {
                anchors.centerIn: parent
                text: "󰐕"
                font.family: Theme.iconFontFamily
                font.pixelSize: 18
                color: addBtn.canAdd ? Theme.onAccentColor : Theme.fgMuted
            }

            MouseArea {
                id: addMouse
                anchors.fill: parent
                enabled: addBtn.canAdd
                hoverEnabled: true
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                acceptedButtons: Qt.LeftButton
                onClicked: root.submitTask()
            }
        }
    }
}
