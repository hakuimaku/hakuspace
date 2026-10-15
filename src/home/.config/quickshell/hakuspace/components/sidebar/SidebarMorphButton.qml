import QtQuick
import "../motion" as Motion
import "../../services"

Motion.MorphButton {
    idleColor: Theme.hoverMuted
    foregroundColor: Theme.accent
    hoverColor: Theme.accent
    hoverForegroundColor: Theme.onAccentColor
    pressedColor: Qt.darker(Theme.accent, 1.16)
    pressedForegroundColor: Theme.onAccentColor
    selectedColor: Theme.accent
    selectedForegroundColor: Theme.onAccentColor
    focusColor: idleColor
    focusForegroundColor: Theme.accent
    hoverScaleDelta: 0.16
    pressScaleDelta: 0.05
    border.width: focused ? 2 : 0
    border.color: Theme.accent
}
