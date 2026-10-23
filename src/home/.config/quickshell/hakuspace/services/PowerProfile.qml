pragma Singleton
import QtQuick
import Quickshell.Io

QtObject {
    id: root
    // Poll only while visible controls subscribe; actions still refresh immediately.
    property int subscribers: 0
    property string profile: ""
    property bool refreshPending: false

    // Register visible controls and fetch their initial state.
    function acquire() {
        ++subscribers
        if (subscribers === 1) refresh()
    }

    // Stop recurring reads when the final visible control disappears.
    function release() {
        subscribers = Math.max(0, subscribers - 1)
    }

    // Triggers an immediate query of the active system power profile.
    function refresh() {
        if (poll.running) {
            refreshPending = true
        } else {
            poll.running = true
        }
    }

    // Cycles the system power profile to the next mode (performance -> balanced -> power-saver).
    function cycle() {
        if (action.running || profile === "") return
        var profiles = ["performance", "balanced", "power-saver"]
        var index = profiles.indexOf(profile)
        if (index < 0) return
        action.command = ["powerprofilesctl", "set", profiles[(index + 1) % profiles.length]]
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
        command: ["powerprofilesctl", "get"]
        onExited: {
            if (root.refreshPending) {
                root.refreshPending = false
                Qt.callLater(root.refresh)
            }
        }
        stdout: SplitParser {
            onRead: data => {
                var value = data.trim()
                if (value === "performance" || value === "balanced" || value === "power-saver")
                    root.profile = value
            }
        }
    }

    property Process action: Process {
        onExited: root.refresh()
    }
}
