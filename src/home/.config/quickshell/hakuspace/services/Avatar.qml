pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    readonly property string ctlScript: Env.binDir + "/avatar_ctl.sh"

    property string path: ""
    property string source: ""
    readonly property bool hasAvatar: path.length > 0
    property bool busy: false
    property string lastError: ""
    property int revision: 0

    function refresh() {
        if (queryProc.running) return
        queryProc.running = true
    }

    function setAvatar(localPath) {
        if (!localPath || busy) return
        busy = true
        lastError = ""
        setProc.pendingPath = localPath
        setProc.command = [root.ctlScript, "set", localPath]
        setProc.running = true
    }

    function reportDecodeError(msg) {
        lastError = msg ? msg : "Image format not supported by runtime"
    }

    Component.onCompleted: {
        refresh()
    }

    property Process queryProc: Process {
        id: queryProc
        property string queryOutput: ""

        command: [root.ctlScript, "current"]
        stdout: SplitParser {
            onRead: data => {
                var p = data.trim()
                if (p.length > 0) queryProc.queryOutput = p
            }
        }
        onStarted: {
            queryProc.queryOutput = ""
        }
        onExited: (code, status) => {
            if (code === 0 && queryProc.queryOutput.length > 0) {
                root.path = queryProc.queryOutput
                root.source = "file://" + queryProc.queryOutput
            } else {
                root.path = ""
                root.source = ""
            }
        }
    }

    property Process setProc: Process {
        id: setProc
        property string pendingPath: ""
        property string outPath: ""
        property string errText: ""

        stdout: SplitParser {
            onRead: data => {
                var line = data.trim()
                if (line.length > 0) setProc.outPath = line
            }
        }
        stderr: SplitParser {
            onRead: data => {
                var line = data.trim()
                if (line.length > 0) setProc.errText = line
            }
        }
        onStarted: {
            setProc.outPath = ""
            setProc.errText = ""
        }
        onExited: (code, status) => {
            root.busy = false
            if (code === 0 && setProc.outPath.length > 0) {
                root.lastError = ""
                root.path = setProc.outPath
                root.revision += 1
                root.source = "file://" + setProc.outPath
            } else {
                root.lastError = setProc.errText.length > 0 ? setProc.errText : "Failed to set avatar"
            }
        }
    }
}
