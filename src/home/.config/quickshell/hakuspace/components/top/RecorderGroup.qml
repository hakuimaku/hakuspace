import QtQuick
import Quickshell.Io
import "../../services"
import ".."

TopModule {
    id: root
    
    property bool isRecording: Recorder.isRecording
    property string recordTime: Recorder.recordTime
    
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
