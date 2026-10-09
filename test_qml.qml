import QtQuick
import Quickshell
import Quickshell.Io

ShellRoot {
    Process {
        id: proc
        command: ["echo", "test_stdout"]
        running: true
        Component.onCompleted: {
            console.log("Process started")
        }
    }
}
