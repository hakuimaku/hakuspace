import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import Quickshell.Io
import "services"
import "components"

ShellRoot {
    id: root
    // Exercise row action columns against real live pins in disposable preferences.
    readonly property var output: Quickshell.screens.find(item => item.name === "HEADLESS-1")
    property int phase: 0
    property int ticks: 0
    property var page: null
    property var dashboard: null
    property var input: null
    property var first: null
    property var second: null
    property real timestamp: 0
    property int collectorPid: 0

    function check(ok, message) {
        if (ok) return
        console.error("Mini unpin phase=" + phase + ": " + message)
        Qt.exit(1)
        throw new Error(message)
    }
    function find(item, predicate) {
        if (!item) return null
        if (predicate(item)) return item
        if (item.active && item.item) { var found = find(item.item, predicate); if (found) return found }
        var children = item.contentItem ? item.contentItem.data : item.children || []
        if (!item.contentItem && item.data && typeof item.data !== "function" && typeof item.data.length === "number") children = item.data
        for (var child of children) { var found = find(child, predicate); if (found) return found }
        return null
    }
    function row(process) { return find(dashboard, item => item.objectName === "taskManagerMiniPinnedRow" && item.modelData.key === process.key) }
    function button(process) { return find(row(process), item => item.objectName === "taskManagerMiniUnpinButton") }
    function click(process) {
        var target = row(process)
        root.check(!!target, "live pinned row exists")
        input.mouseClick(target, target.width / 2, target.height / 2, Qt.LeftButton, Qt.NoModifier, 0)
    }
    HakuMenuPanel { id: menu; modelData: root.output }
    Component { id: events; TestEvent {} }
    Process { id: capture }
    Timer {
        interval: 250; repeat: true; running: true
        onTriggered: {
            root.check(++root.ticks < 120, "timeout")
            if (root.phase === 0) {
                UiState.openHakuMenu(root.output.name, "theme", "default")
                UiState.setHakuPanelTab("taskManager")
            } else if (root.phase === 1) {
                root.page = root.find(menu, item => typeof item.miniLoaded === "boolean")
                if (root.page) root.page.keyboardActivity()
                if (!root.page || !root.page.mini || !TaskManagerService.ready) return
                root.dashboard = root.page.mini.content
                root.input = events.createObject(root.page.Window.window.contentItem)
                root.first = TaskManagerService.processes.find(process => process.pid === Quickshell.processId)
                root.second = TaskManagerService.processes.find(process => process.pid !== Quickshell.processId && process.pid !== TaskManagerService.collectorPid)
                root.check(root.first && root.second, "two live identities")
                TaskManagerPins.pin(root.first)
                TaskManagerPins.pin(root.second)
                root.collectorPid = TaskManagerService.collectorPid
            } else if (root.phase === 2) {
                root.click(root.first)
                root.check(TaskManagerPins.isPinned(root.first) && root.dashboard.pendingUnpinKey === root.first.key,
                    "row click opens the action column without removing the pin")
                root.check(root.button(root.first).visible && root.button(root.first).enabled
                    && Qt.colorEqual(root.button(root.first).foregroundColor, Theme.danger), "red X action is visible")
                root.timestamp = TaskManagerService.processTimestamp
            } else if (root.phase === 3) {
                if (TaskManagerService.processTimestamp <= root.timestamp) return
                root.check(root.dashboard.pendingUnpinKey === root.first.key && root.row(root.first).unpinShown
                    && root.button(root.first).width === Theme.comfortableControlHeight,
                    "action column survives telemetry refresh for the same PID:startTime")
                root.check(root.find(root.row(root.first), item => item.objectName === "taskManagerMiniPinnedCpu").text.startsWith("CPU "),
                    "CPU telemetry remains visible beside the X")
                capture.command = ["grim", "-o", root.output.name,
                    Quickshell.env("HAKUSPACE_MINI_ARTIFACT").replace(".png", "-unpin-confirm.png")]
                capture.running = true
            } else if (root.phase === 4) {
                if (capture.running) return
                root.click(root.second)
                root.check(root.dashboard.pendingUnpinKey === root.second.key && TaskManagerPins.isPinned(root.first)
                    && TaskManagerPins.isPinned(root.second) && !root.row(root.first).unpinShown,
                    "only the newly clicked row has an open action column")
                root.click(root.first)
                root.check(TaskManagerPins.isPinned(root.first), "switching rows never removes a pin")
                root.click(root.first)
                root.check(!root.dashboard.pendingUnpinKey && TaskManagerPins.isPinned(root.first),
                    "clicking the same row background closes the column instead of unpinning")
                root.click(root.first)
                root.input.keyClick(Qt.Key_Escape, Qt.NoModifier, 0)
                root.check(!root.dashboard.pendingUnpinKey && UiState.activePanel === "hakumenu", "Escape cancels confirmation without closing Mini")
            } else if (root.phase === 5) {
                root.click(root.first)
                root.check(TaskManagerPins.isPinned(root.first), "cancelled confirmation requires a new first click")
            } else if (root.phase === 6) {
                var action = root.button(root.first)
                root.input.mouseClick(action, action.width / 2, action.height / 2, Qt.LeftButton, Qt.NoModifier, 0)
                root.check(!TaskManagerPins.isPinned(root.first) && TaskManagerPins.isPinned(root.second)
                    && !root.dashboard.pendingUnpinKey, "only the red X unpins the selected identity without reopening the column")
                root.check(TaskManagerService.processes.some(process => process.key === root.first.key)
                    && TaskManagerService.collectorPid === root.collectorPid && TaskManagerService.subscribers === 1
                    && !TaskManagerService.actionBusy, "unpin neither terminates the process nor changes collector ownership")
            } else if (root.phase === 7) {
                root.click(root.second)
                UiState.setHakuPanelTab("hakumenu")
                root.check(!root.dashboard.pendingUnpinKey && TaskManagerPins.isPinned(root.second), "leaving Mini cancels confirmation")
                UiState.setHakuPanelTab("taskManager")
            } else if (root.phase === 8) {
                if (!TaskManagerService.ready || !root.row(root.second)) return
                root.click(root.second)
                root.check(TaskManagerPins.isPinned(root.second), "reopening still requires two activations")
                root.input.keyClick(Qt.Key_Return, Qt.NoModifier, 0)
                root.check(!root.dashboard.pendingUnpinKey && TaskManagerPins.isPinned(root.second),
                    "keyboard activation of the row also only toggles the column")
                root.input.keyClick(Qt.Key_Return, Qt.NoModifier, 0)
            } else if (root.phase === 9) {
                root.input.keyClick(Qt.Key_Tab, Qt.NoModifier, 0)
                root.check(root.button(root.second).activeFocus, "Tab reaches the explicit unpin action")
                root.input.keyClick(Qt.Key_Return, Qt.NoModifier, 0)
                root.check(!TaskManagerPins.isPinned(root.second) && !root.dashboard.pendingUnpinKey,
                    "keyboard activation of the X unpins the process")
                UiState.closeHakuMenu()
            } else if (root.phase === 10) {
                if (TaskManagerService.subscribers || TaskManagerService.collectorRunning) return
                console.info("HakuMenu Mini passed: explicit X unpin, identity refresh and background cancellation")
                Qt.quit()
                return
            }
            ++root.phase
        }
    }
}
