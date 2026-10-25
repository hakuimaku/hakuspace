import QtQuick
import Quickshell
import Quickshell.Io
import "services"
import "components/wallpaper" as Wallpaper

ShellRoot {
    id: root
    // Hold the encoder independently of the foreground selection lane.
    property int phase: 0
    property int ticks: 0
    property bool gateReady: false
    property bool sawClearBeforeVideo: false
    property bool sawStopBeforeImage: false
    property var builderPid: null
    property string videoToken: ""
    property string imageToken: ""
    readonly property string fixture: Quickshell.env("HAKUSPACE_WALLPAPER_FIXTURE")
    Variants { model: Quickshell.screens; Wallpaper.WallpaperSurface {} }
    Process {
        id: encoderGate
        stdinEnabled: true
        command: ["python3", "-u", "-c", "import fcntl, pathlib, sys\np = pathlib.Path(sys.argv[1]); p.parent.mkdir(parents=True, exist_ok=True)\nwith p.open('a+') as lock:\n fcntl.flock(lock, fcntl.LOCK_EX)\n print('ready', flush=True)\n sys.stdin.readline()\n",
            Quickshell.env("XDG_CACHE_HOME") + "/hakuspace/wallpaper/encoder.lock"]
        stdout: SplitParser { onRead: line => { if (line === "ready") root.gateReady = true } }
    }
    function check(ok, message) {
        if (ok) return
        console.error("Wallpaper flow failed at " + phase + ": " + message + " " + WallpaperService.error)
        Qt.exit(1)
        throw new Error(message)
    }
    Connections {
        target: WallpaperService
        function onCandidateChanged() {
            if (WallpaperService.candidate.kind === "video" && WallpaperService.current.kind === "static") {
                root.check(WallpaperService.imageCleared, "awww is cleared before the video candidate starts")
                root.sawClearBeforeVideo = true
            }
        }
    }
    Connections {
        target: WallpaperService.committer
        function onRunningChanged() {
            if (WallpaperService.committer.running && WallpaperService.candidate.kind === "static" && WallpaperService.current.kind === "video") {
                root.check(WallpaperService.renderer.stopped && !WallpaperService.rendererPid,
                    "video process exits completely before awww image application")
                root.sawStopBeforeImage = true
            }
        }
    }
    Timer {
        interval: 50; repeat: true; running: true
        onTriggered: {
            root.check(++root.ticks < 600, "timeout")
            if (!WallpaperSettingsStore.ready || !WallpaperService.initialized) return
            if (phase === 0) {
                if (WallpaperService.busy) return
                root.check(WallpaperService.select(fixture + "/Pictures/Wallpapers/forest # one.png", "screen", false), "apply initial image")
            } else if (phase === 1) {
                if (WallpaperService.busy) return
                root.check(WallpaperService.current.kind === "static", "initial image commits")
                encoderGate.running = true
            } else if (phase === 2) {
                if (!gateReady) return
                root.check(WallpaperService.select(fixture + "/Videos/Wallpapers/clip.mp4", "low-memory", false), "request an unbuilt video")
            } else if (phase === 3) {
                if (!WallpaperService.waitingBuild || !WallpaperService.preloader.running) return
                builderPid = WallpaperService.preloader.processId
                root.check(WallpaperService.select(fixture + "/Videos/Wallpapers/second.mp4", "low-memory", false), "queue another unbuilt video")
            } else if (phase === 4) {
                if (!WallpaperService.waitingBuild || !WallpaperService.waitingBuild.path.endsWith("/second.mp4") || !WallpaperService.buildQueue.length) return
                root.check(WallpaperService.select(fixture + "/Pictures/Wallpapers/other.png", "screen", false), "image Apply is accepted while encoding waits")
                root.check(WallpaperService.preloader.running && WallpaperService.preloader.processId === builderPid, "Apply keeps the original build worker alive")
            } else if (phase === 5) {
                if (WallpaperService.busy) return
                root.check(WallpaperService.current.path === fixture + "/Pictures/Wallpapers/other.png", "new image applies without waiting for the encoder")
                root.check(WallpaperService.preloader.running && WallpaperService.preloader.processId === builderPid, "old video is still building after the image commits")
                encoderGate.write("release\n")
            } else if (phase === 6) {
                if (WallpaperService.cacheBusy) return
                root.check(WallpaperService.cacheMessage === "All videos ready" && !WallpaperService.error, "old build finishes successfully: " + WallpaperService.cacheMessage)
                root.check(WallpaperService.cacheEntries.length === 2 && WallpaperService.cacheEntries.every(entry => entry.profile === "low-memory" && entry.bytes > 0 && entry.render.height === 720),
                    "cache inventory reports both finished copies with their quality and size")
                root.check(WallpaperService.cacheTotalBytes >= WallpaperService.cacheBytes && WallpaperService.cachePreviewBytes > 0, "cache reports disk and preview usage")
                root.check(WallpaperService.current.path === fixture + "/Pictures/Wallpapers/other.png", "completed old video cannot replace the newer image")
                root.check(WallpaperService.select(fixture + "/Videos/Wallpapers/second.mp4", "low-memory", false), "apply the queued video from its completed cache")
            } else if (phase === 7) {
                if (WallpaperService.busy || WallpaperService.cacheBusy) return
                root.check(WallpaperService.cacheEntries.some(entry => entry.active && entry.path === WallpaperService.current.path), "inventory marks the playing video copy")
                root.check(WallpaperService.current.kind === "video" && sawClearBeforeVideo && !WallpaperService.buildingVideos, "video commits after awww clear and native readiness without rebuilding")
                root.check(WallpaperService.select(fixture + "/Videos/Wallpapers/clip.mp4", "low-memory", false), "apply the first superseded video from its cache")
            } else if (phase === 8) {
                if (WallpaperService.busy) return
                root.check(WallpaperService.current.path.endsWith("/clip.mp4"), "video to video handoff keeps the newest selection")
                gateReady = false
                encoderGate.running = true
            } else if (phase === 9) {
                if (!gateReady) return
                root.check(WallpaperService.rebuild(), "rebuild the current video in the cache worker")
            } else if (phase === 10) {
                if (!WallpaperService.activeBuild || !WallpaperService.activeBuild.rebuild || !WallpaperService.preloader.running) return
                root.check(WallpaperService.select(fixture + "/Pictures/Wallpapers/other.png", "screen", false), "Apply is accepted while Prepare current is encoding")
            } else if (phase === 11) {
                if (WallpaperService.busy) return
                root.check(WallpaperService.current.kind === "static" && WallpaperService.preloader.running, "image commits before the current-video rebuild finishes")
                encoderGate.write("release\n")
            } else if (phase === 12) {
                if (WallpaperService.cacheBusy) return
                root.check(WallpaperService.current.kind === "static" && !WallpaperService.error, "a superseded rebuild cannot reactivate its video")
                root.check(WallpaperService.select(fixture + "/Videos/Wallpapers/clip.mp4", "low-memory", false), "restore video after the superseded rebuild")
            } else if (phase === 13) {
                if (WallpaperService.busy) return
                videoToken = WallpaperService.current.token
                root.check(WallpaperService.select(fixture + "/broken.png", "screen", false), "try an invalid image after stopping video")
            } else if (phase === 14) {
                if (WallpaperService.busy || WallpaperService.renderer.stopped || !Object.values(WallpaperService.rendererStates).every(state => state.front && state.front.record.token === videoToken)) return
                root.check(!!WallpaperService.error && WallpaperService.current.token === videoToken && !WallpaperService.rendererSuspended,
                    "failed awww application restarts the previously committed video")
                root.check(WallpaperService.select(fixture + "/Pictures/Wallpapers/forest # one.png", "screen", false), "replace video with an image")
            } else if (phase === 15) {
                if (WallpaperService.busy || WallpaperService.cacheBusy) return
                root.check(WallpaperService.current.kind === "static" && sawStopBeforeImage && WallpaperService.renderer.stopped,
                    "video is fully stopped before the awww transition")
                WallpaperService.clearUnused()
            } else if (phase === 16) {
                if (WallpaperService.cacheBusy) return
                root.check(WallpaperService.cacheMiB === 0 && !WallpaperService.cacheEntries.length, "clear unused removes the inactive build artifacts and inventory rows")
                root.check(WallpaperService.buildAll([
                    {kind: "video", path: fixture + "/Videos/Wallpapers/clip.mp4"},
                    {kind: "video", path: fixture + "/Videos/Wallpapers/second.mp4"}], "low-memory"), "prepare the library as one batch")
            } else if (phase === 17) {
                if (WallpaperService.cacheBusy) return
                root.check(WallpaperService.cacheMessage === "All videos ready" && WallpaperService.cacheMiB > 0
                    && WallpaperService.current.kind === "static" && !WallpaperService.error, "batch builds finish without applying any video")
                imageToken = WallpaperService.current.token
                root.check(WallpaperService.select(fixture + "/broken.mp4", "original", false), "try a video that cannot produce a frame")
            } else {
                if (WallpaperService.busy || !WallpaperService.renderer.stopped || WallpaperService.canceller.running) return
                root.check(!!WallpaperService.error && !WallpaperService.imageCleared && WallpaperService.current.token === imageToken,
                    "failed video readiness restores awww without replacing the committed image")
                console.info("Wallpaper flow checks passed")
                Qt.quit()
            }
            ++phase
        }
    }
}
