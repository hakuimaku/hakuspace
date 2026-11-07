import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import "../"
import "../base"
import "../../services"

Row {
    id: root
    // Compact controls remain individually reachable in a vertical bar.
    property bool vertical: false
    spacing: Theme.gap
    // Tighten icon spacing while adding room at both ends of the capsule.
    readonly property real verticalControlHeight: ScreenGeometry.leftTouchSize - 12
    // A single control needs the extra pixel retained by its rounded minimum height.
    readonly property real verticalEdgePadding: sysRow.visibleChildren.length === 1 ? 7 : 6
    // Balance service demand across visibility changes and output removal.
    property bool subscribed: false
    function syncSubscriptions() {
        if (visible === subscribed) return
        subscribed = visible
        if (subscribed) {
            Audio.acquire()
            Brightness.acquire()
        } else {
            Audio.release()
            Brightness.release()
        }
    }
    onVisibleChanged: syncSubscriptions()
    Component.onCompleted: syncSubscriptions()
    Component.onDestruction: {
        if (subscribed) {
            Audio.release()
            Brightness.release()
        }
    }

    property int backlight: Brightness.level
    property int volume: Audio.volume
    property bool muted: Audio.muted

    Process {
        id: execProc
    }

    // Spawns shell command asynchronously via background process.
    function exec(cmd) {
        execProc.command = ["bash", "-c", cmd];
        execProc.running = false;
        execProc.running = true;
    }

    // Quick settings pill grouping backlight, volume, and battery status icons.
    Item {
        id: controlHost
        objectName: "quick-controls-hit"
        visible: !root.vertical || root.backlight >= 0 || root.volume >= 0 || batItem.isPresent
        property real hoverExpansion: root.vertical && groupHover.hovered ? ScreenGeometry.leftModuleHoverExtent : 0
        implicitHeight: root.vertical ? sysRow.implicitHeight + root.verticalEdgePadding * 2 + ScreenGeometry.leftModuleHoverExtent * 2 : Theme.fontSize * 1.8
        implicitWidth: root.vertical ? ScreenGeometry.leftTouchSize : sysRow.implicitWidth + Theme.pad * 2
        HoverHandler { id: groupHover; enabled: root.vertical }
        // A centered narrow chassis never determines the children's transparent hit width.
        Rectangle {
            id: capsule
            objectName: "quick-controls-capsule"
            readonly property real hoverExpansion: controlHost.hoverExpansion
            anchors.centerIn: parent
            width: root.vertical ? ScreenGeometry.leftVisualSize : parent.width
            height: root.vertical ? Math.max(ScreenGeometry.leftVisualSize, sysRow.implicitHeight + root.verticalEdgePadding * 2) + controlHost.hoverExpansion * 2 : parent.height
            color: Theme.accent
            radius: root.vertical ? width / 2 : Theme.radius
        }
        Behavior on hoverExpansion { NumberAnimation { duration: HAnimation.slow; easing.bezierCurve: HAnimation.moduleCurve } }
        Behavior on implicitWidth { NumberAnimation { duration: HAnimation.normal } }

        Grid {
            id: sysRow
            columns: root.vertical ? 1 : 3
            anchors.centerIn: parent
            spacing: root.vertical ? ScreenGeometry.leftControlGap : 0
            
            Item {
                id: blItem
                objectName: "quick-brightness"
                width: root.vertical ? ScreenGeometry.leftTouchSize : Theme.fontSize * 1.8
                height: root.vertical ? root.verticalControlHeight : Theme.fontSize * 1.8
                visible: root.backlight >= 0

                Text {
                    id: iconTextBL
                    property var icons: ["", "", "", "", "", "", "", "", ""]
                    property int idx: Math.max(0, Math.min(8, Math.floor((root.backlight / 100) * 9)))
                    text: icons[idx]
                    font.family: Theme.fontFamily; font.pixelSize: root.vertical ? ScreenGeometry.leftIconSize : Theme.fontSize + 2; font.weight: Font.Bold
                    color: Theme.onAccentColor
                    anchors.centerIn: parent
                    scale: blMA.containsMouse ? 1.2 : 1.0
                    // Animates brightness icon hover scale.
                    Behavior on scale { NumberAnimation { duration: HAnimation.slow } }
                }
                MouseArea {
                    id: blMA
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton
                    hoverEnabled: true
                    onEntered: blTooltip.active = true
                    onExited: blTooltip.active = false
                    onClicked: Quickshell.execDetached([Env.binDir + "/nightlight_toggle.sh"])
                    onWheel: (wheel) => Brightness.change("brightnessctl set " + (wheel.angleDelta.y > 0 ? "1%+" : "1%-"))
                }
                HTooltip { id: blTooltip; target: blItem; text: "Brightness: " + root.backlight + "%" }
            }
            
            Item {
                id: volItem
                objectName: "quick-volume"
                width: root.vertical ? ScreenGeometry.leftTouchSize : Theme.fontSize * 1.8
                height: root.vertical ? root.verticalControlHeight : Theme.fontSize * 1.8
                visible: root.volume >= 0

                Text {
                    id: iconTextVol
                    property var icons: ["", "", ""]
                    property int idx: root.volume > 60 ? 2 : (root.volume > 30 ? 1 : 0)
                    text: root.muted ? "󰝟" : icons[idx]
                    font.family: Theme.fontFamily; font.pixelSize: root.vertical ? ScreenGeometry.leftIconSize : Theme.fontSize + 2; font.weight: Font.Bold
                    color: Theme.onAccentColor
                    anchors.centerIn: parent
                    scale: volMA.containsMouse ? 1.2 : 1.0
                    // Animates volume icon hover scale.
                    Behavior on scale { NumberAnimation { duration: HAnimation.slow } }
                }
                MouseArea {
                    id: volMA
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    hoverEnabled: true
                    onEntered: volTooltip.active = true
                    onExited: volTooltip.active = false
                    onClicked: (mouse) => {
                        if (mouse.button === Qt.RightButton) {
                            root.exec("pavucontrol")
                        } else {
                            Audio.change("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle")
                        }
                    }
                    onWheel: (wheel) => Audio.change("wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ " + (wheel.angleDelta.y > 0 ? "1%+" : "1%-"))
                }
                HTooltip { id: volTooltip; target: volItem; text: root.muted ? "Volume: Muted" : ("Volume: " + root.volume + "%") }
            }
            
            Item {
                id: batItem
                objectName: "quick-battery"
                width: root.vertical ? ScreenGeometry.leftTouchSize : Theme.fontSize * 1.8
                height: root.vertical ? root.verticalControlHeight : Theme.fontSize * 1.8
                
                property var bat: UPower.displayDevice
                property bool isPresent: !!bat && bat.isPresent
                property bool isCharging: !!bat && bat.state === 1
                property int capacity: bat ? Math.round(bat.percentage * 100) : 0
                
                visible: isPresent

                Text {
                    id: iconTextBat
                    property var defIcons: ["󰂎", "󰁺", "󰁻", "󰁼", "󰁽", "󰁾", "󰁿", "󰂀", "󰂁", "󰂂", "󰁹"]
                    property var chgIcons: ["󰢟", "󰢜", "󰂆", "󰂇", "󰂈", "󰢝", "󰂉", "󰢞", "󰂊", "󰂋", "󰂅"]
                    property int idx: Math.max(0, Math.min(10, Math.round(batItem.capacity / 10)))
                    text: batItem.isCharging ? chgIcons[idx] : defIcons[idx]
                    font.family: Theme.fontFamily; font.pixelSize: root.vertical ? ScreenGeometry.leftIconSize : Theme.fontSize + 2; font.weight: Font.Bold
                    color: Theme.onAccentColor
                    anchors.centerIn: parent
                    scale: batMA.containsMouse ? 1.2 : 1.0
                    // Animates battery icon hover scale.
                    Behavior on scale { NumberAnimation { duration: HAnimation.slow } }
                }
                MouseArea {
                    id: batMA
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: batTooltip.active = true
                    onExited: batTooltip.active = false
                }
                HTooltip { id: batTooltip; target: batItem; text: "Battery: " + batItem.capacity + "%" + (batItem.isCharging ? " (Charging)" : "") }
            }
        }
    }

}
