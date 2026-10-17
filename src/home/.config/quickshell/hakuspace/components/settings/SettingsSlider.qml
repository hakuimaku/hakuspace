import QtQuick
import QtQuick.Controls
import "../../services"

Slider {
    id: root
    stepSize: 1
    snapMode: Slider.SnapAlways
    live: true
    implicitWidth: 260
    implicitHeight: 32
    padding: 8
    focusPolicy: Qt.StrongFocus

    // Keep platform slider keyboard/accessibility behavior with native Hikai visuals.
    background: Rectangle {
        x: root.leftPadding
        y: root.topPadding + root.availableHeight / 2 - height / 2
        width: root.availableWidth
        height: 6
        radius: 3
        color: Theme.hoverMuted
        Rectangle {
            width: root.visualPosition * parent.width
            height: parent.height
            radius: parent.radius
            color: Theme.accent
        }
    }
    handle: Rectangle {
        x: root.leftPadding + root.visualPosition * (root.availableWidth - width)
        y: root.topPadding + root.availableHeight / 2 - height / 2
        width: 16
        height: 16
        radius: width / 2
        color: root.pressed ? Theme.fg : Theme.accent
        border.width: root.activeFocus ? 2 : 0
        border.color: Theme.fg
        scale: root.pressed ? 1.15 : root.hovered ? 1.05 : 1
        Behavior on x { enabled: !root.pressed; NumberAnimation { duration: HAnimation.fast } }
        Behavior on scale { NumberAnimation { duration: HAnimation.buttonHoverDuration } }
        Behavior on color { ColorAnimation { duration: HAnimation.fast } }
    }
}
