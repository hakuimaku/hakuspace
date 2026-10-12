pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "."

QtObject {
    id: root

    property bool ready: false

    property string bioPath: ""
    property string scratchPath: ""

    property string bioDraft: ""
    property string bioSaved: ""
    readonly property bool bioDirty: bioDraft !== bioSaved

    property string scratchDraft: ""
    property string scratchSaved: ""
    readonly property bool scratchDirty: scratchDraft !== scratchSaved

    property bool bioSaving: false
    property bool scratchSaving: false

    property string bioError: ""
    property string scratchError: ""

    // Version generation tracking for race-free saves
    property int _bioDraftGen: 0
    property int _bioWritingGen: 0
    property string _bioWritingSnapshot: ""
    property bool _bioPendingSave: false

    property int _scratchDraftGen: 0
    property int _scratchWritingGen: 0
    property string _scratchWritingSnapshot: ""
    property bool _scratchPendingSave: false
    property bool _scratchPendingFlush: false

    readonly property string _deployedScript: (Quickshell.env("HOME") || "") + "/.local/bin/text_store_ctl.sh"
    readonly property string _repoScript: Quickshell.shellPath("../../../../core/backend/user/text_store_ctl.sh")
    readonly property string _envBinScript: Env.binDir + "/text_store_ctl.sh"

    // Builds command descriptor and environment for executing text_store_ctl.sh.
    function _runCtl(action, envPayload) {
        return {
            command: [
                "sh", "-c",
                'if [ -x "$1" ]; then exec "$1" "$4"; elif [ -x "$2" ]; then exec "$2" "$4"; elif [ -x "$3" ]; then exec "$3" "$4"; else exec text_store_ctl.sh "$4"; fi',
                "--",
                root._deployedScript,
                root._envBinScript,
                root._repoScript,
                action
            ],
            environment: envPayload ? envPayload : ({})
        }
    }

    // -------------------------------------------------------------
    // Public API
    // -------------------------------------------------------------

    // Initializes storage directory layout and fetches initial file contents.
    function prepare() {
        if (prepareProc.running) return
        var cfg = _runCtl("prepare")
        prepareProc.command = cfg.command
        prepareProc.environment = cfg.environment
        prepareProc.running = true
    }

    // Sets uncommitted bio text and tracks revision generation counter.
    function setBioDraft(text) {
        var str = text !== undefined && text !== null ? String(text) : ""
        if (root.bioDraft === str) return
        root.bioDraft = str
        root._bioDraftGen++
    }

    // Commits dirty bio draft to storage via text_store_ctl.sh process.
    function saveBio() {
        if (!root.ready) return
        if (root.bioSaving) {
            root._bioPendingSave = true
            return
        }
        if (!root.bioDirty) return

        root._bioWritingGen = root._bioDraftGen
        root._bioWritingSnapshot = root.bioDraft
        root.bioSaving = true
        root.bioError = ""
        root._bioPendingSave = false

        var cfg = _runCtl("save-bio", ({
            "HAKUSPACE_TEXT_PAYLOAD": root._bioWritingSnapshot
        }))
        saveBioProc.command = cfg.command
        saveBioProc.environment = cfg.environment
        saveBioProc.running = true
    }

    // Reads bio text from file storage and updates local draft state.
    function reloadBio() {
        if (!root.ready || root.bioSaving || readBioProc.running) return
        var cfg = _runCtl("read-bio")
        readBioProc.command = cfg.command
        readBioProc.environment = cfg.environment
        readBioProc.running = true
    }

    // Updates scratchpad note draft and schedules debounced save.
    function setScratchDraft(text) {
        var str = text !== undefined && text !== null ? String(text) : ""
        if (root.scratchDraft === str) return
        root.scratchDraft = str
        root._scratchDraftGen++
        scheduleScratchSave()
    }

    // Restarts debounced autosave timer for scratchpad notes.
    function scheduleScratchSave() {
        scratchDebounceTimer.restart()
    }

    // Flushes pending scratchpad notes immediately without debounce delay.
    function flushScratch() {
        scratchDebounceTimer.stop()
        if (root.scratchSaving) {
            root._scratchPendingFlush = true
            return
        }
        _performScratchSave()
    }

    // Reads persisted scratchpad note content from storage.
    function reloadScratch() {
        if (!root.ready || root.scratchSaving || readScratchProc.running) return
        scratchDebounceTimer.stop()
        var cfg = _runCtl("read-scratch")
        readScratchProc.command = cfg.command
        readScratchProc.environment = cfg.environment
        readScratchProc.running = true
    }

    // Spawns background process to write current scratchpad snapshot to storage.
    function _performScratchSave() {
        if (!root.ready) return
        if (root.scratchSaving) {
            root._scratchPendingSave = true
            return
        }
        if (!root.scratchDirty) return

        root._scratchWritingGen = root._scratchDraftGen
        root._scratchWritingSnapshot = root.scratchDraft
        root.scratchSaving = true
        root.scratchError = ""
        root._scratchPendingSave = false
        root._scratchPendingFlush = false

        var cfg = _runCtl("save-scratch", ({
            "HAKUSPACE_TEXT_PAYLOAD": root._scratchWritingSnapshot
        }))
        saveScratchProc.command = cfg.command
        saveScratchProc.environment = cfg.environment
        saveScratchProc.running = true
    }

    // -------------------------------------------------------------
    // Autosave Debounce Timer (350 ms)
    // -------------------------------------------------------------
    property Timer scratchDebounceTimer: Timer {
        id: scratchDebounceTimer
        interval: 350
        repeat: false
        onTriggered: root._performScratchSave()
    }

    // -------------------------------------------------------------
    // Background Processes
    // -------------------------------------------------------------

    property Process prepareProc: Process {
        id: prepareProc
        stdout: StdioCollector { id: prepareStdout }
        stderr: StdioCollector { id: prepareStderr }

        onExited: (code, status) => {
            if (code === 0) {
                try {
                    var parsed = JSON.parse(prepareStdout.text.trim())
                    root.bioPath = parsed.bioPath || ""
                    root.scratchPath = parsed.scratchPath || ""
                } catch (e) {
                    root.bioError = "Failed to parse storage configuration"
                }

                // Initial read for Bio and Scratch
                var bioCfg = root._runCtl("read-bio")
                readBioProc.command = bioCfg.command
                readBioProc.environment = bioCfg.environment
                readBioProc.isInitial = true
                readBioProc.running = true

                var scratchCfg = root._runCtl("read-scratch")
                readScratchProc.command = scratchCfg.command
                readScratchProc.environment = scratchCfg.environment
                readScratchProc.isInitial = true
                readScratchProc.running = true
            } else {
                root.bioError = prepareStderr.text.trim() || "Storage preparation failed"
                root.scratchError = root.bioError
            }
        }
    }

    property Process readBioProc: Process {
        id: readBioProc
        property bool isInitial: false
        stdout: StdioCollector { id: readBioStdout }
        stderr: StdioCollector { id: readBioStderr }

        onExited: (code, status) => {
            if (code === 0) {
                root.bioSaved = readBioStdout.text
                root.bioDraft = readBioStdout.text
                root.bioError = ""
            } else {
                root.bioError = readBioStderr.text.trim() || "Failed to read bio"
            }
            if (readBioProc.isInitial && !readScratchProc.running) {
                root.ready = true
            }
        }
    }

    property Process readScratchProc: Process {
        id: readScratchProc
        property bool isInitial: false
        stdout: StdioCollector { id: readScratchStdout }
        stderr: StdioCollector { id: readScratchStderr }

        onExited: (code, status) => {
            if (code === 0) {
                root.scratchSaved = readScratchStdout.text
                root.scratchDraft = readScratchStdout.text
                root.scratchError = ""
            } else {
                root.scratchError = readScratchStderr.text.trim() || "Failed to read scratch"
            }
            if (readScratchProc.isInitial && !readBioProc.running) {
                root.ready = true
            }
        }
    }

    property Process saveBioProc: Process {
        id: saveBioProc
        stderr: StdioCollector { id: saveBioStderr }

        onExited: (code, status) => {
            root.bioSaving = false
            if (code === 0) {
                root.bioSaved = root._bioWritingSnapshot
                root.bioError = ""
                if (root._bioPendingSave || root.bioDirty) {
                    root._bioPendingSave = false
                    root.saveBio()
                }
            } else {
                root.bioError = saveBioStderr.text.trim() || "Failed to save bio"
                if (root._bioPendingSave) {
                    root._bioPendingSave = false
                    root.saveBio()
                }
            }
        }
    }

    property Process saveScratchProc: Process {
        id: saveScratchProc
        stderr: StdioCollector { id: saveScratchStderr }

        onExited: (code, status) => {
            root.scratchSaving = false
            if (code === 0) {
                root.scratchSaved = root._scratchWritingSnapshot
                root.scratchError = ""
                // Explicit close flush immediately fires latest save without timer debounce
                if (root._scratchPendingFlush) {
                    root._scratchPendingFlush = false
                    root._performScratchSave()
                } else if (root._scratchDraftGen > root._scratchWritingGen || root._scratchPendingSave) {
                    root.scheduleScratchSave()
                }
            } else {
                root.scratchError = saveScratchStderr.text.trim() || "Failed to autosave scratch"
                if (root._scratchPendingFlush) {
                    root._scratchPendingFlush = false
                    root._performScratchSave()
                } else if (root._scratchPendingSave) {
                    root.scheduleScratchSave()
                }
            }
        }
    }

    Component.onCompleted: {
        prepare()
    }
}
