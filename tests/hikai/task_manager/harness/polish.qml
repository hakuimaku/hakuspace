import QtQuick
import QtTest
import Quickshell
import Quickshell.Io
import "components"
import "components/base" as Base
import "services"

ShellRoot {
    id: root
    // Exercise presentation changes with stable process fixtures and real Qt input.
    property int phase: 0
    property int ticks: 0
    property real startedAt: 0
    readonly property bool reduced: Quickshell.env("HAKUSPACE_REDUCED_MOTION") === "1"
    property bool secondCore: false
    property bool hoverSent: false
    property bool filtered: false
    property var identity: null
    readonly property var primaryOutput: Quickshell.screens.find(output => output.name === "HEADLESS-1")
    readonly property var overlay: surface.item
    readonly property var content: overlay ? overlay.content : null
    readonly property var input: overlay ? overlay.testInput : null
    property var cpu: null
    property var table: null
    property var pill: null
    property var tooltip: null
    property bool sawTooltipFadeIn: false
    property bool sawTooltipFadeOut: false
    property string tooltipExitText: ""
    property point tooltipExitAnchor: Qt.point(0, 0)

    Connections {
        target: root.tooltip
        function onOpacityChanged() {
            if (root.reduced || !root.tooltip || !root.tooltip.visible || root.tooltip.opacity <= 0 || root.tooltip.opacity >= 1) return
            if (root.tooltip.active) root.sawTooltipFadeIn = true
            else {
                root.sawTooltipFadeOut = true
                root.check(root.tooltip.text === root.tooltipExitText
                    && root.tooltip.x === root.tooltipExitAnchor.x && root.tooltip.y === root.tooltipExitAnchor.y,
                    "fade-out retains the last core text and anchor: text=" + root.tooltip.text
                        + "; expected=" + root.tooltipExitText + "; at=" + root.tooltip.x + "," + root.tooltip.y
                        + "; expected at=" + root.tooltipExitAnchor)
            }
        }
    }

    function check(ok, message) {
        if (ok) return
        console.error("Task Manager polish phase=" + phase + " reduced=" + reduced + ": " + message)
        Qt.exit(1)
        throw new Error(message)
    }
    function find(item, name) {
        if (!item) return null
        if (item.objectName === name) return item
        var children = item.children || []
        for (var child of children) {
            var result = find(child, name)
            if (result) return result
        }
        if (item.data && typeof item.data.length === "number") for (var child of item.data) {
            if (children.indexOf(child) >= 0) continue
            var result = find(child, name)
            if (result) return result
        }
        return item.contentItem ? find(item.contentItem, name) : null
    }
    function assertSelection() {
        check(pill === identity && pill.targetItem === table.currentItem && pill.parent === table.contentItem,
            "one pill follows the current delegate in content coordinates; same=" + (pill === identity)
                + "; target=" + pill.targetItem + "; current=" + table.currentItem + "; parent=" + pill.parent
                + "; content=" + table.contentItem)
        check(Math.abs(pill.y - table.currentItem.y) < 0.5 && Math.abs(pill.height - table.currentItem.height) < 0.5
            && pill.radius === Theme.radius && Qt.colorEqual(pill.color, Theme.accent), "settled accent pill geometry")
        check(table.currentItem.color.a === 0, "selected delegate has no duplicate background")
        for (var name of ["Pid", "ProcessName", "ProcessUser", "ProcessCpu", "ProcessMemory", "ProcessThreads", "ProcessPin"])
            check(Qt.colorEqual(find(table.currentItem, "taskManager" + name).color, Theme.onAccentColor), "selected contrast " + name)
    }
    function captureFrame(kind) {
        capture.command = ["grim", "-o", root.primaryOutput.name,
            "/tmp/taskmanager-polish-main-" + root.primaryOutput.width + "-" + (reduced ? "reduced-" : "normal-") + kind + ".png"]
        capture.running = true
    }
    function hoverCore(index) {
        var core = root.find(root.cpu, "cpuCoreCell_" + index)
        var point = core.mapToItem(root.overlay.contentItem, core.width / 2, core.height / 2)
        console.info("CPU hover evidence " + JSON.stringify({reduced: reduced, index: index, x: point.x, y: point.y,
            width: core.width, height: core.height, visible: core.visible, enabled: core.enabled}))
        pointer.write(Math.round(point.x) + " " + Math.round(point.y) + " " + root.overlay.width + " " + root.overlay.height + " 0\n")
    }
    Process { id: capture }
    Process {
        id: pointer
        command: ["python3", "-u", Quickshell.env("TASK_MANAGER_INPUT_DIR") + "/wayland_pointer.py"]
        environment: ({HAKUSPACE_TEST_POINTER_OUTPUT: root.primaryOutput.name})
        stdinEnabled: true
        running: true
    }
    Base.LifecycleLoader {
        id: surface
        requested: UiState.taskManagerOpen
        TaskManagerOverlay {
            modelData: root.primaryOutput
            property alias testInput: events
            TestEvent { id: events }
        }
    }
    Timer {
        interval: 100; repeat: true; running: true
        onTriggered: {
            root.check(++root.ticks < 400, "timeout")
            if (root.phase === 0) UiState.openTaskManager(root.primaryOutput.name)
            else if (root.phase === 1) {
                if (!root.overlay || !root.overlay.interactionReady) return
                root.cpu = root.find(root.content, "taskCpuCard")
                root.table = root.find(root.content, "taskManagerProcesses")
                root.pill = root.find(root.content, "taskProcessSelectionPill")
                root.tooltip = root.find(root.cpu, "cpuCoreTooltip")
                root.secondCore = false
                root.hoverSent = false
                root.filtered = false
                var rows = []
                for (var i = 0; i < 310; i++) rows.push({pid: 900000 + i, startTime: 1, key: (900000 + i) + ":1",
                    name: "process-" + i, user: "haku", cpuTotalPercent: 10, rss: 1048576, threads: 2})
                root.content.processesData = rows
                root.content.cpuData = {usage: 18, cores: [62.5, 12, 0, 100], frequencyHighestMHz: 3800, temperatureC: 54}
                root.content.reducedMotion = root.reduced
                root.content.sortKey = "pid"
                root.content.descending = false
            } else if (root.phase === 2) {
                if (!root.hoverSent) {
                    pointer.write((root.overlay.width - 10) + " " + (root.overlay.height - 10) + " " + root.overlay.width + " " + root.overlay.height + " 0\n")
                    root.hoverCore(0)
                    root.startedAt = Date.now()
                    root.hoverSent = true
                    return
                }
                var elapsed = Date.now() - root.startedAt
                if (root.cpu.hoveredCoreIndex !== 0) {
                    root.check(elapsed < 1800, "pointer hover identifies the core; index=" + root.cpu.hoveredCoreIndex
                        + "; cpu enabled=" + root.cpu.enabled + "; visible=" + root.cpu.visible + "; pointer running=" + pointer.running)
                    return
                }
                if (elapsed < 200) root.check(!root.tooltip.visible, "tooltip respects short hover delay")
                if (elapsed < 400) return
                root.check(root.tooltip.visible && root.tooltip.text === "Core 0 · 62.5%"
                    && root.tooltip.background.radius === Theme.radius, "lightweight tooltip after delay")
                root.check(Qt.colorEqual(root.find(root.cpu, "cpuCoreFill_0").color, Theme.accent)
                    && root.cpu.stemProgress === undefined && root.cpu.unfurlProgress === undefined, "highlight without tooltip morph")
                root.captureFrame("tooltip")
            } else if (root.phase === 3) {
                if (!root.secondCore) {
                    if (capture.running) return
                    root.check(root.reduced || root.sawTooltipFadeIn, "normal core tooltip fades in")
                    root.tooltipExitText = root.tooltip.text
                    root.tooltipExitAnchor = Qt.point(root.tooltip.x, root.tooltip.y)
                    root.cpu.handleCoreHover(0, false)
                    root.check(!root.tooltip.active, "leaving closes the tooltip")
                    root.hoverCore(1)
                    root.startedAt = Date.now()
                    root.secondCore = true
                    return
                }
                if (Date.now() - root.startedAt < 400) return
                if (!root.tooltip.visible || root.tooltip.text !== "Core 1 · 12%") {
                    root.check(Date.now() - root.startedAt < 1800, "tooltip follows another core; index=" + root.cpu.hoveredCoreIndex
                        + "; text=" + root.tooltip.text + "; visible=" + root.tooltip.visible)
                    if (root.cpu.hoveredCoreIndex !== 1) root.hoverCore(1)
                    return
                }
                root.check(root.reduced || root.sawTooltipFadeOut, "normal core tooltip fades out")
                root.tooltipExitText = root.tooltip.text
                root.tooltipExitAnchor = Qt.point(root.tooltip.x, root.tooltip.y)
                root.cpu.clearCoreTooltip()
                root.content.selectedKey = root.content.rows[1].key
                TaskManagerPins.keys = [root.content.selectedKey]
                root.startedAt = Date.now()
            } else if (root.phase === 4) {
                if (!root.pill.shown) {
                    root.check(Date.now() - root.startedAt < 2000, "selection target not ready; selected="
                        + root.content.selectedKey + "; index=" + root.table.currentIndex + "; current="
                        + (root.table.currentItem ? root.table.currentItem.modelData.key : "none"))
                    return
                }
                root.identity = root.pill
                root.assertSelection()
                var row = root.table.itemAtIndex(3)
                root.input.mouseClick(row, row.width / 2, row.height / 2, Qt.LeftButton, Qt.NoModifier, 0)
                root.check(root.content.selectedKey === root.content.rows[3].key, "mouse selects the process")
                root.startedAt = Date.now()
            } else if (root.phase === 5) {
                if (!root.reduced) root.check(root.pill.y !== root.table.currentItem.y, "shared pill interpolates between rows")
                var y = root.pill.y
                root.table.contentY += 20
                root.check(root.pill.y === y && Math.abs(root.pill.mapToItem(root.table, 0, 0).y - y + root.table.contentY) < 0.5,
                    "scrolling moves the content and pill together")
                root.startedAt = Date.now()
            } else if (root.phase === 6) {
                if (Date.now() - root.startedAt < 1000) return
                root.assertSelection()
                root.table.forceActiveFocus()
                root.input.keyClick(Qt.Key_Down, Qt.NoModifier, 0)
                root.check(root.content.selectedKey === root.content.rows[4].key, "keyboard shares process selection")
                root.startedAt = Date.now()
            } else if (root.phase === 7) {
                if (Date.now() - root.startedAt < 1000) return
                root.assertSelection()
                root.content.reducedMotion = true
                root.content.selectedKey = root.content.rows[170].key
                root.table.positionViewAtIndex(170, ListView.Contain)
            } else if (root.phase === 8) {
                if (!root.table.currentItem) return
                root.assertSelection()
                root.check(root.pill.duration === 0, "reduced motion snaps after delegate virtualization")
                ShellSettingsStore.colorMode = "light"
            } else if (root.phase === 9) {
                root.assertSelection()
                root.captureFrame("selection")
            } else if (root.phase === 10) {
                if (capture.running) return
                if (!root.filtered) {
                    root.content.query = "no-such-process"
                    root.filtered = true
                    return
                }
                root.check(!root.pill.shown && !root.pill.visible, "filtering removes the pill without a stale flash")
                root.content.query = ""
                root.content.selectedKey = ""
                ShellSettingsStore.colorMode = "dark"
                TaskManagerPins.keys = []
                UiState.closeTaskManager()
            } else if (root.phase === 11) {
                if (surface.active || capture.running) return
                console.info("Task Manager polish passed")
                Qt.quit()
                return
            }
            ++root.phase
        }
    }
}
