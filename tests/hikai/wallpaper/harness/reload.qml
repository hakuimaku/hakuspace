import QtQuick
import Quickshell
import "services"
import "components/wallpaper" as Wallpaper

ShellRoot {
    id: root
    // Keep generation boundaries observable without logging from production services.
    property int phase: 0
    property int ticks: 0
    property bool restored: false
    PersistentProperties {
        id: memory
        reloadableId: "wallpaper-renderer-reloads"
        property int cycles: 0
        onLoaded: root.restored = true
    }
    Variants { model: Quickshell.screens; Wallpaper.WallpaperSurface {} }
    Component.onDestruction: {
        snapshot("before-shutdown")
        WallpaperService.shutdown()
        snapshot("after-shutdown")
    }
    // Record all maintenance operands while their owning QML context is still live.
    function snapshot(stage) {
        var service = WallpaperService
        console.info("Wallpaper reload evidence " + JSON.stringify({stage: stage, cycle: memory.cycles,
            busy: service.busy, cacheBusy: service.cacheBusy,
            handoff: service.handoff && service.handoff.running, canceller: service.canceller && service.canceller.running,
            accent: service.accent && service.accent.running, statusWriter: service.statusWriter && service.statusWriter.running,
            rendererAlive: !!service.renderer, rendererStopping: service.renderer && service.renderer.stopping,
            rendererPid: service.rendererPid, rendererStates: service.rendererStates, maintenanceBusy: service.maintenanceBusy}))
    }
    function check(ok, message) {
        if (ok) return
        console.error("Wallpaper reload failed: " + message)
        Qt.exit(1)
        throw new Error(message)
    }
    Timer {
        interval: 80; repeat: true; running: true
        onTriggered: {
            root.check(++root.ticks < 300, "timeout at phase " + root.phase + ": " + WallpaperService.error)
            if (!root.restored || !WallpaperSettingsStore.ready || !WallpaperService.initialized || WallpaperService.busy) return
            root.check(typeof WallpaperService.maintenanceBusy === "boolean", "maintenance gate is Boolean")
            if (root.phase === 0) {
                root.snapshot("configuration-ready")
                WallpaperService.select(Quickshell.env("HAKUSPACE_WALLPAPER_FIXTURE") + "/Videos/Wallpapers/clip.mp4", "original", false)
                root.phase = 1
            } else if (root.phase === 1) {
                if (WallpaperService.current.kind !== "video" || !WallpaperService.rendererPid) return
                var states = Object.values(WallpaperService.rendererStates)
                if (states.length !== Quickshell.screens.length || !states.every(state => state.front && !state.incoming)) return
                if (memory.cycles < 5) {
                    root.snapshot("before-reload")
                    ++memory.cycles
                    Quickshell.reload(false)
                } else {
                    root.snapshot("after-reloads")
                    WallpaperService.select(Quickshell.env("HAKUSPACE_WALLPAPER_FIXTURE") + "/Pictures/Wallpapers/other.png", "original", false)
                    root.phase = 2
                }
            } else {
                if (WallpaperService.current.kind !== "static" || !WallpaperService.renderer.stopped
                    || WallpaperService.maintenanceBusy) return
                root.check(!WallpaperService.rendererPid && !Object.keys(WallpaperService.rendererStates).length,
                    "static commit releases renderer and reopens maintenance")
                root.snapshot("after-renderer-exit")
                console.info("Wallpaper reload checks passed")
                Qt.quit()
            }
        }
    }
}
