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
        height: 20
        radius: height / 2
        color: Theme.hoverMuted
        Rectangle {
            // Follow the animated handle so the solid fill and marker stay joined.
            width: root.handle ? Math.max(0, Math.min(parent.width, root.handle.x - parent.x + root.handle.width)) : 0
            height: parent.height
            radius: parent.radius
            color: Theme.accent
        }
    }
    handle: Item {
        x: root.leftPadding + root.visualPosition * (root.availableWidth - width)
        y: root.topPadding + root.availableHeight / 2 - height / 2
        width: 24
        height: 24
        // Keep a circular grip inside the filled track without shrinking its hitbox.
        Rectangle {
            anchors.centerIn: parent
            width: root.activeFocus || root.keyboardEditing ? 16 : 14
            height: width
            radius: width / 2
            color: Theme.onAccentColor
            opacity: root.pressed || root.activeFocus ? 1 : 0.8
        }
        Behavior on x { enabled: !root.pressed; NumberAnimation { duration: HAnimation.fast } }
    }
}
