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
            console.log("[picker] IpcHandler.open called. FIFO:", fifo, "Length:", jsonString.length);
            try {
                var req = JSON.parse(jsonString);
                console.log("[picker] JSON parsed. Prompt:", req.prompt, "Items:", (req.items ? req.items.length : 0), "Password:", req.password, "NoCustom:", req.noCustom);
                pickerWindow.open(fifo, req.prompt || "", req.items || [], req.password === true, req.noCustom === true);
            } catch (e) {
                console.log("[picker] Failed to parse picker request:", e, "JSON string:", jsonString.substring(0, 200));
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
