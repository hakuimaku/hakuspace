import QtQuick
import Quickshell
import Quickshell.Io
import "services"
import "components"

ShellRoot {
    id: root
    // Trace every state edge, not only the settled subscriber count.
    property var surfaces: []
    property int phase: 0
    property int styleIndex: 0
    property int cycles: 0
    property int ticks: 0
    property int phaseTicks: 0
    onPhaseChanged: phaseTicks = 0
    property bool tracking: false
    property int collectorPid: 0
    property var subscriberSequence: []
    property var savedComponent: null
    property var page: null
    property var target: null
    readonly property var primary: surfaces.find(item => item.modelData.name === "HEADLESS-1")
    readonly property var secondary: surfaces.find(item => item.modelData.name === "HEADLESS-2")
    readonly property string source: styleIndex === 2 ? "dockbar" : styleIndex === 1 ? "taskbar" : "default"
    readonly property var standalone: {
        var owner = surfaces.find(item => item.modelData.name === UiState.taskManagerScreenName)
        return owner ? owner.utility.item : null
    }

    // Report the first broken lifecycle invariant before exiting the private session.
    function check(ok, message) {
        if (ok) return
        console.error("Handoff failed: style=" + styleIndex + " cycle=" + cycles + " phase=" + phase + " " + message)
        Qt.exit(1)
        throw new Error(message)
    }
    function find(item, predicate) {
        if (!item) return null
        if (predicate(item)) return item
        if (item.active === true && item.item) { var result = find(item.item, predicate); if (result) return result }
        var children = item.contentItem ? item.contentItem.data : item.children || []
        if (!item.contentItem && item.data && typeof item.data !== "function" && typeof item.data.length === "number") children = item.data
        for (var child of children) { var result = find(child, predicate); if (result) return result }
        return null
    }
    function openMini() {
        UiState.openHakuMenu(target.modelData.name, "theme", source,
            {x: 40, y: target.modelData.height - 60, width: 48, height: 48})
        UiState.setHakuPanelTab("taskManager")
    }
    function miniReady() {
        page = find(target.menu, item => typeof item.miniLoaded === "boolean")
        return !!page && !!page.mini && TaskManagerService.ready && !TaskManagerService.warmingUp
    }
    function startHandoff() {
        collectorPid = TaskManagerService.collectorPid
        subscriberSequence = [TaskManagerService.subscribers]
        var snapshot = TaskManagerService.snapshot
        var processes = TaskManagerService.processes
        var history = TaskManagerService.history
        tracking = true
        find(page.mini, item => item.objectName === "taskManagerMiniOpenFull").clicked()
        check(TaskManagerService.snapshot === snapshot && TaskManagerService.processes === processes
            && TaskManagerService.history === history, "handoff resets neither snapshot, model nor history")
        check(UiState.activePanel === "" && UiState.taskManagerOpen
            && UiState.taskManagerScreenName === target.modelData.name, "same-output handoff state")
    }

    Connections {
        target: TaskManagerService
        function onSubscribersChanged() {
            if (!root.tracking) return
            root.subscriberSequence = root.subscriberSequence.concat([TaskManagerService.subscribers])
            root.check(TaskManagerService.subscribers > 0, "subscriber count reached zero")
        }
        function onCollectorPidChanged() {
            if (root.tracking) root.check(TaskManagerService.collectorPid === root.collectorPid, "collector PID changed")
        }
        function onSnapshotChanged() {
            if (root.tracking) root.check(!!TaskManagerService.snapshot.seq, "blank telemetry frame")
        }
        function onProcessesChanged() {
            if (root.tracking) root.check(TaskManagerService.processes.length > 0, "process model cleared")
        }
        function onWarmingUpChanged() {
            if (root.tracking) root.check(!TaskManagerService.warmingUp, "warm-up replayed")
        }
    }
    Process {
        command: ["python3", Quickshell.env("HAKUSPACE_TEST_KEYBOARD")]
        running: true
        stdinEnabled: true
    }
    Component {
        id: detachedHost
        TaskManagerHost { requested: false; component: null }
    }
    Variants {
        model: Quickshell.screens
        Item {
            id: surface
            required property var modelData
            property alias menu: menu
            property alias utility: utility
            HakuMenuPanel { id: menu; modelData: surface.modelData }
            TaskManagerHost { id: utility; modelData: surface.modelData }
            Component.onCompleted: root.surfaces.push(this)
        }
    }
    Timer {
        interval: 30
        running: true
        repeat: true
        onTriggered: {
            root.check(++root.ticks < 6500, "timeout")
            root.check(++root.phaseTicks < 400, "phase timeout " + JSON.stringify({service: TaskManagerService.status(),
                panel: UiState.activePanel, output: UiState.hakuMenuScreenName,
                loaded: root.target ? root.target.menu.loadedCount : -1,
                miniActive: root.page && root.page.mini ? root.page.mini.active : false}))
            if (!root.primary || !root.secondary) return
            if (root.phase === 0) {
                ChromeLayout.topBarMode = root.styleIndex !== 1
                ChromeLayout.dockbarActive = root.styleIndex === 2
                root.target = root.primary
                root.cycles = 0
                root.openMini()
                root.phase = 1
            } else if (root.phase === 1) {
                if (!root.miniReady() || TaskManagerService.subscribers !== 1) return
                root.startHandoff()
                root.phase = 2
            } else if (root.phase === 2) {
                if (!root.standalone || !root.standalone.interactionReady || root.target.menu.loadedCount !== 0
                    || TaskManagerService.subscribers !== 1) return
                root.check(TaskManagerService.collectorPid === root.collectorPid && TaskManagerService.subscribers === 1
                    && !TaskManagerService.handoffScreenName, "collector and final lease ownership")
                root.check(UiState.ownsInteraction("taskManager", root.target.modelData.name), "standalone keyboard ownership")
                console.info("Handoff evidence " + JSON.stringify({style: root.styleIndex, cycle: root.cycles,
                    output: root.target.modelData.name, pidBefore: root.collectorPid, pidAfter: TaskManagerService.collectorPid,
                    subscribers: root.subscriberSequence}))
                root.tracking = false
                if (++root.cycles === 20) {
                    UiState.closeTaskManager()
                    root.phase = 4
                } else {
                    if (root.cycles % 5 !== 0) root.target = root.cycles % 2 ? root.secondary : root.primary
                    root.openMini()
                    root.phase = 3
                }
            } else if (root.phase === 3) {
                if (!root.miniReady() || TaskManagerService.subscribers !== 2) return
                if (root.cycles % 5 < 2) {
                    root.startHandoff()
                    root.phase = 2
                } else {
                    UiState.closeTaskManager()
                    root.phase = 1
                }
            } else if (root.phase === 4) {
                if (TaskManagerService.subscribers || TaskManagerService.collectorRunning) return
                if (++root.styleIndex < 3) root.phase = 0
                else {
                    root.styleIndex = 0
                    ChromeLayout.topBarMode = true
                    ChromeLayout.dockbarActive = false
                    root.target = root.primary
                    root.openMini()
                    root.phase = 5
                }
            } else if (root.phase === 5) {
                if (!root.miniReady()) return
                root.savedComponent = root.primary.utility.component
                root.primary.utility.component = null
                UiState.openTaskManagerFromHakuMenu()
                root.phase = 6
            } else if (root.phase === 6) {
                if (TaskManagerService.subscribers || TaskManagerService.collectorRunning || root.primary.menu.loadedCount) return
                root.check(!TaskManagerService.handoffScreenName && !UiState.taskManagerOpen
                    && !root.primary.utility.active, "failed loading releases transfer lease and loader")
                root.primary.utility.component = root.savedComponent
                TaskManagerService.beginHandoff(root.primary.modelData.name)
                UiState.closeTaskManager()
                root.check(TaskManagerService.subscribers === 0 && !TaskManagerService.handoffScreenName, "cancel before acquisition is idempotent")
                TaskManagerService.beginHandoff(root.primary.modelData.name)
                var foreign = detachedHost.createObject(root, {modelData: root.secondary.modelData})
                foreign.destroy()
                root.phase = 7
            } else if (root.phase === 7) {
                root.check(TaskManagerService.subscribers === 1, "foreign output teardown cannot release transfer")
                var owner = detachedHost.createObject(root, {modelData: root.primary.modelData})
                owner.destroy()
                root.phase = 8
            } else if (root.phase === 8) {
                if (TaskManagerService.subscribers || TaskManagerService.collectorRunning) return
                root.check(!TaskManagerService.handoffScreenName, "owner teardown releases pending transfer")
                UiState.hakuMenuScreenName = "absent-output"
                UiState.openTaskManagerFromHakuMenu()
                root.check(TaskManagerService.subscribers === 0 && !UiState.taskManagerOpen, "invalid output cannot retain a transfer lease")
                UiState.closeHakuMenu()
                console.info("HakuMenu Mini passed: 20 handoffs per presentation, two outputs, failure/cancel/teardown cleanup")
                Qt.quit()
            }
        }
    }
}
