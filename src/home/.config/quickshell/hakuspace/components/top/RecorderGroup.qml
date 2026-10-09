import QtQuick
import "../"
import "../../services"
import Quickshell.Io
Row {
    TopModule {
        id: recMod
        text: ""
        visible: false
        Process {
            id: proc
            command: ["sh", "-c", "if [ -f /tmp/recording_time ]; then cat /tmp/recording_time; else echo ''; fi"]
            running: false
            onExited: (code, out) => { // qs <0.4
                // Not standard, but we skip for now
            }
        }
    }
}
