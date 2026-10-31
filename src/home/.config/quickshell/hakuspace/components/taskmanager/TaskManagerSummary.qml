import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../services"
import "TaskManagerLogic.js" as Logic

ScrollView {
    id: root
    // Keep interface choice local to the disposable monitor view.
    property string interfaceName: ""
    readonly property var network: TaskManagerService.network
    readonly property var interfaces: (network.interfaces || []).filter(row => !row.loopback)
    readonly property var names: ["All"].concat(interfaces.map(row => row.name))
    readonly property string effectiveInterface: names.includes(interfaceName) ? interfaceName : (network.defaultInterface || "All")
    readonly property var traffic: effectiveInterface === "All" ? (network.all || {})
        : (interfaces.find(row => row.name === effectiveInterface) || {})
    // Bound the summary viewport so the process table remains usable at minimum size.
    contentWidth: availableWidth
    clip: true
    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
    ColumnLayout {
        width: root.availableWidth
        spacing: 6
        Label {
            Layout.fillWidth: true
            color: Theme.fg
            wrapMode: Text.Wrap
            text: "CPU  " + Logic.metric(TaskManagerService.cpu.usage, "%")
                + "   Load " + (TaskManagerService.cpu.load || []).map(v => v.toFixed(2)).join(" / ")
                + "   Highest " + Logic.metric(TaskManagerService.cpu.frequencyHighestMHz, " MHz", 0)
                + "   " + Logic.metric(TaskManagerService.cpu.temperatureC, " °C")
        }
        Label {
            Layout.fillWidth: true
            color: Theme.fgMuted
            wrapMode: Text.Wrap
            text: "Cores  " + (TaskManagerService.cpu.cores || []).map((v, i) => i + ": " + Logic.metric(v, "%", 0)).join("   ")
        }
        Repeater {
            model: TaskManagerService.gpus
            Label {
                required property var modelData
                Layout.fillWidth: true
                color: Theme.fg
                wrapMode: Text.Wrap
                text: "GPU " + modelData.name + " (" + modelData.backend + ")  " + Logic.gpuUsage(modelData)
                    + (modelData.memoryType === "shared" ? "   Shared memory" : "   VRAM " + Logic.bytes(modelData.memoryUsed)
                        + " / " + Logic.bytes(modelData.memoryTotal) + " ("
                        + Logic.metric(Number.isFinite(modelData.memoryUsed) && modelData.memoryTotal > 0 ? modelData.memoryUsed / modelData.memoryTotal * 100 : null, "%") + ")")
                    + (modelData.vendor === "intel" ? "   Clock " + Logic.metric(modelData.clockMHz, " MHz", 0)
                        + "   Power " + Logic.metric(modelData.powerW, " W", 2) : "")
                    + "   " + Logic.metric(modelData.temperatureC, " °C")
                    + (modelData.detail ? " · " + modelData.detail : "")
            }
        }
        Label { visible: !TaskManagerService.gpus.length; color: Theme.fgMuted; text: TaskManagerService.ready ? "GPU  Unsupported" : "GPU  Unavailable" }
        Label {
            Layout.fillWidth: true
            color: Theme.fg
            wrapMode: Text.Wrap
            text: TaskManagerService.memory.available ? "Memory  " + Logic.metric(TaskManagerService.memory.percent, "%") + "   "
                + Logic.bytes(TaskManagerService.memory.used) + " / " + Logic.bytes(TaskManagerService.memory.total)
                + "   Available " + Logic.bytes(TaskManagerService.memory.availableBytes)
                + "   Cache " + Logic.bytes(TaskManagerService.memory.cache) + "   Buffers " + Logic.bytes(TaskManagerService.memory.buffers)
                + "   Swap " + Logic.bytes(TaskManagerService.memory.swapUsed) + " / " + Logic.bytes(TaskManagerService.memory.swapTotal) : "Memory  Unavailable"
        }
        Label {
            Layout.fillWidth: true
            color: Theme.fg
            wrapMode: Text.Wrap
            text: "Disk I/O  Read " + Logic.bytes(TaskManagerService.disks.readBps) + "/s   Write " + Logic.bytes(TaskManagerService.disks.writeBps) + "/s"
        }
        Repeater {
            model: TaskManagerService.disks.devices || []
            Label {
                required property var modelData
                color: Theme.fgMuted
                text: modelData.name + "   R " + Logic.bytes(modelData.readBps) + "/s   W " + Logic.bytes(modelData.writeBps) + "/s"
            }
        }
        Repeater {
            model: TaskManagerService.disks.mounts || []
            Label {
                required property var modelData
                Layout.fillWidth: true
                color: Theme.fgMuted
                elide: Text.ElideMiddle
                text: modelData.mount + "  " + Logic.bytes(modelData.used) + " / " + Logic.bytes(modelData.total)
                    + "  (" + Logic.metric(modelData.percent, "%") + ")"
            }
        }
        RowLayout {
            Layout.fillWidth: true
            ComboBox {
                model: root.names
                currentIndex: root.names.indexOf(root.effectiveInterface)
                Accessible.name: "Network interface"
                onActivated: root.interfaceName = currentText
            }
            Label {
                Layout.fillWidth: true
                color: Theme.fg
                wrapMode: Text.Wrap
                text: "RX " + Logic.bytes(root.traffic.rxBps) + "/s   TX " + Logic.bytes(root.traffic.txBps)
                    + "/s   Total " + Logic.bytes(root.traffic.rxBytes) + " / " + Logic.bytes(root.traffic.txBytes)
            }
        }
    }
}
