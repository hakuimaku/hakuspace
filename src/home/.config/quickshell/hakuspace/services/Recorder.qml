pragma Singleton
import QtQuick
import Quickshell.Io

QtObject {
    id: root
    property bool isRecording: false
    property string recordTime: ""

    property Timer pollTimer: Timer {
        interval: 1000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: { if (!poll.running) poll.running = true }
    }
    // The recording script publishes status through these /tmp files.
    property Process poll: Process {
        command: ["bash", "-c", "if [ -f /tmp/recording_pid ]; then echo \"T:$(cat /tmp/recording_time 2>/dev/null)\"; else echo \"STOPPED\"; fi"]
        stdout: SplitParser {
            onRead: data => {
                var line = data.trim()
                if (line.startsWith("T:")) {
                    root.isRecording = true
                    root.recordTime = line.substring(2)
                } else if (line === "STOPPED") {
                    root.isRecording = false
                    root.recordTime = ""
                }
            }
        }
    }
}
