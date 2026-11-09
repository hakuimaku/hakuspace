import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "../services"

Scope {
    id: root

    // Open generic image sessions independently of Dashboard and notification hosts.
    IpcHandler {
        target: "imageEditor"
        function open(path: string): bool { return ImageEditor.open(path, "") }
        function openOnScreen(path: string, screenName: string): bool { return ImageEditor.open(path, screenName) }
        function status(): string { return ImageEditor.status() }
        function close(): bool { return ImageEditor.close() }
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
}
