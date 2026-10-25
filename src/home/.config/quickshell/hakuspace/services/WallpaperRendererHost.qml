import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root
    required property var service
    property var states: ({})
    property Socket connection: null
    property bool faulted: false
    property bool stopping: false
    readonly property bool requested: !service.rendererSuspended && Object.keys(service.surfaces).length > 0
        && (service.current.kind === "video" || service.candidate.kind === "video")
    readonly property var processId: renderer.processId
    readonly property bool stopped: !renderer.running && !stopping
    readonly property string socketPath: Quickshell.env("XDG_RUNTIME_DIR") + "/hakuspace-wallpaper-" + Quickshell.processId + ".sock"
    // One snapshot preserves the preparation barrier and policy across every output.
    function sync() {
        if (!connection || !connection.connected) return
        connection.write(JSON.stringify({current: service.current, candidate: service.candidate,
            preferences: service.preferences, manuallyPaused: service.manuallyPaused,
            screens: Object.keys(service.surfaces)}) + "\n")
        connection.flush()
    }
    // Messages contain state transitions only; video frames stay inside the renderer.
    function receive(line) {
        try {
            var message = JSON.parse(line)
            if (message.name && !service.surfaces[message.name]) return
            if (message.type === "ready") service.surfaceReady(message.name, message.token)
            else if (message.type === "error" && (message.token === service.candidate.token
                    || !service.busy && message.token === service.current.token)) service.fail(message.message)
            else if (message.type === "ownership") service.takeOwnership()
            else if (message.type === "report") service.report(message.name, message.state)
            else if (message.type === "state") {
                var next = Object.assign({}, states); next[message.name] = message.state; states = next
            }
        } catch (error) { service.fail("Invalid native wallpaper response: " + error) }
    }
    // Finish an in-flight stop before reopening so a late exit cannot cancel a new video.
    function start() {
        if (requested && !faulted && !stopping && server.active) renderer.running = true
    }
    function resumeAfterExit() { stopping = false; start(); service.maybeCommit() }
    onRequestedChanged: {
        if (requested) start()
        else {
            states = ({})
            if (renderer.running) { stopping = true; renderer.running = false }
        }
    }
    Component.onCompleted: start()
    property Connections updates: Connections {
        target: root.service
        function onCurrentChanged() { root.sync() }
        function onCandidateChanged() {
            if (root.service.candidate.token) { root.faulted = false; root.start() }
            root.sync()
        }
        function onPreferencesChanged() { root.sync() }
        function onManuallyPausedChanged() { root.sync() }
        function onSurfacesChanged() {
            var next = ({})
            for (var name in root.service.surfaces) if (root.states[name]) next[name] = root.states[name]
            root.states = next
            root.sync()
        }
    }
    // The socket lives under the user's private runtime directory and is scoped by PID.
    property SocketServer server: SocketServer {
        path: root.socketPath
        active: root.requested && !root.faulted
        onActiveStatusChanged: if (active) root.start()
        handler: Socket {
            id: peer
            parser: SplitParser { onRead: data => root.receive(data) }
            onConnectionStateChanged: {
                if (connected) { root.connection = peer; root.sync() }
                else if (root.connection === peer) root.connection = null
            }
        }
    }
    property Process renderer: Process {
        command: ["quickshell", "-p", Quickshell.shellPath("components/wallpaper/WallpaperRenderer.qml")]
        environment: ({HAKUSPACE_WALLPAPER_RENDER_SOCKET: root.socketPath})
        running: false
        onExited: code => {
            root.connection = null
            root.states = ({})
            if (root.requested && !root.stopping) {
                root.faulted = true
                root.service.fail("Native wallpaper renderer exited (" + code + ")")
            }
            Qt.callLater(root.resumeAfterExit)
        }
    }
}
