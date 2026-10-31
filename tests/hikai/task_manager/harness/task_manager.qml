import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "components"
import "components/base" as Base
import "services"

ShellRoot {
    id: root
    // Track asynchronous window transitions and repeated demand lifetimes.
    property int phase: 0
    property int cycles: 0
    property bool dragSent: false
    property int collectorPid: 0
    property int ticks: 0
    property bool maskTest: false
    property bool pointerReady: false
    property int settingsClicks: 0
    readonly property string output: Quickshell.screens[0].name
    readonly property var overlay: surface.item
    readonly property var input: overlay ? overlay.testInput : null
    readonly property var card: overlay ? overlay.mask.item : null
    // Keep identity fixtures independent of real process ordering.
    property var fixture: [
        {pid: 123456, startTime: 1, key: "123456:1", name: "Beta", user: "alice", cmdline: "beta --flag", rss: 20, cpuPercent: 100, cpuTotalPercent: 100 / 12, threads: 1},
        {pid: 1234567, startTime: 2, key: "1234567:2", name: "Alpha", user: "bob", cmdline: "alpha", rss: 40, cpuPercent: 50, cpuTotalPercent: 50 / 12, threads: 2}
    ]

    // Fail at the first violated behavior and report the current phase.
    function check(condition, message) {
        if (condition) return
        console.error("Task Manager QML failed at " + phase + ": " + message)
        Qt.exit(1)
        throw new Error(message)
    }
    // Exercise the real lower-right grip through Qt pointer events.
    function resize(dx, dy) {
        var x = card.x + card.width - 14, y = card.y + card.height - 14
        input.mousePress(overlay.contentItem, x, y, Qt.LeftButton, Qt.NoModifier, 0)
        input.mouseMove(overlay.contentItem, x + (dx > 0 ? 20 : -20), y + (dy > 0 ? 20 : -20), 0, Qt.LeftButton, Qt.NoModifier)
        input.mouseMove(overlay.contentItem, x + dx, y + dy, 0, Qt.LeftButton, Qt.NoModifier)
        input.mouseRelease(overlay.contentItem, x + dx, y + dy, Qt.LeftButton, Qt.NoModifier, 0)
    }
    // Find real action controls without adding test hooks to production content.
    function find(item, text) {
        if (item.text === text && typeof item.clicked === "function") return item
        for (var child of item.children || []) {
            var found = find(child, text)
            if (found) return found
        }
        return null
    }
    // Verify the real header and rows agree at minimum and default window widths.
    function checkColumns() {
        if (!TaskManagerService.processes.some(row => row.pid === 123456)) {
            TaskManagerService.processes = root.fixture
            return false
        }
        var findPid = function(item, pid) {
            if (item.objectName === "taskManagerPid" && item.text === String(pid)) return item
            for (var child of item.children || []) {
                var found = findPid(child, pid)
                if (found) return found
            }
            return null
        }
        var headerPid = findPid(root.overlay.content, "PID")
        for (var pid of [123456, 1234567]) {
            var cell = findPid(root.overlay.content, pid)
            if (!cell) return false
            root.check(cell && cell.elide === Text.ElideNone && !cell.truncated && cell.width >= cell.contentWidth,
                "PID truncated: " + pid + "; cell=" + cell + (cell ? "; width=" + cell.width + "; content=" + cell.contentWidth + "; elide=" + cell.elide + "; truncated=" + cell.truncated : ""))
            var row = cell.parent
            root.check(row.children.length === headerPid.parent.children.length, "header/row column count")
            for (var i = 1; i < row.children.length; i++) {
                var expected = headerPid.parent.children[i]
                var actual = row.children[i]
                root.check(Math.abs(actual.width - expected.width) < 1.1 && Math.abs(actual.x - expected.x) < 1.1,
                    "header/row column geometry")
            }
        }
        var cpuCell = findPid(root.overlay.content, 123456).parent.children.find(item => item.text === "8.3%")
        root.check(!!cpuCell, "normalized CPU is not rendered")
        return true
    }
    // Deliver real seat clicks through the evaluated Settings input mask.
    function clickOutput(x, y) {
        pointer.write(Math.round(x) + " " + Math.round(y) + " " + overlay.width + " " + overlay.height + " 272\n")
    }
    Process {
        id: pointer
        // The helper reaches stdin iteration only after its Wayland round trips finish.
        command: ["python3", "-u", "-c", "import runpy,sys\nclass ReadyInput:\n def __iter__(self):\n  print('ready',flush=True)\n  yield from sys.__stdin__\nsys.stdin=ReadyInput()\nrunpy.run_path(sys.argv[1],run_name='__main__')",
            Quickshell.env("TASK_MANAGER_INPUT_DIR") + "/wayland_pointer.py"]
        stdout: SplitParser { onRead: line => { if (line === "ready") root.pointerReady = true } }
        environment: ({HAKUSPACE_TEST_POINTER_OUTPUT: root.output})
        stdinEnabled: true
        running: root.maskTest
    }
    // Evaluate the production Settings mask above the floating utility.
    LazyLoader {
        id: settingsMask
        active: root.maskTest
        PanelWindow {
            id: settingsProbe
            property var modelData: Quickshell.screens[0]
            screen: modelData
            anchors { top: true; bottom: true; left: true; right: true }
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "task-manager-settings-mask-probe"
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            /*SETTINGS_MASK*/
            Rectangle { id: settingsBody; x: UiState.taskManagerRect.x + 100; y: UiState.taskManagerRect.y + 80; width: 100; height: 80; color: "gray" }
            MouseArea { anchors.fill: parent; onPressed: { root.settingsClicks++; UiState.claimInteraction("settings", root.output) } }
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
    Base.LifecycleLoader {
        id: secondary
        requested: UiState.taskManagerOpen && UiState.taskManagerScreenName === Quickshell.screens[1].name
        TaskManagerOverlay { modelData: Quickshell.screens[1] }
    }
    Base.LifecycleLoader {
        id: note
        requested: UiState.tempNoteOpen
        TempNoteOverlay {
            modelData: Quickshell.screens[0]
            property alias testInput: noteEvents
            TestEvent { id: noteEvents }
        }
    }
    // Verify process actions only against a disposable helper.
    Process { id: victim; command: ["sleep", "60"]; running: true }
    Process {
        id: reaper
        stdout: StdioCollector { id: reaperOutput }
        onExited: root.check(reaperOutput.text.trim() === "gone", "collector remained after close: " + reaperOutput.text)
    }

    Timer {
        interval: 30
        repeat: true
        running: true
        onTriggered: {
            root.ticks++
            root.check(root.ticks < 1500, "timeout; owner=" + UiState.interactionOwner + "; settingsClicks=" + root.settingsClicks + "; rect=" + UiState.taskManagerRect)
            if (root.phase === 0) {
                root.check(!TaskManagerService.collectorRunning && !TaskManagerService.subscribers, "idle collector")
                UiState.activePanel = "settings"
                UiState.openTaskManager(root.output)
                root.check(UiState.activePanel === "settings", "floating visibility coupled to activePanel")
            } else if (root.phase === 1) {
                if (!root.overlay || !root.overlay.interactionReady || !TaskManagerService.ready) return
                root.check(TaskManagerService.subscribers === 1 && TaskManagerService.collectorRunning, "single acquire")
                root.check(TaskManagerService.processes.length > 0, "real collector table empty: " + TaskManagerService.error)
                root.collectorPid = TaskManagerService.collectorPid
                root.check(root.collectorPid > 0, "collector pid unavailable")
                root.check(UiState.taskManagerRect.width === root.card.width, "published rectangle")
                root.overlay.position = Qt.point(10000, 10000)
                root.check(root.card.x + root.card.width === root.overlay.width && root.card.y + root.card.height === root.overlay.height, "drag lower clamp")
                root.overlay.position = Qt.point(-10000, -10000)
                root.check(root.card.x === 0 && root.card.y === 0, "drag upper clamp")
                root.overlay.position = Qt.point(20, 30)
                root.resize(-10000, -10000)
                root.check(root.card.width === 720 && root.card.height === 480, "resize minimum")
                root.resize(10000, 10000)
                root.check(root.card.x === 20 && root.card.y === 30 && root.card.width === root.overlay.width - 20
                    && root.card.height === root.overlay.height - 30, "resize bounds/origin")
                root.overlay.cardSize = Qt.size(800, 500)
                root.overlay.position = Qt.point(80, 60)
            } else if (root.phase === 2) {
                if (!root.dragSent) {
                // A real handle gesture must move the card independently of table interaction.
                input.mousePress(root.card, root.card.width / 2, 28, Qt.LeftButton, Qt.NoModifier, 0)
                input.mouseMove(root.overlay.contentItem, root.card.x + root.card.width / 2 + 20, root.card.y + 48, 0, Qt.LeftButton, Qt.NoModifier)
                input.mouseMove(root.overlay.contentItem, root.card.x + root.card.width / 2 + 70, root.card.y + 98, 0, Qt.LeftButton, Qt.NoModifier)
                input.mouseRelease(root.overlay.contentItem, root.card.x + root.card.width / 2 + 70, root.card.y + 98, Qt.LeftButton, Qt.NoModifier, 0)
                    root.dragSent = true
                    return
                }
                root.check(root.card.x > 80 && root.card.y > 60, "drag handle")
                UiState.openTempNote(root.output)
            } else if (root.phase === 3) {
                if (!note.item || !note.item.interactionReady) return
                root.check(UiState.ownsInteraction("tempNote", root.output) && UiState.taskManagerOpen, "note focus coexistence")
                root.overlay.takeFocus()
                root.check(UiState.tempNoteOpen && UiState.ownsInteraction("taskManager", root.output), "task focus coexistence")
                UiState.tempNoteFocusRequested(root.output)
                root.check(UiState.ownsInteraction("tempNote", root.output) && UiState.taskManagerOpen, "focus return")
                input.keyClick(Qt.Key_Escape, Qt.NoModifier, 0)
                root.check(UiState.taskManagerOpen && UiState.tempNoteOpen, "passive Task Manager consumed Escape")
                note.item.testInput.keyClick(Qt.Key_Escape, Qt.NoModifier, 0)
                root.check(!UiState.tempNoteOpen && UiState.taskManagerOpen, "Escape closed the wrong floating utility")
                root.overlay.takeFocus()
                // Inject fixture frames through the actual parser and bounded-history path.
                for (var i = 0; i < 130; i++) {
                    TaskManagerService.receive(JSON.stringify({schema: 1, seq: i + 1, processMonotonicMs: i,
                        cpu: {usage: 20}, memory: {percent: 30}, gpus: [], network: {all: {}}, disks: {}, processes: root.fixture}))
                }
                root.check(TaskManagerService.history.length === 120, "unbounded history")
                root.phase = 30
                return
            } else if (root.phase === 30) {
                if (!root.checkColumns()) return
                root.overlay.cardSize = Qt.size(720, 480)
                root.phase = 31
                return
            } else if (root.phase === 31) {
                if (!root.checkColumns()) return
                root.overlay.cardSize = Qt.size(800, 500)
                root.overlay.content.query = "alice"
                root.check(root.overlay.content.rows.length === 1 && root.overlay.content.rows[0].pid === 123456, "search")
                root.overlay.content.query = ""
                root.overlay.content.selectedKey = "123456:1"
                root.overlay.content.sortKey = "name"
                root.overlay.content.descending = false
                root.check(root.overlay.content.rows[0].pid === 1234567 && root.overlay.content.selectedProcess.pid === 123456, "selection reordered by index")
                root.overlay.content.killKey = "123456:1"
                root.overlay.content.handleEscape()
                root.check(!root.overlay.content.killKey && UiState.taskManagerOpen, "Escape confirmation")
                root.overlay.content.detailsOpen = true
                root.overlay.content.handleEscape()
                root.check(!root.overlay.content.detailsOpen && UiState.taskManagerOpen, "Escape details")
                TaskManagerService.processes = [root.fixture[1]]
                root.check(!root.overlay.content.selectedKey && !root.overlay.content.selectedProcess, "stale process selection")
                TaskManagerService.receiveAction('{"ok":false,"status":"permissionDenied"}', 1)
                root.check(TaskManagerService.actionError === "permissionDenied", "action error")
                TaskManagerService.receiveAction('{"ok":true,"status":"alreadyExited"}', 0)
                root.check(!TaskManagerService.actionError && TaskManagerService.actionStatus === "alreadyExited", "exited action nonfatal")
                TaskManagerService.receive('malformed')
                root.check(!!TaskManagerService.error, "parser failure missing")
                root.overlay.content.forceFocus()
                input.keyClick(Qt.Key_F, Qt.ControlModifier, 0)
                root.phase = 4
                return
            } else if (root.phase === 4) {
                // Escape clears search focus before closing the overlay.
                input.keyClick(Qt.Key_Escape, Qt.NoModifier, 0)
                root.check(UiState.taskManagerOpen, "Escape search closed utility")
                root.overlay.content.selectedKey = ""
                root.overlay.content.forceFocus()
                input.keyClick(Qt.Key_Down, Qt.NoModifier, 0)
                root.check(!!root.overlay.content.selectedKey, "Down selection; focus=" + root.overlay.contentItem.Window.window.activeFocusItem + "; rows=" + root.overlay.content.rows.length)
                input.keyClick(Qt.Key_Return, Qt.NoModifier, 0)
                root.check(root.overlay.content.detailsOpen, "Enter details")
                input.keyClick(Qt.Key_Delete, Qt.NoModifier, 0)
                root.check(!TaskManagerService.actionBusy && !root.overlay.content.killKey, "Delete invoked kill")
                root.overlay.content.handleEscape()
                UiState.closeTaskManager()
                root.check(surface.active && TaskManagerService.subscribers === 1, "destroyed before visual close")
            } else if (root.phase === 5) {
                root.check(surface.active, "closing surface destroyed early")
                var reveal = root.overlay.reveal
                UiState.openTaskManager(root.output)
                root.check(root.overlay.reveal === reveal && TaskManagerService.subscribers === 1, "close reversal lost owner")
            } else if (root.phase === 6) {
                if (!root.overlay.interactionReady) return
                UiState.openTaskManager(Quickshell.screens[1].name)
            } else if (root.phase === 7) {
                if (surface.active || !secondary.item || !secondary.item.interactionReady) return
                root.check(TaskManagerService.subscribers === 1, "output transfer subscribers")
                UiState.closeTaskManagerIfScreen(root.output)
                root.check(UiState.taskManagerOpen, "stale output destroyed new owner")
                UiState.openTaskManager(root.output)
            } else if (root.phase === 8) {
                if (secondary.active || !root.overlay || !root.overlay.interactionReady) return
                root.check(TaskManagerService.subscribers === 1, "return output ownership")
                UiState.closeTaskManager()
            } else if (root.phase === 9) {
                if (surface.active || secondary.active || TaskManagerService.collectorRunning) return
                root.check(!TaskManagerService.subscribers && !TaskManagerService.processes.length && !TaskManagerService.history.length, "release retained heavy data")
                reaper.command = ["python3", "-c", "import pathlib,sys; print('gone' if not pathlib.Path('/proc/' + sys.argv[1]).exists() else 'alive')", String(root.collectorPid)]
                reaper.running = true
                UiState.openTaskManager(root.output)
            } else if (root.phase === 10) {
                if (!root.overlay || !root.overlay.interactionReady || !TaskManagerService.ready) return
                root.check(TaskManagerService.subscribers === 1, "cycle subscriber leak")
                UiState.closeTaskManager()
            } else if (root.phase === 11) {
                if (surface.active || TaskManagerService.collectorRunning) return
                root.check(TaskManagerService.subscribers === 0, "cycle release")
                root.cycles++
                if (root.cycles < 20) { UiState.openTaskManager(root.output); root.phase = 10; return }
                // Classic must refuse collector startup even with a stale subscriber.
                AppState.shellBackend = "classic"
                TaskManagerService.acquire()
                root.check(!TaskManagerService.active && !TaskManagerService.collectorRunning, "Classic starts collector")
                TaskManagerService.release()
                AppState.shellBackend = "hikai"
                UiState.openTaskManager(root.output)
            } else if (root.phase === 12) {
                if (!root.overlay || !root.overlay.interactionReady) return
                var process = TaskManagerService.processes.find(row => row.pid === victim.processId)
                if (!process) return
                root.overlay.content.selectedKey = process.key
                root.find(root.overlay.content, "Terminate").clicked()
            } else if (root.phase === 13) {
                if (victim.running || TaskManagerService.actionBusy) return
                root.check(TaskManagerService.actionStatus === "sent" && !TaskManagerService.actionError, "UI TERM failed")
                victim.running = true
            } else if (root.phase === 14) {
                var process = TaskManagerService.processes.find(row => row.pid === victim.processId)
                if (!process) return
                root.overlay.content.selectedKey = process.key
                root.find(root.overlay.content, "Force kill").clicked()
                root.check(!TaskManagerService.actionBusy && victim.running && !!root.overlay.content.killKey, "KILL skipped confirmation")
                root.overlay.content.handleEscape()
                root.check(!root.overlay.content.killKey && victim.running, "KILL cancel")
                root.find(root.overlay.content, "Force kill").clicked()
            } else if (root.phase === 15) {
                root.find(root.overlay.content, "Confirm kill").clicked()
            } else if (root.phase === 16) {
                if (victim.running || TaskManagerService.actionBusy) return
                root.check(TaskManagerService.actionStatus === "sent" && !TaskManagerService.actionError, "UI KILL failed")
                root.maskTest = true
                UiState.claimInteraction("settings", root.output)
            } else if (root.phase === 17) {
                if (!root.pointerReady) return
                input.mouseClick(root.card, 40, 100, Qt.LeftButton, Qt.NoModifier, 0)
                root.check(UiState.ownsInteraction("taskManager", root.output), "local pointer did not claim lease")
                UiState.claimInteraction("settings", root.output)
                root.clickOutput(root.card.x + 40, root.card.y + 100)
            } else if (root.phase === 18) {
                if (!UiState.ownsInteraction("taskManager", root.output)) return
                root.clickOutput(root.card.x + 140, root.card.y + 110)
            } else if (root.phase === 19) {
                if (!UiState.ownsInteraction("settings", root.output)) return
                root.check(UiState.taskManagerOpen, "Settings click closed utility")
                root.maskTest = false
                // Simulate removal of the owning output by destroying its loader.
                surface.active = false
            } else if (root.phase === 20) {
                if (TaskManagerService.collectorRunning) return
                root.check(!UiState.taskManagerOpen && !TaskManagerService.subscribers, "output destruction left ownership")
                root.check(!TaskManagerService.collectorRunning, "collector alive after output destruction")
                console.info("Task Manager QML passed: 20 cycles, focus, geometry, process identity, actions, Classic")
                Qt.quit()
                return
            }
            root.phase++
        }
    }
}
