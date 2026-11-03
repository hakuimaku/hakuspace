import QtQuick
import QtQuick.Window
import Quickshell
import Quickshell.Io
import "services"
import "components"
import "components/taskmanager/glassgrid" as Glass

ShellRoot {
    id: root
    // Verify material parameters with native pointer input and frozen presentation samples.
    readonly property var output: Quickshell.screens.find(item => item.name === "HEADLESS-1")
    readonly property bool reduced: Quickshell.env("HAKUSPACE_REDUCED_MOTION") === "1"
    property int phase: 0
    property int ticks: 0
    property real readyAt: 0
    property var page: null
    property var dashboard: null
    property var metric: null
    property var gauge: null
    property string probeImage: ""
    property int paints: 0
    property int metricIndex: 0
    property var pinRows: []
    property var pill: null
    property int rapidMode: 0
    property int rapidStep: 0
    property real rapidAt: 0
    property bool sawPillMorph: false
    property int gapStep: 0
    property real gapStartY: 0
    property real hoverAt: 0
    property real collapsedHeight: 0
    property real cardTop: 0
    property var expandedHeights: []
    property int overlayStep: 0
    property real panelHeight: 0
    property real pinsTop: 0

    // Sample motion after crossing an actual inter-row gap rather than teleporting row-to-row.
    Timer {
        id: gapProbe
        interval: 70
        onTriggered: {
            root.check(root.pill.targetItem === root.pinRows[3], "gap crossing targets the next row")
            root.check(root.reduced ? Math.abs(root.pill.y - root.pill.targetY) < 0.5
                : Math.abs(root.pill.y - root.pill.targetY) > 1 && Math.abs(root.pill.y - root.gapStartY) > 1,
                "normal hover morphs after a gap; reduced motion snaps")
        }
    }

    function check(ok, message) {
        if (ok) return
        console.error("Mini material phase=" + phase + " reduced=" + reduced + ": " + message)
        Qt.exit(1)
        throw new Error(message)
    }
    function walk(item, predicate) {
        if (!item) return null
        if (predicate(item)) return item
        if (item.active && item.item) { var found = walk(item.item, predicate); if (found) return found }
        var children = item.contentItem ? item.contentItem.data : item.children || []
        if (!item.contentItem && item.data && typeof item.data !== "function" && typeof item.data.length === "number") children = item.data
        for (var child of children) { var found = walk(child, predicate); if (found) return found }
        return null
    }
    function find(item, name) { return walk(item, item => item.objectName === name) }
    function moveTo(item, x, y, buttons) {
        var point = item.mapToItem(page.Window.window.contentItem, item.width * x, item.height * y)
        pointer.write(Math.round(point.x) + " " + Math.round(point.y) + " " + output.width + " " + output.height + " " + (buttons || 0) + "\n")
    }
    function leave() { moveTo(find(dashboard, "taskManagerMiniOpenFull"), 0.5, 0.5) }
    function scrollTo(item) {
        var point = item.mapToItem(page.Window.window.contentItem, item.width / 2, item.height / 2)
        pointer.write("scroll " + Math.round(point.x) + " " + Math.round(point.y) + " " + output.width + " " + output.height + " 1\n")
    }
    function canvas(item) { return item.children.find(child => typeof child.toDataURL === "function") }
    function photo(kind) {
        capture.command = ["grim", "-o", output.name, Quickshell.env("HAKUSPACE_MINI_ARTIFACT").replace(".png", "-material-" + kind + ".png")]
        capture.running = true
    }
    function rows() {
        var result = []
        walk(dashboard, item => { if (item.objectName === "taskManagerMiniPinnedRow") result.push(item); return false })
        return result
    }
    HakuMenuPanel { id: menu; modelData: root.output }
    Process {
        id: pointer
        command: ["python3", "-u", Quickshell.env("HAKUSPACE_TEST_KEYBOARD").replace("wayland_keyboard.py", "wayland_pointer.py")]
        environment: ({HAKUSPACE_TEST_POINTER_OUTPUT: "HEADLESS-1"})
        stdinEnabled: true
        running: true
    }
    Process { id: capture }
    Connections {
        target: root.gauge ? root.canvas(root.gauge) : null
        function onPaint(region) { ++root.paints }
    }
    PanelWindow {
        screen: root.output
        anchors { top: true; left: true }
        implicitWidth: 120; implicitHeight: 120
        color: Theme.surface
        exclusionMode: ExclusionMode.Ignore
        mask: Region {}
        Glass.TaskWaterGauge { id: probe; x: 16; y: 16; metricId: "memory"; value: 42; reducedMotion: true; wavePhase: 0.7 }
    }
    Timer {
        id: rapid
        interval: 45; repeat: true
        onTriggered: {
            if (root.rapidMode === 1 && root.pill && root.pill.shown
                && Math.abs(root.pill.y - root.pill.targetY) > 0.05) root.sawPillMorph = true
            if (root.rapidMode === 0) {
                if (root.rapidStep < 3) root.moveTo(root.find(root.dashboard,
                    "taskManagerMini" + ["Cpu", "Memory", "Gpu"][root.rapidStep]), 0.75, 0.5)
                else root.leave()
            } else {
                if (root.rapidStep < 4) root.moveTo(root.pinRows[[1, 0, 3, 1][root.rapidStep]], 0.5, 0.5)
                else root.leave()
            }
            if (++root.rapidStep > (root.rapidMode === 0 ? 3 : 4)) {
                stop()
                root.rapidAt = Date.now()
            }
        }
    }
    Timer {
        interval: 250; repeat: true; running: true
        onTriggered: {
            root.check(++root.ticks < 200, "timeout")
            if (root.phase === 0) {
                UiState.openHakuMenu(root.output.name, "theme", "default")
                UiState.setHakuPanelTab("taskManager")
            } else if (root.phase === 1) {
                root.page = root.walk(menu, item => typeof item.miniLoaded === "boolean")
                if (root.page) root.page.keyboardActivity()
                if (!root.page || !root.page.mini || !TaskManagerService.ready) return
                root.dashboard = root.page.mini.content
                var openButton = root.find(root.dashboard, "taskManagerMiniOpenFull")
                root.check(openButton.horizontalPadding === (openButton.compact ? 16 : 18)
                    && Qt.colorEqual(openButton.color, Theme.accent)
                    && Qt.colorEqual(openButton.foregroundColor, Theme.onAccentColor),
                    "open action uses eight extra pixels per side and contrasting accent fill")
                root.dashboard.snapshot = {
                    cpu: {usage: 42, temperatureC: 43, frequencyHighestMHz: 3800, frequencyAverageMHz: 2400,
                        frequencyLowestMHz: 800, load: [1.2, 0.8, 0.5], cores: [62.5, 12, 0, 100]},
                    memory: {percent: 50, used: 8e9, total: 16e9, availableBytes: 8e9, cache: 2e9, buffers: 1e8,
                        swapUsed: 0, swapTotal: 4e9},
                    gpus: [{usage: 29, temperatureC: 48, name: "Fixture GPU", clockMHz: 1150, powerW: 12,
                        memoryUsed: 2e9, memoryTotal: 8e9}]}
                root.dashboard.pinnedProcesses = [{key: "1:1", name: "qs", cpuTotalPercent: 3.7, rss: 443547648}]
                root.readyAt = Date.now()
                root.leave()
            } else if (root.phase === 2) {
                if (Date.now() - root.readyAt < 1000) return
                root.metric = root.find(root.dashboard, "taskManagerMini" + ["Cpu", "Memory", "Gpu"][root.metricIndex])
                root.gauge = root.find(root.metric, "taskManagerMiniWaterGauge")
                root.collapsedHeight = root.metric.height
                root.cardTop = root.metric.mapToItem(root.page.Window.window.contentItem, 0, 0).y
                root.panelHeight = root.page.parent.height
                root.pinsTop = root.find(root.dashboard, "taskManagerMiniPinsPane").y
                root.overlayStep = 0
                root.probeImage = root.canvas(probe).toDataURL()
                root.moveTo(root.metric, 0.1, 0.55)
                root.hoverAt = Date.now()
            } else if (root.phase === 3) {
                if (Date.now() - root.hoverAt < HAnimation.slow + 100) return
                var surface = root.find(root.metric, "taskManagerMiniMetricSurface")
                root.check(Math.abs(surface.scale - (root.reduced ? 1 : 1.05)) < 0.001
                    && surface.height > root.collapsedHeight + 30 && root.metric.detailProgress === 1,
                    "hover scales and expands the visual surface: metric=" + root.metric.label + "; hovered=" + root.metric.hovered
                        + "; scale=" + surface.scale + "; height=" + surface.height + "; base=" + root.collapsedHeight
                        + "; progress=" + root.metric.detailProgress + "; limit=" + root.metric.maximumOverlayHeight)
                root.check(root.metric.height === root.collapsedHeight && root.page.parent.height === root.panelHeight
                    && root.find(root.dashboard, "taskManagerMiniPinsPane").y === root.pinsTop,
                    "expansion overlays pins without reserving space or resizing the panel")
                root.check(root.metric.detailRows.length === [7, 7, 6][root.metricIndex]
                    && root.find(root.metric, "taskManagerMiniDetailLoader").active,
                    "all supported summary values are loaded on demand")
                root.check(Math.abs(root.metric.mapToItem(root.page.Window.window.contentItem, 0, 0).y - root.cardTop) < 0.5,
                    "card expands downwards from its existing top edge")
                var other = root.find(root.dashboard, "taskManagerMini" + ["Memory", "Gpu", "Cpu"][root.metricIndex])
                root.check(Math.abs(other.height - root.collapsedHeight) < 0.5,
                    "neighboring cards retain their collapsed height")
                root.expandedHeights.push(Math.round(root.metric.detailHeight))
                root.check(Math.abs(root.find(root.dashboard, "taskManagerMiniOpenFull").scale - 1) < 0.001,
                    "open action returns to normal size after pointer leaves")
                root.check(root.metric.hovered && root.gauge.emphasized, "metric receives pointer hover")
                root.check(root.reduced ? root.gauge.hoverStrength === 0 && root.gauge.hoverBiasX === 0
                    : root.gauge.hoverStrength > 0.95 && root.gauge.hoverBiasX < -0.6, "left liquid attraction or reduced snap")
                root.check(root.gauge.fillRatio === [0.42, 0.5, 0.29][root.metricIndex]
                    && root.gauge.percentText === ["42%", "50%", "29%"][root.metricIndex], "pointer cannot change telemetry")
                var ink = root.find(root.metric, "taskManagerMiniInk")
                root.check(ink.visible === !root.reduced && (root.reduced || ink.amount > 0.95), "ink follows normal motion only")
                root.check(Math.abs(root.find(root.dashboard, "taskManagerMini" + ["Memory", "Gpu", "Cpu"][root.metricIndex]).opacity - 0.92) < 0.01
                    && root.metric.opacity === 1, "cross-card emphasis remains restrained")
                root.photo("left-" + root.metricIndex)
            } else if (root.phase === 4) {
                if (capture.running) return
                var expandedSurface = root.find(root.metric, "taskManagerMiniMetricSurface")
                if (root.overlayStep === 0) {
                    root.moveTo(expandedSurface, 0.9, 0.95)
                    root.overlayStep = 1
                    return
                }
                root.check(root.metric.hovered && root.metric.detailProgress === 1 && !root.dashboard.hoveredPinRow,
                    "expanded content keeps hover and blocks rows underneath")
                if (root.overlayStep === 1) {
                    root.moveTo(expandedSurface, 0.9, 0.95, 272)
                    root.moveTo(expandedSurface, 0.9, 0.95, 0)
                    root.overlayStep = 2
                    return
                }
                root.check(root.dashboard.pendingUnpinKey === "", "clicking the overlay cannot arm unpin underneath")
                var expandedView = root.find(root.metric, "taskManagerMiniMetricExpanded")
                if (expandedView.contentHeight > expandedView.height) {
                    root.check(expandedView.interactive, "details that reach the panel edge can scroll")
                    if (root.overlayStep === 2) {
                        root.scrollTo(expandedView)
                        root.overlayStep = 3
                        return
                    }
                    root.check(expandedView.contentY > 0, "native wheel input scrolls the expanded details")
                    expandedView.contentY = expandedView.contentHeight - expandedView.height
                }
                root.moveTo(root.metric, 0.9, 0.55)
            } else if (root.phase === 5) {
                root.check(root.reduced ? root.gauge.hoverStrength === 0 && root.gauge.hoverBiasX === 0 : root.gauge.hoverBiasX > 0.6,
                    "right liquid attraction or reduced snap")
                root.check(root.canvas(probe).toDataURL() === root.probeImage && probe.hoverStrength === 0 && probe.hoverBiasX === 0,
                    "full/default gauge stays pixel-identical")
                root.check(root.gauge.fillRatio === [0.42, 0.5, 0.29][root.metricIndex] && root.gauge.wavePhase === root.dashboard.waterWavePhase,
                    "fill and the shared wave clock remain independent")
                root.photo("right-" + root.metricIndex)
            } else if (root.phase === 6) {
                if (capture.running) return
                root.leave()
                root.hoverAt = Date.now()
            } else if (root.phase === 7) {
                if (Date.now() - root.hoverAt < HAnimation.slow + 100) return
                root.check(root.metric.detailProgress === 0
                    && !root.find(root.metric, "taskManagerMiniDetailLoader").active
                    && Math.abs(root.metric.height - root.collapsedHeight) < 0.5,
                    "leaving collapses the card and releases expanded content: progress=" + root.metric.detailProgress
                        + "; hovered=" + root.metric.hovered + "; loader=" + root.find(root.metric, "taskManagerMiniDetailLoader").active
                        + "; height=" + root.metric.height + "; collapsed=" + root.collapsedHeight)
                root.check(Math.abs(root.find(root.dashboard, "taskManagerMiniOpenFull").scale - (root.reduced ? 1 : 1.1)) < 0.001,
                    "open action grows on hover unless reduced motion is enabled")
                root.check(Qt.colorEqual(root.find(root.dashboard, "taskManagerMiniOpenFull").color, Theme.accent),
                    "open action retains its accent fill while hovered")
                root.check(!root.metric.hovered && root.gauge.hoverStrength === 0 && root.gauge.hoverBiasX === 0,
                    "liquid settles to neutral after leave")
                if (++root.metricIndex < 3) { root.phase = 2; return }
                root.check(new Set(root.expandedHeights).size === 3, "each card has its own natural detail height")
                root.rapidMode = 0
                root.rapidStep = 0
                rapid.start()
            } else if (root.phase === 8) {
                if (rapid.running || Date.now() - root.rapidAt < HAnimation.slow + 100) return
                for (var name of ["Cpu", "Memory", "Gpu"]) {
                    var card = root.find(root.dashboard, "taskManagerMini" + name)
                    root.check(!card.hovered && card.hoverStrength === 0 && card.hoverBiasX === 0 && card.opacity === 1,
                        "rapid metric hover settles without queued motion")
                }
                root.dashboard.pinnedProcesses = [1, 2, 3, 4].map(i => ({key: i + ":1", name: i === 1 ? "qs" : "worker-" + i,
                    cpuTotalPercent: 3.7, rss: 443547648}))
                root.readyAt = Date.now()
            } else if (root.phase === 9) {
                if (Date.now() - root.readyAt < 1000) return
                root.pinRows = root.rows()
                root.check(root.pinRows.length === 4, "four pin objects fit the same layout")
                var viewport = root.find(root.dashboard, "taskManagerMiniViewport")
                root.check(viewport.contentHeight <= viewport.height + 0.5, "four pin rows fit without scrolling")
                root.moveTo(root.pinRows[0], 0.5, 0.5)
            } else if (root.phase === 10) {
                root.pill = root.find(root.dashboard, "taskManagerMiniPinHoverPill")
                root.check(root.pill.targetItem === root.pinRows[0] && root.pill.shown && root.pill.radius === Theme.radius,
                    "one shared pill targets the hovered identity")
                root.check(Qt.colorEqual(root.pill.color, root.metric.visuals.miniRowHoverSurface), "hover pill is neutral")
                var group = root.find(root.pinRows[0], "taskManagerMiniPinNameGroup")
                root.check(group.transform[0].x === (root.reduced ? 0 : 3)
                    && group.children[0].rotation === (root.reduced ? 0 : -6), "name-only nudge and tiny icon motion")
                root.check(root.pill.duration === (root.reduced ? 0 : HAnimation.taskBarFillDuration), "pill uses shared motion tokens or snaps")
                root.photo("pins")
            } else if (root.phase === 11) {
                if (capture.running) return
                if (root.gapStep === 0) {
                    root.gapStartY = root.pill.y
                    root.moveTo(root.pinRows[0], 0.5, 1.05)
                    root.gapStep = 1
                    return
                }
                if (root.gapStep === 1) {
                    root.check(!root.dashboard.hoveredPinRow && root.pill.opacity === 0,
                        "the gap has no active row or visible hover")
                    root.check(root.reduced || root.pill.absoluteInitialized,
                        "leaving a row retains the pill geometry for the next morph")
                    root.moveTo(root.pinRows[3], 0.5, 0.5)
                    gapProbe.start()
                    root.gapStep = 2
                    return
                }
                if (gapProbe.running) return
                root.rapidMode = 1
                root.rapidStep = 0
                rapid.start()
            } else if (root.phase === 12) {
                if (rapid.running || Date.now() - root.rapidAt < 400) return
                root.check(!root.dashboard.hoveredPinRow && root.pill.opacity === 0, "rapid row hover leaves no stale pill")
                root.check(root.reduced || root.sawPillMorph, "shared pill morphs instead of teleporting between rows")
                var count = 0
                root.walk(root.dashboard, item => { if (item.objectName === "taskManagerMiniPinHoverPill") ++count; return false })
                root.check(count === 1, "rapid retargeting never duplicates the pill")
                root.moveTo(root.pinRows[1], 0.5, 0.5)
            } else if (root.phase === 13) {
                root.check(root.pill.targetItem === root.pinRows[1], "pill can re-enter after rapid leave")
                root.page.keyboardActivity()
                UiState.setHakuPanelTab("hakumenu")
            } else if (root.phase === 14) {
                root.check(!root.dashboard.hoveredPinRow && root.pill.opacity === 0, "tab switch releases hover")
                root.moveTo(root.page, 0.5, 0.05)
                UiState.setHakuPanelTab("taskManager")
                root.readyAt = Date.now()
            } else if (root.phase === 15) {
                if (Date.now() - root.readyAt < 1000) return
                root.check(!root.dashboard.hoveredMetric && !root.dashboard.hoveredPinRow, "returning has no stale material state")
                root.moveTo(root.pinRows[0], 0.5, 0.5)
            } else if (root.phase === 16) {
                root.check(root.pill.targetItem === root.pinRows[0], "row is hovered before close")
                console.info("Material canvas paints " + root.paints)
                UiState.closeHakuMenu()
            } else if (root.phase === 17) {
                if (menu.loadedCount || TaskManagerService.subscribers) return
                UiState.openHakuMenu(root.output.name, "theme", "default")
                UiState.setHakuPanelTab("taskManager")
            } else if (root.phase === 18) {
                root.page = root.walk(menu, item => typeof item.miniLoaded === "boolean")
                if (root.page) root.page.keyboardActivity()
                if (!root.page || !root.page.mini || !TaskManagerService.ready) return
                root.dashboard = root.page.mini.content
                root.check(!root.dashboard.hoveredPinRow && !root.dashboard.hoveredMetric, "reopen has no retained hover")
                UiState.closeHakuMenu()
            } else if (root.phase === 19) {
                if (menu.loadedCount || TaskManagerService.subscribers) return
                console.info("HakuMenu Mini passed: material hover, rapid retarget, four pins and reopen")
                Qt.quit()
                return
            }
            ++root.phase
        }
    }
}
