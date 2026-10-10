import QtQuick
import "../../services"

Rectangle {
    id: root

    radius: Theme.radius
    color: Theme.surface
    border.width: 1
    border.color: Qt.lighter(Theme.hoverMuted, 1.25)
    clip: true

    property bool active: false
    property bool _subscribed: false

    function _updateSubscription() {
        if (active && !_subscribed) {
            _subscribed = true;
            SysStats.acquireExtended();
        } else if (!active && _subscribed) {
            _subscribed = false;
            SysStats.releaseExtended();
        }
    }

    onActiveChanged: _updateSubscription()
    Component.onCompleted: _updateSubscription()
    Component.onDestruction: {
        if (_subscribed) {
            _subscribed = false;
            SysStats.releaseExtended();
        }
    }

    Item {
        id: headerArea
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 36
        anchors.topMargin: Math.max(8, Math.round(Theme.pad * 0.8))
        anchors.leftMargin: Math.max(12, Math.round(Theme.pad * 1.2))
        anchors.rightMargin: Math.max(12, Math.round(Theme.pad * 1.2))

        Text {
            id: titleLabel
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: "Monitor"
            font.family: Theme.fontFamily
            font.pixelSize: Math.max(12, Theme.fontSize - 1)
            font.weight: Font.Bold
            color: Theme.fg
        }
    }

    Item {
        id: contentArea
        anchors.top: headerArea.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: Math.max(14, Math.round(Theme.pad * 1.2))

        readonly property real colGap: Math.max(16, Math.round(Theme.gap * 2))
        readonly property real rowGap: Math.max(20, Math.round(Theme.gap * 2.5))
        readonly property real slotWidth: Math.floor((contentArea.width - colGap) / 2)

        Grid {
            id: metricGrid
            anchors.centerIn: parent
            columns: 2
            columnSpacing: contentArea.colGap
            rowSpacing: contentArea.rowGap

            // Slot 1: ROM
            Item {
                width: contentArea.slotWidth
                height: 44

                Text {
                    id: romLabel
                    anchors.left: parent.left
                    anchors.top: parent.top
                    text: "ROM"
                    font.family: Theme.fontFamily
                    font.pixelSize: Math.max(11, Theme.fontSize - 1)
                    font.weight: Font.Bold
                    color: Theme.fgDim
                }

                Text {
                    id: romValue
                    anchors.right: parent.right
                    anchors.top: parent.top
                    text: SysStats.hasRootFs ? SysStats.rootFsUsed + "%" : "N/A"
                    font.family: Theme.fontFamily
                    font.pixelSize: Math.max(13, Theme.fontSize + 1)
                    font.weight: Font.Bold
                    color: SysStats.hasRootFs ? Theme.fg : Theme.fgDim
                }

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: romLabel.bottom
                    anchors.topMargin: 8
                    height: 4
                    radius: 2
                    color: Theme.hoverMuted

                    Rectangle {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: SysStats.hasRootFs
                            ? Math.round(parent.width * (Math.max(0, Math.min(100, SysStats.rootFsUsed)) / 100))
                            : 0
                        radius: 2
                        color: Theme.accent
                        visible: SysStats.hasRootFs

                        Behavior on width {
                            NumberAnimation {
                                duration: HAnimation.normal
                                easing.type: Easing.OutCubic
                            }
                        }
                    }
                }
            }

            // Slot 2: RAM
            Item {
                width: contentArea.slotWidth
                height: 44

                Text {
                    id: ramLabel
                    anchors.left: parent.left
                    anchors.top: parent.top
                    text: "RAM"
                    font.family: Theme.fontFamily
                    font.pixelSize: Math.max(11, Theme.fontSize - 1)
                    font.weight: Font.Bold
                    color: Theme.fgDim
                }

                Text {
                    id: ramValue
                    anchors.right: parent.right
                    anchors.top: parent.top
                    text: SysStats.ram + "%"
                    font.family: Theme.fontFamily
                    font.pixelSize: Math.max(13, Theme.fontSize + 1)
                    font.weight: Font.Bold
                    color: Theme.fg
                }

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: ramLabel.bottom
                    anchors.topMargin: 8
                    height: 4
                    radius: 2
                    color: Theme.hoverMuted

                    Rectangle {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: Math.round(parent.width * (Math.max(0, Math.min(100, SysStats.ram)) / 100))
                        radius: 2
                        color: Theme.accent

                        Behavior on width {
                            NumberAnimation {
                                duration: HAnimation.normal
                                easing.type: Easing.OutCubic
                            }
                        }
                    }
                }
            }

            // Slot 3: CPU
            Item {
                width: contentArea.slotWidth
                height: 44

                Text {
                    id: cpuLabel
                    anchors.left: parent.left
                    anchors.top: parent.top
                    text: "CPU"
                    font.family: Theme.fontFamily
                    font.pixelSize: Math.max(11, Theme.fontSize - 1)
                    font.weight: Font.Bold
                    color: Theme.fgDim
                }

                Text {
                    id: cpuValue
                    anchors.right: parent.right
                    anchors.top: parent.top
                    text: SysStats.cpu + "%"
                    font.family: Theme.fontFamily
                    font.pixelSize: Math.max(13, Theme.fontSize + 1)
                    font.weight: Font.Bold
                    color: Theme.fg
                }

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: cpuLabel.bottom
                    anchors.topMargin: 8
                    height: 4
                    radius: 2
                    color: Theme.hoverMuted

                    Rectangle {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: Math.round(parent.width * (Math.max(0, Math.min(100, SysStats.cpu)) / 100))
                        radius: 2
                        color: Theme.accent

                        Behavior on width {
                            NumberAnimation {
                                duration: HAnimation.normal
                                easing.type: Easing.OutCubic
                            }
                        }
                    }
                }
            }

            // Slot 4: GPU
            Item {
                width: contentArea.slotWidth
                height: 44

                Text {
                    id: gpuLabel
                    anchors.left: parent.left
                    anchors.top: parent.top
                    text: "GPU"
                    font.family: Theme.fontFamily
                    font.pixelSize: Math.max(11, Theme.fontSize - 1)
                    font.weight: Font.Bold
                    color: Theme.fgDim
                }

                Text {
                    id: gpuValue
                    anchors.right: parent.right
                    anchors.top: parent.top
                    text: SysStats.hasGpu ? SysStats.gpu + "%" : "N/A"
                    font.family: Theme.fontFamily
                    font.pixelSize: Math.max(13, Theme.fontSize + 1)
                    font.weight: Font.Bold
                    color: SysStats.hasGpu ? Theme.fg : Theme.fgDim
                }

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: gpuLabel.bottom
                    anchors.topMargin: 8
                    height: 4
                    radius: 2
                    color: Theme.hoverMuted

                    Rectangle {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: SysStats.hasGpu
                            ? Math.round(parent.width * (Math.max(0, Math.min(100, SysStats.gpu)) / 100))
                            : 0
                        radius: 2
                        color: Theme.accent
                        visible: SysStats.hasGpu

                        Behavior on width {
                            NumberAnimation {
                                duration: HAnimation.normal
                                easing.type: Easing.OutCubic
                            }
                        }
                    }
                }
            }
        }
    }
}
