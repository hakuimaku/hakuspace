pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    readonly property string rawUser: Quickshell.env("USER") || Quickshell.env("LOGNAME") || "User"
    property string displayName: rawUser
    readonly property string subtitle: "--- The Hikaide ---"

    Component.onCompleted: {
        // One-shot user display name lookup; no recurring polling.
        probeProc.running = true
    }

    property Process probeProc: Process {
        id: probeProc
        command: ["sh", "-c", "getent passwd \"$USER\" 2>/dev/null | cut -d: -f5 | cut -d, -f1"]
        stdout: SplitParser {
            onRead: data => {
                var trimmed = data ? data.trim() : ""
                if (trimmed.length > 0) {
                    root.displayName = trimmed
                }
            }
        }
    }
}
