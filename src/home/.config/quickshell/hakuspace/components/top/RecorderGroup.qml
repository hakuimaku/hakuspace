import QtQuick
import Quickshell
import Quickshell.Io
import "../../services"
import ".."

TopModule {
    id: root
    
    property bool isRecording: false
    property string recordTime: ""
    
    Timer {
        interval: 1000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: {
            pollProc.running = false
            pollProc.running = true
        }
    }
    
    Process {
        id: pollProc
        command: ["bash", "-c", "if [ -f /tmp/recording_pid ]; then echo \"T:$(cat /tmp/recording_time 2>/dev/null)\"; else echo \"STOPPED\"; fi"]
        stdout: SplitParser {
            onRead: data => {
                if (!data) return;
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
    
    visible: true
    
    icon: isRecording ? "" : ""
    text: (isRecording && recordTime !== "") ? " " + recordTime + " " : ""
    tooltip: isRecording ? "Recording Time: " + recordTime : "Screen Recorder"
    
    borderWidth: 0
    isAccent: isRecording
    blink: isRecording
    blinkDuration: 500
    
    Process {
        id: recordProc
        command: ["bash", "-c", "nohup " + Env.binDir + "/record.sh >/dev/null 2>&1 &"]
    }
    
    onClicked: {
        recordProc.running = false
        recordProc.running = true
    }
}
