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

    // The picker IPC request supplies a FIFO for the selected value.
    IpcHandler {
        target: "picker"
        enabled: true
        function open(fifo: string, jsonString: string) {
            try {
                var req = JSON.parse(jsonString);
                pickerWindow.open(fifo, req.prompt || "", req.items || [], req.password === true, req.noCustom === true);
            } catch (e) {
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

    // Route external level keys through the queued audio and brightness services.
    IpcHandler {
        target: "level"
        enabled: true
        function change(action: string) {
            switch (action) {
            case "volume-up": Audio.change("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 2%+"); break;
            case "volume-down": Audio.change("wpctl set-volume @DEFAULT_AUDIO_SINK@ 2%-"); break;
            case "volume-mute": Audio.change("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"); break;
            case "brightness-up": Brightness.change("brightnessctl -e4 -n2 set 2%+"); break;
            case "brightness-down": Brightness.change("brightnessctl -e4 -n2 set 2%-"); break;
            }
        }
    }

    Variants {
        model: Quickshell.screens
        TopBar {}
    }

    Variants {
        model: Quickshell.screens
        LevelOsdOverlay {}
    }

    Variants {
        model: Quickshell.screens
        RoundedScreen {}
    }
}
