import QtQuick
import Quickshell
import "../../services"
import ".."

TopModule {
    id: root
    
    // Recording state remains visible without a width-changing time label.
    property bool compact: false
    property bool isRecording: Recorder.isRecording
    property string recordTime: Recorder.recordTime
    
    icon: isRecording ? "" : ""
    text: (!compact && isRecording && recordTime !== "") ? " " + recordTime + " " : ""
    tooltip: isRecording ? "Recording Time: " + recordTime : "Screen Recorder"
    
    borderWidth: 0
    isAccent: isRecording
    blink: isRecording
    blinkDuration: 500
    
    onClicked: Quickshell.execDetached([Env.binDir + "/record.sh"])
}
