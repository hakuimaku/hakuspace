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
    // Keep temporary capture ownership in the service across Dashboard close/reload.
    property Item pendingCropItem: null
    property string temporaryPath: ""
    property bool savingCrop: false
    onPendingCropItemChanged: if (!pendingCropItem && savingCrop) Qt.callLater(function() {
        if (!root.savingCrop || root.pendingCropItem || cropProbe.source || setProc.running || stageProc.running) return
        root.lastError = "The avatar crop was interrupted. Please try again."
        root.finishCrop(false)
    })
    signal cropCommitted()

    // Stage a fixed square PNG before the controller replaces the existing avatar.
    function saveCrop(item) {
        if (busy || !item) return
        busy = true
        savingCrop = true
        lastError = ""
        pendingCropItem = item
        stageProc.running = true
    }

    // Release temporary pixels and files on success, failure, or interrupted capture.
    function finishCrop(success) {
        pendingCropItem = null
        cropProbe.source = ""
        if (temporaryPath) {
            cleanupProc.command = ["rm", "-f", "--", temporaryPath]
            cleanupProc.running = true
            temporaryPath = ""
        }
        savingCrop = false
        busy = cleanupProc.running
        if (success) cropCommitted()
    }

    property Process stageProc: Process {
        command: ["mktemp", (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/hikai-avatar-XXXXXX.png"]
        stdout: StdioCollector { id: stageOutput }
        onExited: code => {
            root.temporaryPath = stageOutput.text.trim()
            if (code !== 0 || !root.temporaryPath || !root.pendingCropItem) {
                root.lastError = "The avatar crop could not be saved."
                root.finishCrop(false)
                return
            }
            var targetPath = root.temporaryPath
            var started = root.pendingCropItem.grabToImage(function(result) {
                if (!root.savingCrop || root.temporaryPath !== targetPath) return
                if (!result.saveToFile(targetPath)) {
                    root.lastError = "The avatar crop could not be saved."
                    root.finishCrop(false)
                    return
                }
                root.pendingCropItem = null
                cropProbe.source = "file://" + root.temporaryPath
            }, Qt.size(512, 512))
            if (!started) { root.lastError = "The avatar crop could not be saved."; root.finishCrop(false) }
        }
    }
    property Process cleanupProc: Process { onExited: root.busy = false }
    property Image cropProbe: Image {
        sourceSize: Qt.size(512, 512)
        cache: false
        visible: false
        onStatusChanged: {
            if (!root.savingCrop) return
            if (status === Image.Error || (status === Image.Ready && (implicitWidth !== 512 || implicitHeight !== 512))) {
                root.lastError = "The avatar crop could not be opened."
                root.finishCrop(false)
            } else if (status === Image.Ready) {
                setProc.pendingPath = root.temporaryPath
                setProc.command = [root.ctlScript, "set", root.temporaryPath]
                setProc.running = true
            }
        }
    }

    // Queries current avatar path from avatar_ctl.sh.
    function refresh() {
        if (queryProc.running) return
        queryProc.running = true
    }

    // Assigns and commits a new avatar image path via avatar_ctl.sh.
    function setAvatar(localPath) {
        if (!localPath || busy) return
        busy = true
        lastError = ""
        setProc.pendingPath = localPath
        setProc.command = [root.ctlScript, "set", localPath]
        setProc.running = true
    }

    // Reports image decoding failure message for error banner presentation.
    function reportDecodeError(msg) {
        lastError = msg ? msg : "This image could not be opened."
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
            if (code === 0 && setProc.outPath.length > 0) {
                root.lastError = ""
                root.path = setProc.outPath
                root.revision += 1
                root.source = "file://" + setProc.outPath
            } else {
                root.lastError = "The avatar could not be saved. Your previous avatar is still selected."
            }
            if (root.savingCrop) root.finishCrop(code === 0 && setProc.outPath.length > 0)
            else root.busy = false
        }
    }
}
