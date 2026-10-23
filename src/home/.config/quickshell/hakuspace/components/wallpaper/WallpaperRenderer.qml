import QtQuick
import Quickshell
import Quickshell.Io

ShellRoot {
    id: root
    // This process imports Qt Multimedia only while native video is needed.
    property var current: ({})
    property var candidate: ({})
    property var preferences: ({playback: {pauseWhenFullscreen: true, unloadWhenHidden: true, unloadDelaySec: 20, loop: true}})
    property bool manuallyPaused: false
    property var screens: []
    property string transitionStrategy: Quickshell.env("HAKUSPACE_WALLPAPER_TRANSITION_STRATEGY") || "stagedStill"
    // The shell retains ownership of registration, commits and persisted state.
    function fileUrl(path) { return path ? "file://" + path.split("/").map(encodeURIComponent).join("/") : "" }
    function send(message) { socket.write(JSON.stringify(message) + "\n"); socket.flush() }
    function surfaceReady(name, token) { send({type: "ready", name: name, token: token}) }
    function fail(message) { send({type: "error", message: message}) }
    function report(name, state) { send({type: "report", name: name, state: state}) }
    function takeOwnership() { send({type: "ownership"}) }
    // Publish lightweight diagnostics without exposing renderer objects to the shell.
    function state(name, front, incoming, visible, unloaded) {
        send({type: "state", name: name, state: {
            front: front ? {record: front.record, unloaded: front.unloaded} : null,
            incoming: incoming ? {record: incoming.record} : null,
            visible: visible, unloaded: unloaded}})
    }
    Variants {
        model: Quickshell.screens.filter(screen => root.screens.includes(screen.name))
        NativeWallpaperWindow { controller: root }
    }
    Socket {
        id: socket
        path: Quickshell.env("HAKUSPACE_WALLPAPER_RENDER_SOCKET")
        Component.onCompleted: connected = true
        onConnectionStateChanged: if (!connected) Qt.quit()
        onError: Qt.exit(1)
        parser: SplitParser {
            onRead: data => {
                try {
                    var state = JSON.parse(data)
                    root.preferences = state.preferences
                    root.manuallyPaused = state.manuallyPaused
                    root.current = state.current
                    root.candidate = state.candidate
                    root.screens = state.screens
                    if (state.transitionStrategy) root.transitionStrategy = state.transitionStrategy
                } catch (error) { root.fail("Invalid wallpaper state: " + error) }
            }
        }
    }
}
