pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "."

QtObject {
    id: root

    // Retain the last valid snapshot when external edits contain invalid JSON.
    property var items: []
    property string revision: ""
    property string error: ""
    readonly property bool busy: controller.running
    property bool pendingRefresh: false
    property string operation: "list"
    signal mutationFinished(string operation, bool success)
    onErrorChanged: if (error) console.warn("General menu: " + error)

    // Resolve the flat installation and source checkout without shell interpolation.
    function command(action, args) {
        return ["sh", "-c",
            'for script in "$1" "$2" "$3"; do if [ -f "$script" ]; then shift 3; exec python3 "$script" "$@"; fi; done; exit 127',
            "--", Env.binDir + "/general_menu_ctl.py",
            (Quickshell.env("HOME") || "") + "/.local/bin/general_menu_ctl.py",
            Quickshell.shellPath("../../../../core/backend/user/general_menu_ctl.py"), action].concat(args)
    }

    // Serialize UI requests and let callers keep their editor open when busy.
    function request(action, args) {
        if (busy) return false
        operation = action
        controller.command = command(action, args)
        controller.running = true
        return true
    }

    // Coalesce opening refreshes behind a pending mutation or launch.
    function refresh() {
        if (busy) { pendingRefresh = true; return }
        request("list", [])
    }

    // Dispatch editable custom actions by stable ID.
    function run(id) { return request("run", [id]) }

    // Require a loaded revision before allowing edits from the UI.
    function mutate(action, args) {
        if (!revision) { error = "Refresh General menu before editing"; return false }
        return request(action, args.concat(["--expected-revision", revision]))
    }

    // Insert a custom row after another user row or append it to the list.
    function add(payload, afterId) {
        var value = Object.assign({}, payload)
        if (afterId !== undefined && afterId !== "") value.afterId = afterId
        return mutate("add", [JSON.stringify(value)])
    }

    // Preserve stable identity while editing presentation or command fields.
    function update(id, payload) { return mutate("update", [id, JSON.stringify(payload)]) }

    // Remove exactly one mutable row.
    function remove(id) { return mutate("remove", [id]) }

    // Reorder only the user portion of the shared menu.
    function move(id, index) { return mutate("move", [id, String(index)]) }

    // Accept one complete backend response and refresh after revision conflicts.
    function accept(output, code) {
        try {
            var result = JSON.parse(output)
            if (code !== 0 || !result.ok) {
                error = result.error || "General menu request failed"
                if (result.error === "conflict") pendingRefresh = true
                return false
            }
            if (operation !== "run") {
                if (result.schemaVersion !== 1 || !Array.isArray(result.items) || typeof result.revision !== "string")
                    throw new Error("Invalid General menu snapshot")
                items = result.items
                revision = result.revision
            }
            error = ""
            return true
        } catch (failure) {
            error = "Invalid General menu response"
            return false
        }
    }

    property Process controller: Process {
        stdout: StdioCollector { id: output }
        stderr: StdioCollector { id: diagnostic }
        onExited: code => {
            var success = root.accept(output.text, code)
            if (!success && diagnostic.text.trim()) root.error += ": " + diagnostic.text.trim()
            if (root.operation !== "list" && root.operation !== "run")
                root.mutationFinished(root.operation, success)
            if (root.pendingRefresh) {
                root.pendingRefresh = false
                Qt.callLater(root.refresh)
            }
        }
    }
}
