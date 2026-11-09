import QtQuick
import Quickshell
import Quickshell.Io
import "../modules/picker"
import "../services"

Scope {
    id: root

    readonly property bool maintenanceBusy: pickerWindow.maintenanceBusy

    Picker {
        id: pickerWindow
    }

    // Status instantiates the sole native idle owner without a separate UI surface.
    IpcHandler {
        target: "idle"
        function status(): string { return IdleService.status() }
        function logs(): string { return IdleService.logs() }
        function inhibitStatus(): string { IdleService.refreshInhibit(); return JSON.stringify(IdleService.customInhibit) }
        function release(): string { return IdleService.release() }
        function acquire(): string { return IdleService.acquire() }
        function forceStage(stage: string): string { return IdleService.forceStage(stage) }
    }

    // Transition IPC changes presentation state only; bash owns the cutover.
    IpcHandler {
        target: "shellTransition"
        function status(): string { return ShellTransitionState.status() }
        function begin(mode: string): string { return ShellTransitionState.begin(mode) }
        function showChrome(): string { return ShellTransitionState.setChrome(true) }
        function hideChrome(): string { return ShellTransitionState.setChrome(false) }
        function release(): string { return ShellTransitionState.release(false) }
        function releaseAndQuit(): string { return ShellTransitionState.release(true) }
        function cancel(): string { return ShellTransitionState.cancel() }
    }

    // Hyprland navigation keeps compositor focus separate from overlay selection.
    IpcHandler {
        target: "windowNavigator"
        function next() { WindowNavigator.step(1) }
        function previous() { WindowNavigator.step(-1) }
        function commit() { WindowNavigator.commitSwitcher() }
        function cancel() { WindowNavigator.cancel() }
        function overviewToggle() { WindowNavigator.overviewToggle() }
        function overviewOpen() { WindowNavigator.open("overview", 0) }
        function overviewClose() { if (WindowNavigator.mode === "overview") WindowNavigator.cancel() }
        function status(): string { return WindowNavigator.status() }
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
            if (LockState.locked) return;
            Quickshell.reload(false);
        }
        function quit() {
            if (LockState.locked) return;
            Qt.quit();
        }
    }

    IpcHandler {
        target: "lock"
        enabled: true
        function lock(): string { return LockState.requestLock() }
        function status(): string { return LockState.status() }
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
}
