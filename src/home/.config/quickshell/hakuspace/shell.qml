//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "services"
import "components"

import "modules/picker"

ShellRoot {
    id: root

    PersistentProperties {
        id: notificationMemory
        reloadableId: "hakuspace-notification-records"
        property string recordsJson: "[]"
        property int nextKey: 1
        // Restore history before the native server activates.
        onLoaded: NotificationStore.start(notificationMemory)
    }

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
                UiState.closeHakuMenu();
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
            Quickshell.reload(false);
        }
        function quit() { Qt.quit(); }
    }

    IpcHandler {
        target: "hakumenu"
        function open(screenName: string) {
            for (var screen of Quickshell.screens) {
                if (screen.name === screenName) {
                    UiState.openHakuMenu(screenName)
                    return
                }
            }
        }
        function close() { UiState.closeHakuMenu() }
    }

    IpcHandler {
        target: "notif"
        function toggleCenter() {
            if (!NotificationStore._started || Quickshell.screens.length === 0) return
            var screen = Quickshell.screens[0]
            UiState.toggleNotifications(screen.name, screen.width - Theme.pad - Theme.fontSize * 2,
                                        Theme.fontSize * 2)
        }
        function toggleDnd() { NotificationStore.toggleDnd() }
        function clearAll() { NotificationStore.clearAll() }
        function count(): string { return String(NotificationStore.count) }
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
        TrayMenuPanel {}
    }

    Variants {
        model: Quickshell.screens
        NotificationCenterPanel {}
    }

    Variants {
        model: Quickshell.screens
        HakuMenuPanel {}
    }

    Variants {
        model: Quickshell.screens
        NotificationPopup {}
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
