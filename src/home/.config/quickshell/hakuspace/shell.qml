import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import "services"
import "components"

ShellRoot {
    id: root
    
    IpcHandler {
        target: "shell"
        enabled: true
        function ping(): string { return "pong"; }
        function reload() { 
            Theme.reload();
            Quickshell.reload(); 
        }
        function quit() { Qt.quit(); }
    }
    
    IpcHandler {
        target: "picker"
        enabled: true
        function open(reqJsonPath: string, fifoPath: string) {
            console.log("Picker requested via IPC:", reqJsonPath, fifoPath);
        }
    }
    
    NotificationServer {
        id: notifServer
    }
    
    Variants {
        model: Quickshell.screens
        TopBar { modelData: modelData }
    }
    
    Variants {
        model: Quickshell.screens
        RoundedScreen { modelData: modelData }
    }
}
