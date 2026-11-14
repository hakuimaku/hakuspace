import QtQuick
import QtQuick.Controls
import "../../services"

Rectangle {
    id: root
    property string title: ""
    property string icon: ""
    property string valueText: ""
    property real from: 0
    property real to: 100
    property real stepSize: 1
    property real value: 0
    property bool available: true
    property bool hoverEnabled: true
    property bool focused: false
    property bool iconInteractive: false
    readonly property alias dragging: slider.pressed

    signal movedValue(real nextValue)
    signal iconClicked()

    radius: Theme.radius
    color: Qt.tint(Theme.surface, Qt.alpha(Theme.hoverMuted, 0.4))
    border.width: focused ? 2 : 0
    border.color: Theme.accent
    opacity: available ? 1 : 0.45
    transformOrigin: Item.Center
    scale: (cardHover.hovered || dragging) && available ? 1.05 : 1.0

    Behavior on scale {
        NumberAnimation {
            duration: HAnimation.buttonHoverDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: HAnimation.buttonHoverCurve
        }
    }

    HoverHandler {
        id: cardHover
        enabled: root.available && root.hoverEnabled
    }

    Item {
        anchors {
            top: parent.top
            topMargin: 10
            left: parent.left
            leftMargin: 14
            right: parent.right
            rightMargin: 14
        }
        height: 24

        Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            Item {
                width: 20
                height: 20
                anchors.verticalCenter: parent.verticalCenter

                Text {
                    anchors.centerIn: parent
                    text: root.icon
                    font.family: Theme.fontFamily
                    font.pixelSize: Math.max(15, Theme.fontSize + 1)
                    color: root.available ? Theme.accent : Theme.fgMuted
                    scale: iconArea.containsMouse ? 1.15 : 1.0
                    Behavior on scale { NumberAnimation { duration: HAnimation.fast } }
                }

                MouseArea {
                    id: iconArea
                    anchors.fill: parent
                    enabled: root.iconInteractive && root.available && root.hoverEnabled
                    hoverEnabled: true
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: root.iconClicked()
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.title
                font.family: Theme.fontFamily
                font.pixelSize: Math.max(11, Theme.fontSize - 1)
                font.weight: Font.DemiBold
                color: root.available ? Theme.fg : Theme.fgMuted
            }
        }

        Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: root.valueText
            font.family: Theme.fontFamily
            font.pixelSize: Math.max(10, Theme.fontSize - 2)
            color: root.available ? Theme.fgDim : Theme.fgMuted
        }
    }

    Slider {
        id: slider
        anchors {
            left: parent.left
            leftMargin: 8
            right: parent.right
            rightMargin: 8
            bottom: parent.bottom
            bottomMargin: 10
        }
        height: 36
        padding: 6
        from: root.from
        to: root.to
        stepSize: root.stepSize
        snapMode: Slider.SnapAlways
        live: true
        wheelEnabled: true
        enabled: root.available && root.hoverEnabled
        focusPolicy: Qt.NoFocus
        activeFocusOnTab: false
        value: root.value
        onMoved: root.movedValue(value)

        // Match SettingsSlider's track, joined fill, and inner circular grip.
        background: Rectangle {
            x: slider.leftPadding
            y: slider.topPadding + slider.availableHeight / 2 - height / 2
            width: slider.availableWidth
            height: 20
            radius: height / 2
            color: Theme.hoverMuted

            Rectangle {
                width: slider.handle ? Math.max(0, Math.min(parent.width, slider.handle.x - parent.x + slider.handle.width)) : 0
                height: parent.height
                radius: parent.radius
                color: Theme.accent
            }
        }

        handle: Item {
            x: slider.leftPadding + slider.visualPosition * (slider.availableWidth - width)
            y: slider.topPadding + slider.availableHeight / 2 - height / 2
            width: 24
            height: 24

            Rectangle {
                anchors.centerIn: parent
                width: root.focused || slider.pressed ? 16 : 14
                height: width
                radius: width / 2
                color: Theme.onAccentColor
                opacity: slider.pressed || root.focused ? 1 : 0.8
            }

            Behavior on x {
                enabled: !slider.pressed
                NumberAnimation { duration: HAnimation.fast }
            }
        }
    }
}
