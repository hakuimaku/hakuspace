import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "services"
import "components"

import "modules/picker"

ShellRoot {
    id: root

    Picker {
        id: pickerWindow
    }

    IpcHandler {
        target: "picker"
        enabled: true
        function open(fifo: string, jsonString: string) {
            try {
                var req = JSON.parse(jsonString);
                pickerWindow.open(fifo, req.prompt || "", req.items || [], req.password === true, req.noCustom === true);
            } catch (e) {
                console.log("Failed to parse picker request:", e);
            }
        }
    }

    IpcHandler {
        target: "shell"
        enabled: true
        function ping(): string { return "pong"; }
        function reload() {
            Quickshell.reload();
        }
        function quit() { Qt.quit(); }
    }

    Variants {
        model: Quickshell.screens
        TopBar {}
    }

    Variants {
        model: Quickshell.screens
        RoundedScreen {}
    }
}
