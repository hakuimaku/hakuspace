import QtQuick
import Quickshell
import Quickshell.Io
import "services"

ShellRoot {
    id: root
    // Exercise real worker IPC, audio ownership, reversal, recovery and active reload.
    property int phase: 0
    property int ticks: 0
    property var workerPid: 0
    property var audioPid: 0
    // Record audio children so the runner can detect orphaned backends after shutdown.
    property var audioPids: []
    PersistentProperties {
        id: memory
        reloadableId: "cava-worker-lifecycle"
        property bool reloaded: false
        onLoaded: if (reloaded) root.phase = 10
    }
    CavaRendererHost { id: host; service: CavaService }
    Process { id: killer }
    Connections {
        target: CavaService
        function onRendererPidChanged() {
            if (CavaService.rendererPid > 0) console.log("rendererPid=" + CavaService.rendererPid)
        }
        function onRendererStateChanged() {
            var pid = CavaService.rendererState.audioPid
            if (pid > 0 && !root.audioPids.includes(pid)) {
                root.audioPids.push(pid)
                console.log("audioPid=" + pid)
            }
        }
    }
    // Make failure output identify the current process-lifetime transition.
    function check(condition, message) {
        if (condition) return
        console.error("Cava renderer failed at " + phase + ": " + message + " " + CavaService.errorString)
        Qt.exit(1)
        throw new Error(message)
    }
    function start() {
        CavaService.process.command = ["python3", Quickshell.shellPath("cava-fixture.py")]
        CavaService.start()
    }
    Timer {
        interval: 20; running: true; repeat: true
        onTriggered: {
            root.check(++root.ticks < 1000, "timeout: " + JSON.stringify(CavaService.rendererState)
                + " connected=" + !!(host.connection && host.connection.connected))
            var state = CavaService.rendererState
            if (root.phase === 0) {
                root.check(!CavaService.rendererPid, "disabled state has no worker")
                root.start()
                root.phase = 1
            } else if (root.phase === 1 && CavaService.running && CavaService.totalFrames > 2) {
                root.workerPid = CavaService.rendererPid
                root.audioPid = state.audioPid
                root.check(root.workerPid > 0 && root.workerPid !== Quickshell.processId, "renderer is a different process")
                root.check(!CavaService.process.running && CavaService._parser === null && !CavaService.bars.length,
                    "shell owns no audio parser, process or spectrum buffers")
                root.check(state.screens.length === Quickshell.screens.length && !CavaService.sleeping, "worker renders outputs and receives audio")
                AppState.cavaTopState = false
                AppState.cavaColorMode = "accent"
                CavaService.height = 88
                Theme.accent = "#7f91c3"
                root.phase = 2
            } else if (root.phase === 2 && !state.top && state.height === 88 && state.color === "#7f91c3") {
                CavaService.stop()
                root.phase = 3
            } else if (root.phase === 3 && state.enabled === false) {
                root.check(CavaService.rendererPid === root.workerPid && state.screens.length > 0, "close animation retains its worker")
                CavaService.start()
                root.phase = 4
            } else if (root.phase === 4 && state.enabled && CavaService.running && CavaService.totalFrames > 2) {
                root.check(CavaService.rendererPid === root.workerPid, "reopening reverses without replacing the worker")
                root.audioPid = state.audioPid
                CavaService.restart()
                root.phase = 5
            } else if (root.phase === 5 && CavaService.running && state.audioPid !== root.audioPid && CavaService.totalFrames > 2) {
                root.check(CavaService.rendererPid === root.workerPid, "audio restart keeps the renderer")
                killer.command = ["kill", "-TERM", String(root.workerPid)]
                killer.running = true
                root.phase = 6
            } else if (root.phase === 6 && CavaService.running && CavaService.rendererPid > 0 && CavaService.rendererPid !== root.workerPid) {
                root.check(!CavaService.process.running, "recovery does not start audio in the shell")
                host.screens = []
                root.phase = 7
            } else if (root.phase === 7 && !CavaService.rendererPid) {
                host.screens = Quickshell.screens
                root.phase = 8
            } else if (root.phase === 8 && CavaService.running && CavaService.totalFrames > 2) {
                memory.reloaded = true
                root.phase = 9
                Quickshell.reload(false)
            } else if (root.phase === 10) {
                CavaService.start()
                root.phase = 11
            } else if (root.phase === 11 && CavaService.running && CavaService.totalFrames > 2) {
                CavaService.stop()
                root.phase = 12
            } else if (root.phase === 12 && !CavaService.rendererPid) {
                console.log("Hikai Cava renderer checks passed")
                Qt.quit()
            }
        }
    }
}
