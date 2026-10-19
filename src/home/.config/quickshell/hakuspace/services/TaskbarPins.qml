pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "."

QtObject {
    id: root
    // Retain the last valid backend response when the shared JSONC file is broken.
    property var pins: []
    property string error: ""
    onErrorChanged: if (error) console.warn(error)
    property bool pendingReload: false
    readonly property bool busy: controller.running
    readonly property string path: Quickshell.env("HAKUSPACE_TASKBAR_PINS_FILE")
        || (Quickshell.env("HOME") || "") + "/hakucfg/config/taskbar-pin-apps"

    // Queue file notifications behind an in-flight pin mutation.
    function reload() {
        if (busy) { pendingReload = true; return }
        run("list", [])
    }
    // Resolve installed and source-tree controllers without interpolating application IDs.
    function run(action, args) {
        if (busy) return
        controller.command = ["sh", "-c",
            'for script in "$1" "$2" "$3"; do if [ -x "$script" ]; then shift 3; exec "$script" "$@"; fi; done; exit 127',
            "--", (Quickshell.env("HOME") || "") + "/.local/bin/taskbar_pins_ctl.py",
            Env.binDir + "/taskbar_pins_ctl.py", Quickshell.shellPath("../../../../core/backend/user/taskbar_pins_ctl.py"), action].concat(args)
        controller.running = true
    }
    // Pin actions share the same serialized backend as external CLI edits.
    function add(id) { run("add", [id]) }
    function remove(id) { run("remove", [id]) }
    function move(from, to) { run("move", [String(from), String(to)]) }
    Component.onCompleted: reload()

    property FileView sharedFile: FileView {
        path: root.path
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onTextChanged: root.reload()
        onLoadFailed: root.reload()
    }
    property Process controller: Process {
        stdout: StdioCollector { id: output }
        stderr: StdioCollector { id: diagnostic }
        onExited: (code, status) => {
            if (code !== 0) root.error = diagnostic.text.trim() || "Could not update taskbar pins"
            else {
                try {
                    var model = JSON.parse(output.text)
                    if (!Array.isArray(model)) throw new Error("Invalid pin model")
                    root.pins = model
                    root.error = ""
                } catch (error) { root.error = "Invalid taskbar pin response" }
            }
            if (root.pendingReload) {
                root.pendingReload = false
                Qt.callLater(root.reload)
            }
        }
    }
}
