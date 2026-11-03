import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import "components"
import "components/base" as Base
import "services"

ShellRoot {
    id: root
    property int phase: 0
    property int ticks: 0
    readonly property string output: Quickshell.screens[0].name
    readonly property var overlay: surface.item
    readonly property var input: overlay ? overlay.testInput : null
    readonly property var card: overlay ? overlay.mask.item : null
    readonly property var content: overlay ? overlay.content : null

    property rect initialFocusRect: Qt.rect(0, 0, 0, 0)

    function buildProcesses(count) {
        var list = [
            {
                pid: 123456, startTime: 10, key: "123456:10",
                name: "very-long-application-process-name-that-must-elide-cleanly-without-truncating-pid-or-metrics",
                user: "extremely_long_username_account",
                cmdline: "/usr/lib/very-long-application --with-many-flags --render-backend=vulkan",
                rss: 1572864000, memoryPercent: 9.6, cpuPercent: 100, cpuTotalPercent: 100 / 12,
                threads: 24, ppid: 1, state: "R", runtimeSeconds: 4120
            },
            {
                pid: 1234567, startTime: 20, key: "1234567:20",
                name: "quickshell-worker",
                user: "hakuimaku",
                cmdline: "quickshell -c hakuspace",
                rss: 314572800, memoryPercent: 1.9, cpuPercent: 50, cpuTotalPercent: 50 / 12,
                threads: 9, ppid: 900, state: "S", runtimeSeconds: 980
            }
        ]
        for (var i = 0; i < count - 2; i++) {
            var pid = 2000 + i
            list.push({
                pid: pid, startTime: 100 + i, key: pid + ":" + (100 + i),
                name: "worker-" + i, user: i % 2 === 0 ? "hakuimaku" : "root",
                cmdline: "/usr/bin/worker-" + i + " --daemon",
                rss: (16 + (i % 64)) * 1048576,
                memoryPercent: 0.4,
                cpuPercent: (i % 15) * 1.5,
                cpuTotalPercent: ((i % 15) * 1.5) / 12,
                threads: 1 + (i % 8), ppid: 1, state: "S", runtimeSeconds: 120 + i
            })
        }
        return list
    }

    function buildHistory(count) {
        var hist = []
        for (var i = 0; i < count; i++) {
            hist.push({
                t: i * 1000,
                cpu: 15 + (i % 25),
                gpu: 22 + (i % 30),
                memory: 42 + (i % 10) * 0.5,
                rx: (i + 1) * 65536,
                tx: (i + 1) * 32768,
                read: (i % 8) * 1048576,
                write: (i % 6) * 524288
            })
        }
        return hist
    }

    readonly property var normalSnapshot: ({
        schema: 1,
        seq: 10,
        monotonicMs: 10000,
        processMonotonicMs: 10000,
        cpu: {
            usage: 18.4,
            warmingUp: false,
            frequencyHighestMHz: 3800,
            frequencyAverageMHz: 2450,
            frequencyLowestMHz: 800,
            temperatureC: 54.0,
            load: [1.82, 1.45, 1.19],
            cores: [62.5, 12.0, 88.4, 5.2, 19.0, 4.1, 31.0, 9.5, 14.2, 2.0, 7.8, 11.1]
        },
        memory: {
            available: true,
            percent: 45.2,
            used: 7408816128,
            total: 16447311872,
            availableBytes: 9038495744,
            cache: 3221225472,
            buffers: 268435456,
            swapUsed: 936378368,
            swapTotal: 12884901888
        },
        gpus: [
            {
                id: "card1",
                name: "Intel Iris Xe",
                vendor: "intel",
                backend: "drm-fdinfo",
                status: "available",
                detail: "accessible-clients",
                usage: 38.0,
                temperatureC: null,
                clockMHz: 1150,
                powerW: null,
                memoryType: "shared",
                memoryUsed: null,
                memoryTotal: null
            }
        ],
        disks: {
            readBps: 4194304,
            writeBps: 10485760,
            devices: [{name: "nvme0n1", readBps: 4194304, writeBps: 10485760}],
            mounts: [
                {mount: "/", device: "/dev/nvme0n1p2", fstype: "ext4", used: 182536110080, total: 512110190592, percent: 35.6},
                {mount: "/mnt/Data", device: "/dev/nvme0n1p3", fstype: "ext4", used: 410000000000, total: 1000000000000, percent: 41.0}
            ]
        },
        network: {
            defaultInterface: "wlan0",
            all: {rxBps: 3145728, txBps: 524288, rxBytes: 8589934592, txBytes: 1073741824},
            interfaces: [
                {name: "wlan0", loopback: false, rxBps: 3145728, txBps: 524288, rxBytes: 8589934592, txBytes: 1073741824},
                {name: "eth0", loopback: false, rxBps: 0, txBps: 0, rxBytes: 1048576, txBytes: 524288}
            ]
        },
        processes: buildProcesses(310)
    })

    // Keep visual fixtures independent of live collector updates.
    function applySnapshot(value) {
        content.cpuData = value.cpu
        content.memoryData = value.memory
        content.gpusData = value.gpus
        content.disksData = value.disks
        content.networkData = value.network
        content.processesData = value.processes
        content.historyData = root.buildHistory(36)
        content.serviceReady = true
        content.warmingUp = false
    }

    function check(condition, message) {
        if (condition) return
        console.error("Glass Grid harness failed at phase " + phase + ": " + message)
        Qt.exit(1)
        throw new Error(message)
    }

    function findByObjectName(item, name) {
        if (!item) return null
        if (item.objectName === name) return item
        for (var child of item.children || []) {
            var found = findByObjectName(child, name)
            if (found) return found
        }
        if (item.contentItem) {
            var inContent = findByObjectName(item.contentItem, name)
            if (inContent) return inContent
        }
        return null
    }

    function collectTexts(item, out) {
        if (!item || !item.visible) return out
        if (typeof item.text === "string" && item.text.length > 0) out.push(item.text)
        for (var child of item.children || []) collectTexts(child, out)
        return out
    }

    function assertNoInvalidStrings() {
        var texts = collectTexts(root.content, [])
        for (var i = 0; i < texts.length; i++) {
            var t = texts[i]
            root.check(!t.includes("undefined") && !t.includes("NaN") && !t.includes("0 B / 0 B"),
                "Invalid telemetry text rendered: '" + t + "'")
        }
    }

    // Keep one reading in the right header and no duplicated text inside the water.
    function assertGaugeLabels() {
        var focus = root.findByObjectName(root.content, "taskFocusCard")
        var visual = root.findByObjectName(focus, "focusCardVisualLayer")
        var gauge = root.findByObjectName(visual, "taskWaterGauge")
        var title = root.findByObjectName(visual, "taskMetricTitle_" + focus.metricId)
        var heroName = focus.metricId === "memory" ? "focusMemoryPercent"
            : focus.metricId === "gpu" ? "focusGpuHero" : focus.metricId === "disk" ? "focusDiskPercent" : "taskMetricPrimary_network"
        var reading = root.findByObjectName(visual, heroName)
        root.check(gauge && root.collectTexts(gauge, []).length === 0, "standalone water contains no numeric text")
        root.check(reading && reading.text.length > 0 && reading.horizontalAlignment === Text.AlignRight
            && reading.x >= title.x + title.width + reading.parent.spacing - 0.5
            && Math.abs(reading.x + reading.width - reading.parent.width) <= 0.5,
            "standalone keeps its reading at the right edge of the header")
    }

    function assertResponsiveLayout(expectedW, expectedH) {
        root.check(Math.abs(root.card.width - expectedW) < 1.1 && Math.abs(root.card.height - expectedH) < 1.1,
            "Unexpected card size: " + root.card.width + "x" + root.card.height)
        var leftPane = findByObjectName(root.content, "taskTelemetryPane")
        var procPane = findByObjectName(root.content, "taskProcessPane")
        var focusCard = findByObjectName(root.content, "taskFocusCard")
        var footer = findByObjectName(root.content, "taskManagerFooterStatus")
        var table = findByObjectName(root.content, "taskManagerProcesses")
        root.check(leftPane && procPane && focusCard && footer && table, "Missing core Glass Grid subtrees")
        root.check(leftPane.width >= 264 && leftPane.width <= 340, "Left pane out of bounds: " + leftPane.width)
        root.check(procPane.width > 340, "Process pane starved: " + procPane.width)
        root.check(leftPane.x + leftPane.width <= procPane.x + 0.5, "Left and right panes overlap")
        root.check(procPane.x + procPane.width <= root.content.width + 0.5, "Process pane overflows content width")
        root.check(table.height >= 40, "Process table collapsed at " + expectedW + "x" + expectedH)
        root.assertGaugeLabels()

        // Verify borderless visual contract across shell, cards, panes and controls.
        var cpuCard = findByObjectName(root.content, "taskCpuCard")
        var memCard = findByObjectName(root.content, "taskMetricCard_memory")
        var searchField = findByObjectName(root.content, "taskManagerSearch")
        var sortCombo = findByObjectName(root.content, "taskManagerSortCombo")
        var netCombo = findByObjectName(root.content, "taskManagerNetworkCombo")
        for (var surfaceItem of [root.card, cpuCard, focusCard, memCard, procPane,
                searchField ? searchField.background : null,
                sortCombo ? sortCombo.background : null,
                netCombo ? netCombo.background : null]) {
            root.check(surfaceItem && surfaceItem.border.width === 0,
                "Unexpected border on " + surfaceItem + " at " + expectedW + "x" + expectedH)
        }
        if (expectedW === 980 && expectedH === 680) {
            root.check(focusCard.height >= 150 && focusCard.height <= 170,
                "Focus Card height outside 150..170 at 980x680: " + focusCard.height)
            root.check(memCard.height >= 88 && memCard.height <= 100,
                "Compact metric card height outside 88..100 at 980x680: " + memCard.height)
        }

        // Verify 6- and 7-digit PIDs never truncate at any tested size.
        var findPid = function(item, pidText) {
            if (!item) return null
            if (item.objectName === "taskManagerPid" && item.text === String(pidText)) return item
            for (var child of item.children || []) {
                var found = findPid(child, pidText)
                if (found) return found
            }
            return null
        }
        var headerPid = findPid(root.content, "PID")
        var pid6 = findPid(root.content, "123456")
        var pid7 = findPid(root.content, "1234567")
        root.check(headerPid && pid6 && pid7, "PID cells missing at " + expectedW + "x" + expectedH)
        for (var cell of [pid6, pid7]) {
            root.check(cell.elide === Text.ElideNone && !cell.truncated && cell.width >= cell.contentWidth,
                "PID truncated at " + expectedW + "x" + expectedH + ": " + cell.text)
            var row = cell.parent
            root.check(row.children.length === headerPid.parent.children.length, "Column count mismatch")
            for (var c = 1; c < row.children.length; c++) {
                var exp = headerPid.parent.children[c]
                var act = row.children[c]
                root.check(Math.abs(act.width - exp.width) < 1.1 && Math.abs(act.x - exp.x) < 1.1,
                    "Column alignment mismatch at col " + c + " in " + expectedW + "x" + expectedH)
            }
        }
        // Check column colors and reject obsolete accentName bindings.
        for (var rItem of [pid6.parent, pid7.parent]) {
            root.check(rItem.accentName === undefined, "Obsolete accentName property must be removed from TaskProcessRow")
            var rPid = findByObjectName(rItem, "taskManagerPid")
            var rName = findByObjectName(rItem, "taskManagerProcessName")
            var rUser = findByObjectName(rItem, "taskManagerProcessUser")
            var rCpu = findByObjectName(rItem, "taskManagerProcessCpu")
            var rMem = findByObjectName(rItem, "taskManagerProcessMemory")
            var rThr = findByObjectName(rItem, "taskManagerProcessThreads")
            root.check(Qt.colorEqual(rPid.color, rUser.color)
                && Qt.colorEqual(rUser.color, rMem.color)
                && Math.abs(rPid.color.r - rItem.fgCol.r) < 0.02
                && Math.abs(rPid.color.a - rItem.fgCol.a) < 0.02,
                "PID/USER/MEM columns must use foreground color")
            root.check(Qt.colorEqual(rName.color, rItem.selected ? Theme.onAccentColor : Theme.accent)
                && Qt.colorEqual(rCpu.color, rItem.selected ? Theme.onAccentColor : Theme.accent)
                && Qt.colorEqual(rThr.color, rItem.selected ? Theme.onAccentColor : Theme.accent),
                "PROCESS/CPU/THR columns must use Theme.accent")
        }

        // Verify CPU logical core hit area and tooltip formatting.
        var core0 = findByObjectName(cpuCard, "cpuCoreCell_0")
        root.check(core0 && core0.height >= 11, "CPU logical core hit area too small: " + (core0 ? core0.height : 0))
        if (expectedW === 980 && expectedH === 680) {
            root.check(core0.height >= 14, "Normal 980x680 CPU core hit area should be >= 14px: " + core0.height)
            root.check(cpuCard.formatCoreTooltip(0) === "Core 0 · 62.5%"
                && cpuCard.formatCoreTooltip(1) === "Core 1 · 12%"
                && cpuCard.stemProgress === undefined && cpuCard.unfurlProgress === undefined,
                "CPU core tooltip formatting without obsolete motion state")
        }
    }

    Base.LifecycleLoader {
        id: surface
        requested: UiState.taskManagerOpen && UiState.taskManagerScreenName === root.output
        TaskManagerOverlay {
            modelData: Quickshell.screens[0]
            property alias testInput: events
            TestEvent { id: events }
        }
    }

    Timer {
        interval: 35
        repeat: true
        running: true
        onTriggered: {
            root.ticks++
            root.check(root.ticks < 900, "Glass Grid harness timed out at phase " + root.phase)

            if (root.phase === 0) {
                UiState.openTaskManager(root.output)
            } else if (root.phase === 1) {
                if (!root.overlay || !root.overlay.interactionReady) return
                // Keep this responsive-size fixture independent of the fitted default height.
                root.overlay.cardSize = Qt.size(980, 680)
                root.applySnapshot(root.normalSnapshot)
            } else if (root.phase === 2) {
                root.applySnapshot(root.normalSnapshot)
                // Verify default Focus Card state is "memory" and 310 processes are loaded.
                var focusCard = root.findByObjectName(root.content, "taskFocusCard")
                root.check(root.content.focusedMetric === "memory" && root.content.displayMetric === "memory"
                    && focusCard.displayMetric === "memory" && !root.content.focusMorphActive,
                    "Default focus must be memory at settled state, got " + root.content.focusedMetric + "/" + focusCard.displayMetric)
                root.check(root.content.rows.length === 310, "300+ process model not loaded: " + root.content.rows.length)
                root.assertNoInvalidStrings()
                root.assertResponsiveLayout(980, 680)

                // Check the stationary chassis and every Settings attachment position.
                var shellSurface = root.findByObjectName(root.overlay, "taskManagerShellSurface")
                root.overlay.setMorphProgress(0.00)
                root.check(root.card.opacity === 1
                    && root.card.width === 0 && root.card.height === 0
                    && Math.abs(root.card.x - root.overlay.targetX - root.overlay.cardWidth / 2) < 0.5
                    && shellSurface.width === root.overlay.cardWidth
                    && shellSurface.height === root.overlay.cardHeight, "Settings-style morph checkpoint 0.00 failed")
                root.overlay.setMorphProgress(0.20)
                var w20 = root.card.width
                var h20 = root.card.height
                root.check(root.card.opacity === 1 && w20 > 0 && w20 < root.overlay.cardWidth
                    && h20 > 0 && h20 < root.overlay.cardHeight
                    && shellSurface.width === root.overlay.cardWidth, "Settings-style morph checkpoint 0.20 failed")
                root.overlay.setMorphProgress(0.50)
                var w50 = root.card.width
                var h50 = root.card.height
                root.check(root.card.opacity === 1 && w50 > w20 && w50 < root.overlay.cardWidth
                    && h50 > h20 && h50 < root.overlay.cardHeight
                    && shellSurface.width === root.overlay.cardWidth, "Settings-style morph checkpoint 0.50 failed")
                for (var position = 1; position <= 8; position++) {
                    root.overlay.revealPosition = position
                    var geometry = root.overlay.revealGeometry
                    var bounds = root.overlay.revealBounds
                    root.check(geometry.path.length > 0 && geometry.anchor.x >= bounds.x
                        && geometry.anchor.x <= bounds.x + bounds.width && geometry.anchor.y >= bounds.y
                        && geometry.anchor.y <= bounds.y + bounds.height
                        && Math.abs(geometry.center.x - root.overlay.targetX - root.overlay.cardWidth / 2) < 0.5
                        && Math.abs(geometry.center.y - root.overlay.targetY - root.overlay.cardHeight / 2) < 0.5,
                        "Settings-style fixed endpoints at position " + position)
                    if (position === 2) root.check(geometry.anchor.y === 0, "HakuMenu foot reaches the top screen edge")
                    if (position === 8) root.check(geometry.anchor.x === 0, "Sidebar foot reaches the left screen edge")
                }
                root.overlay.setMorphProgress(0.80)
                root.check(root.card.opacity === 1 && root.card.width > w50 && root.card.width < root.overlay.cardWidth
                    && root.card.height > h50 && root.card.height < root.overlay.cardHeight
                    && shellSurface.width === root.overlay.cardWidth, "Settings-style morph checkpoint 0.80 failed")
                root.overlay.setMorphProgress(1.00)
                root.check(root.card.opacity === 1
                    && Math.abs(root.card.width - root.overlay.cardWidth) < 0.5
                    && Math.abs(root.card.height - root.overlay.cardHeight) < 0.5
                    && Math.abs(root.card.x - root.overlay.targetX) < 0.5
                    && Math.abs(root.card.y - root.overlay.targetY) < 0.5
                    && Math.abs(root.card.radius - Theme.largeRadius) < 0.5
                    && root.overlay.revealGeometry.path === "", "Settings-style morph checkpoint 1.00 failed")

                root.initialFocusRect = Qt.rect(focusCard.x, focusCard.y, focusCard.width, focusCard.height)

                // Check focus-card checkpoints from memory to GPU.
                var focusLayer = root.findByObjectName(root.content, "taskFocusLayer")
                var focusSlot = root.findByObjectName(root.content, "taskFocusSlot")
                var memCard = root.findByObjectName(root.content, "taskMetricCard_memory")
                var gpuCard = root.findByObjectName(root.content, "taskMetricCard_gpu")
                var diskCard = root.findByObjectName(root.content, "taskMetricCard_disk")

                root.check(focusLayer && focusLayer.visible, "taskFocusLayer must be present and visible")
                root.check(focusSlot && focusSlot.width > 0, "taskFocusSlot must be present in telemetryGrid")

                root.content.setFocusMorphState("memory", "gpu", 0.00)
                var incomingCard = root.findByObjectName(root.content, "incomingMorphCard")
                var incomingInstanceId = incomingCard ? incomingCard.instanceId : -1
                var focusPres = root.findByObjectName(focusCard, "focusCardVisualLayer")
                root.check(incomingCard && incomingCard.visible, "incomingMorphCard must be visible at 0.00")
                root.check(gpuCard.visualSuppressed && !memCard.visualSuppressed && !diskCard.visualSuppressed,
                    "Only target compact card (GPU) must be visually suppressed during morph")
                root.check(focusCard && focusCard.visible, "Old focusCard must stay visible underneath during morph")
                root.check(focusPres && focusPres.visible, "focusCard presentation must stay render-hot (visible) during morph")
                root.check(Math.abs(incomingCard.width - gpuCard.width) <= 1,
                    "Incoming card 0.00 width mismatch: " + (incomingCard ? incomingCard.width : 0) + " vs " + gpuCard.width)

                root.content.setFocusMorphState("memory", "gpu", 0.25)
                var inW25 = incomingCard.width
                root.check(inW25 > gpuCard.width && inW25 < focusSlot.width
                    && focusCard.x === root.initialFocusRect.x && focusCard.y === root.initialFocusRect.y,
                    "Stacked focus morph 0.25 geometry failed")

                root.content.setFocusMorphState("memory", "gpu", 0.50)
                root.check(incomingCard.width > inW25
                    && incomingCard.detailProgress > 0 && incomingCard.detailProgress < 1
                    && focusCard.x === root.initialFocusRect.x,
                    "Stacked focus morph 0.50 detail reveal failed")

                root.content.setFocusMorphState("memory", "gpu", 0.75)
                root.check(incomingCard.detailProgress > 0.7,
                    "Stacked focus morph 0.75 detail progression failed")

                root.content.setFocusMorphState("memory", "gpu", 1.00)
                var settledFocusCard = root.findByObjectName(root.content, "taskFocusCard")
                root.check(!root.content.transitionActive && !gpuCard.visualSuppressed && !memCard.visualSuppressed
                    && root.content.displayMetric === "gpu", "Stacked focus morph 1.00 settle failed")
                root.check(settledFocusCard.instanceId === incomingInstanceId,
                    "Incoming card instance must persist and become the front Focus Card at 1.00")

                // Reset back to memory and test live click on GPU compact card
                root.content.resetVisualState()
                input.mouseClick(gpuCard, gpuCard.width / 2, gpuCard.height / 2, Qt.LeftButton, Qt.NoModifier, 0)
            } else if (root.phase === 3) {
                var focusCard = root.findByObjectName(root.content, "taskFocusCard")
                if (root.content.focusMorphActive) return
                root.applySnapshot(root.normalSnapshot)
                root.check(root.content.focusedMetric === "gpu" && root.content.displayMetric === "gpu" && focusCard.displayMetric === "gpu",
                    "Click GPU compact card did not morph to gpu")
                root.check(focusCard.x === root.initialFocusRect.x && focusCard.y === root.initialFocusRect.y
                    && focusCard.width === root.initialFocusRect.width && focusCard.height === root.initialFocusRect.height,
                    "Focus Card geometry jumped on GPU selection")
                var vramLabel = root.findByObjectName(root.content, "focusGpuVram")
                var vramBar = root.findByObjectName(root.content, "focusGpuVramBar")
                var gpuTemp = root.findByObjectName(root.content, "focusGpuTemp")
                var gpuPower = root.findByObjectName(root.content, "focusGpuPower")
                root.check(vramLabel && vramLabel.text === "Shared", "Intel shared memory not rendered as Shared")
                root.check(vramBar && !vramBar.visible, "Fake VRAM progress bar visible on shared-memory Intel GPU")
                root.check(gpuTemp && gpuTemp.text === "—" && gpuPower && gpuPower.text === "—", "Missing GPU fields must render em-dash")
                root.assertNoInvalidStrings()

                // Check every remaining metric transition at mid-morph.
                for (var pair of [["gpu", "disk"], ["disk", "network"], ["network", "memory"], ["memory", "disk"], ["disk", "gpu"]]) {
                    root.content.setFocusMorphState(pair[0], pair[1], 0.50)
                    var inc = root.findByObjectName(root.content, "incomingMorphCard")
                    var currentFront = root.findByObjectName(root.content, "taskFocusCard")
                    var targetCard = root.findByObjectName(root.content, "taskMetricCard_" + pair[1])
                    root.check(inc && inc.metricId === pair[1]
                        && inc.width > targetCard.width
                        && currentFront && currentFront.x === root.initialFocusRect.x && currentFront.y === root.initialFocusRect.y,
                        "Path " + pair[0] + "->" + pair[1] + " mid-morph failed")
                    var incInstanceId = inc.instanceId
                    root.content.setFocusMorphState(pair[0], pair[1], 1.00)
                    var settled = root.findByObjectName(root.content, "taskFocusCard")
                    root.check(settled && settled.instanceId === incInstanceId && settled.displayMetric === pair[1],
                        "Path " + pair[0] + "->" + pair[1] + " instance persistence failed")
                }

                // Click Disk compact card from GPU
                var diskCard = root.findByObjectName(root.content, "taskMetricCard_disk")
                input.mouseClick(diskCard, diskCard.width / 2, diskCard.height / 2, Qt.LeftButton, Qt.NoModifier, 0)
            } else if (root.phase === 4) {
                var focusCard = root.findByObjectName(root.content, "taskFocusCard")
                if (root.content.focusMorphActive) return
                root.applySnapshot(root.normalSnapshot)
                root.check(root.content.focusedMetric === "disk" && root.content.displayMetric === "disk" && focusCard.displayMetric === "disk",
                    "Click Disk compact card did not morph to disk")
                root.check(focusCard.height === root.initialFocusRect.height, "Focus Card height changed on Disk selection")
                root.assertNoInvalidStrings()

                // Rapid changes must settle on the latest requested metric.
                var memCard = root.findByObjectName(root.content, "taskMetricCard_memory")
                var gpuCard = root.findByObjectName(root.content, "taskMetricCard_gpu")
                var netCard = root.findByObjectName(root.content, "taskMetricCard_network")
                input.mouseClick(memCard, memCard.width / 2, memCard.height / 2, Qt.LeftButton, Qt.NoModifier, 0)
                input.mouseClick(gpuCard, gpuCard.width / 2, gpuCard.height / 2, Qt.LeftButton, Qt.NoModifier, 0)
                input.mouseClick(netCard, netCard.width / 2, netCard.height / 2, Qt.LeftButton, Qt.NoModifier, 0)
            } else if (root.phase === 5) {
                var focusCard = root.findByObjectName(root.content, "taskFocusCard")
                if (root.content.focusMorphActive) return
                root.applySnapshot(root.normalSnapshot)
                root.check(root.content.focusedMetric === "network" && root.content.displayMetric === "network"
                    && focusCard.displayMetric === "network" && root.content.focusMorphProgress === 1,
                    "Rapid Memory -> GPU -> Network sequence did not settle on network")
                root.check(focusCard.height === root.initialFocusRect.height, "Focus Card height changed on Network selection")
                // Verify compact network card has no ComboBox inside it
                var netCard = root.findByObjectName(root.content, "taskMetricCard_network")
                root.check(!root.findByObjectName(netCard, "taskManagerNetworkCombo"), "ComboBox must not be inside compact Network card")
                root.assertNoInvalidStrings()

                // Click CPU card: must NOT change focusedMetric
                var cpuCard = root.findByObjectName(root.content, "taskCpuCard")
                input.mouseClick(cpuCard, cpuCard.width / 2, cpuCard.height / 2, Qt.LeftButton, Qt.NoModifier, 0)
                root.check(root.content.focusedMetric === "network", "CPU card click must not alter focusedMetric")

                // Check network dropdown toggle and animated close.
                var netCombo = root.findByObjectName(focusCard, "taskManagerNetworkCombo")
                root.check(netCombo && !netCombo.popup.visible && !netCombo.popupOpen, "Network dropdown should start closed")
                input.mouseClick(netCombo, netCombo.width / 2, netCombo.height / 2, Qt.LeftButton, Qt.NoModifier, 0)
                root.check(netCombo.popup.visible && netCombo.popupOpen, "First click on network dropdown must open popup")
                netCombo.setUnfurlProgress(0.5)
                root.check(netCombo.popup.height < netCombo.popup.implicitHeight, "Dropdown Sheet Unfurl mid-progress must clip height")
                netCombo.setUnfurlProgress(1.0)
                input.mouseClick(netCombo, netCombo.width / 2, netCombo.height / 2, Qt.LeftButton, Qt.NoModifier, 0)
                root.check(!netCombo.popupOpen && (netCombo.popupClosing || !netCombo.popup.visible),
                    "Second click on network dropdown must begin close transition")

                // Check sort dropdown toggle and animated close.
                var sortCombo = root.findByObjectName(root.content, "taskManagerSortCombo")
                root.check(sortCombo && !sortCombo.popup.visible && !sortCombo.popupOpen, "Sort dropdown should start closed")
                input.mouseClick(sortCombo, sortCombo.width / 2, sortCombo.height / 2, Qt.LeftButton, Qt.NoModifier, 0)
                root.check(sortCombo.popup.visible && sortCombo.popupOpen, "First click on sort dropdown must open popup")
                input.mouseClick(sortCombo, sortCombo.width / 2, sortCombo.height / 2, Qt.LeftButton, Qt.NoModifier, 0)
                root.check(!sortCombo.popupOpen && (sortCombo.popupClosing || !sortCombo.popup.visible),
                    "Second click on sort dropdown must begin close transition")

                // Click Memory compact card to return to memory
                var memCard = root.findByObjectName(root.content, "taskMetricCard_memory")
                input.mouseClick(memCard, memCard.width / 2, memCard.height / 2, Qt.LeftButton, Qt.NoModifier, 0)
            } else if (root.phase === 6) {
                var focusCard = root.findByObjectName(root.content, "taskFocusCard")
                var sortCombo = root.findByObjectName(root.content, "taskManagerSortCombo")
                if (root.content.focusMorphActive || (sortCombo && sortCombo.popup.visible)) return
                root.check(root.content.focusedMetric === "memory" && root.content.displayMetric === "memory" && focusCard.displayMetric === "memory",
                    "Click Memory compact card did not return to memory")
                root.check(!sortCombo.popup.visible && !sortCombo.popupClosing && sortCombo.unfurlProgress === 0,
                    "Sort dropdown close transition did not finish cleanly")

                // Check metric-card keyboard activation and table navigation.
                var gpuCard = root.findByObjectName(root.content, "taskMetricCard_gpu")
                gpuCard.forceActiveFocus()
                input.keyClick(Qt.Key_Space, Qt.NoModifier, 0)
                root.check(root.content.focusedMetric === "gpu", "Space on focused GPU card did not switch focus")

                var diskCard = root.findByObjectName(root.content, "taskMetricCard_disk")
                diskCard.forceActiveFocus()
                input.keyClick(Qt.Key_Return, Qt.NoModifier, 0)
                root.check(root.content.focusedMetric === "disk", "Enter on focused Disk card did not switch focus")

                // Check process selection from metric-card keyboard focus.
                root.content.selectedKey = ""
                input.keyClick(Qt.Key_Down, Qt.NoModifier, 0)
                var pill = root.findByObjectName(root.content, "taskProcessSelectionPill")
                root.check(!!root.content.selectedKey && pill, "Down arrow selects the shared process pill")

                // Verify Details Footer Fold and Kill Confirmation Morph in-place
                var procPane = root.findByObjectName(root.content, "taskProcessPane")
                var detailsDrawer = root.findByObjectName(procPane, "taskProcessDetailsDrawer")
                root.content.detailsOpen = true
                procPane.setDetailsFoldProgress(0.5)
                root.check(detailsDrawer && detailsDrawer.visible && detailsDrawer.foldedHeight > 0 && detailsDrawer.foldedHeight < detailsDrawer.targetHeight,
                    "Details Footer Fold mid-progress failed")
                root.content.detailsOpen = false
                procPane.setDetailsFoldProgress(0.0)

                root.content.killKey = root.content.selectedKey
                procPane.setConfirmationProgress(0.6)
                var killRail = root.findByObjectName(procPane, "taskProcessKillRail")
                root.check(killRail && killRail.visible && killRail.height > 0, "Kill Confirmation Morph rail failed")
                root.content.killKey = ""
                procPane.setConfirmationProgress(0.0)

                input.keyClick(Qt.Key_F, Qt.ControlModifier, 0)
                var searchField = root.findByObjectName(root.content, "taskManagerSearch")
                root.check(searchField.activeFocus, "Ctrl+F failed after metric card interaction")
                input.keyClick(Qt.Key_Escape, Qt.NoModifier, 0)
                root.check(!searchField.activeFocus && UiState.taskManagerOpen, "Escape from search closed panel")

                // Test GPU unavailable snapshot (gpus: [])
                var noGpuSnap = JSON.parse(JSON.stringify(root.normalSnapshot))
                noGpuSnap.seq = 11
                noGpuSnap.gpus = []
                noGpuSnap.memory.swapTotal = 0
                noGpuSnap.memory.swapUsed = 0
                root.applySnapshot(noGpuSnap)
                root.content.selectMetric("gpu")
            } else if (root.phase === 7) {
                var focusCard = root.findByObjectName(root.content, "taskFocusCard")
                if (root.content.focusMorphActive) return
                var noGpuSnap = JSON.parse(JSON.stringify(root.normalSnapshot))
                noGpuSnap.seq = 12
                noGpuSnap.gpus = []
                noGpuSnap.memory.swapTotal = 0
                noGpuSnap.memory.swapUsed = 0
                root.applySnapshot(noGpuSnap)
                var gpuHero = root.findByObjectName(root.content, "focusGpuHero")
                var vramBar = root.findByObjectName(root.content, "focusGpuVramBar")
                root.check(gpuHero && gpuHero.text === "Unsupported", "Empty GPU list should show Unsupported when ready")
                root.check(vramBar && !vramBar.visible, "VRAM bar must remain hidden when GPU is unavailable")
                root.assertNoInvalidStrings()

                // Reopening resets the focused metric to memory.
                UiState.closeTaskManager()
            } else if (root.phase === 8) {
                if (surface.active) return
                UiState.openTaskManager(root.output)
            } else if (root.phase === 9) {
                if (!root.overlay || !root.overlay.interactionReady) return
                root.applySnapshot(root.normalSnapshot)
                var focusCard = root.findByObjectName(root.content, "taskFocusCard")
                root.check(root.content.focusedMetric === "memory" && root.content.displayMetric === "memory"
                    && focusCard.displayMetric === "memory" && !root.content.focusMorphActive,
                    "Reopen did not reset focusedMetric/displayMetric to memory without morph lag")

                // Test Light Mode
                ShellSettingsStore.colorMode = "light"
            } else if (root.phase === 10) {
                root.applySnapshot(root.normalSnapshot)
                root.check(Theme.isLight === true, "Light mode did not activate")
                root.assertNoInvalidStrings()
                root.overlay.cardSize = Qt.size(900, 600)
            } else if (root.phase === 11) {
                root.applySnapshot(root.normalSnapshot)
                root.assertResponsiveLayout(900, 600)
                root.overlay.cardSize = Qt.size(800, 520)
            } else if (root.phase === 12) {
                root.applySnapshot(root.normalSnapshot)
                root.assertResponsiveLayout(800, 520)
                root.overlay.cardSize = Qt.size(720, 480)
            } else if (root.phase === 13) {
                root.applySnapshot(root.normalSnapshot)
                root.assertResponsiveLayout(720, 480)
                ShellSettingsStore.colorMode = "dark"
                root.check(Theme.isLight === false, "Dark mode did not restore")
                console.info("Glass Grid harness passed: focus card, reset, GPU unavailable, 310 processes, 6/7-digit PIDs, 4 responsive sizes, light/dark")
                Qt.quit()
                return
            }

            root.phase++
        }
    }
}
