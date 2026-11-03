import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../services"
import "../motion" as Motion
import "TaskManagerLogic.js" as Logic

FocusScope {
    id: root
    // Share only telemetry and live-instance pins with the standalone presentation.
    property var snapshot: ({})
    property var pinnedProcesses: TaskManagerPins.pinnedProcesses
    property bool reducedMotion: false
    readonly property int maxVisiblePins: 4
    readonly property bool compact: height < 260
    readonly property var cpu: snapshot.cpu || ({})
    readonly property var memory: snapshot.memory || ({})
    readonly property var gpu: (snapshot.gpus || [])[0] || ({})
    readonly property var network: (snapshot.network || {}).all || ({})
    readonly property var disks: snapshot.disks || ({})
    readonly property real frequency: Number.isFinite(cpu.frequencyHighestMHz) ? cpu.frequencyHighestMHz
        : Number.isFinite(cpu.frequencyAverageMHz) ? cpu.frequencyAverageMHz : NaN
    signal openFullRequested()

    // Keep the only Mini action in the focus path, including at compact heights.
    function forcePrimaryFocus() { openFull.forceActiveFocus() }
    function clearPrimaryFocus() { focus = false }
    function rate(value) { return Number.isFinite(value) ? Logic.bytes(value) + "/s" : "—" }

    RowLayout {
        id: header
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: Math.max(26, Theme.fontSize * 2)
        spacing: Theme.gap
        Text {
            text: "SYSTEM"
            color: Theme.fgMuted
            font.family: Theme.fontFamily
            font.pixelSize: Math.max(10, Theme.fontSize - 2)
            font.bold: true
        }
        Text {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignRight
            text: TaskManagerService.error || (TaskManagerService.warmingUp ? "Warming up…" : "Live")
            color: TaskManagerService.error ? Theme.danger : Theme.fgMuted
            elide: Text.ElideRight
            font.family: Theme.fontFamily
            font.pixelSize: Math.max(10, Theme.fontSize - 3)
        }
        Motion.MorphButton {
            id: openFull
            objectName: "taskManagerMiniOpenFull"
            Layout.preferredWidth: Theme.fontSize * 11
            Layout.fillHeight: true
            text: "↗ Task Manager"
            radius: Theme.radius
            idleColor: "transparent"
            hoverColor: Theme.surfaceSubtle(1.5)
            foregroundColor: Theme.accent
            hoverForegroundColor: Theme.accent
            hoverScaleDelta: 0
            pressScaleDelta: 0
            focused: activeFocus
            activeFocusOnTab: true
            Accessible.role: Accessible.Button
            Accessible.name: "Open Task Manager"
            onClicked: root.openFullRequested()
            Keys.onReturnPressed: clicked()
            Keys.onSpacePressed: clicked()
        }
    }

    Flickable {
        anchors { top: header.bottom; left: parent.left; right: parent.right; bottom: parent.bottom; topMargin: Theme.gap }
        contentWidth: width
        contentHeight: body.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        clip: true
        ScrollBar.vertical: ScrollBar {}
        ColumnLayout {
            id: body
            width: parent.width
            spacing: root.compact ? Theme.gap / 2 : Theme.gap
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.pad * 2
                TaskManagerMiniMetric {
                    objectName: "taskManagerMiniCpu"
                    compact: root.compact
                    Layout.fillWidth: true
                    label: "CPU"
                    value: Logic.metric(root.cpu.usage, "%", 0)
                    usage: Number.isFinite(root.cpu.usage) ? root.cpu.usage : NaN
                    secondary: [Number.isFinite(root.frequency) ? Logic.metric(root.frequency / 1000, " GHz") : "",
                        Number.isFinite(root.cpu.temperatureC) ? Logic.metric(root.cpu.temperatureC, "°C", 0) : ""].filter(value => !!value).join(" · ")
                    reducedMotion: root.reducedMotion
                }
                TaskManagerMiniMetric {
                    objectName: "taskManagerMiniMemory"
                    compact: root.compact
                    Layout.fillWidth: true
                    label: "MEMORY"
                    value: Logic.metric(root.memory.percent, "%", 0)
                    usage: Number.isFinite(root.memory.percent) ? root.memory.percent : NaN
                    secondary: Number.isFinite(root.memory.used) && Number.isFinite(root.memory.total)
                        ? Logic.bytes(root.memory.used) + " / " + Logic.bytes(root.memory.total) : "—"
                    reducedMotion: root.reducedMotion
                }
                TaskManagerMiniMetric {
                    objectName: "taskManagerMiniGpu"
                    compact: root.compact
                    Layout.fillWidth: true
                    label: "GPU"
                    value: Number.isFinite(root.gpu.usage) ? Logic.gpuUsage(root.gpu) : "Unavailable"
                    usage: Number.isFinite(root.gpu.usage) ? root.gpu.usage : NaN
                    secondary: Number.isFinite(root.gpu.temperatureC) ? Logic.metric(root.gpu.temperatureC, "°C", 0) : "—"
                    reducedMotion: root.reducedMotion
                }
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.pad * 2
                Repeater {
                    model: ["NET", "DISK"]
                    ColumnLayout {
                        required property string modelData
                        Layout.fillWidth: true
                        spacing: 2
                        Accessible.role: Accessible.Grouping
                        Accessible.name: modelData + ", " + ioValue.text
                        Text {
                            visible: !root.compact
                            text: modelData
                            color: Theme.fgMuted
                            font.family: Theme.fontFamily
                            font.pixelSize: Math.max(10, Theme.fontSize - 2)
                        }
                        Text {
                            id: ioValue
                            objectName: modelData === "NET" ? "taskManagerMiniNetwork" : "taskManagerMiniDisk"
                            Layout.fillWidth: true
                            text: (root.compact ? modelData + "  " : "") + (modelData === "NET"
                                ? "↓ " + root.rate(root.network.rxBps) + "  ↑ " + root.rate(root.network.txBps)
                                : "R " + root.rate(root.disks.readBps) + "  W " + root.rate(root.disks.writeBps))
                            color: Theme.fgMuted
                            font.family: Theme.fontFamily
                            font.pixelSize: Math.max(10, Theme.fontSize - 3)
                            elide: Text.ElideRight
                        }
                    }
                }
            }
            Text {
                Layout.fillWidth: true
                text: TaskManagerPins.error || "PINNED"
                color: TaskManagerPins.error ? Theme.danger : Theme.fgMuted
                elide: Text.ElideRight
                font.family: Theme.fontFamily
                font.pixelSize: Math.max(10, Theme.fontSize - 2)
            }
            Text {
                objectName: "taskManagerMiniEmptyPins"
                Layout.fillWidth: true
                visible: root.pinnedProcesses.length === 0
                text: "No pinned processes\nPin a process in Task Manager to monitor it here."
                color: Theme.fgMuted
                font.family: Theme.fontFamily
                font.pixelSize: Math.max(10, Theme.fontSize - 3)
                wrapMode: Text.WordWrap
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Repeater {
                    model: root.pinnedProcesses.slice(0, root.maxVisiblePins)
                    RowLayout {
                        required property var modelData
                        objectName: "taskManagerMiniPinnedRow"
                        Layout.fillWidth: true
                        Layout.preferredHeight: root.compact ? 16 : 20
                        spacing: Theme.gap
                        Accessible.role: Accessible.Grouping
                        Accessible.name: modelData.name + ", CPU " + Logic.metric(modelData.cpuTotalPercent, "%") + ", memory " + Logic.bytes(modelData.rss)
                        Text {
                            Layout.fillWidth: true
                            text: "󰐃 " + modelData.name
                            color: Theme.fgMuted
                            font.family: Theme.fontFamily
                            font.pixelSize: Math.max(11, Theme.fontSize - 2)
                            elide: Text.ElideRight
                        }
                        Text {
                            Layout.preferredWidth: Theme.fontSize * 6
                            horizontalAlignment: Text.AlignRight
                            text: Logic.metric(modelData.cpuTotalPercent, "%")
                            color: Theme.accent
                            font.family: Theme.fontFamily
                            font.pixelSize: Math.max(11, Theme.fontSize - 2)
                        }
                        Text {
                            Layout.preferredWidth: Theme.fontSize * 7
                            horizontalAlignment: Text.AlignRight
                            text: Logic.bytes(modelData.rss)
                            color: Theme.fgMuted
                            font.family: Theme.fontFamily
                            font.pixelSize: Math.max(11, Theme.fontSize - 2)
                        }
                    }
                }
            }
            Text {
                objectName: "taskManagerMiniMorePins"
                visible: root.pinnedProcesses.length > root.maxVisiblePins
                text: "+" + (root.pinnedProcesses.length - root.maxVisiblePins) + " pinned"
                color: Theme.fgMuted
                font.family: Theme.fontFamily
                font.pixelSize: Math.max(10, Theme.fontSize - 3)
            }
        }
    }
}
