import QtQuick
import Quickshell
import "../../services"
import "../motion" as Motion

Motion.MorphButton {
    id: root
    width: Math.max(implicitWidth, height)
    height: Theme.fontSize * 2
    radius: Theme.radiusSm
    idleColor: Theme.surface
    hoverColor: Theme.surfaceHi
    pressedColor: Theme.surfaceHi
    selectedColor: Theme.accent
    foregroundColor: Theme.fg
    hoverForegroundColor: Theme.onAccentColor
    pressedForegroundColor: Theme.onAccentColor
    selectedForegroundColor: Theme.onAccentColor
}
