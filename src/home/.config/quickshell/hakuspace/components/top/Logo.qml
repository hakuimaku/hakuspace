import QtQuick
import Quickshell
import Quickshell.Io
import "../"

TopModule {
    text: "󰮯"
    isAccent: true
    
    Process {
        id: menuProc
        command: ["sh", "-c", "hakumenu.sh"]
        running: false
    }
    
    onClicked: {
        menuProc.running = true;
    }
}
