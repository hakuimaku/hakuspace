import QtQuick
import Quickshell
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
    
    onClicked: Quickshell.execDetached([Env.binDir + "/record.sh"])
}
