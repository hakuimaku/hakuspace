import QtQuick
import Quickshell
import Quickshell.Wayland
import "../services"
import "osd" as Osd

PanelWindow {
    id: root
    required property var modelData
    screen: modelData
    anchors { top: true; left: true; right: true }
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "hakuspace-level-osd"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0
    implicitHeight: FlareEdges.topOriginY + Theme.levelOsdHeight + Theme.tipRadius
    color: "transparent"
    // The overlay is visual only and must not capture pointer input.
    mask: Region {}

    // Stay inside the rounded-screen border and corner radius.
    readonly property real spanWidth: Math.min(Theme.levelOsdWidth,
                                                Math.max(0, width - 2 * (FlareEdges.thickness + Theme.tipRadius)))
    readonly property real spanStart: (width - spanWidth) / 2

    Rectangle {
        id: osdBackground
        x: root.spanStart + Theme.gap
        y: FlareEdges.topOriginY + Theme.gap
        width: Math.max(0, root.spanWidth - Theme.gap * 2)
        height: Math.max(0, Theme.levelOsdHeight * CenterState.osdExpansion - Theme.gap * 2)
        radius: Math.min(Theme.tipRadius, height / 2)
        color: "#000000"
        clip: true
        visible: CenterState.osdExpansion > 0 && root.spanWidth > 0

        Osd.LevelOsdContent {
            x: Theme.levelOsdPadding
            y: Theme.levelOsdPadding
            width: Math.max(0, osdBackground.width - Theme.levelOsdPadding * 2)
            mode: CenterState.transientMode
            opacity: CenterState.osdVisible && CenterState.osdExpansion > 0.4 ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: HAnimation.fast } }
        }
    }
}
