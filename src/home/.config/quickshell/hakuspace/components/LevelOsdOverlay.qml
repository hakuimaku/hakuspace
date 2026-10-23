import QtQuick
import Quickshell
import Quickshell.Wayland
import "../services"
import "osd" as Osd
import "bar" as Bar

PanelWindow {
    id: root
    // Release only after the surface has finished its visual close.
    readonly property bool releaseReady: !CenterState.osdVisible && CenterState.osdExpansion === 0
    required property var modelData
    screen: modelData
    anchors { top: true; bottom: true; left: true; right: true }
    WlrLayershell.layer: ShellTransitionState.chromeOverlayLayer
    WlrLayershell.namespace: "hakuspace-level-osd"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0
    color: "transparent"
    // The overlay is visual only and must not capture pointer input.
    mask: Region {}

    // Stay inside the rounded-screen border and corner radius.
    readonly property var screenBounds: ScreenGeometry.horizontalBounds(width)
    readonly property real spanWidth: Math.min(Theme.levelOsdWidth,
                                                Math.max(0, screenBounds.end - screenBounds.start - 2 * (Theme.largeRadius + 8)))
    readonly property real spanStart: (width - spanWidth) / 2
    readonly property real attachmentY: ChromeLayout.topBarMode ? Theme.topBarHeight : ScreenGeometry.topBorderThickness

    // Attach the Taskbar OSD bridge to the rounded frame’s inner top edge.
    PanelWindow {
        screen: root.modelData
        anchors { top: true; bottom: true; left: true; right: true }
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "hakuspace-level-osd-flare"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore
        exclusiveZone: 0
        color: "transparent"
        visible: ChromeLayout.taskbarMode
        mask: Region {}
        Bar.LevelOsdBridge { y: root.attachmentY }
    }
    Rectangle {
        id: osdBackground
        x: root.spanStart + Theme.gap
        y: root.attachmentY + Theme.gap
        width: Math.max(0, root.spanWidth - Theme.gap * 2)
        height: Math.max(0, Theme.levelOsdHeight * CenterState.osdExpansion - Theme.gap * 2)
        radius: Math.min(Theme.largeRadius + 8, height / 2)
        color: Theme.surface
        clip: true
        visible: CenterState.osdExpansion > 0 && root.spanWidth > 0

        Osd.LevelOsdContent {
            anchors.horizontalCenter: parent.horizontalCenter
            y: Theme.levelOsdPadding
            width: Math.max(0, osdBackground.width - Theme.levelOsdPadding * 2)
            height: implicitHeight
            mode: CenterState.transientMode
            opacity: CenterState.osdVisible && CenterState.osdExpansion > 0.4 ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: HAnimation.fast } }
        }
    }
}
