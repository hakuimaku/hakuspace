pragma Singleton
import QtQuick
import Quickshell.Io

QtObject {
    id: root
    property int level: -1
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

    // Serialize brightnessctl actions to preserve rapid key presses in order.
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
        // The first backlight device supplies both the current and maximum values.
        command: ["bash", "-c", "echo \"$(cat /sys/class/backlight/*/brightness 2>/dev/null | head -n1)/$(cat /sys/class/backlight/*/max_brightness 2>/dev/null | head -n1)\""]
        stdout: SplitParser {
            onRead: data => {
                var parts = data.trim().split("/")
                var value = parseInt(parts[0])
                var maximum = parseInt(parts[1])
                root.level = maximum > 0 && !isNaN(value) ? Math.round(value / maximum * 100) : -1
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
