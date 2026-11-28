import QtQuick
import Quickshell
import "../../services"

// Clock and Focus Timer split card positioned in Row 1, Col 1 of the Dashboard cluster.
Rectangle {
    id: root

    radius: Theme.largeRadius
    color: Theme.surfaceSubtle(1.6)
    border.width: 0
    clip: true

    readonly property bool reducedMotion: Quickshell.env("HAKUSPACE_REDUCED_MOTION") === "1"
    readonly property int sidePad: Math.max(12, Math.round(Theme.pad * 1.1))

    // Left half: Clock + compact date
    Item {
        id: clockHalf
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: Math.round(parent.width * 0.41)

        Column {
            anchors.centerIn: parent
            width: Math.max(0, parent.width - root.sidePad * 2)
            spacing: 4

            Text {
                id: timeText
                anchors.horizontalCenter: parent.horizontalCenter
                text: Clock.date ? Clock.date.toLocaleString(Qt.locale(), "HH:mm") : ""
                font.family: Theme.fontFamily
                font.pixelSize: Math.round(Theme.fontSize * 1.9)
                font.weight: Font.Bold
                color: Theme.fg
            }

            Text {
                id: dateText
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.min(implicitWidth, parent.width)
                horizontalAlignment: Text.AlignHCenter
                text: Clock.date ? Clock.date.toLocaleString(Qt.locale(), "ddd, dd/MM") : ""
                font.family: Theme.fontFamily
                font.pixelSize: Math.max(11, Theme.fontSize - 1)
                font.weight: Font.Normal
                color: Theme.fgDim
                elide: Text.ElideRight
            }
        }

        HoverHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onHoveredChanged: {
                if (hovered && Clock.date) {
                    DashboardTooltip.show(clockHalf, Clock.date.toLocaleDateString(Qt.locale(), Locale.LongFormat) + " " + Clock.date.toLocaleTimeString(Qt.locale(), "HH:mm:ss"))
                } else {
                    DashboardTooltip.hide(clockHalf)
                }
            }
        }
    }

    // Hairline vertical divider
    Rectangle {
        id: divider
        anchors.left: clockHalf.right
        anchors.verticalCenter: parent.verticalCenter
        width: 1
        height: Math.round(parent.height * 0.64)
        color: Qt.alpha(Theme.fgMuted, 0.16)
    }

    // Right half: Focus Timer controls & flexible +/- duration adjustments
    Item {
        id: timerHalf
        anchors.left: divider.right
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom

        Column {
            id: timerColumn
            anchors.centerIn: parent
            width: Math.max(0, parent.width - root.sidePad * 2)
            spacing: 10

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 10

                Item {
                    id: timerDisplay
                    anchors.verticalCenter: parent.verticalCenter
                    width: timerText.implicitWidth + 8
                    height: Math.max(30, timerText.implicitHeight)

                    Text {
                        id: timerText
                        anchors.centerIn: parent
                        text: FocusTimer.formattedTime
                        font.family: Theme.fontFamily
                        font.pixelSize: Math.round(Theme.fontSize * 1.65)
                        font.weight: Font.Bold
                        color: FocusTimer.running ? Theme.accent : Theme.fg
                    }

                    HoverHandler {
                        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                        onHoveredChanged: {
                            if (hovered) DashboardTooltip.show(timerDisplay, "Scroll to adjust ±1m (Shift: ±5m)")
                            else DashboardTooltip.hide(timerDisplay)
                        }
                    }

                    WheelHandler {
                        target: null
                        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                        onWheel: event => {
                            var dir = event.angleDelta.y > 0 ? 1 : (event.angleDelta.y < 0 ? -1 : 0)
                            if (dir === 0) return
                            var step = (event.modifiers & Qt.ShiftModifier) ? 5 : 1
                            DashboardTooltip.dismiss()
                            FocusTimer.adjustMinutes(dir * step)
                            event.accepted = true
                        }
                    }
                }

                Rectangle {
                    id: playPauseBtn
                    anchors.verticalCenter: parent.verticalCenter
                    width: 36
                    height: 36
                    radius: 18
                    color: FocusTimer.running ? Theme.accent : Theme.surfaceSubtle(1.25)
                    scale: (playPauseMouse.containsMouse && !root.reducedMotion) ? 1.05 : 1.0

                    Behavior on color {
                        enabled: !root.reducedMotion
                        ColorAnimation { duration: HAnimation.fast }
                    }
                    Behavior on scale {
                        enabled: !root.reducedMotion
                        NumberAnimation {
                            duration: playPauseMouse.containsMouse ? HAnimation.buttonHoverDuration : HAnimation.buttonReleaseDuration
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: playPauseMouse.containsMouse ? HAnimation.buttonHoverCurve : HAnimation.buttonReleaseCurve
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: FocusTimer.running ? "󰏤" : "󰐊"
                        font.family: Theme.iconFontFamily
                        font.pixelSize: 20
                        color: FocusTimer.running ? Theme.onAccentColor : Theme.fg
                    }

                    MouseArea {
                        id: playPauseMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton
                        onEntered: DashboardTooltip.show(playPauseBtn, FocusTimer.running ? "Pause focus timer" : (FocusTimer.paused ? "Resume focus timer" : "Start focus timer"))
                        onExited: DashboardTooltip.hide(playPauseBtn)
                        onClicked: {
                            DashboardTooltip.dismiss()
                            FocusTimer.toggle()
                        }
                    }
                }

                Rectangle {
                    id: resetBtn
                    visible: FocusTimer.active
                    anchors.verticalCenter: parent.verticalCenter
                    width: 32
                    height: 32
                    radius: 16
                    color: Theme.surfaceSubtle(1.25)
                    scale: (resetMouse.containsMouse && !root.reducedMotion) ? 1.05 : 1.0

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
                        color: Theme.fgDim
                    }

                    MouseArea {
                        id: resetMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton
                        onEntered: DashboardTooltip.show(resetBtn, "Reset focus timer")
                        onExited: DashboardTooltip.hide(resetBtn)
                        onClicked: {
                            DashboardTooltip.dismiss()
                            FocusTimer.reset()
                        }
                    }
                }
            }

            Row {
                id: adjustRow
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 6

                readonly property real btnWidth: Math.max(38, Math.min(54, Math.floor((timerColumn.width - spacing * 3 - 4) / 4)))

                Repeater {
                    model: [
                        { delta: -5, icon: "󰄽", tip: "Decrease 5 min" },
                        { delta: -1, icon: "󰅁", tip: "Decrease 1 min" },
                        { delta: 1,  icon: "󰅂", tip: "Increase 1 min" },
                        { delta: 5,  icon: "󰄾", tip: "Increase 5 min" }
                    ]

                    delegate: Rectangle {
                        id: adjustBtn
                        required property var modelData
                        readonly property bool canAct: modelData.delta < 0 ? FocusTimer.canDecrease : FocusTimer.canIncrease
                        property bool _didRepeat: false

                        width: adjustRow.btnWidth
                        height: 32
                        radius: Theme.radius
                        color: Theme.surface
                        border.width: 0
                        opacity: canAct ? 1.0 : 0.38
                        scale: (btnMouse.containsMouse && canAct && !root.reducedMotion) ? 1.05 : 1.0

                        onCanActChanged: if (!canAct) holdRepeatTimer.stop()

                        Behavior on scale {
                            enabled: !root.reducedMotion
                            NumberAnimation {
                                duration: btnMouse.containsMouse ? HAnimation.buttonHoverDuration : HAnimation.buttonReleaseDuration
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: btnMouse.containsMouse ? HAnimation.buttonHoverCurve : HAnimation.buttonReleaseCurve
                            }
                        }

                        Timer {
                            id: holdRepeatTimer
                            interval: 140
                            repeat: true
                            running: false
                            onTriggered: {
                                if (!adjustBtn.canAct) {
                                    stop()
                                    return
                                }
                                adjustBtn._didRepeat = true
                                FocusTimer.adjustMinutes(adjustBtn.modelData.delta)
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: adjustBtn.modelData.icon
                            font.family: Theme.iconFontFamily
                            font.pixelSize: 19
                            color: adjustBtn.canAct ? Theme.fg : Theme.fgMuted
                        }

                        MouseArea {
                            id: btnMouse
                            anchors.fill: parent
                            enabled: adjustBtn.canAct
                            hoverEnabled: true
                            pressAndHoldInterval: 360
                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                            acceptedButtons: Qt.LeftButton
                            onEntered: DashboardTooltip.show(adjustBtn, adjustBtn.modelData.tip)
                            onExited: DashboardTooltip.hide(adjustBtn)
                            onPressed: adjustBtn._didRepeat = false
                            onPressAndHold: {
                                if (!adjustBtn.canAct) return
                                DashboardTooltip.dismiss()
                                adjustBtn._didRepeat = true
                                FocusTimer.adjustMinutes(adjustBtn.modelData.delta)
                                holdRepeatTimer.start()
                            }
                            onReleased: holdRepeatTimer.stop()
                            onCanceled: holdRepeatTimer.stop()
                            onClicked: {
                                if (adjustBtn._didRepeat || !adjustBtn.canAct) return
                                DashboardTooltip.dismiss()
                                FocusTimer.adjustMinutes(adjustBtn.modelData.delta)
                            }
                        }
                    }
                }
            }
        }

        // Ultra-thin progress bar anchored along the bottom of the timer half
        Rectangle {
            visible: FocusTimer.active
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.leftMargin: root.sidePad
            anchors.rightMargin: root.sidePad
            anchors.bottomMargin: 6
            height: 2
            radius: 1
            color: Theme.surfaceSubtle(1.25)

            Rectangle {
                height: parent.height
                width: Math.round(parent.width * FocusTimer.progress)
                radius: 1
                color: Theme.accent
            }
        }
    }
}
