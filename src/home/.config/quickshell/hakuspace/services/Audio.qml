pragma Singleton
import QtQuick
import Quickshell.Io

QtObject {
    id: root
    // Poll only while visible controls subscribe; actions still refresh immediately.
    property int subscribers: 0
    property int volume: -1
    property bool muted: false
    property bool refreshPending: false
    property bool pendingFeedback: false
    property var queuedCommands: []
    property bool actionBusy: false
    property bool hadSuccessfulAction: false
    signal userInteracted()
    signal userChanged()

    // Register visible controls and fetch their initial state.
    function acquire() {
        ++subscribers
        if (subscribers === 1) refresh()
    }

    // Stop recurring reads when the final visible control disappears.
    function release() {
        subscribers = Math.max(0, subscribers - 1)
    }

    // Triggers an immediate poll of the default audio sink volume and mute state.
    function refresh() {
        if (poll.running) refreshPending = true
        else poll.running = true
    }

    // Enqueues an audio adjustment command and schedules execution.
    function change(command) {
        queuedCommands.push(command)
        userInteracted()
        startNext()
    }

    // Serializes wpctl actions to preserve rapid key presses in order.
    function startNext() {
        if (actionBusy || queuedCommands.length === 0) return
        actionBusy = true
        action.command = ["bash", "-c", queuedCommands.shift()]
        action.running = true
    }

    property Timer pollTimer: Timer {
        interval: 2000
        repeat: true
        running: root.subscribers > 0
        onTriggered: root.refresh()
    }
    property Process poll: Process {
        running: false
        onExited: {
            if (root.refreshPending) {
                root.refreshPending = false
                Qt.callLater(root.refresh)
            }
        }
        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]
        stdout: SplitParser {
            onRead: data => {
                var line = data.trim()
                if (!line.startsWith("Volume:")) return
                var value = parseFloat(line.split(" ")[1])
                if (!isNaN(value)) root.volume = Math.round(value * 100)
                root.muted = line.indexOf("[MUTED]") !== -1
                // Notify the OSD only after polling the resulting sink state.
                if (root.pendingFeedback && !root.refreshPending) {
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
