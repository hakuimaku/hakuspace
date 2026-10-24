import QtQuick
import Quickshell
import Quickshell.Io
import "../../services"
import "../" as Components
import "../base" as Base

ShellRoot {
    id: root
    // The parent supplies runtime settings and the absolute audio command.
    property var screens: []
    property bool configured: false
    property bool closeReported: false
    property bool quitting: false

    // Only compact diagnostics return to the shell; spectrum frames remain local.
    function send(message) {
        if (!socket.connected) return
        socket.write(JSON.stringify(message) + "\n")
        socket.flush()
    }
    function report() {
        send({type: "state", state: {running: CavaService.running, sleeping: CavaService.sleeping,
            errorString: CavaService.errorString, energies: CavaService._energies,
            enabled: CavaService.enabled, top: CavaService.top, height: CavaService.height,
            colorMode: CavaService.colorMode, color: CavaService.underbarColor.toString(),
            audioPid: CavaService.process.processId,
            malformedFrames: CavaService.malformedFrames, totalFrames: CavaService.totalFrames,
            screens: surfaces.instances.filter(owner => owner.active).map(owner => owner.modelData.name)}})
    }
    // Report visual completion before the parent commits to terminating this process.
    function finishClose() {
        if (!root) return
        if (!configured || quitting || closeReported || CavaService.enabled && CavaService.available) return
        if (surfaces.instances.some(owner => owner.active)) return
        closeReported = true
        report()
        send({type: "closed"})
    }
    // Validate the private control message before applying it to the worker's state.
    function configure(state) {
        if (!state || !Array.isArray(state.screens) || !state.screens.every(name => typeof name === "string")
            || !Array.isArray(state.audioCommand) || !state.audioCommand.length
            || !state.audioCommand.every(word => typeof word === "string")) throw new Error("invalid renderer configuration")
        var booleans = ["enabled", "available", "top", "needsSurface"]
        var numbers = ["leftInset", "rightInset", "edgeInset", "height", "barCount", "sensitivity", "smoothing", "amplitude", "motionStrength"]
        for (var key of booleans) if (typeof state[key] !== "boolean") throw new Error("invalid " + key)
        for (var key of numbers) if (typeof state[key] !== "number" || !Number.isFinite(state[key]) || state[key] < 0) throw new Error("invalid " + key)
        if (state.barCount < 2 || state.barCount > 512 || state.height > 300
            || !["surface", "accent"].includes(state.colorMode) || !["liquid", "capsule"].includes(state.style)
            || typeof state.surfaceColor !== "string" || typeof state.accentColor !== "string") throw new Error("invalid visual configuration")
        CavaService.process.command = state.audioCommand
        for (var key of booleans.concat(numbers, ["colorMode", "style", "surfaceColor", "accentColor"])) {
            if (key !== "enabled") CavaService[key] = state[key]
        }
        screens = state.screens
        configured = true
        closeReported = false
        CavaService.enabled = state.enabled
        report()
        Qt.callLater(finishClose)
    }

    Variants {
        id: surfaces
        model: Quickshell.screens.filter(screen => root.screens.includes(screen.name))
        onInstancesChanged: Qt.callLater(root.finishClose)
        Base.LifecycleLoader {
            id: owner
            required property var modelData
            requested: CavaService.enabled && CavaService.available
            onActiveChanged: { root.report(); Qt.callLater(root.finishClose) }
            Components.CavaUnderbarWindow { modelData: owner.modelData }
        }
    }
    Connections {
        target: CavaService
        function onRunningChanged() { root.report(); Qt.callLater(root.finishClose) }
        function onSleepingChanged() { root.report() }
        function onErrorStringChanged() { root.report() }
    }
    // Status sampling is independent of rendering and stops when Cava is disabled.
    Timer { interval: 1000; repeat: true; running: CavaService.enabled; onTriggered: root.report() }
    Socket {
        id: socket
        path: Quickshell.env("HAKUSPACE_CAVA_RENDER_SOCKET")
        Component.onCompleted: connected = true
        onConnectionStateChanged: if (!connected) Qt.quit()
        onError: Qt.exit(1)
        parser: SplitParser {
            onRead: data => {
                if (root.quitting) return
                try {
                    if (data.length > 16384) throw new Error("oversized control message")
                    var message = JSON.parse(data)
                    if (message.type === "config") root.configure(message.state)
                    else if (message.type === "restart") CavaService.restart()
                    else if (message.type === "quit") { root.quitting = true; Qt.quit() }
                    else throw new Error("unknown control message")
                } catch (error) { console.error("Invalid Cava control message: " + error); Qt.exit(1) }
            }
        }
    }
}
