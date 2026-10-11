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

    // Presentation state: "system" (default) or "gpu"
    property string currentPage: "system"

    function togglePage() {
        currentPage = (currentPage === "system") ? "gpu" : "system"
    }

    function _updateSubscription() {
        if (active && !_subscribed) {
            _subscribed = true
            SysStats.acquireExtended()
        } else if (!active && _subscribed) {
            _subscribed = false
            SysStats.releaseExtended()
        }
    }

    onActiveChanged: _updateSubscription()
    Component.onCompleted: _updateSubscription()
    Component.onDestruction: {
        if (_subscribed) {
            _subscribed = false
            SysStats.releaseExtended()
        }
    }

    // 1. Header Area
    Item {
        id: headerArea
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 32
        anchors.topMargin: Math.max(6, Math.round(Theme.pad * 0.7))
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

        // Active page indicator pill
        Rectangle {
            id: pagePill
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: pillText.implicitWidth + 14
            height: 20
            radius: 10
            color: pageMouse.containsMouse ? Qt.lighter(Theme.hoverMuted, 1.25) : Theme.hoverMuted
            Behavior on color { ColorAnimation { duration: HAnimation.fast } }

            Text {
                id: pillText
                anchors.centerIn: parent
                text: root.currentPage === "system" ? "System" : "GPU"
                font.family: Theme.fontFamily
                font.pixelSize: Math.max(10, Theme.fontSize - 3)
                font.weight: Font.DemiBold
                color: Theme.accent
            }

            MouseArea {
                id: pageMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton
                onEntered: DashboardTooltip.show(pagePill, "Switch to " + (root.currentPage === "system" ? "GPU" : "System") + " view")
                onExited: DashboardTooltip.hide(pagePill)
                onClicked: { DashboardTooltip.dismiss(); root.togglePage() }
            }
        }
    }

    // 2. Gauge cluster area with left/right switcher arrows
    Item {
        id: gaugeArea
        anchors.top: headerArea.bottom
        anchors.topMargin: 2
        anchors.left: parent.left
        anchors.right: parent.right
        height: 80

        Row {
            anchors.centerIn: parent
            spacing: 12

            // Left arrow button
            Rectangle {
                id: prevBtn
                width: 24
                height: 24
                radius: 12
                anchors.verticalCenter: parent.verticalCenter
                color: prevMouse.containsMouse ? Theme.hoverMuted : "transparent"
                Behavior on color { ColorAnimation { duration: HAnimation.fast } }

                Text {
                    anchors.centerIn: parent
                    text: "‹"
                    font.family: Theme.fontFamily
                    font.pixelSize: 17
                    font.weight: Font.Bold
                    color: Theme.fg
                }

                MouseArea {
                    id: prevMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton
                    onEntered: DashboardTooltip.show(prevBtn, "Toggle System / GPU view")
                    onExited: DashboardTooltip.hide(prevBtn)
                    onClicked: { DashboardTooltip.dismiss(); root.togglePage() }
                }
            }

            // Gauge slot: crossfades System and GPU circular gauges
            Item {
                id: gaugeSlot
                width: 70 * 2 + 16
                height: 70
                anchors.verticalCenter: parent.verticalCenter

                // System gauges: CPU & RAM
                Row {
                    id: systemGauges
                    anchors.centerIn: parent
                    spacing: 16
                    opacity: root.currentPage === "system" ? 1.0 : 0.0
                    visible: opacity > 0.001

                    Behavior on opacity {
                        NumberAnimation {
                            duration: HAnimation.normal
                            easing.bezierCurve: HAnimation.moduleCurve
                        }
                    }

                    DashboardMetricGauge {
                        id: cpuGauge
                        title: "CPU"
                        value: SysStats.cpu
                        available: true
                        usedText: SysStats.cpuUsedStr
                        diameter: 70
                    }

                    DashboardMetricGauge {
                        id: ramGauge
                        title: "RAM"
                        value: SysStats.ram
                        available: true
                        usedText: SysStats.ramUsedStr
                        diameter: 70
                    }
                }

                // GPU gauges: GPU & VRAM
                Row {
                    id: gpuGauges
                    anchors.centerIn: parent
                    spacing: 16
                    opacity: root.currentPage === "gpu" ? 1.0 : 0.0
                    visible: opacity > 0.001

                    Behavior on opacity {
                        NumberAnimation {
                            duration: HAnimation.normal
                            easing.bezierCurve: HAnimation.moduleCurve
                        }
                    }

                    DashboardMetricGauge {
                        id: gpuGauge
                        title: "GPU"
                        value: SysStats.gpu
                        available: SysStats.hasGpu
                        usedText: SysStats.hasGpu ? (SysStats.gpuBackend.toUpperCase()) : ""
                        diameter: 70
                    }

                    DashboardMetricGauge {
                        id: vramGauge
                        title: "VRAM"
                        value: SysStats.gpuMemoryPercent
                        available: SysStats.hasGpuMemory
                        usedText: SysStats.gpuMemoryUsedStr
                        diameter: 70
                    }
                }
            }

            // Right arrow button
            Rectangle {
                id: nextBtn
                width: 24
                height: 24
                radius: 12
                anchors.verticalCenter: parent.verticalCenter
                color: nextMouse.containsMouse ? Theme.hoverMuted : "transparent"
                Behavior on color { ColorAnimation { duration: HAnimation.fast } }

                Text {
                    anchors.centerIn: parent
                    text: "›"
                    font.family: Theme.fontFamily
                    font.pixelSize: 17
                    font.weight: Font.Bold
                    color: Theme.fg
                }

                MouseArea {
                    id: nextMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton
                    onEntered: DashboardTooltip.show(nextBtn, "Toggle System / GPU view")
                    onExited: DashboardTooltip.hide(nextBtn)
                    onClicked: { DashboardTooltip.dismiss(); root.togglePage() }
                }
            }
        }
    }

    // Divider separating gauges from persistent storage section
    Rectangle {
        id: divider
        anchors.top: gaugeArea.bottom
        anchors.topMargin: 6
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        height: 1
        color: Theme.hoverMuted
    }

    // 3. Persistent storage rows (root / always first, then mounts)
    readonly property var storageList: {
        if (SysStats.hasMounts && SysStats.mounts.length > 0) {
            return SysStats.mounts
        }
        return [
            {
                "target": "/",
                "source": "root",
                "fstype": "",
                "used": "",
                "size": "",
                "percent": SysStats.hasRootFs ? SysStats.rootFsUsed : 0
            }
        ]
    }

    Item {
        id: storageSection
        anchors.top: divider.bottom
        anchors.topMargin: 6
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        anchors.bottomMargin: 6
        clip: true

        ListView {
            id: storageView
            anchors.fill: parent
            model: root.storageList
            spacing: 2
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            delegate: DashboardStorageRow {
                width: storageView.width
                target: modelData.target || "/"
                source: modelData.source || ""
                fstype: modelData.fstype || ""
                usedStr: modelData.used || ""
                sizeStr: modelData.size || ""
                percent: (typeof modelData.percent === "number") ? modelData.percent : 0
                available: true
            }
        }
    }
}
