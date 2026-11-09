import QtQuick
import Quickshell
import Quickshell.Io
import "../services"

Scope {
    id: root

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
        function setTab(tab: string) { UiState.setHakuPanelTab(tab) }
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
}
