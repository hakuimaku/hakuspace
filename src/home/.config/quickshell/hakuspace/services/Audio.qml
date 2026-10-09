pragma Singleton
import QtQuick
import Quickshell.Io

QtObject {
    id: root
    property int volume: -1
    property bool muted: false
    property bool pendingFeedback: false
    property var queuedCommands: []
    property bool actionBusy: false
    property bool hadSuccessfulAction: false
    signal userInteracted()
    signal userChanged()

    function refresh() {
        poll.running = false
        poll.running = true
    }

    function change(command) {
        queuedCommands.push(command)
        userInteracted()
        startNext()
    }

    // Serialize wpctl actions to preserve rapid key presses in order.
    function startNext() {
        if (actionBusy || queuedCommands.length === 0) return
        actionBusy = true
        action.command = ["bash", "-c", queuedCommands.shift()]
        action.running = true
    }

    property Timer pollTimer: Timer {
        interval: 2000
        repeat: true
        running: true
        onTriggered: root.refresh()
    }
    property Process poll: Process {
        running: true
        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]
        stdout: SplitParser {
            onRead: data => {
                var line = data.trim()
                if (!line.startsWith("Volume:")) return
                var value = parseFloat(line.split(" ")[1])
                if (!isNaN(value)) root.volume = Math.round(value * 100)
                root.muted = line.indexOf("[MUTED]") !== -1
                // Notify the OSD only after polling the resulting sink state.
                if (root.pendingFeedback) {
                    root.pendingFeedback = false
                    root.userChanged()
                }
            }
        }
    }
    property Process action: Process {
        onExited: exitCode => {
            root.actionBusy = false
            if (exitCode === 0) root.hadSuccessfulAction = true
            // Refresh once after the final command, then release the OSD feedback.
            if (root.queuedCommands.length > 0) {
                Qt.callLater(root.startNext)
            } else {
                if (root.hadSuccessfulAction) root.pendingFeedback = true
                root.hadSuccessfulAction = false
                root.refresh()
            }
        }
    }
}
