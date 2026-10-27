pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../components/imageeditor/ImageEditorGeometry.js" as Geometry
import "../components/imageeditor/ImageEditorOps.js" as Ops

QtObject {
    id: root
    // Keep document data resident while the disposable workspace owns visual resources.
    readonly property string controller: Env.binDir + "/image_edit_ctl.py"
    property string sourcePath: ""
    property int sourceWidth: 0
    property int sourceHeight: 0
    property string mimeType: ""
    property string sourceFingerprint: ""
    property string mode: "file"
    property string screenName: ""
    property int rotation: 0
    property bool flipX: false
    property bool flipY: false
    property var cropRectNormalized: ({x: 0, y: 0, width: 1, height: 1})
    property var annotations: []
    property var undoStack: []
    property var redoStack: []
    property real outputScale: 1
    property int encodeQuality: 90
    property bool busy: false
    property bool dirty: false
    property bool closing: false
    property string lastError: ""
    property string originalState: ""
    // Tool settings and selection do not become document history entries.
    property string tool: "crop"
    property real cropRatio: 0
    property string inkColor: "#ff3b30"
    property real inkWidth: 0.006
    property real inkOpacity: 1
    property int selectedAnnotation: -1
    property string runtimeDirectory: ""
    property string pendingOutput: ""
    property bool awaitingAvatar: false
    readonly property int orientedWidth: rotation % 180 ? sourceHeight : sourceWidth
    readonly property int orientedHeight: rotation % 180 ? sourceWidth : sourceHeight
    readonly property var outputSize: Geometry.outputSize(cropRectNormalized, orientedWidth, orientedHeight, outputScale, mode === "avatar")
    readonly property bool ready: !!sourcePath && sourceWidth > 0 && sourceHeight > 0 && !busy

    // Decode file dialog URLs without interpreting literal percent signs in IPC paths.
    function localPath(value) {
        var path = String(value)
        if (path.indexOf("file:///") === 0) {
            try { return decodeURIComponent(path.slice(7)) } catch (error) { return "" }
        }
        return path
    }

    // Reject replacement requests while a live draft or export owns the editor.
    function openSession(path, requestedMode, requestedScreen) {
        path = localPath(path)
        if (!busy && closing && sourcePath === path && mode === requestedMode
                && UiState.activePanel === "imageEditor") { closing = false; return true }
        if (busy || sourcePath || UiState.nativeDialogOpen) return false
        if (path[0] !== "/" || /[\u0000-\u001f]/.test(path)) { lastError = "Choose an absolute local image path."; return false }
        var screens = Quickshell.screens
        if (!screens.length) return false
        screenName = screens.some(function(screen) { return screen.name === requestedScreen }) ? requestedScreen : screens[0].name
        mode = requestedMode
        sourcePath = path
        sourceWidth = 0; sourceHeight = 0
        rotation = 0; flipX = false; flipY = false
        annotations = []; undoStack = []; redoStack = []
        cropRectNormalized = {x: 0, y: 0, width: 1, height: 1}
        outputScale = 1; encodeQuality = 90
        cropRatio = mode === "avatar" ? 1 : 0
        tool = "crop"; selectedAnnotation = -1
        lastError = ""; dirty = false; closing = false
        UiState.imageEditorScreenName = screenName
        UiState.claimInteraction("imageEditor", screenName)
        UiState.activePanel = "imageEditor"
        busy = true
        inspectProc.command = ["python3", controller, "inspect", path]
        inspectProc.running = true
        return true
    }
    function openAvatar(path, screen) { return openSession(path, "avatar", screen || UiState.navigationScreenName) }
    function openScreenshot(path, screen) { return openSession(path, "screenshot", screen) }
    function open(path, screen) { return openSession(path, "file", screen) }

    // Cancel is disabled during commit; the original image is untouched before Save.
    function close() {
        if (busy) return false
        closing = true
        return true
    }
    function finishClose() {
        if (!closing && UiState.activePanel === "imageEditor") return
        if (UiState.activePanel === "imageEditor") UiState.activePanel = ""
        UiState.imageEditorScreenName = ""
        if (!busy) {
            sourcePath = ""; sourceWidth = 0; sourceHeight = 0
            annotations = []; undoStack = []; redoStack = []
            selectedAnnotation = -1; originalState = ""; dirty = false; closing = false
        }
    }
    function status() {
        return JSON.stringify({sourcePath: sourcePath, mode: mode, screenName: screenName,
            busy: busy, dirty: dirty, closing: closing, lastError: lastError,
            width: orientedWidth, height: orientedHeight, output: outputSize})
    }

    // Apply one complete document edit and keep its previous state available to undo.
    function commit(next) { if (!busy) Ops.commit(root, next) }
    function undo(redo) { if (!busy) Ops.undo(root, redo) }
    function reset() { if (originalState) commit(JSON.parse(originalState)) }
    function setCrop(rect) {
        if (rect.width * orientedWidth < 1 || rect.height * orientedHeight < 1) return
        var next = Ops.snapshot(root); next.cropRectNormalized = rect; commit(next)
    }
    function setRatio(ratio) {
        var next = Ops.snapshot(root)
        next.cropRatio = mode === "avatar" ? 1 : ratio
        next.cropRectNormalized = Geometry.ratioRect({x: 0, y: 0, width: 1, height: 1}, next.cropRatio, orientedWidth, orientedHeight)
        commit(next)
    }
    function setOutput(scale, quality) {
        var next = Ops.snapshot(root); next.outputScale = scale; next.encodeQuality = quality; commit(next)
    }

    // Compose orientation in rotate-then-mirror order and transform every document point.
    function orient(operation) {
        if (!ready) return
        var next = Ops.snapshot(root)
        if (operation === "cw" || operation === "ccw") {
            next.rotation = (next.rotation + (operation === "cw" ? 90 : 270)) % 360
            var oldFlip = next.flipX; next.flipX = next.flipY; next.flipY = oldFlip
        } else if (operation === "horizontal") next.flipX = !next.flipX
        else next.flipY = !next.flipY
        next.cropRectNormalized = Geometry.transformRect(next.cropRectNormalized, operation)
        next.annotations = next.annotations.map(function(item) {
            if (item.type === "arrow") {
                item.start = Geometry.transformPoint(item.start, operation)
                item.end = Geometry.transformPoint(item.end, operation)
            } else item.points = item.points.map(function(point) { return Geometry.transformPoint(point, operation) })
            return item
        })
        if (next.cropRatio && operation !== "horizontal" && operation !== "vertical") next.cropRatio = 1 / next.cropRatio
        commit(next)
    }
    function addAnnotation(item) {
        if (annotations.length >= 1000) { lastError = "The session annotation limit has been reached."; return }
        var count = item.type === "stroke" ? item.points.length : 0
        annotations.forEach(function(annotation) { if (annotation.type === "stroke") count += annotation.points.length })
        if (count > 200000) { lastError = "The session stroke point limit has been reached."; return }
        var next = Ops.snapshot(root); next.annotations.push(item); commit(next)
    }
    function replaceAnnotation(index, item) {
        var next = Ops.snapshot(root); next.annotations[index] = item; commit(next); selectedAnnotation = index
    }
    function deleteAnnotation() {
        if (selectedAnnotation < 0) return
        var next = Ops.snapshot(root); next.annotations.splice(selectedAnnotation, 1); commit(next)
    }
    function styleAnnotation(color, width, opacity) {
        inkColor = color; inkWidth = width; inkOpacity = opacity
        if (selectedAnnotation < 0) return
        var next = Ops.snapshot(root), item = next.annotations[selectedAnnotation]
        item.color = color; item.width = width; item.opacity = opacity
        var index = selectedAnnotation; commit(next); selectedAnnotation = index
    }

    // Stage a private JSON spec and start rendering only after FileView reports its save.
    function save(outputPath) {
        if (!ready || (mode === "avatar" && Avatar.busy)) return false
        pendingOutput = mode === "screenshot" ? sourcePath : localPath(outputPath || "")
        if (mode === "file" && !pendingOutput) return false
        busy = true; lastError = ""
        stageProc.running = true
        return true
    }
    function spec() {
        var value = Ops.snapshot(root)
        value.sourcePath = sourcePath; value.fingerprint = sourceFingerprint
        value.mode = mode; value.outputPath = mode === "avatar" ? runtimeDirectory + "/avatar.png" : pendingOutput
        return value
    }
    function fail(message) {
        lastError = message || "The image could not be exported."
        cleanup()
    }
    function cleanup() {
        specFile.path = ""
        if (runtimeDirectory) {
            cleanupProc.command = ["rm", "-rf", "--", runtimeDirectory]
            runtimeDirectory = ""
            cleanupProc.running = true
        } else busy = false
    }
    function errorText(text) {
        try { return JSON.parse(text).error || "Image operation failed." } catch (error) { return text.slice(0, 1000) || "Image operation failed." }
    }

    // Transfer an open session to an available output without losing its draft or save.
    property Connections screenEvents: Connections {
        target: Quickshell
        function onScreensChanged() {
            if (!root.sourcePath || Quickshell.screens.some(function(screen) { return screen.name === root.screenName })) return
            if (UiState.nativeDialogOwner === "imageEditor") UiState.endNativeDialog(UiState.nativeDialogSerial)
            if (!Quickshell.screens.length) { root.closing = true; if (!root.busy) root.finishClose(); return }
            root.screenName = Quickshell.screens[0].name
            UiState.imageEditorScreenName = root.screenName
            if (UiState.activePanel === "imageEditor") UiState.claimInteraction("imageEditor", root.screenName)
        }
    }
    property Connections avatarEvents: Connections {
        target: Avatar
        function onCommitted(success) {
            if (!root.awaitingAvatar) return
            root.awaitingAvatar = false
            if (success) root.closing = true
            else root.lastError = Avatar.lastError
            root.cleanup()
        }
    }
    property Process inspectProc: Process {
        id: inspectProc
        stdout: StdioCollector { id: inspectOutput }
        stderr: StdioCollector { id: inspectError }
        onExited: code => {
            root.busy = false
            if (code !== 0) { root.lastError = root.errorText(inspectError.text); return }
            try {
                var info = JSON.parse(inspectOutput.text)
                root.sourceWidth = info.width; root.sourceHeight = info.height
                root.mimeType = info.mime; root.sourceFingerprint = info.fingerprint
                root.cropRectNormalized = Geometry.ratioRect({x: 0, y: 0, width: 1, height: 1}, root.cropRatio, info.width, info.height)
                root.originalState = JSON.stringify(Ops.snapshot(root))
            } catch (error) { root.lastError = "The image metadata could not be read." }
        }
    }
    property Process stageProc: Process {
        id: stageProc
        command: ["mktemp", "-d", (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/hikai-image-editor-XXXXXX"]
        stdout: StdioCollector { id: stageOutput }
        onExited: code => {
            if (code !== 0 || !stageOutput.text.trim()) { root.fail("The export workspace could not be created."); return }
            root.runtimeDirectory = stageOutput.text.trim()
            specFile.path = root.runtimeDirectory + "/spec.json"
            specFile.setText(JSON.stringify(root.spec()))
        }
    }
    property FileView specFile: FileView {
        id: specFile
        atomicWrites: true
        printErrors: false
        onSaved: {
            renderProc.command = ["python3", root.controller, "render", path]
            renderProc.running = true
        }
        onSaveFailed: root.fail("The export specification could not be saved.")
    }
    property Process renderProc: Process {
        id: renderProc
        stdout: StdioCollector { id: renderOutput }
        stderr: StdioCollector { id: renderError }
        onExited: code => {
            if (code !== 0) { root.fail(root.errorText(renderError.text)); return }
            try {
                var result = JSON.parse(renderOutput.text)
                if (root.mode === "avatar") {
                    root.awaitingAvatar = true
                    Avatar.setAvatar(result.path)
                } else {
                    root.lastError = result.warning || ""
                    // A committed image closes the workspace even when clipboard delivery fails.
                    if (root.lastError) Quickshell.execDetached(["notify-send", "--app-name=HakuSpace", "Image saved", root.lastError])
                    root.closing = true
                    root.cleanup()
                }
            } catch (error) { root.fail("The export result could not be read.") }
        }
    }
    property Process cleanupProc: Process {
        id: cleanupProc
        onExited: {
            root.busy = false
            if (UiState.activePanel !== "imageEditor" || !Quickshell.screens.length) root.finishClose()
        }
    }
    Component.onDestruction: {
        if (runtimeDirectory) Quickshell.execDetached(["rm", "-rf", "--", runtimeDirectory])
    }
}
