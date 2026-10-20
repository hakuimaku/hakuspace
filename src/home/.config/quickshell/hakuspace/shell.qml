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
        target: "navigation"
        enabled: true
        function openDefault() {
            if (Quickshell.screens.length > 0)
                UiState.openNavigation(Quickshell.screens[0].name, ScreenGeometry.fallbackModuleAnchor(Quickshell.screens[0].name, Theme.pad, Theme.fontSize * 1.8))
        }
        function open(screenName: string) {
            for (var screen of Quickshell.screens) {
                if (screen.name === screenName) {
                    UiState.openNavigation(screenName, ScreenGeometry.fallbackModuleAnchor(screenName, Theme.pad, Theme.fontSize * 1.8))
                    return
                }
            }
        }
        function openDashboard() {
            if (Quickshell.screens.length > 0) {
                UiState.openNavigation(Quickshell.screens[0].name, ScreenGeometry.fallbackModuleAnchor(Quickshell.screens[0].name, Theme.pad, Theme.fontSize * 1.8))
                UiState.beginNavigationHandoff("dashboard")
            }
        }
        function toggleDefault() {
            if (Quickshell.screens.length > 0)
                UiState.toggleNavigation(Quickshell.screens[0].name, ScreenGeometry.fallbackModuleAnchor(Quickshell.screens[0].name, Theme.pad, Theme.fontSize * 1.8))
        }
        function close() { UiState.closeNavigation() }
        function status(): string {
            return JSON.stringify({
                activePanel: UiState.activePanel,
                navigationMode: UiState.navigationMode,
                cava: {
                    dashboardRequested: Cava.dashboardRequested,
                    dashboardSubscribers: Cava._dashboardSubscribers,
                    shouldRun: Cava.shouldRun,
                    soundPresent: Cava.soundPresent,
                    audioVisible: Cava.audioVisible,
                    levelsLength: (Cava.levels ? Cava.levels.length : 0),
                    levelsSample: (Cava.levels ? Cava.levels.slice(0, 4) : []),
                    bars: Cava.bars
                },
                media: {
                    playing: Media.playing,
                    title: Media.title,
                    artist: Media.artist
                },
                center: {
                    baseMode: CenterState.baseMode,
                    centerMode: CenterState.centerMode
                },
                sysstats: {
                    cpu: SysStats.cpu,
                    cpuUsedStr: SysStats.cpuUsedStr,
                    ram: SysStats.ram,
                    ramUsedStr: SysStats.ramUsedStr,
                    gpu: SysStats.gpu,
                    gpuMemory: SysStats.gpuMemory,
                    gpuMemoryUsedStr: SysStats.gpuMemoryUsedStr,
                    hasGpu: SysStats.hasGpu,
                    hasGpuMemory: SysStats.hasGpuMemory,
                    mountsCount: (SysStats.mounts ? SysStats.mounts.length : 0),
                    mounts: SysStats.mounts,
                    extendedSubscribers: SysStats._extendedSubscribers
                }
            })
        }
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
        function openDefault() {
            if (Quickshell.screens.length > 0)
                UiState.openHakuMenu(Quickshell.screens[0].name)
        }
        function close() { UiState.closeHakuMenu() }
        function setMode(mode: string) { UiState.setHakuMenuMode(mode) }
    }

    IpcHandler {
        target: "wallpaper"
        enabled: true
        function open(screenName: string) {
            for (var screen of Quickshell.screens) {
                if (screen.name === screenName) {
                    UiState.openWallpaper(screenName)
                    return
                }
            }
        }
        function openDefault() {
            if (Quickshell.screens.length > 0)
                UiState.openWallpaper(Quickshell.screens[0].name)
        }
        function toggleDefault() {
            if (Quickshell.screens.length > 0)
                UiState.toggleWallpaper(Quickshell.screens[0].name)
        }
        function close() { UiState.closeWallpaper() }
    }

    IpcHandler {
        target: "actionMenu"
        enabled: true
        function open(screenName: string, flow: string) {
            for (var screen of Quickshell.screens) {
                if (screen.name === screenName) {
                    UiState.openActionMenu(screenName, flow)
                    return
                }
            }
        }
        function openDefault(flow: string) {
            if (Quickshell.screens.length > 0)
                UiState.openActionMenu(Quickshell.screens[0].name, flow)
        }
        function toggleDefault(flow: string) {
            if (Quickshell.screens.length > 0)
                UiState.toggleActionMenu(Quickshell.screens[0].name, flow)
        }
        function close() { UiState.closeActionMenu() }
        function scrollNext() { UiState.actionMenuScrollNextRequested() }
        function scrollPrevious() { UiState.actionMenuScrollPreviousRequested() }
        function activate() { UiState.actionMenuActivateRequested() }
        function status(): string {
            return JSON.stringify({
                activePanel: UiState.activePanel,
                screenName: UiState.actionMenuScreenName,
                flow: UiState.actionMenuFlow,
                closeRequested: UiState.actionMenuCloseRequested
            })
        }
    }

    IpcHandler {
        target: "launcher"
        enabled: true
        function open(mode: string) {
            if (mode !== "drun" || Quickshell.screens.length === 0) return
            UiState.openHakuMenu(Quickshell.screens[0].name, "drun")
        }
    }

    IpcHandler {
        target: "notif"
        function toggleCenter() {
            if (!NotificationStore._started || Quickshell.screens.length === 0) return
            var screen = Quickshell.screens[0]
            UiState.toggleNotifications(screen.name, ScreenGeometry.barAnchor(screen.height, screen.width - Theme.pad - Theme.fontSize * 2,
                                        Theme.fontSize * 2))
        }
        function closeCenter() {
            UiState.closeNotifications()
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

    // Separate hosts reuse the same app content without sharing enable policy.
    Variants {
        model: Quickshell.screens
        Taskbar {}
    }
    Variants {
        model: Quickshell.screens
        DockBar {}
    }


    Variants {
        model: Quickshell.screens
        NavigationPanel {}
    }

    Variants {
        model: Quickshell.screens
        SettingsPanel {}
    }

    Variants {
        model: Quickshell.screens
        TempNoteOverlay {}
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
        WallpaperPanel {}
    }

    Variants {
        model: Quickshell.screens
        ActionMenuPanel {}
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
