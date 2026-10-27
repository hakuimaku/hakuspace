//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "services"
import "components"
import "components/wallpaper" as Wallpaper

import "modules/picker"

ShellRoot {
    id: root
    // Keep idle and logind hooks resident even before the first diagnostic IPC call.
    readonly property bool nativeIdleEnabled: IdleService.enabled

    DesktopColorScheme {}

    // Bootstrap keeps all ordinary surfaces absent until the cover barrier.
    readonly property var hikaiScreenModel: ShellTransitionState.chromeEnabled ? Quickshell.screens : []

    // Consume the bootstrap guard once, including across in-process reloads.
    PersistentProperties {
        id: transitionMemory
        reloadableId: "hakuspace-shell-transition-bootstrap"
        property bool bootstrapComplete: false
        onLoaded: {
            if (bootstrapComplete) ShellTransitionState.chromeEnabled = true
        }
    }

    Connections {
        target: ShellTransitionState
        function onFinishedAndQuit() { Qt.quit() }
        function onChromeEnabledChanged() {
            if (ShellTransitionState.chromeEnabled) transitionMemory.bootstrapComplete = true
        }
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
            if (LockState.locked) return;
            Quickshell.reload(false);
        }
        function quit() {
            if (LockState.locked) return;
            Qt.quit();
        }
    }

    PersistentProperties {
        id: lockMemory
        reloadableId: "hakuspace-lock-state"
        property bool locked: false
        onLoaded: {
            if (locked && !LockState.locked) LockState.requestLock()
        }
    }

    Connections {
        target: LockState
        function onLockedChanged() {
            lockMemory.locked = LockState.locked
        }
    }

    IpcHandler {
        target: "lock"
        enabled: true
        function lock(): string { return LockState.requestLock() }
        function status(): string { return LockState.status() }
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

    LockSession {}


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
        // Prefer the current wallpaper owner, then the active window's output.
        function defaultScreenName(): string {
            if (UiState.activePanel === "wallpaper") return UiState.wallpaperScreenName
            var top = ToplevelManager.activeToplevel
            if (top && top.screens.length) return top.screens[0].name
            var focused = WM.workspaces.find(workspace => workspace.focused)
            return focused && focused.output ? focused.output : Quickshell.screens.length ? Quickshell.screens[0].name : ""
        }
        function openDefault() { UiState.openWallpaperQuick(defaultScreenName()) }
        function toggleDefault() { UiState.toggleWallpaperQuick(defaultScreenName()) }
        function quick() { openDefault() }
        function workspace() { UiState.openWallpaperWorkspace(defaultScreenName()) }
        function toggleWorkspaceDefault() { UiState.toggleWallpaperWorkspace(defaultScreenName()) }
        function close() { UiState.closeWallpaper() }
        function select(path: string): bool { return WallpaperService.select(path, "", false) }
        function pause() { WallpaperService.manuallyPaused = true }
        function resume() { WallpaperService.manuallyPaused = false }
        function status(): string { return JSON.stringify({current: WallpaperService.current, playbackState: WallpaperService.playbackState, error: WallpaperService.error}) }
    }

    IpcHandler {
        target: "settings"
        enabled: true
        function open(screenName: string) {
            for (var screen of Quickshell.screens) {
                if (screen.name === screenName) {
                    UiState.openSettings(screenName)
                    return
                }
            }
        }
        function openDefault() {
            if (Quickshell.screens.length > 0)
                UiState.openSettings(Quickshell.screens[0].name)
        }
        function toggleDefault() {
            if (Quickshell.screens.length > 0)
                UiState.toggleSettings(Quickshell.screens[0].name)
        }
        function close() { UiState.closeSettings() }
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

    // Toggle only the floating note, independently of Navigation and Sidebar.
    IpcHandler {
        target: "tempNote"
        function toggle() {
            if (UiState.tempNoteOpen) UiState.closeTempNote()
            else if (Quickshell.screens.length > 0)
                UiState.openTempNote(Quickshell.screens[0].name)
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

    IpcHandler {
        target: "cavaUnderbar"
        enabled: true
        function toggle() { CavaService.toggle() }
        function start() { CavaService.start() }
        function stop() { CavaService.stop() }
        function restart() { CavaService.restart() }
        function status(): string {
            return JSON.stringify({
                enabled: CavaService.enabled,
                running: CavaService.running,
                rendererPid: CavaService.rendererPid,
                sleeping: CavaService.sleeping,
                style: CavaService.style,
                height: CavaService.height,
                ceilingHeadroom: CavaService.ceilingHeadroom,
                amplitude: CavaService.amplitude,
                barCount: CavaService.barCount,
                overallEnergy: CavaService.overallEnergy,
                bassEnergy: CavaService.bassEnergy,
                midEnergy: CavaService.midEnergy,
                trebleEnergy: CavaService.trebleEnergy,
                peakEnergy: CavaService.peakEnergy,
                malformedFrames: CavaService.malformedFrames,
                totalFrames: CavaService.totalFrames
            })
        }
    }

    Variants {
        model: root.hikaiScreenModel
        TopBar {}
    }

    // Separate hosts reuse the same app content without sharing enable policy.
    Variants {
        model: root.hikaiScreenModel
        Taskbar {}
    }
    Variants {
        model: root.hikaiScreenModel
        DockBar {}
    }


    // Cava owns its audio processing and animated surfaces in a separate process.
    CavaRendererHost { service: CavaService; screens: root.hikaiScreenModel }

    // Enumerate screens cheaply and create heavy surfaces only while needed.
    Variants {
        id: ephemeralHosts
        model: root.hikaiScreenModel
        EphemeralSurfaces {}
    }

    // Persistent wallpaper renderers are independent from browser visibility.
    Variants {
        model: root.hikaiScreenModel
        Wallpaper.WallpaperSurface {}
    }

    Variants {
        model: root.hikaiScreenModel
        RoundedScreen {}
    }

    // Map last so an active wipe sits above existing Hikai overlay panels.
    Variants {
        model: Quickshell.screens
        ShellTransitionOverlay {}
    }
}
