pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "."
import "../config/SettingsCatalog.js" as Catalog

QtObject {
    id: root
    property bool ready: false
    property bool listing: false
    property bool loading: false
    property bool saving: false
    property bool openingExternal: false
    property bool validating: false
    property string validatingSnapshot: ""
    readonly property bool reloadSupported: selectedFileId === ({hyprland: "wm/hyprland-custom.lua", niri: "wm/niri-custom.kdl", mango: "wm/mango-custom.conf"})[WM.backendName]
    property string error: ""
    property string statusMessage: ""
    property var files: []
    property int skippedCount: 0
    property string selectedFileId: ""
    property string selectedPath: ""
    property string savedText: ""
    property string text: ""
    property string savedRevision: ""
    // A dirty file waits here until the user chooses Save, Discard, or Cancel.
    property string pendingFileId: ""
    property bool conflict: false
    // Process callbacks use these IDs/snapshots to ignore stale results and preserve newer edits.
    property string _readingFileId: ""
    property string _writingFileId: ""
    property string _writingSnapshot: ""
    property string _queuedFileId: ""
    property bool _switchAfterSave: false
    readonly property bool dirty: text !== savedText
    readonly property bool hasFile: selectedFileId.length > 0 && savedRevision.length > 0
    readonly property bool busy: listing || loading || saving || validating
    readonly property bool canSave: hasFile && dirty && !busy && !conflict && !text.includes("\0")
                            && unescape(encodeURIComponent(text)).length <= 96 * 1024
    readonly property string deployedScript: (Quickshell.env("HOME") || "") + "/.local/bin/hakucfg_editor_ctl.py"
    readonly property string envScript: Env.binDir + "/hakucfg_editor_ctl.py"
    readonly property string repoScript: Quickshell.shellPath("../../../../core/backend/user/hakucfg_editor_ctl.py")

    function command(action, fileId) {
        var result = ["sh", "-c", 'if [ -x "$1" ]; then ctl=$1; elif [ -x "$2" ]; then ctl=$2; elif [ -x "$3" ]; then ctl=$3; else ctl=hakucfg_editor_ctl.py; fi; shift 3; exec "$ctl" "$@"',
                      "--", deployedScript, envScript, repoScript, action]
        if (fileId) result.push(fileId)
        return result
    }
    function loadFiles() { refreshFiles() }
    function refreshFiles() {
        if (listing) return
        listing = true
        error = ""
        listProc.command = command("list")
        listProc.running = true
    }
    // Guard drafts before switching and queue reads while another read is active.
    function selectFile(fileId) {
        if (!fileId || fileId === selectedFileId) return
        if (dirty) { pendingFileId = fileId; return }
        if (saving) return
        pendingFileId = ""
        selectedFileId = fileId
        selectedPath = ""
        savedText = ""
        text = ""
        savedRevision = ""
        conflict = false
        error = ""
        statusMessage = ""
        if (readProc.running) { _queuedFileId = fileId; return }
        _read(fileId)
    }
    function _read(fileId) {
        _readingFileId = fileId
        loading = true
        readProc.command = command("read", fileId)
        readProc.running = true
    }
    function reload() {
        if (!selectedFileId || saving || dirty) return
        if (readProc.running) { _queuedFileId = selectedFileId; return }
        error = ""
        _read(selectedFileId)
    }
    function setText(value) { text = value; statusMessage = "" }
    function discard() { text = savedText; conflict = false; pendingFileId = ""; error = "" }
    function discardAndSwitch() {
        var next = pendingFileId
        discard()
        selectFile(next)
    }
    property string writeAction: "save-reload"
    // Explicit document saves never participate in preference autosave.
    function save(action) {
        if (!canSave && !(action === "restore-backup" && hasFile && !busy && !dirty)) return
        _writingFileId = selectedFileId
        _writingSnapshot = text
        saving = true
        error = ""
        statusMessage = ""
        writeAction = action || "save-reload"
        writeProc.command = command(writeAction, _writingFileId)
        writeProc.environment = { "HAKUSPACE_CONFIG_TEXT": _writingSnapshot,
                                  "HAKUSPACE_CONFIG_EXPECTED_REVISION": savedRevision }
        writeProc.running = true
    }
    function saveAndSwitch() {
        if (!pendingFileId || !canSave) return
        _switchAfterSave = true
        save("write")
    }
    // Validation reports unsupported validators without saving or reloading the document.
    function validateDraft() {
        if (!hasFile || busy || text.includes("\0") || unescape(encodeURIComponent(text)).length > 96 * 1024) return
        validating = true
        validatingSnapshot = text
        error = ""
        validator.command = command("validate", selectedFileId)
        validator.environment = {HAKUSPACE_CONFIG_TEXT: text}
        validator.running = true
    }
    property Process validator: Process {
        stdout: StdioCollector { id: validationOut }
        stderr: StdioCollector { id: validationErr }
        onExited: code => {
            root.validating = false
            if (code !== 0) { root.error = validationErr.text.trim() || "Validation failed"; return }
            try { var result = JSON.parse(validationOut.text); root.statusMessage = result.validationMessage + (root.text !== root.validatingSnapshot ? " · newer edits need validation" : "") }
            catch (error) { root.error = "Invalid validation response" }
        }
    }
    function openInVsCode() {
        if (!hasFile || openingExternal) return
        openingExternal = true
        error = ""
        openProc.command = command("open-vscode", selectedFileId)
        openProc.running = true
    }
    function clearSelection() {
        if (dirty || saving) return
        selectedFileId = ""
        selectedPath = ""
        savedText = ""
        text = ""
        savedRevision = ""
    }

    property Process listProc: Process {
        id: listProc
        stdout: StdioCollector { id: listOut }
        stderr: StdioCollector { id: listErr }
        onExited: (code, status) => {
            root.listing = false
            if (code !== 0) { root.error = listErr.text.trim() || "Could not list config files"; return }
            try {
                var data = JSON.parse(listOut.text)
                root.files = data.files || []
                root.skippedCount = data.skippedCount || 0
                root.ready = true
                var visibleFiles = Catalog.configFiles(root.files, WM.backendName, false)
                if (!root.selectedFileId && visibleFiles.length) root.selectFile(visibleFiles[0].id)
            } catch (e) { root.error = "Invalid file list response" }
        }
    }
    property Process readProc: Process {
        id: readProc
        stdout: StdioCollector { id: readOut }
        stderr: StdioCollector { id: readErr }
        onExited: (code, status) => {
            root.loading = false
            if (root._readingFileId === root.selectedFileId) {
                if (code !== 0) root.error = readErr.text.trim() || "Could not read selected file"
                else try {
                    var data = JSON.parse(readOut.text)
                    root.selectedPath = data.path
                    root.savedText = data.content
                    root.text = data.content
                    root.savedRevision = data.revision
                    root.conflict = false
                    root.error = ""
                } catch (e) { root.error = "Invalid file response" }
            }
            if (root._queuedFileId) {
                var next = root._queuedFileId
                root._queuedFileId = ""
                root._read(next)
            }
        }
    }
    // Accept only the submitted file; keep edits made after Save started.
    property Process writeProc: Process {
        id: writeProc
        stdout: StdioCollector { id: writeOut }
        stderr: StdioCollector { id: writeErr }
        onExited: (code, status) => {
            root.saving = false
            if (code !== 0) {
                root._switchAfterSave = false
                root.error = writeErr.text.trim() || "Could not save selected file"
                root.conflict = root.error.indexOf("conflict:") >= 0
                return
            }
            try {
                var data = JSON.parse(writeOut.text)
                if (data.id !== root._writingFileId || root.selectedFileId !== data.id) return
                root.savedText = data.content
                root.savedRevision = data.revision
                if (root.text === root._writingSnapshot) root.text = data.content
                root.statusMessage = (root.dirty ? "Saved earlier edits; newer edits remain unsaved" : "Saved — " + data.id) + (data.validationMessage ? " · " + data.validationMessage : "")
                root.conflict = false
                if (root._switchAfterSave && root.pendingFileId && !root.dirty) {
                    var next = root.pendingFileId
                    root.pendingFileId = ""
                    root.selectFile(next)
                }
                root._switchAfterSave = false
            } catch (e) {
                root._switchAfterSave = false
                root.error = "Invalid save response"
            }
        }
    }
    property Process openProc: Process {
        id: openProc
        stdout: StdioCollector { id: openOut }
        stderr: StdioCollector { id: openErr }
        onExited: (code, status) => {
            root.openingExternal = false
            if (code !== 0) root.error = openErr.text.trim() || "Could not open VS Code"
            else root.statusMessage = "Opened saved file in VS Code"
        }
    }
}
