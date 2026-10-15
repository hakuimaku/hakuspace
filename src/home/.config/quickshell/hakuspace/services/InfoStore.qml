pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "."

QtObject {
    id: root
    property bool ready: false
    property bool loading: false
    property string error: ""
    property var repo: ({ detected: false, version: "Not detected" })
    property var system: ({})
    property var hardware: ({})
    readonly property string deployedScript: (Quickshell.env("HOME") || "") + "/.local/bin/hakuspace_info_ctl.py"
    readonly property string envScript: Env.binDir + "/hakuspace_info_ctl.py"
    readonly property string repoScript: Quickshell.shellPath("../../../../core/backend/system/hakuspace_info_ctl.py")

    function load() { if (!ready) refresh() }
    function refresh() {
        if (loading) return
        loading = true
        error = ""
        infoProc.command = ["sh", "-c", 'if [ -x "$1" ]; then ctl=$1; elif [ -x "$2" ]; then ctl=$2; elif [ -x "$3" ]; then ctl=$3; else ctl=hakuspace_info_ctl.py; fi; exec "$ctl" read',
                            "--", deployedScript, envScript, repoScript]
        infoProc.running = true
    }

    property Process infoProc: Process {
        id: infoProc
        stdout: StdioCollector { id: infoOut }
        stderr: StdioCollector { id: infoErr }
        onExited: (code, status) => {
            root.loading = false
            if (code !== 0) { root.error = infoErr.text.trim() || "Could not read system information"; return }
            try {
                var data = JSON.parse(infoOut.text)
                root.repo = data.repo || root.repo
                root.system = data.system || ({})
                root.hardware = data.hardware || ({})
                root.ready = true
            } catch (e) { root.error = "Invalid system information response" }
        }
    }
}
