import QtQuick
import Quickshell
import Quickshell.Io
import "services"
import "components"
import "components/base" as Base

ShellRoot {
    id: root
    // Keep profiling requests scoped to this disposable process.
    Component.onCompleted: Quickshell.watchFiles = false
    Variants {
        model: Quickshell.screens
        Item {
            id: profileHost
            required property var modelData
            /*TASK_MANAGER_LOADER*/
        }
    }
    /*TASK_MANAGER_IPC*/
    IpcHandler {
        target: "taskManagerProfile"
        function diagnostics(): string {
            return JSON.stringify({pid: Quickshell.processId, screens: Quickshell.screens.map(screen => ({
                name: screen.name, width: screen.width, height: screen.height, scale: screen.devicePixelRatio
            })), snapshot: TaskManagerService.snapshot})
        }
        function quit() { Qt.quit() }
    }
}
