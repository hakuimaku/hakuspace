import QtQuick
import Quickshell
import Quickshell.Io
import "services"
import "components/wallpaper" as Wallpaper

ShellRoot {
    id: root
    // Run only the wallpaper service and its per-output surface during measurement.
    property bool selected: false
    property bool sampling: false
    Variants { id: surfaces; model: Quickshell.screens; Wallpaper.WallpaperSurface {} }
    // The external sampler owns reload/crash probes so it survives shell reloads.
    IpcHandler {
        target: "wallpaperSoak"
        function select(path: string): bool { return WallpaperService.select(path, Quickshell.env("HAKUSPACE_SOAK_PROFILE"), true) }
        function reload(): void { Quickshell.reload(false) }
        function state(): string {
            return JSON.stringify({ready: WallpaperSettingsStore.ready, busy: WallpaperService.busy,
                error: WallpaperService.error, kind: WallpaperService.current.kind, rendererPid: WallpaperService.rendererPid || 0,
                slots: surfaces.instances.map(surface => ({front: !!surface.front, incoming: !!surface.incoming, visible: surface.visible}))})
        }
    }
    Timer {
        interval: 100; repeat: true; running: !root.sampling && Number(Quickshell.env("HAKUSPACE_SOAK_CYCLES")) === 0
        onTriggered: {
            if (WallpaperService.error) { console.error(WallpaperService.error); Qt.exit(1); return }
            if (!root.selected && WallpaperSettingsStore.ready && !WallpaperService.busy) {
                root.selected = WallpaperService.select(Quickshell.env("HAKUSPACE_SOAK_SOURCE"), Quickshell.env("HAKUSPACE_SOAK_PROFILE"), true)
            }
            if (!root.selected || WallpaperService.busy || !WallpaperService.current.token) return
            root.sampling = true
            sampler.command = ["python3", Quickshell.env("HAKUSPACE_SOAK_SCRIPT"), "_sample", Quickshell.env("HAKUSPACE_SOAK_OUTPUT"), Quickshell.env("HAKUSPACE_SOAK_SECONDS")]
            sampler.running = true
        }
    }
    Timer { interval: 300000; running: !root.sampling && Number(Quickshell.env("HAKUSPACE_SOAK_CYCLES")) === 0; onTriggered: Qt.exit(1) }
    Process { id: sampler; onExited: code => Qt.exit(code) }
}
