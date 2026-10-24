import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root
    required property var service
    // One worker renders every output owned by the shell's chrome model.
    property var screens: Quickshell.screens
    readonly property bool requested: service.enabled && service.available && screens.length > 0
    readonly property var processId: renderer.processId
    readonly property string socketPath: Quickshell.env("XDG_RUNTIME_DIR") + "/hakuspace-cava-" + Quickshell.processId + "-" + Date.now() + ".sock"
    property Socket connection: null
    property bool stopping: false
    property int failures: 0
    // Settings and geometry cross the socket only when their values change.
    readonly property var configuration: ({enabled: requested, available: service.available,
        top: service.top, needsSurface: service.needsSurface, leftInset: service.leftInset,
        rightInset: service.rightInset, edgeInset: service.edgeInset, colorMode: service.colorMode,
        surfaceColor: service.surfaceColor.toString(), accentColor: service.accentColor.toString(),
        style: service.style, height: service.height, barCount: service.barCount,
        sensitivity: service.sensitivity, smoothing: service.smoothing, amplitude: service.amplitude,
        motionStrength: service.motionStrength, audioCommand: service.process.command,
        screens: screens.map(screen => screen.name)})

    // Spectrum data and animation clocks stay entirely inside the worker.
    function send(message) {
        if (!connection || !connection.connected) return
        connection.write(JSON.stringify(message) + "\n")
        connection.flush()
    }
    function sync() { send({type: "config", state: configuration}) }
    // Wait for a terminating worker before spawning its replacement.
    function start() {
        if (!root) return
        if (requested && server.active && !stopping && !retry.running) renderer.running = true
    }
    function restart() {
        if (connection && connection.connected) send({type: "restart"})
        else { retry.stop(); start() }
    }
    // A close acknowledgement is checked against the latest request before allowing exit.
    function receive(line) {
        try {
            if (line.length > 16384) throw new Error("oversized status")
            var message = JSON.parse(line)
            if (message.type === "closed") {
                if (requested) sync()
                else { stopping = true; send({type: "quit"}) }
            } else if (message.type === "state" && message.state && typeof message.state.running === "boolean"
                && typeof message.state.sleeping === "boolean" && typeof message.state.errorString === "string"
                && message.state.energies && ["overall", "bass", "mid", "treble", "peak"].every(key =>
                    typeof message.state.energies[key] === "number" && Number.isFinite(message.state.energies[key]))) {
                service.rendererState = message.state
                service.sleeping = message.state.sleeping
                service.errorString = message.state.errorString
                service._energies = message.state.energies
            } else throw new Error("unknown status")
        } catch (error) { service.errorString = "Invalid Cava renderer response: " + error }
    }
    onConfigurationChanged: sync()
    onRequestedChanged: {
        retry.stop()
        if (requested) start()
        sync()
    }
    Component.onCompleted: { service.renderer = root; start() }
    Component.onDestruction: if (service && service.renderer === root) service.renderer = null

    // The private PID-scoped socket also makes a worker exit when its parent disappears.
    property SocketServer server: SocketServer {
        path: root.socketPath
        active: root.requested || renderer.running
        onActiveStatusChanged: if (active) root.start()
        handler: Socket {
            id: peer
            parser: SplitParser { onRead: data => { if (root.connection === peer) root.receive(data) } }
            onConnectionStateChanged: {
                if (connected) { root.connection = peer; root.sync() }
                else if (root.connection === peer) root.connection = null
            }
        }
    }
    property Timer retry: Timer {
        onTriggered: root.start()
    }
    property Process renderer: Process {
        command: ["quickshell", "-p", Quickshell.shellPath("cava.qml")]
        environment: ({HAKUSPACE_CAVA_RENDER_SOCKET: root.socketPath})
        // Stream worker failures without retaining an unbounded output collector.
        stderr: SplitParser { onRead: data => console.warn("Cava renderer: " + data) }
        stdout: SplitParser {
            onRead: data => {
                if (data.includes("ERROR") || data.includes("caused by")) console.warn("Cava renderer: " + data)
            }
        }
        onExited: code => {
            root.connection = null
            root.service.rendererState = ({})
            root.service.sleeping = true
            root.service._energies = ({overall: 0, bass: 0, mid: 0, treble: 0, peak: 0})
            var unexpected = !root.stopping && root.requested
            root.stopping = false
            if (unexpected) {
                root.service.errorString = "Cava renderer exited (" + code + ")"
                retry.interval = Math.min(250 * Math.pow(2, Math.min(root.failures++, 4)), 3000)
                retry.restart()
            } else {
                root.failures = 0
                Qt.callLater(root.start)
            }
        }
    }
}
