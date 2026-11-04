import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import Quickshell.Io
import "services"
import "components"
import "components/base" as Base

ShellRoot {
    id: root
    // Exercise the dashboard, shared pins and same-output standalone handoff.
    property var surfaces: []
    property int phase: 0
    property int styleIndex: 0
    property int ticks: 0
    property int cycles: 0
    property var page: null
    property var host: null
    property var input: null
    property var miniIdentity: null
    property var windowIdentity: null
    property var pinFixtures: []
    property var fullPin: null
    property var exitPin: null
    property bool watchingExit: false
    property int exitMisses: 0
    property int collectorPid: 0
    property real memoryLevel: 0
    property bool afterProfiled: false
    // Inspect theme changes and hidden-page animation without changing telemetry.
    property int themePreviewStage: 0
    property int pinPreviewStage: 0
    property real inactiveWavePhase: NaN
    // Confirm that waves stop when only the pinned row is in view.
    property real pinnedWavePhase: NaN
    readonly property var output: surfaces.find(item => item.modelData.name === "HEADLESS-1")
    readonly property var second: surfaces.find(item => item.modelData.name === "HEADLESS-2")
    readonly property string source: styleIndex === 2 ? "dockbar" : styleIndex === 1 ? "taskbar" : "default"
    readonly property var standalone: {
        var owner = surfaces.find(item => item.modelData.name === UiState.taskManagerScreenName)
        return owner ? owner.utility.item : null
    }

    // Fail at the first violated behavior with its presentation and phase.
    function check(ok, message) {
        if (ok) return
        console.error("HakuMenu Mini failed: style=" + styleIndex + " phase=" + phase + " " + message)
        Qt.exit(1)
        throw new Error(message)
    }
    // Walk real controls and lazy-loaded content without production test hooks.
    function find(item, predicate) {
        if (!item) return null
        if (predicate(item)) return item
        if (item.active === true && item.item) {
            var loaded = find(item.item, predicate)
            if (loaded) return loaded
        }
        var children = item.contentItem ? item.contentItem.data : item.children || []
        if (!item.contentItem && item.data && typeof item.data !== "function" && typeof item.data.length === "number") children = item.data
        for (var child of children) {
            var result = find(child, predicate)
            if (result) return result
        }
        return null
    }
    function control(name) { return find(page.mini, item => item.objectName === name) }
    function key(code, modifiers) { input.keyClick(code, modifiers || Qt.NoModifier, 0) }
    function open(surface) {
        UiState.openHakuMenu(surface.modelData.name, "theme", source,
            {x: 40, y: surface.modelData.height - 60, width: 48, height: 48})
    }
    function locate(surface) {
        host = find(surface.menu, item => item.panelOpen === true && typeof item.bottomAttached === "boolean")
        page = find(host, item => typeof item.miniLoaded === "boolean")
        if (!page) return false
        if (input) input.destroy()
        input = inputFactory.createObject(page.Window.window.contentItem)
        return true
    }
    function geometry(surface) {
        var expected = host.taskSize
        var rect = page.parent
        check(Math.abs(rect.width - expected.width) < 1 && Math.abs(rect.height - expected.height) < 1, "settled mini envelope")
        check(Math.abs(rect.width - surface.modelData.width * 0.45) < 1
            && rect.height >= Math.min(surface.modelData.height * 0.45, expected.height) - 1,
            "Mini keeps its width and grows only enough for readable content")
        check(rect.width < surface.modelData.width && rect.height < surface.modelData.height, "geometry fits owning output")
    }
    function pinRows() {
        var rows = []
        find(page.mini, item => { if (item.objectName === "taskManagerMiniPinnedRow") rows.push(item.modelData.key); return false })
        return rows
    }
    // Preserve the original three-card first row and full-width pinned second row.
    function assertMiniRows() {
        var metrics = root.control("taskManagerMiniMetricsRow")
        var pane = root.control("taskManagerMiniPinsPane")
        var viewport = root.control("taskManagerMiniViewport")
        root.check(metrics && pane && viewport && pane.parent === metrics.parent,
            "metrics and pinned processes share the same grid")
        root.check(pane.y >= metrics.y + metrics.height
            && Math.abs(pane.width - metrics.width) < 0.5
            && Math.abs(pane.width - page.mini.content.width) < 0.5,
            "pins occupy the full second row below the metrics")
        var cards = ["Cpu", "Memory", "Gpu"].map(name => root.control("taskManagerMini" + name))
        root.check(cards.every(card => card.parent === metrics && Math.abs(card.y - cards[0].y) < 0.5)
            && cards[0].x < cards[1].x && cards[1].x < cards[2].x,
            "CPU Memory GPU remain together in the first row")
        root.check(viewport.contentHeight >= pane.y + pane.height - 0.5,
            "the whole pinned row is reachable by scrolling")
    }
    function handoff(surface) {
        control("taskManagerMiniOpenFull").clicked()
        check(UiState.activePanel === "" && UiState.taskManagerOpen && UiState.taskManagerScreenName === surface.modelData.name,
            "handoff closes menu and opens standalone on the same output")
        check(UiState.taskManagerRevealPosition === 2, "HakuMenu handoff records the top attachment")
    }
    // Sample the same renderer, two outputs and stress workload as the V1 baseline.
    function profile(stage) {
        var count = 0
        find(page.mini, item => { ++count; return false })
        console.info("Mini objects " + styleIndex + " " + stage + " " + count)
        sampler.command = ["python3", Quickshell.env("HAKUSPACE_MEMORY_SAMPLER"), "--pid", String(Quickshell.processId),
            "--software", "--warmup", "0", "--seconds", "0", "--output",
            Quickshell.env("HAKUSPACE_MINI_PROFILE") + "-" + styleIndex + "-" + stage + ".json"]
        sampler.running = true
    }

    Component { id: inputFactory; TestEvent {} }
    Process { id: capture }
    Process { id: victim; command: ["sleep", "60"] }
    // Assert grace behavior on real collector frames after a disposable process exits.
    Connections {
        target: TaskManagerService
        function onProcessTimestampChanged() {
            if (!root.watchingExit || !TaskManagerService.ready || TaskManagerService.warmingUp
                || TaskManagerService.processTimestamp < 0) return
            if (TaskManagerService.processes.some(row => row.key === root.exitPin.key)) return
            var misses = ++root.exitMisses
            Qt.callLater(function() {
                root.check(TaskManagerPins.isPinned(root.exitPin) === (misses < 3), "runtime prune threshold at miss " + misses)
                if (misses === 3) root.watchingExit = false
            })
        }
    }
    Process {
        id: sampler
        onExited: code => {
            root.check(code === 0, "resource sampler completes")
            if (root.phase === 8) stress.start()
        }
    }
    Process {
        command: ["python3", Quickshell.env("HAKUSPACE_TEST_KEYBOARD")]
        running: true
        stdinEnabled: true
    }
    Variants {
        model: Quickshell.screens
        Item {
            id: surface
            required property var modelData
            property alias menu: menu
            property alias utility: utility
            HakuMenuPanel { id: menu; modelData: surface.modelData }
            TaskManagerHost {
                id: utility
                modelData: surface.modelData
            }
            Component.onCompleted: root.surfaces.push(this)
        }
    }
    Timer {
        id: stress
        interval: 45
        repeat: true
        onTriggered: {
            var task = ++root.cycles % 2 === 1
            UiState.setHakuPanelTab(task ? "taskManager" : "hakumenu")
            root.check(TaskManagerService.subscribers === (task ? 2 : 1), "one mini lease per active visit")
            root.check(root.page.mini === root.miniIdentity && root.page.Window.window === root.windowIdentity, "switch retains content and window")
            root.check(TaskManagerService.collectorPid === root.collectorPid, "standalone and mini share a single collector")
            if (root.cycles === 40) { stop(); root.phase = 9 }
        }
    }
    Timer {
        interval: 700
        repeat: true
        running: true
        onTriggered: {
            root.check(++root.ticks < 115, "timeout")
            if (!root.output || !root.second) return
            if (root.phase === 0) {
                root.check(TaskManagerService.subscribers === 0, "idle collector baseline")
                root.afterProfiled = false
                root.themePreviewStage = 0
                root.pinPreviewStage = 0
                root.inactiveWavePhase = NaN
                root.fullPin = null
                ChromeLayout.topBarMode = root.styleIndex !== 1
                ChromeLayout.dockbarActive = root.styleIndex === 2
                victim.running = true
                root.open(root.output)
            } else if (root.phase === 1) {
                root.check(root.locate(root.output), "root exists")
                root.check(!root.page.mini && root.find(root.page, item => item.objectName === "hakumenu-searchInput").activeFocus, "default page has search and no Mini tree")
                root.key(Qt.Key_Left, Qt.AltModifier)
                root.key(Qt.Key_Right, Qt.AltModifier)
                root.check(UiState.hakuPanelTab === "taskManager" && UiState.hakuMenuMode === "theme", "Alt navigation preserves submode")
                root.miniIdentity = root.page.mini
                root.windowIdentity = root.page.Window.window
            } else if (root.phase === 2) {
                if (!TaskManagerService.ready) return
                root.exitPin = TaskManagerService.processes.find(row => row.pid === victim.processId)
                if (!root.exitPin) return
                root.geometry(root.output)
                root.assertMiniRows()
                root.check(TaskManagerService.subscribers === 1 && root.control("taskManagerMiniOpenFull").activeFocus, "Mini focuses the open-full action")
                root.check(!root.control("taskProcessPane") && !root.find(root.page.mini, item => typeof item.focusedMetric === "string"), "Mini instantiates neither process pane nor GlassGrid")
                for (var name of ["Cpu", "Memory", "Gpu"])
                    root.check(!!root.control("taskManagerMini" + name), "essential metric " + name)
                root.check(!root.control("taskManagerMiniNetwork") && !root.control("taskManagerMiniDisk"),
                    "Mini omits Network and Disk")
                var metric = root.control("taskManagerMiniCpu")
                var secondary = root.find(metric, item => item.objectName === "taskManagerMiniMetricDetail")
                var gauge = root.find(metric, item => item.objectName === "taskManagerMiniWaterGauge")
                var reading = root.find(metric, item => item.objectName === "taskManagerMiniMetricValue")
                root.check(reading.mapToItem(metric, 0, reading.height).y <= gauge.mapToItem(metric, 0, 0).y
                    && gauge.mapToItem(metric, 0, gauge.height).y <= secondary.mapToItem(metric, 0, 0).y
                    && reading.text === gauge.percentText && reading.font.pixelSize === Theme.fontSize + 6
                    && secondary.font.pixelSize === Theme.fontSize - 1,
                    "Mini uses a larger header value and readable detail around the water")
                root.check(secondary.mapToItem(metric, 0, 0).y - gauge.mapToItem(metric, 0, gauge.height).y >= Theme.spaceMd - 0.5,
                    "water and secondary text retain a comfortable twelve-pixel gap")
                root.check(!root.find(gauge, item => typeof item.text === "string" && item.text.length > 0),
                    "Mini water gauge contains no text")
                root.check(Math.abs(gauge.diameter - Math.min(metric.compact ? 110 : 144, metric.width - metric.contentPadding * 2)) < 0.01
                    && gauge.diameter <= metric.width - metric.contentPadding * 2
                    && Math.abs(gauge.width - gauge.diameter) < 0.01 && Math.abs(gauge.height - gauge.diameter) < 0.01,
                    "large water gauge renders at its diameter inside standard card padding")
                root.check(secondary.mapToItem(metric, 0, secondary.height).y <= metric.height
                    && Qt.colorEqual(root.find(metric, item => item.objectName === "taskManagerMiniMetricSurface").color, Qt.tint(Theme.surface, metric.hovered ? metric.visuals.hoverSurface : metric.visuals.cardSurface))
                    && root.find(metric, item => item.objectName === "taskManagerMiniMetricSurface").radius === Theme.radius,
                    "Mini uses standalone card styling with contained telemetry")
                for (var name of ["Cpu", "Memory", "Gpu"])
                    root.check(!!root.find(root.control("taskManagerMini" + name), item => item.objectName === "taskManagerMiniWaterGauge"
                        && item.interactive === false), "read-only water gauge for " + name)
                root.check(root.pinRows().length === 0 && root.control("taskManagerMiniEmptyPins").visible, "empty pin state")
                var saved = root.page.mini.snapshot
                root.page.mini.snapshot = {cpu: {}, memory: {}, gpus: [], network: {}, disks: {}}
                root.check(root.control("taskManagerMiniGpu").value === "Unavailable"
                    && root.control("taskManagerMiniCpu").value === "Unavailable"
                    && root.control("taskManagerMiniMemory").value === "Unavailable", "missing telemetry is never fake zero")
                root.check(root.find(root.control("taskManagerMiniGpu"), item => item.objectName === "taskManagerMiniMetricValue").text === "—",
                    "unavailable GPU keeps its outside reading empty instead of displaying zero")
                root.page.mini.snapshot = saved
                root.pinFixtures = TaskManagerService.processes.filter(row => row.pid !== victim.processId && row.pid !== TaskManagerService.collectorPid).slice(0, 6)
                root.check(root.pinFixtures.length === 6, "enough real process fixtures")
                TaskManagerPins.pin(root.pinFixtures[0])
                root.phase = 21
                return
            } else if (root.phase === 21) {
                if (capture.running) return
                var viewport = root.control("taskManagerMiniViewport")
                if (Math.abs(root.page.parent.height - root.host.taskSize.height) >= 1) return
                if (root.pinPreviewStage === 0) {
                    root.page.mini.content.pinnedProcesses = [Object.assign({}, root.pinFixtures[0], {name: "qs"})]
                    root.check(root.pinRows().length === 1, "one-pin presentation")
                    var row = root.control("taskManagerMiniPinnedRow")
                    root.check(row.height === Theme.comfortableControlHeight && row.radius === Theme.radius,
                        "one pin remains a deliberate fixed-height inset row")
                    capture.command = ["grim", "-o", root.output.modelData.name,
                        Quickshell.env("HAKUSPACE_MINI_ARTIFACT").replace(".png", "-" + root.styleIndex + "-one-pin.png")]
                    capture.running = true
                    root.pinPreviewStage = 1
                    return
                }
                if (root.pinPreviewStage === 1) {
                    root.page.mini.content.pinnedProcesses = Qt.binding(function() { return TaskManagerPins.pinnedProcesses })
                    for (var process of root.pinFixtures.slice(1, 4)) TaskManagerPins.pin(process)
                    root.pinPreviewStage = 2
                    return
                }
                if (root.pinPreviewStage === 2) {
                    root.check(root.pinRows().length === 4 && viewport.contentHeight <= viewport.height + 0.5,
                        "four readable pin rows fit with the metrics without scrolling")
                    capture.command = ["grim", "-o", root.output.modelData.name,
                        Quickshell.env("HAKUSPACE_MINI_ARTIFACT").replace(".png", "-" + root.styleIndex + "-four-pins.png")]
                    capture.running = true
                    root.pinPreviewStage = 3
                    return
                }
                for (var process of root.pinFixtures.slice(4)) TaskManagerPins.pin(process)
                root.phase = 3
                return
            } else if (root.phase === 3) {
                if (root.themePreviewStage === 0) {
                    ShellSettingsStore.colorMode = "light"
                    var metric = root.control("taskManagerMiniMemory")
                    root.check(Theme.isLight, "Mini uses the light palette")
                    root.themePreviewStage = 1
                    return
                }
                if (root.themePreviewStage === 1) {
                    var metric = root.control("taskManagerMiniMemory")
                    root.check(Qt.colorEqual(root.find(metric, item => item.objectName === "taskManagerMiniMetricSurface").color, Qt.tint(Theme.surface, metric.hovered ? metric.visuals.hoverSurface : metric.visuals.cardSurface)),
                        "Mini card reaches its light surface after the color transition")
                    capture.command = ["grim", "-o", root.output.modelData.name,
                        Quickshell.env("HAKUSPACE_MINI_ARTIFACT").replace(".png", "-" + root.styleIndex + "-light.png")]
                    capture.running = true
                    root.themePreviewStage = 2
                    return
                }
                if (root.themePreviewStage === 2) {
                    if (capture.running) return
                    ShellSettingsStore.colorMode = "dark"
                    root.themePreviewStage = 3
                    return
                }
                root.check(root.pinRows().join() === root.pinFixtures.slice(0, 4).map(row => row.key).join(), "only four pinned rows, in pin order")
                root.assertMiniRows()
                root.check(root.control("taskManagerMiniMorePins").text === "+2 pinned", "pin overflow count")
                if (root.themePreviewStage === 3) {
                    capture.command = ["grim", "-o", root.output.modelData.name, Quickshell.env("HAKUSPACE_MINI_ARTIFACT")]
                    capture.running = true
                    root.themePreviewStage = 4
                    return
                }
                if (root.themePreviewStage === 4) {
                    if (capture.running) return
                    var viewport = root.control("taskManagerMiniViewport")
                    viewport.contentY = Math.min(root.control("taskManagerMiniPinsPane").y,
                        Math.max(0, viewport.contentHeight - viewport.height))
                    var firstPin = root.find(root.page.mini, item => item.objectName === "taskManagerMiniPinnedRow"
                        && item.modelData.key === root.pinFixtures[0].key)
                    root.check(firstPin.mapToItem(viewport, 0, 0).y >= -0.5
                        && firstPin.mapToItem(viewport, 0, firstPin.height).y <= viewport.height + 0.5,
                        "the pinned second row becomes visible when scrolled into view")
                    var row = root.control("taskManagerMiniMetricsRow")
                    root.pinnedWavePhase = viewport.contentY >= row.y + row.height ? root.page.mini.content.waterWavePhase : NaN
                    root.themePreviewStage = 5
                    return
                }
                if (root.themePreviewStage === 5) {
                    if (Number.isFinite(root.pinnedWavePhase)) root.check(root.page.mini.content.waterWavePhase === root.pinnedWavePhase,
                        "offscreen first-row gauges stop their decorative waves")
                    capture.command = ["grim", "-o", root.output.modelData.name,
                        Quickshell.env("HAKUSPACE_MINI_ARTIFACT").replace(".png", "-pins.png")]
                    capture.running = true
                    root.themePreviewStage = 6
                    return
                }
                if (capture.running) return
                TaskManagerPins.pin(root.exitPin)
                var model = TaskManagerService.processes
                var timestamp = TaskManagerService.processTimestamp
                TaskManagerService.processes = model.filter(row => row.key !== root.exitPin.key)
                TaskManagerService.processTimestamp = timestamp + 0.1
                root.check(TaskManagerPins.isPinned(root.exitPin), "one temporary model miss keeps the pin")
                TaskManagerService.processes = model
                TaskManagerService.processTimestamp = timestamp + 0.2
                root.check(!TaskManagerPins.missingFramesByKey[root.exitPin.key], "reappearance resets runtime grace counter")
                root.exitMisses = 0
                root.watchingExit = true
                victim.running = false
            } else if (root.phase === 4) {
                if (root.watchingExit || TaskManagerPins.isPinned(root.exitPin)) return
                root.check(!TaskManagerPins.pinnedProcesses.some(row => row.key === root.exitPin.key), "exited process is pruned while Mini is open")
                var viewport = root.control("taskManagerMiniViewport")
                viewport.contentY = Math.max(0, viewport.contentHeight - viewport.height)
                var lastPin = root.find(root.page.mini, item => item.objectName === "taskManagerMiniPinnedRow"
                    && item.modelData.key === root.pinFixtures[3].key)
                root.check(lastPin.mapToItem(viewport, 0, 0).y >= -0.5
                    && lastPin.mapToItem(viewport, 0, lastPin.height).y <= viewport.height + 0.5,
                    "the last pinned process remains reachable in the second row")
                viewport.contentY = 0
                for (var process of root.pinFixtures) TaskManagerPins.unpin(process)
                root.memoryLevel = root.page.mini.snapshot.memory.percent
                root.key(Qt.Key_Left, Qt.AltModifier)
            } else if (root.phase === 5) {
                root.check(TaskManagerService.subscribers === 0 && !TaskManagerService.collectorRunning, "inactive Mini stops collector")
                root.check(root.page.mini.snapshot.memory.percent === root.memoryLevel && UiState.hakuMenuMode === "theme", "return keeps last telemetry and Theme mode")
                if (!Number.isFinite(root.inactiveWavePhase)) {
                    root.inactiveWavePhase = root.page.mini.content.waterWavePhase
                    return
                }
                root.check(!root.page.mini.content.visible && root.page.mini.content.waterWavePhase === root.inactiveWavePhase,
                    "hidden Mini stops its shared water-wave clock")
                root.key(Qt.Key_Right, Qt.AltModifier)
            } else if (root.phase === 6) {
                if (!TaskManagerService.ready) return
                UiState.openTaskManager(root.output.modelData.name)
            } else if (root.phase === 7) {
                if (!root.standalone || !root.standalone.interactionReady) return
                root.check(TaskManagerService.subscribers === 2, "standalone and Mini coexist")
                root.check(root.standalone.revealPosition === 8, "direct standalone entry attaches to the left")
                root.collectorPid = TaskManagerService.collectorPid
                UiState.claimInteraction("hakumenu", root.output.modelData.name)
                root.page.forcePrimaryFocus()
                root.cycles = 0
                root.phase = 8
                root.profile("before")
                return
            } else if (root.phase === 8) return
            else if (root.phase === 9) {
                if (!root.afterProfiled) { root.afterProfiled = true; root.profile("after"); return }
                if (sampler.running) return
                root.check(TaskManagerService.subscribers === 1, "stress restores Mini baseline")
                UiState.setHakuMenuMode("drun")
                UiState.setHakuPanelTab("taskManager")
                UiState.setHakuPanelTab("hakumenu")
                root.check(UiState.hakuMenuMode === "drun", "Drun survives root switching")
                UiState.closeTaskManager()
                UiState.setHakuPanelTab("taskManager")
            } else if (root.phase === 10) {
                root.check(TaskManagerService.subscribers === 1, "standalone releases only its own lease")
                root.key(Qt.Key_Return)
                root.check(UiState.taskManagerOpen && UiState.activePanel === "", "Enter activates open-full handoff")
            } else if (root.phase === 11) {
                if (!root.standalone || !root.standalone.interactionReady || !TaskManagerService.ready) return
                root.check(root.output.menu.loadedCount === 0 && UiState.ownsInteraction("taskManager", root.output.modelData.name), "handoff leaves no orphan menu and gives standalone focus")
                root.check(root.standalone.revealPosition === 2, "HakuMenu opens standalone from the top")
                var bounds = root.standalone.placementBounds
                var card = root.standalone.mask.item
                // Compact outputs share the remaining vertical space instead of clipping the card.
                var topGap = Math.min(Theme.panelPadding, (bounds.height - card.height) / 2)
                var expectedTop = Math.max(0, Math.min(root.standalone.height - card.height, bounds.y + topGap))
                root.check(Math.abs(card.y - expectedTop) < 0.5
                    && card.y >= 0 && card.y + card.height <= root.standalone.height
                    && Math.abs(card.x + card.width / 2 - bounds.x - bounds.width / 2) < 0.5,
                    "HakuMenu entry places the default card at the top, horizontally centered")
                root.fullPin = TaskManagerService.processes[0]
                root.standalone.content.selectedKey = root.fullPin.key
                root.find(root.standalone.content, item => item.text === "Pin" && typeof item.clicked === "function").clicked()
                root.check(TaskManagerPins.isPinned(root.fullPin), "standalone pin action updates shared model")
                UiState.closeTaskManager()
                root.input = null
                root.open(root.output)
                UiState.setHakuPanelTab("taskManager")
            } else if (root.phase === 12) {
                if (!TaskManagerService.ready) return
                root.check(root.locate(root.output), "Mini opens after standalone closes")
                root.check(root.pinRows().includes(root.fullPin.key), "standalone pin propagates to Mini")
                root.handoff(root.output)
            } else if (root.phase === 13) {
                if (!root.standalone || !root.standalone.interactionReady) return
                root.check(root.output.menu.loadedCount === 0, "second handoff releases menu")
                root.standalone.content.selectedKey = root.fullPin.key
                var cell = root.find(root.standalone.content, item => item.objectName === "taskManagerPid" && item.text === String(root.fullPin.pid))
                root.check(!!cell, "pinned process row remains visible")
                var rowInput = inputFactory.createObject(root.standalone.content.Window.window.contentItem)
                rowInput.mouseClick(cell, cell.width / 2, cell.height / 2, Qt.RightButton, Qt.NoModifier, 0)
                rowInput.destroy()
                root.check(!TaskManagerPins.isPinned(root.fullPin), "process row right-click unpins through shared model")
                UiState.closeTaskManager()
                root.input = null
                root.open(root.output)
                UiState.setHakuPanelTab("taskManager")
            } else if (root.phase === 14) {
                if (!TaskManagerService.ready) return
                root.check(root.locate(root.output) && !root.pinRows().includes(root.fullPin.key), "unpin propagates to Mini")
                root.key(Qt.Key_Escape)
                root.check(UiState.activePanel === "", "Mini Escape directly closes HakuMenu")
            } else if (root.phase === 15) {
                root.check(TaskManagerService.subscribers === 0 && root.output.menu.loadedCount === 0, "close releases Mini")
                root.input = null
                root.open(root.output)
                UiState.setHakuPanelTab("taskManager")
            } else if (root.phase === 16) {
                root.check(root.locate(root.output), "Mini reopens before transfer")
                UiState.hakuMenuScreenName = root.second.modelData.name
                UiState.claimInteraction("hakumenu", root.second.modelData.name)
            } else if (root.phase === 17) {
                root.input = null
                root.check(root.locate(root.second), "second output owns Mini")
                root.geometry(root.second)
                root.check(TaskManagerService.subscribers === 1 && root.output.menu.loadedCount === 0, "transfer leaves one Mini lease")
                root.handoff(root.second)
            } else if (root.phase === 18) {
                if (!root.standalone || !root.standalone.interactionReady) return
                root.check(root.second.menu.loadedCount === 0 && UiState.ownsInteraction("taskManager", root.second.modelData.name), "handoff follows second output and focus")
                UiState.closeTaskManager()
                root.input = null
            } else if (root.phase === 19) {
                root.check(TaskManagerService.subscribers === 0 && !TaskManagerService.collectorRunning, "all presentations release collector")
                root.page = null
                root.host = null
                if (++root.styleIndex === 3) {
                    console.info("HakuMenu Mini passed: dashboard, pins, handoff, three presentations, outputs, 40 switches")
                    Qt.quit()
                    return
                }
                root.phase = 0
                return
            }
            ++root.phase
        }
    }
}
