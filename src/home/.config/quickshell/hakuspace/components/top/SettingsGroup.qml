import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import "../"
import "../base"
import "../../services"

Row {
    id: root
    spacing: Theme.gap
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
    Rectangle {
        color: Theme.accent
        radius: Theme.radius
        implicitHeight: Theme.fontSize * 1.8
        implicitWidth: sysRow.implicitWidth + Theme.pad * 2
        
        // Animates quick settings pill width when status icons become visible or hidden.
        Behavior on implicitWidth { NumberAnimation { duration: HAnimation.normal } }
        
        Row {
            id: sysRow
            anchors.centerIn: parent
            spacing: 0
            
            Item {
                id: blItem
                width: Theme.fontSize * 1.8
                height: Theme.fontSize * 1.8
                anchors.verticalCenter: parent.verticalCenter
                visible: root.backlight >= 0

                Text {
                    id: iconTextBL
                    property var icons: ["", "", "", "", "", "", "", "", ""]
                    property int idx: Math.max(0, Math.min(8, Math.floor((root.backlight / 100) * 9)))
                    text: icons[idx]
                    font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize + 2; font.weight: Font.Bold
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
                width: Theme.fontSize * 1.8
                height: Theme.fontSize * 1.8
                anchors.verticalCenter: parent.verticalCenter
                visible: root.volume >= 0

                Text {
                    id: iconTextVol
                    property var icons: ["", "", ""]
                    property int idx: root.volume > 60 ? 2 : (root.volume > 30 ? 1 : 0)
                    text: root.muted ? "󰝟" : icons[idx]
                    font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize + 2; font.weight: Font.Bold
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
                width: Theme.fontSize * 1.8
                height: Theme.fontSize * 1.8
                anchors.verticalCenter: parent.verticalCenter
                
                property var bat: UPower.displayDevice
                property bool isPresent: bat && bat.isPresent
                property bool isCharging: bat && bat.state === 1
                property int capacity: bat ? Math.round(bat.percentage * 100) : 0
                
                visible: isPresent

                Text {
                    id: iconTextBat
                    property var defIcons: ["󰂎", "󰁺", "󰁻", "󰁼", "󰁽", "󰁾", "󰁿", "󰂀", "󰂁", "󰂂", "󰁹"]
                    property var chgIcons: ["󰢟", "󰢜", "󰂆", "󰂇", "󰂈", "󰢝", "󰂉", "󰢞", "󰂊", "󰂋", "󰂅"]
                    property int idx: Math.max(0, Math.min(10, Math.round(batItem.capacity / 10)))
                    text: batItem.isCharging ? chgIcons[idx] : defIcons[idx]
                    font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize + 2; font.weight: Font.Bold
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
