import QtQuick
import Quickshell
import Quickshell.Io
import "services"
import "components/wallpaper" as Wallpaper

ShellRoot {
    id: root
    property int phase: 0
    property int ticks: 0
    property bool queueImageOnFallback: false
    readonly property string fixture: Quickshell.env("HAKUSPACE_WALLPAPER_FIXTURE")
    Variants { model: Quickshell.screens; Wallpaper.WallpaperSurface {} }
    // Inspect the real image backend after the failed native video preparation.
    Process {
        id: query
        command: ["awww", "query"]
        stdout: StdioCollector { id: queryOut }
        onExited: code => {
            root.check(code === 0 && queryOut.text.includes(".jpg"), "prepared thumbnail is visible through awww")
            WallpaperService.select(root.fixture + "/Videos/Wallpapers/clip.mp4", "original", false)
            root.phase = 3
        }
    }
    Process {
        id: notifications
        command: ["sh", "-c", 'wc -l < "$HOME/notifications.log"']
        stdout: StdioCollector { id: notificationOut }
        onExited: code => {
            root.check(code === 0 && Number(notificationOut.text.trim()) === 1, "dependency warning is emitted once across outputs and retries")
            root.queueImageOnFallback = true
            WallpaperService.select(root.fixture + "/Videos/Wallpapers/clip.mp4", "original", false)
            root.phase = 5
        }
    }
    // A new selection must run after the old fallback finishes applying its image.
    Connections {
        target: WallpaperService.thumbnailFallback
        function onRunningChanged() {
            if (WallpaperService.thumbnailFallback.running && root.queueImageOnFallback) {
                root.queueImageOnFallback = false
                WallpaperService.select(root.fixture + "/Pictures/Wallpapers/forest # one.png", "screen", false)
            }
        }
    }
    Process {
        id: imageQuery
        command: ["awww", "query"]
        stdout: StdioCollector { id: imageOut }
        onExited: code => {
            root.check(code === 0 && imageOut.text.includes("forest # one.png"), "new image selection wins over an older thumbnail fallback")
            console.info("Missing multimedia checks passed")
            Qt.quit()
        }
    }
    function check(ok, message) {
        if (ok) return
        console.error("Missing multimedia failed: " + message + ": " + WallpaperService.error)
        Qt.exit(1)
        throw new Error(message)
    }
    Timer {
        interval: 50
        repeat: true
        running: true
        onTriggered: {
            root.check(++root.ticks < 600, "timeout")
            if (!WallpaperSettingsStore.ready || !WallpaperService.initialized) return
            if (phase === 0) {
                if (WallpaperService.busy) return
                WallpaperService.select(root.fixture + "/Videos/Wallpapers/clip.mp4", "original", false)
                phase = 1
            } else if (phase === 1 || phase === 3) {
                if (WallpaperService.busy || !WallpaperService.renderer.stopped || WallpaperService.canceller.running) return
                root.check(WallpaperService.error.includes("qt6-multimedia-ffmpeg"), "diagnostic includes the repair packages")
                root.check(!WallpaperService.current.token && WallpaperService.multimediaWarningSent, "failed video is never committed")
                if (phase === 1) { query.running = true; phase = 2 }
                else { notifications.running = true; phase = 4 }
            } else if (phase === 5) {
                if (WallpaperService.busy || WallpaperService.current.kind !== "static") return
                imageQuery.running = true
                phase = 6
            }
        }
    }
}
