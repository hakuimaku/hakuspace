import QtQuick
import QtQuick.Controls
import "../../services"

Slider {
    id: root
    // Arrow targets are independent from compatibility Tab traversal.
    property bool settingsNavItem: true
    property string settingsNavRole: "control"
    property Item settingsNavGroup: null
    stepSize: 1
    snapMode: Slider.SnapAlways
    live: true
    implicitWidth: 260
    implicitHeight: 36
    padding: 10
    focusPolicy: Qt.StrongFocus
    // Enter separates spatial navigation from native slider adjustment.
    property Item shortcutTarget: null
    property bool keyboardEditing: false
    readonly property bool settingsNavEditing: keyboardEditing
    Keys.forwardTo: shortcutTarget ? [shortcutTarget] : []
    Keys.onPressed: event => {
        if (!keyboardEditing && event.modifiers === Qt.NoModifier
                && [Qt.Key_Left, Qt.Key_Right, Qt.Key_Up, Qt.Key_Down, Qt.Key_Home, Qt.Key_End].includes(event.key))
            event.accepted = true
    }
    Keys.onReturnPressed: keyboardEditing = !keyboardEditing
    Keys.onEnterPressed: keyboardEditing = !keyboardEditing
    Keys.onEscapePressed: event => {
        if (keyboardEditing) keyboardEditing = false
        else event.accepted = false
    }
    onActiveFocusChanged: { if (!activeFocus) keyboardEditing = false }
    Accessible.description: keyboardEditing ? "Arrow keys adjust the value. Enter or Escape finishes editing."
        : "Enter edits the value. Arrow keys move focus."

    // Keep platform slider keyboard/accessibility behavior with native Hikai visuals.
    background: Rectangle {
        x: root.leftPadding
        y: root.topPadding + root.availableHeight / 2 - height / 2
        width: root.availableWidth
        height: 4
        radius: Theme.radius
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
        width: 12
        height: 16
        radius: Theme.radius
        color: root.pressed || root.keyboardEditing ? Theme.fg : Theme.accent
        border.width: root.activeFocus ? 2 : 0
        border.color: Theme.fg
        scale: root.pressed ? 1.15 : root.hovered ? 1.05 : 1
        Behavior on x { enabled: !root.pressed; NumberAnimation { duration: HAnimation.fast } }
        Behavior on scale { NumberAnimation { duration: HAnimation.buttonHoverDuration } }
        Behavior on color { ColorAnimation { duration: HAnimation.fast } }
    }
}
