import QtQuick
import "../../services"
import "../motion" as Motion

Motion.MorphButton {
    id: root
    // Arrow targets are independent from compatibility Tab traversal.
    property bool settingsNavItem: true
    property string settingsNavRole: "control"
    property Item settingsNavGroup: null
    // Moderate corners and quiet tonal fills keep small actions distinct from pills.
    radius: Math.min(10, height / 3)
    idleColor: Qt.tint(Theme.surface, Qt.alpha(Theme.overlayInk, 0.06))
    hoverColor: selected ? selectedColor : Qt.tint(Theme.surface, Qt.alpha(Theme.overlayInk, 0.11))
    pressedColor: selected ? Qt.darker(selectedColor, 1.08) : Qt.tint(Theme.surface, Qt.alpha(Theme.accent, 0.18))
    focusColor: selected ? selectedColor : hoverColor
    hoverForegroundColor: selected ? selectedForegroundColor : foregroundColor
    pressedForegroundColor: hoverForegroundColor
    focusForegroundColor: hoverForegroundColor
    // Transparent controls let their shared selection pill own the surface.
    readonly property bool flat: idleColor.a === 0 && selectedColor.a === 0
    border.width: 0
    border.color: activeFocus ? Theme.accent : Theme.hoverMuted
    // An inset underline keeps keyboard focus visible without another pill outline.
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.gap
        width: Math.max(0, Math.min(parent.width - Theme.pad * 2, Theme.fontSize * 2))
        height: 1
        color: root.selected ? Theme.onAccentColor : Theme.accent
        visible: root.activeFocus
    }
    Accessible.role: Accessible.Button
    Accessible.name: text
    Accessible.onPressAction: clicked()
    hoverScaleDelta: 0.006
    pressScaleDelta: 0.02
    hoverXScaleDelta: 0.01
    pressXScaleDelta: 0.01
}
