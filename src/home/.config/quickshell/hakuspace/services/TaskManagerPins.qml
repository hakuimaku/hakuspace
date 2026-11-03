pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root
    // Pins identify a single process lifetime, never an application or a signal target.
    property var keys: []
    readonly property var pinnedKeys: keys
    readonly property var pinnedProcesses: {
        var lookup = Object.create(null)
        for (var process of TaskManagerService.processes) lookup[process.key] = process
        return keys.map(key => lookup[key]).filter(process => !!process)
    }
    property string error: ""
    property bool storageReady: false
    // Count only fresh complete process frames; disk reloads never count as misses.
    property var missingFramesByKey: ({})
    readonly property string path: Quickshell.env("HAKUSPACE_TM_PINS_FILE")
        || ((Quickshell.env("XDG_STATE_HOME") || ((Quickshell.env("HOME") || "") + "/.local/state")) + "/hakuspace/task_manager_pins.json")

    // Preserve the last valid model when a legacy file is malformed.
    function accept(text) {
        try {
            var parsed = JSON.parse(text || "[]")
            if (!Array.isArray(parsed) || !parsed.every(key => typeof key === "string" && /^[1-9]\d*:\d+$/.test(key)))
                throw new Error("Invalid process pins")
            keys = Array.from(new Set(parsed))
            error = ""
        } catch (exception) { error = "Could not read process pins: " + exception.message }
    }

    // Serialize the newest model after creating its state directory once.
    function save() {
        if (!storageReady) {
            if (!directory.running) directory.running = true
            return
        }
        pinFile.setText(JSON.stringify(keys))
    }
    function reload() { pinFile.reload() }
    function isPinned(process) { return !!process && keys.includes(process.key) }

    // Accept only identities currently supplied by the process model.
    function pin(process) {
        if (!process || isPinned(process) || !TaskManagerService.processes.some(row => row.key === process.key)) return
        keys = keys.concat([process.key])
        save()
    }
    function unpin(process) {
        if (!isPinned(process)) return
        keys = keys.filter(key => key !== process.key)
        save()
    }
    function toggle(process) { if (isPinned(process)) unpin(process); else pin(process) }

    // Keep counters bounded to the current pin set, including after explicit unpin.
    onKeysChanged: {
        var retained = ({})
        for (var key of keys) if (missingFramesByKey[key]) retained[key] = missingFramesByKey[key]
        missingFramesByKey = retained
    }

    // Three consecutive complete misses tolerate transient per-process /proc errors.
    function prune() {
        if (!TaskManagerService.ready || TaskManagerService.warmingUp || TaskManagerService.processTimestamp < 0
            || TaskManagerService.monitorRestartPending || TaskManagerService.monitorStopPending) return
        if (!TaskManagerService.processes.every(process => process && typeof process.key === "string" && /^[1-9]\d*:\d+$/.test(process.key))) return
        var live = new Set(TaskManagerService.processes.map(process => process.key))
        var missing = ({})
        var retained = keys.filter(key => {
            if (live.has(key)) return true
            var count = (missingFramesByKey[key] || 0) + 1
            if (count >= 3) return false
            missing[key] = count
            return true
        })
        missingFramesByKey = missing
        if (retained.length === keys.length) return
        keys = retained
        save()
    }

    Component.onCompleted: accept(pinFile.text())
    property FileView pinFile: FileView {
        path: root.path
        watchChanges: true
        blockLoading: true
        blockWrites: true
        printErrors: false
        atomicWrites: true
        onFileChanged: reload()
        onTextChanged: root.accept(text())
        onSaved: root.error = ""
        onSaveFailed: root.error = "Could not save process pins"
    }
    property Process directory: Process {
        command: ["mkdir", "-p", "--", root.path.substring(0, root.path.lastIndexOf("/")) || "."]
        onExited: code => {
            if (code !== 0) { root.error = "Could not create process pin storage"; return }
            root.storageReady = true
            root.save()
        }
    }
    property Connections processEvents: Connections {
        target: TaskManagerService
        function onReadyChanged() { if (!TaskManagerService.ready) root.missingFramesByKey = ({}) }
        function onWarmingUpChanged() { if (TaskManagerService.warmingUp) root.missingFramesByKey = ({}) }
        function onMonitorRestartPendingChanged() { if (TaskManagerService.monitorRestartPending) root.missingFramesByKey = ({}) }
        function onProcessTimestampChanged() { root.prune() }
    }
}
