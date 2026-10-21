import QtQuick
import Quickshell
import Quickshell.Wayland
import "../services"

PanelWindow {
    id: root
    // Each output uses local dimensions with the shared transition progress.
    required property var modelData
    screen: modelData
    anchors { top: true; bottom: true; left: true; right: true }
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "hakuspace-shell-transition"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0
    color: "transparent"
    visible: ShellTransitionState.active
    mask: Region { item: ShellTransitionState.active ? inputSurface : null }

    // Normalized progress travels continuously from entry through cover to exit.
    function layerY(progress, outputHeight) {
        return outputHeight * (ShellTransitionState.direction === "up" ? 1 - progress : progress - 1)
    }

    Item {
        id: inputSurface
        anchors.fill: parent
        Rectangle {
            width: parent.width; height: parent.height
            y: root.layerY(ShellTransitionState.accentProgress, height)
            color: ShellTransitionState.accentSnapshot
            z: 0
        }
        Rectangle {
            width: parent.width; height: parent.height
            y: root.layerY(ShellTransitionState.blackProgress, height)
            color: Theme.shellTransitionBlack
            z: 1
        }
        MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons; onWheel: wheel => wheel.accepted = true }
    }
}
