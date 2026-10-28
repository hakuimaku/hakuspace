import QtQuick
import "../../services"
import "../settings" as Settings

// A file-backed type remains stable across Quickshell configuration reloads.
Settings.SettingsActionButton {
    id: root
    activeFocusOnTab: true
    focused: activeFocus
    fontSize: Theme.fontSize - 1
    // Expand the background independently so the label and hitbox remain stable.
    expandedVisual: true
    border.width: 0
    idleColor: Theme.hoverMuted
    hoverColor: idleColor
    hoverForegroundColor: foregroundColor
    selectedOverridesHover: true
    hoverXScaleDelta: 0.08
    pressXScaleDelta: 0.13
    hoverScaleDelta: 0.012
    pressScaleDelta: 0.045
    radius: pressed ? 6 : hovered ? height / 2 : 10
    z: hovered || pressed || activeFocus ? 2 : 1
    Behavior on radius {
        NumberAnimation {
            duration: transitionDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: transitionCurve
        }
    }
    Keys.onReturnPressed: clicked()
    Keys.onSpacePressed: clicked()
}
