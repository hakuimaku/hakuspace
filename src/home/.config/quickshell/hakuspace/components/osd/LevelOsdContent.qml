import QtQuick
import "../../services"

Item {
    id: root
    property string mode: ""
    property string displayedMode: ""
    readonly property int rawLevel: displayedMode === "brightness" ? Brightness.level : Audio.volume
    readonly property int visualLevel: Math.max(0, Math.min(100, rawLevel))
    readonly property string glyph: displayedMode === "brightness" ? ""
                                   : Audio.muted ? "󰝟"
                                   : visualLevel > 60 ? "" : (visualLevel > 30 ? "" : "")
    readonly property real sideSlotWidth: Theme.fontSize * 3.7

    implicitWidth: Theme.levelOsdWidth - 2 * (Theme.gap + Theme.levelOsdPadding)
    implicitHeight: Theme.fontSize * 2.4
    clip: true

    Component.onCompleted: displayedMode = mode
    onModeChanged: {
        if (mode === "") return
        if (displayedMode === "") displayedMode = mode
        else if (mode !== displayedMode) modeTransition.restart()
    }

    SequentialAnimation {
        id: modeTransition
        NumberAnimation { target: contentGroup; property: "opacity"; to: 0; duration: HAnimation.fast }
        ScriptAction { script: root.displayedMode = root.mode }
        NumberAnimation { target: contentGroup; property: "opacity"; to: 1; duration: HAnimation.fast }
    }

    Item {
        id: contentGroup
        anchors.centerIn: parent
        // Optical correction applies only to the icon/track/value group.
        // Keep the OSD capsule itself physically centered.
        anchors.horizontalCenterOffset: -4
        width: Math.min(parent.width, root.implicitWidth)
        height: root.implicitHeight

        Row {
            anchors.fill: parent
            spacing: Theme.pad

            // Equal side slots keep the visible icon/bar/percentage group
            // optically centered rather than letting the wider percentage slot
            // bias the composition to one side.
            Item {
                id: iconSlot
                width: root.sideSlotWidth
                height: parent.height
                Text {
                    anchors.centerIn: parent
                    text: root.glyph
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize + 7
                    font.weight: Font.Bold
                    color: Theme.fg
                }
            }

            Rectangle {
                id: track
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(0, contentGroup.width - root.sideSlotWidth * 2 - parent.spacing * 2)
                height: Math.max(5, Theme.fontSize * 0.5)
                radius: height / 2
                color: Theme.fgMuted

                Rectangle {
                    width: parent.width * root.visualLevel / 100
                    height: parent.height
                    radius: height / 2
                    color: Theme.accent
                    Behavior on width {
                        NumberAnimation { duration: HAnimation.fast; easing.bezierCurve: HAnimation.moduleCurve }
                    }
                }
            }

            Item {
                id: percentSlot
                width: root.sideSlotWidth
                height: parent.height
                Text {
                    anchors.fill: parent
                    text: root.rawLevel >= 0 ? root.visualLevel + "%" : "--%"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize + 3
                    font.weight: Font.Bold
                    color: Theme.fg
                }
            }
        }
    }
}
