pragma Singleton
import QtQuick
import Quickshell.Io

QtObject {
    id: root
    // Poll only while visible controls subscribe; actions still refresh immediately.
    property int subscribers: 0
    property int level: -1
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

    // Triggers an immediate poll of the current display backlight level.
    function refresh() {
        if (poll.running) refreshPending = true
        else poll.running = true
    }

    // Enqueues a brightnessctl command and schedules execution.
    function change(command) {
        queuedCommands.push(command)
        userInteracted()
        startNext()
    }

    // Serializes brightnessctl actions to preserve rapid key presses in order.
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
        // The first backlight device supplies both the current and maximum values.
        command: ["bash", "-c", "echo \"$(cat /sys/class/backlight/*/brightness 2>/dev/null | head -n1)/$(cat /sys/class/backlight/*/max_brightness 2>/dev/null | head -n1)\""]
        stdout: SplitParser {
            onRead: data => {
                var parts = data.trim().split("/")
                var value = parseInt(parts[0])
                var maximum = parseInt(parts[1])
                root.level = maximum > 0 && !isNaN(value) ? Math.round(value / maximum * 100) : -1
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
