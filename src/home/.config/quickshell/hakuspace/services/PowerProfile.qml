pragma Singleton
import QtQuick
import Quickshell.Io

QtObject {
    id: root
    property string profile: ""
    property bool refreshPending: false

    function refresh() {
        if (poll.running) {
            refreshPending = true
        } else {
            poll.running = true
        }
    }

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
        running: true
        onTriggered: root.refresh()
    }

    property Process poll: Process {
        running: true
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
