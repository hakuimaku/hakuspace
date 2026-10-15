import QtQuick
import Quickshell.Io
import "../../services"

QtObject {
    id: root
    property var pins: []
    property bool loading: false
    property string errorMessage: ""
    property string rawOutput: ""
    property string pendingCommand: ""

    // Refresh the one pin list shared by the rail and manager.
    function reload() {
        rawOutput = ""
        errorMessage = ""
        loading = true
        listProc.running = false
        listProc.running = true
    }

    // Run one validated backend operation.
    function run(command, target, expectedHash) {
        if (mutateProc.running) return
        errorMessage = ""
        pendingCommand = command
        var args = [Env.binDir + "/sidebar_pins_ctl.py", command, target]
        if (expectedHash !== undefined) args.push(expectedHash)
        mutateProc.command = args
        mutateProc.running = true
    }

    function launch(index) { if (index >= 0 && index < pins.length) run("launch", String(index)) }
    function remove(index) {
        if (index >= 0 && index < pins.length)
            run("remove", String(pins[index]._rawIndex), pins[index]._rawHash)
    }
    function addFile(path) { run("add-file", path) }
    function addFolder(path) { run("add-folder", path) }

    property Process listProc: Process {
        command: [Env.binDir + "/sidebar_pins_ctl.py", "list"]
        stdout: SplitParser { onRead: data => root.rawOutput += data }
        onExited: (code, status) => {
            root.loading = false
            if (code !== 0) { root.errorMessage = "Could not load pins"; return }
            try {
                var parsed = JSON.parse(root.rawOutput.trim())
                root.pins = Array.isArray(parsed) ? parsed : []
            } catch (error) { root.errorMessage = "Invalid pin data" }
        }
    }
    property Process mutateProc: Process {
        onExited: (code, status) => {
            if (code !== 0) {
                if (root.pendingCommand === "remove") root.reload()
                root.errorMessage = "Could not " + root.pendingCommand
                return
            }
            if (root.pendingCommand !== "launch") root.reload()
        }
    }
}
