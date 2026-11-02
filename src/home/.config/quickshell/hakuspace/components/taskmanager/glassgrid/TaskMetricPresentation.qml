import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../../services"
import "TaskManagerMotion.js" as Motion

Item {
    id: root

    property string metricId: "memory"
    // 0.0 = compact card presentation, 1.0 = full Focus Card presentation
    property real expansionProgress: 0.0
    property bool interactive: false
    property var visuals
    property bool compact: false
    property bool ultraCompact: false
    property bool reducedMotion: false
    property real waterWavePhase: 0.0

    property var memory: ({})
    property var gpus: []
    property var disks: ({})
    property var network: ({})
    property var history: []
    property bool serviceReady: false
    property string interfaceName: ""
    property string primaryValue: ""
    property string secondaryValue: ""
    property real customBarValue: -1
    property bool customBarAvailable: false
    signal interfaceSelected(string name)

    readonly property real clampedRole: Motion.clamp01(root.expansionProgress)

    readonly property var primaryGpu: (Array.isArray(gpus) && gpus.length > 0) ? gpus[0] : null
    readonly property bool hasDedicatedVram: !!(primaryGpu && primaryGpu.memoryType !== "shared"
        && Number.isFinite(primaryGpu.memoryUsed) && Number.isFinite(primaryGpu.memoryTotal)
        && primaryGpu.memoryTotal > 0)

    readonly property var diskMounts: (disks && Array.isArray(disks.mounts)) ? disks.mounts : []
    readonly property var mainMount: diskMounts.find(m => m && m.mount === "/") || diskMounts[0] || null

    readonly property var netInterfaces: ((network && Array.isArray(network.interfaces)) ? network.interfaces : []).filter(row => !row.loopback)
    readonly property var netNames: ["All"].concat(netInterfaces.map(row => row.name))
    readonly property string effectiveInterface: netNames.includes(interfaceName) ? interfaceName : ((network && network.defaultInterface) || "All")
    readonly property var netTraffic: effectiveInterface === "All"
        ? ((network && network.all) || {})
        : (netInterfaces.find(row => row.name === effectiveInterface) || {})

    readonly property string titleText: {
        if (metricId === "gpu") return "GPU"
        if (metricId === "disk") return "Disk"
        if (metricId === "network") return "Network"
        return "Memory"
    }

    property bool showNumeric: false

    readonly property string percentHeroText: {
        if (clampedRole <= 0.05 && primaryValue !== "") return primaryValue
        if (!visuals) return "—"
        if (metricId === "gpu") return visuals.gpuHeroText(root.primaryGpu, root.serviceReady)
        if (metricId === "disk") return root.mainMount ? visuals.dashMetric(root.mainMount.percent, "%") : "—"
        if (metricId === "network") return "↓ " + visuals.dashRate(root.netTraffic.rxBps)
        return visuals.dashMetric(root.memory.percent, "%")
    }

    readonly property string usedHeroText: {
        if (!visuals) return "—"
        if (metricId === "gpu") return (root.primaryGpu && root.hasDedicatedVram) ? visuals.dashBytes(root.primaryGpu.memoryUsed) : visuals.gpuHeroText(root.primaryGpu, root.serviceReady)
        if (metricId === "disk") return root.mainMount ? visuals.dashBytes(root.mainMount.used) : "—"
        if (metricId === "network") return visuals.dashRate(root.netTraffic.rxBps)
        return visuals.dashBytes(root.memory.used)
    }

    readonly property string heroText: (clampedRole > 0.05 && root.showNumeric) ? usedHeroText : percentHeroText

    readonly property real gaugeValue: {
        if (metricId === "gpu") return root.primaryGpu ? (visuals ? visuals.clampPercent(root.primaryGpu.usage) : 0) : 0
        if (metricId === "disk") return root.mainMount ? (visuals ? visuals.clampPercent(root.mainMount.percent) : 0) : 0
        if (metricId === "network") {
            var sumBps = (root.netTraffic.rxBps || 0) + (root.netTraffic.txBps || 0)
            return Math.min(100, Math.max(0, (sumBps / 1048576) * 10))
        }
        return visuals ? visuals.clampPercent(root.memory.percent) : 0
    }

    readonly property bool gaugeAvailable: {
        if (metricId === "gpu") return !!(root.primaryGpu && Number.isFinite(root.primaryGpu.usage))
        if (metricId === "disk") return !!(root.mainMount && Number.isFinite(root.mainMount.percent))
        if (metricId === "network") return true
        return Number.isFinite(root.memory.percent)
    }

    readonly property string gaugeUsedText: {
        if (!visuals) return ""
        if (metricId === "gpu") return (root.primaryGpu && root.hasDedicatedVram) ? visuals.dashBytes(root.primaryGpu.memoryUsed) : ""
        if (metricId === "disk") return root.mainMount ? visuals.dashBytes(root.mainMount.used) : ""
        if (metricId === "network") return visuals.dashRate(root.netTraffic.rxBps)
        return visuals.dashBytes(root.memory.used)
    }

    readonly property string gaugeTotalText: {
        if (!visuals) return ""
        if (metricId === "gpu") return (root.primaryGpu && root.hasDedicatedVram) ? visuals.dashBytes(root.primaryGpu.memoryTotal) : ""
        if (metricId === "disk") return root.mainMount ? visuals.dashBytes(root.mainMount.total) : ""
        if (metricId === "network") return visuals.dashRate(root.netTraffic.txBps)
        return visuals.dashBytes(root.memory.total)
    }

    // Capture metric identity and values together for the gauge.
    readonly property var gaugeSample: ({
        metricId: root.metricId,
        value: root.gaugeValue,
        available: root.gaugeAvailable,
        usedText: root.gaugeUsedText,
        totalText: root.gaugeTotalText
    })

    readonly property int compactPad: visuals ? visuals.compactCardPadding(root.height * 6, root.width * 6) : 9
    readonly property int focusPad: visuals ? visuals.focusCardPadding(root.height * 3.6, root.width * 3) : 13
    readonly property int pad: Math.round(Motion.lerp(compactPad, focusPad, clampedRole))

    readonly property real compactDiameter: root.ultraCompact ? 42 : (root.compact ? 46 : 52)
    readonly property real focusDiameter: root.ultraCompact ? 72 : (root.compact ? 78 : 84)
    readonly property real currentDiameter: Math.round(Motion.lerp(compactDiameter, focusDiameter, clampedRole))

    anchors.fill: parent
    clip: true

    Item {
        anchors.fill: parent
        anchors.margins: root.pad

        Item {
            id: headerZone
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: Math.round(Motion.lerp(18, 24, root.clampedRole))

            RowLayout {
                anchors.fill: parent
                spacing: 6

                Label {
                    id: titleLabel
                    objectName: "taskMetricTitle_" + root.metricId
                    text: root.titleText
                    color: (root.clampedRole > 0.4) ? Theme.accent : (visuals ? visuals.primaryFg : Theme.fg)
                    font.bold: root.clampedRole > 0.5
                    font.pixelSize: Math.round(Motion.lerp(
                        root.ultraCompact ? visuals.metaFontSize - 1 : visuals.metaFontSize,
                        root.ultraCompact ? visuals.sectionTitleSize - 1 : visuals.sectionTitleSize,
                        root.clampedRole
                    ))
                }

                Item {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 4
                }

                Label {
                    id: heroLabel
                    objectName: root.metricId === "memory" ? "focusMemoryPercent"
                        : (root.metricId === "gpu" ? "focusGpuHero"
                            : (root.metricId === "disk" ? "focusDiskPercent" : "taskMetricPrimary_" + root.metricId))
                    text: root.heroText
                    color: Theme.accent
                    font.bold: true
                    font.pixelSize: Math.round(Motion.lerp(
                        root.ultraCompact ? visuals.sectionTitleSize - 1 : visuals.sectionTitleSize,
                        root.ultraCompact ? visuals.focusHeroFontSize - 2 : (root.compact ? visuals.focusHeroFontSize - 1 : visuals.focusHeroFontSize),
                        root.clampedRole
                    ))
                    horizontalAlignment: Text.AlignRight
                    Layout.minimumWidth: 0
                }
            }
        }

        Item {
            id: bodyZone
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: headerZone.bottom
            anchors.topMargin: Math.round(Motion.lerp(3, 8, root.clampedRole))
            anchors.bottom: parent.bottom

            readonly property real compactCenterX: Math.max(0, Math.round((width - root.currentDiameter) / 2))
            readonly property real gaugeX: Math.round(Motion.lerp(compactCenterX, 0, root.clampedRole))

            // Keep the gauge alive while changing card geometry.
            Item {
                id: gaugeWrap
                x: bodyZone.gaugeX
                anchors.verticalCenter: parent.verticalCenter
                width: root.currentDiameter
                height: root.currentDiameter

                TaskWaterGauge {
                    id: gauge
                    anchors.centerIn: parent
                    diameter: root.currentDiameter
                    expansionProgress: root.clampedRole
                    interactive: root.interactive && root.clampedRole > 0.8
                    sample: root.gaugeSample
                    wavePhase: root.waterWavePhase
                    showNumeric: root.showNumeric
                    reducedMotion: root.reducedMotion
                    onShowNumericToggled: val => root.showNumeric = val
                }
            }

            ColumnLayout {
                id: detailCol
                anchors.left: gaugeWrap.right
                anchors.leftMargin: Math.round(Motion.lerp(8, 14, root.clampedRole))
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                spacing: Math.round(Motion.lerp(1, 4, root.clampedRole))
                opacity: Motion.segment(root.clampedRole, 0.28, 0.88)
                visible: opacity > 0.01

                TaskMetricPair {
                    visible: root.metricId === "memory"
                    label: "Used"
                    value: visuals ? visuals.dashBytes(root.memory.used) : "—"
                    visuals: root.visuals
                    compact: root.compact
                    ultraCompact: root.ultraCompact
                }
                TaskMetricPair {
                    visible: root.metricId === "memory"
                    label: "Available"
                    value: visuals ? visuals.dashBytes(root.memory.availableBytes) : "—"
                    visuals: root.visuals
                    compact: root.compact
                    ultraCompact: root.ultraCompact
                }
                TaskMetricPair {
                    visible: root.metricId === "memory" && (root.clampedRole > 0.25 || root.height >= 110)
                    label: "Cache"
                    value: visuals ? visuals.dashBytes(root.memory.cache) : "—"
                    visuals: root.visuals
                    compact: root.compact
                    ultraCompact: root.ultraCompact
                }
                TaskMetricPair {
                    visible: root.metricId === "memory" && (root.clampedRole > 0.25 || root.height >= 110)
                    label: "Swap"
                    value: (Number.isFinite(root.memory.swapTotal) && root.memory.swapTotal > 0)
                        ? (visuals ? visuals.dashPairBytes(root.memory.swapUsed, root.memory.swapTotal) : "—")
                        : "—"
                    valueObjectName: "focusMemorySwap"
                    visuals: root.visuals
                    compact: root.compact
                    ultraCompact: root.ultraCompact
                }

                TaskMetricPair {
                    visible: root.metricId === "gpu" && (root.clampedRole > 0.25 || root.height >= 110)
                    label: "Name"
                    value: root.primaryGpu && root.primaryGpu.name
                        ? (visuals ? visuals.truncateEnd(root.primaryGpu.name, 22) : root.primaryGpu.name)
                        : (root.serviceReady ? "Unsupported" : "—")
                    valueObjectName: "focusGpuName"
                    visuals: root.visuals
                    compact: root.compact
                    ultraCompact: root.ultraCompact
                }
                TaskMetricPair {
                    visible: root.metricId === "gpu"
                    label: "Temp"
                    value: visuals ? visuals.dashMetric(root.primaryGpu ? root.primaryGpu.temperatureC : null, " °C") : "—"
                    valueObjectName: "focusGpuTemp"
                    visuals: root.visuals
                    compact: root.compact
                    ultraCompact: root.ultraCompact
                }
                TaskMetricPair {
                    visible: root.metricId === "gpu"
                    label: "Clock"
                    value: visuals ? visuals.dashMetric(root.primaryGpu ? root.primaryGpu.clockMHz : null, " MHz", 0) : "—"
                    valueObjectName: "focusGpuClock"
                    visuals: root.visuals
                    compact: root.compact
                    ultraCompact: root.ultraCompact
                }
                TaskMetricPair {
                    visible: root.metricId === "gpu" && (root.clampedRole > 0.25 || root.height >= 110)
                    label: "Power"
                    value: visuals ? visuals.dashMetric(root.primaryGpu ? root.primaryGpu.powerW : null, " W", 2) : "—"
                    valueObjectName: "focusGpuPower"
                    visuals: root.visuals
                    compact: root.compact
                    ultraCompact: root.ultraCompact
                }
                TaskMetricPair {
                    visible: root.metricId === "gpu" && (root.clampedRole > 0.25 || root.height >= 110)
                    label: "VRAM"
                    value: !root.primaryGpu ? "—"
                        : (root.primaryGpu.memoryType === "shared" ? "Shared"
                            : (root.hasDedicatedVram && visuals ? visuals.dashPairBytes(root.primaryGpu.memoryUsed, root.primaryGpu.memoryTotal) : "—"))
                    valueObjectName: "focusGpuVram"
                    visuals: root.visuals
                    compact: root.compact
                    ultraCompact: root.ultraCompact
                }
                Item {
                    objectName: "focusGpuVramBar"
                    Layout.fillWidth: true
                    implicitHeight: 3
                    visible: root.metricId === "gpu" && root.hasDedicatedVram && (root.clampedRole > 0.25 || root.height >= 110)
                    Rectangle {
                        anchors.fill: parent
                        radius: 1.5
                        color: Theme.accent
                    }
                }

                TaskMetricPair {
                    visible: root.metricId === "disk"
                    label: "Read"
                    value: visuals ? visuals.dashRate(root.disks ? root.disks.readBps : null) : "—"
                    valueObjectName: "focusDiskRead"
                    visuals: root.visuals
                    compact: root.compact
                    ultraCompact: root.ultraCompact
                }
                TaskMetricPair {
                    visible: root.metricId === "disk"
                    label: "Write"
                    value: visuals ? visuals.dashRate(root.disks ? root.disks.writeBps : null) : "—"
                    valueObjectName: "focusDiskWrite"
                    visuals: root.visuals
                    compact: root.compact
                    ultraCompact: root.ultraCompact
                }
                TaskMetricPair {
                    visible: root.metricId === "disk" && (root.clampedRole > 0.25 || root.height >= 110)
                    label: "Mount"
                    value: root.mainMount ? (visuals ? visuals.truncateMiddle(root.mainMount.mount, 18) : root.mainMount.mount) : "—"
                    visuals: root.visuals
                    compact: root.compact
                    ultraCompact: root.ultraCompact
                }
                TaskMetricPair {
                    visible: root.metricId === "disk" && (root.clampedRole > 0.25 || root.height >= 110)
                    label: "Used/Tot"
                    value: root.mainMount && visuals ? visuals.dashPairBytes(root.mainMount.used, root.mainMount.total) : "—"
                    visuals: root.visuals
                    compact: root.compact
                    ultraCompact: root.ultraCompact
                }

                TaskDropdown {
                    id: netDropdown
                    Layout.fillWidth: true
                    Layout.preferredHeight: root.ultraCompact ? 22 : 26
                    objectName: root.interactive ? "taskManagerNetworkCombo" : ""
                    visible: root.interactive && root.metricId === "network" && (root.clampedRole > 0.25 || root.height >= 110)
                    visuals: root.visuals
                    reducedMotion: root.reducedMotion
                    padX: 8
                    model: root.netNames
                    currentIndex: Math.max(0, root.netNames.indexOf(root.effectiveInterface))
                    Accessible.name: "Network interface"
                    onActivated: root.interfaceSelected(currentText)
                }
                TaskMetricPair {
                    visible: root.metricId === "network"
                    label: "↓ RX/s"
                    value: visuals ? visuals.dashRate(root.netTraffic.rxBps) : "—"
                    accentValue: true
                    valueObjectName: "focusNetworkRxRate"
                    visuals: root.visuals
                    compact: root.compact
                    ultraCompact: root.ultraCompact
                }
                TaskMetricPair {
                    visible: root.metricId === "network"
                    label: "↑ TX/s"
                    value: visuals ? visuals.dashRate(root.netTraffic.txBps) : "—"
                    accentValue: true
                    valueObjectName: "focusNetworkTxRate"
                    visuals: root.visuals
                    compact: root.compact
                    ultraCompact: root.ultraCompact
                }
                TaskMetricPair {
                    visible: root.metricId === "network" && (root.clampedRole > 0.25 || root.height >= 110)
                    label: "Total RX"
                    value: visuals ? visuals.dashBytes(root.netTraffic.rxBytes) : "—"
                    valueObjectName: "focusNetworkRxTotal"
                    visuals: root.visuals
                    compact: root.compact
                    ultraCompact: root.ultraCompact
                }
                TaskMetricPair {
                    visible: root.metricId === "network" && (root.clampedRole > 0.25 || root.height >= 110)
                    label: "Total TX"
                    value: visuals ? visuals.dashBytes(root.netTraffic.txBytes) : "—"
                    valueObjectName: "focusNetworkTxTotal"
                    visuals: root.visuals
                    compact: root.compact
                    ultraCompact: root.ultraCompact
                }
            }
        }
    }
}
