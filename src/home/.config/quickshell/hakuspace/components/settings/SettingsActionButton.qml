import QtQuick
import "../../services"
import "../motion" as Motion

Motion.MorphButton {
    id: root
    // Arrow targets are independent from compatibility Tab traversal.
    property bool settingsNavItem: true
    property string settingsNavRole: "control"
    property Item settingsNavGroup: null
    radius: Theme.radius
    // Reserve accent fills for explicit selection and primary actions.
    hoverColor: Theme.surfaceHighlight(1.18)
    pressedColor: Theme.hoverMuted
    hoverForegroundColor: Theme.fg
    pressedForegroundColor: Theme.fg
    // Transparent controls let their shared selection pill own the surface.
    readonly property bool flat: idleColor.a === 0 && selectedColor.a === 0
    border.width: flat ? 0 : 1
    border.color: activeFocus ? Theme.accent : Theme.hoverMuted
    // An inset underline keeps keyboard focus visible without another pill outline.
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.gap
        width: Math.max(0, Math.min(parent.width - Theme.pad * 2, Theme.fontSize * 2))
        height: 1
        color: root.selected ? Theme.onAccentColor : Theme.fg
        visible: root.flat && root.activeFocus
    }
    Accessible.role: Accessible.Button
    Accessible.name: text
    Accessible.onPressAction: clicked()
    hoverScaleDelta: 0.012
    pressScaleDelta: 0.045
    hoverXScaleDelta: 0.02
    pressXScaleDelta: 0.02
}
