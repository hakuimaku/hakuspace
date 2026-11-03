import QtQuick
import QtQuick.Window
import Quickshell
import Quickshell.Io
import "services"
import "components"
import "components/taskmanager/glassgrid" as Glass

ShellRoot {
    id: root
    // Drive native pointer hover against the real attached Mini without changing backend data.
    readonly property var output: Quickshell.screens.find(item => item.name === "HEADLESS-1")
    readonly property bool reduced: Quickshell.env("HAKUSPACE_REDUCED_MOTION") === "1"
    property int phase: 0
    property int ticks: 0
    property int metricIndex: 0
    property bool light: false
    property var page: null
    property var dashboard: null
    property var metric: null
    property var gauge: null
    property string probeImage: ""
    property string gaugeImage: ""
    property real rowStart: 0
    property real readyAt: 0
    property var hoveredPinIdentity: null
    property int pinRefreshes: 0
    property real pinCpuStart: 0
    property rect windowRect: Qt.rect(0, 0, 0, 0)

    function check(ok, message) {
        if (ok) return
        console.error("Mini hover phase=" + phase + " reduced=" + reduced + " light=" + light + ": " + message)
        Qt.exit(1)
        throw new Error(message)
    }
    function walk(item, predicate) {
        if (!item) return null
        if (predicate(item)) return item
        if (item.active === true && item.item) { var found = walk(item.item, predicate); if (found) return found }
        var children = item.contentItem ? item.contentItem.data : item.children || []
        if (!item.contentItem && item.data && typeof item.data !== "function" && typeof item.data.length === "number") children = item.data
        for (var child of children) { var found = walk(child, predicate); if (found) return found }
        return null
    }
    function find(item, name) { return walk(item, item => item.objectName === name) }
    function locate(item) { return walk(item, item => typeof item.miniLoaded === "boolean") }
    function moveTo(item) {
        var point = item.mapToItem(page.Window.window.contentItem, item.width / 2, item.height / 2)
        pointer.write(Math.round(point.x) + " " + Math.round(point.y) + " " + output.width + " " + output.height + " 0\n")
    }
    function leave() { moveTo(find(dashboard, "taskManagerMiniOpenFull")) }
    function canvas(item) { return item.children.find(child => typeof child.toDataURL === "function") }
    function photo(kind) {
        capture.command = ["grim", "-o", output.name, Quickshell.env("HAKUSPACE_MINI_ARTIFACT").replace(".png",
            "-hover-" + (light ? "light-" : "dark-") + kind + ".png")]
        capture.running = true
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
    // A fixed default gauge checks the shared primitive without Mini emphasis.
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
        interval: 250; repeat: true; running: true
        onTriggered: {
            root.check(++root.ticks < 160, "timeout")
            if (root.phase === 0) {
                UiState.openHakuMenu(root.output.name, "theme", "default")
                UiState.setHakuPanelTab("taskManager")
            } else if (root.phase === 1) {
                root.page = root.locate(menu)
                if (root.page) root.page.keyboardActivity()
                if (!root.page || !root.page.mini || !TaskManagerService.ready) return
                root.dashboard = root.page.mini.content
                root.dashboard.snapshot = {cpu: {usage: 42, temperatureC: 43}, memory: {percent: 50, used: 8e9, total: 16e9},
                    gpus: [{usage: 29, temperatureC: 48}]}
                root.dashboard.pinnedProcesses = [{key: "1:1", name: "qs", cpuTotalPercent: 3.7, rss: 443547648},
                    {key: "2:1", name: "worker", cpuTotalPercent: 1.2, rss: 16777216}]
                root.leave()
                root.readyAt = Date.now()
            } else if (root.phase === 2) {
                if (Date.now() - root.readyAt < 1000) return
                if (!root.page.mini.active || root.page.parent.height < root.page.mini.content.implicitHeight) return
                root.metric = root.find(root.dashboard, "taskManagerMini" + ["Cpu", "Memory", "Gpu"][root.metricIndex])
                root.gauge = root.find(root.metric, "taskManagerMiniWaterGauge")
                root.check(!root.metric.hovered && !root.gauge.emphasized, "metric rests without emphasis")
                root.probeImage = root.canvas(probe).toDataURL()
                root.gaugeImage = root.canvas(root.gauge).toDataURL()
                root.windowRect = Qt.rect(root.page.Window.window.width, root.page.Window.window.height, root.page.parent.width, root.page.parent.height)
                root.moveTo(root.metric)
            } else if (root.phase === 3) {
                root.check(root.metric.hovered && root.gauge.emphasized && root.metric.scale === 1, "metric responds without scaling")
                root.check(root.metric.data.find(item => typeof item.cursorShape !== "undefined").cursorShape === Qt.ArrowCursor,
                    "metric keeps the Arrow cursor")
                var surface = root.find(root.metric, "taskManagerMiniMetricSurface")
                root.check(Qt.colorEqual(surface.color, Qt.tint(Theme.surface, root.metric.visuals.hoverSurface)) && Math.abs(surface.border.color.a - 0.18) < 0.01,
                    "hover surface and subtle accent border settle")
                root.check(surface.transform.length === 0, "material hover does not elevate the card")
                root.check(root.gauge.fillRatio === [0.42, 0.5, 0.29][root.metricIndex]
                    && root.gauge.wavePhase === root.dashboard.waterWavePhase, "hover preserves fill and the existing wave clock")
                root.check(!probe.emphasized && probe.fillRatio === 0.42 && root.canvas(probe).toDataURL() === root.probeImage,
                    "default shared gauge is unchanged")
                if (root.reduced) root.check(root.canvas(root.gauge).toDataURL() !== root.gaugeImage, "paused gauge repaints on emphasis")
                root.check(root.page.Window.window.width === root.windowRect.x && root.page.Window.window.height === root.windowRect.y
                    && root.page.parent.width === root.windowRect.width && root.page.parent.height === root.windowRect.height,
                    "hover keeps drawing window and panel geometry fixed")
                root.photo("metric-" + root.metricIndex)
            } else if (root.phase === 4) {
                if (capture.running) return
                root.leave()
            } else if (root.phase === 5) {
                root.check(!root.metric.hovered && !root.gauge.emphasized, "metric emphasis clears on leave")
                root.check(root.find(root.metric, "taskManagerMiniMetricSurface").transform.length === 0, "card remains in place after leave")
                if (++root.metricIndex < 3) { root.phase = 2; return }
                var row = root.find(root.dashboard, "taskManagerMiniPinnedRow")
                var content = root.find(row, "taskManagerMiniPinnedContent")
                root.rowStart = root.find(row, "taskManagerMiniPinNameGroup").mapToItem(row, 0, 0).x
                root.hoveredPinIdentity = row
                root.pinRefreshes = 0
                root.pinCpuStart = row.modelData.cpuTotalPercent
                root.moveTo(row)
            } else if (root.phase === 6) {
                var row = root.find(root.dashboard, "taskManagerMiniPinnedRow")
                root.check(row === root.hoveredPinIdentity, "telemetry refresh preserves the hovered delegate identity")
                root.check(row.hovered && row.scale === 1, "pin row has hover without scale")
                root.check(row.data.find(item => typeof item.cursorShape !== "undefined").cursorShape === Qt.PointingHandCursor,
                    "actionable pin row uses the pointing-hand cursor")
                root.check(root.find(root.dashboard, "taskManagerMiniPinHoverPill").targetItem === row
                    && Qt.colorEqual(root.find(root.dashboard, "taskManagerMiniPinHoverPill").color, root.metric.visuals.miniRowHoverSurface), "pin row uses a neutral hover surface")
                var content = root.find(row, "taskManagerMiniPinnedContent")
                root.check(Math.abs(root.find(row, "taskManagerMiniPinNameGroup").mapToItem(row, 0, 0).x - root.rowStart - (root.reduced ? 0 : 3)) < 0.01,
                    "pin content nudges three pixels only with motion enabled")
                root.check(Qt.colorEqual(content.children[0].children[0].color, Theme.accent), "pin glyph gains accent")
                var pane = root.find(root.dashboard, "taskManagerMiniPinsPane")
                var column = pane.children.find(item => item.children && item.children.length > 1)
                root.check(Qt.colorEqual(column.children[0].children[0].color, Theme.accent), "pane header links the hovered row")
                var other = column.children.filter(item => item.objectName === "taskManagerMiniPinnedRow")[1]
                root.check(!other.hovered && Qt.colorEqual(other.color, root.metric.visuals.wellSurface)
                    && Qt.colorEqual(pane.color, root.metric.visuals.paneSurface), "only the hovered row changes surface")
                root.check(UiState.activePanel === "hakumenu" && !UiState.taskManagerOpen && TaskManagerService.subscribers === 1,
                    "hover performs no action or subscription change")
                // Refresh payloads repeatedly while the native pointer remains stationary.
                if (root.pinRefreshes++ < 6) {
                    root.dashboard.pinnedProcesses = root.dashboard.pinnedProcesses.map(process => Object.assign({}, process,
                        {cpuTotalPercent: process.cpuTotalPercent + 0.1, rss: process.rss + 1024}))
                    return
                }
                root.check(content.children[1].text.indexOf((root.pinCpuStart + 0.6).toFixed(1) + "%") >= 0,
                    "retained row still receives fresh telemetry")
                root.photo("pin")
            } else if (root.phase === 7) {
                if (capture.running) return
                root.leave()
            } else if (root.phase === 8) {
                root.check(!root.find(root.dashboard, "taskManagerMiniPinnedRow").hovered, "pin hover clears")
                if (!root.light) {
                    root.light = true
                    ShellSettingsStore.colorMode = "light"
                    root.metricIndex = 0
                    root.phase = 2
                    return
                }
                UiState.closeHakuMenu()
            } else if (root.phase === 9) {
                if (TaskManagerService.subscribers) return
                console.info("HakuMenu Mini passed: surface hover in both palettes and stable gauge telemetry")
                Qt.quit()
                return
            }
            ++root.phase
        }
    }
}
