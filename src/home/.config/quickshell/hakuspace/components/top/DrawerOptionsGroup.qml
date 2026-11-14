import QtQuick
import "../"
import "../base"
import "../../services"

HDrawer {
    id: root
    required property string screenName
    property bool requested: true

    leftToRight: false
    topToBottom: false
    open: false

    // Keep the drawer reachable while recording so the stop control remains accessible.
    visible: requested || Recorder.isRecording
    onVisibleChanged: if (!visible) open = false

    trigger: TopModule {
        id: triggerModule
        objectName: "drawer-options-trigger"
        hoverAxis: root.vertical ? "vertical" : "horizontal"
        iconFontSize: (root.vertical ? ScreenGeometry.leftIconSize : Theme.fontSize) + 6
        icon: root.vertical
            ? (root.open ? "" : "")
            : (root.open ? "" : "")
        isAccent: Recorder.isRecording
        blink: Recorder.isRecording && !root.open
        blinkDuration: 500
        tooltip: Recorder.isRecording
            ? "Drawer Options (Recording: " + Recorder.recordTime + ")"
            : "Drawer Options"
        Accessible.role: Accessible.Button
        Accessible.name: tooltip
        onClicked: root.open = !root.open

        Rectangle {
            parent: triggerModule.visualItem
            anchors.right: parent.right
            anchors.top: parent.top
            width: 6
            height: 6
            radius: 3
            color: Theme.onAccentColor
            visible: Recorder.isRecording && !root.open
        }
    }

    Grid {
        columns: root.vertical ? 1 : 3
        spacing: root.vertical ? ScreenGeometry.leftModuleGap : Theme.gap

        PowerProfileGroup {
            objectName: "power-profile-module"
            hoverAxis: root.vertical ? "vertical" : "horizontal"
            requested: root.visible
        }

        WallpaperGroup {
            hoverAxis: root.vertical ? "vertical" : "horizontal"
            screenName: root.screenName
        }

        RecorderGroup {
            objectName: "screen-recorder-module"
            hoverAxis: root.vertical ? "vertical" : "horizontal"
            compact: root.vertical
        }
    }
}
