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
    Variants { model: Quickshell.screens; Wallpaper.WallpaperSurface {} }
    Timer {
        interval: 100; repeat: true; running: !root.sampling
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
    Timer { interval: 300000; running: !root.sampling; onTriggered: Qt.exit(1) }
    Process { id: sampler; onExited: code => Qt.exit(code) }
}
