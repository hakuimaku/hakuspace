pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root
    // Renderer ownership outlives every browser instance.
    property var current: ({})
    property var candidate: ({})
    property var surfaces: ({})
    property var readyScreens: ({})
    // Apply requests supersede each other while the bounded cache worker keeps running.
    property int requestSerial: 0
    property var pendingRequest: null
    property var activeRequest: null
    property var waitingBuild: null
    property var prepared: ({})
    property var buildQueue: []
    property var activeBuild: null
    property bool rendererSuspended: false
    property bool imageCleared: false
    property bool initialized: false
    property bool ownershipTaken: false
    // Explicit pause is independent of transient fullscreen visibility.
    property bool manuallyPaused: false
    property string error: ""
    property string playbackState: "STOPPED"
    property string proxyState: "original"
    property var outputStates: ({})
    // Qt/FFmpeg heaps disappear with the video-only child when an image commits.
    readonly property var rendererStates: renderer.states
    readonly property var rendererPid: renderer.processId
    property WallpaperRendererHost renderer: WallpaperRendererHost { service: root }
    readonly property bool busy: resolver.running || committer.running || imageClearer.running || rollback.running
        || !!candidate.token || !!prepared.token || !!pendingRequest || !!waitingBuild
    // Process exit signals can run before their running property settles.
    onBusyChanged: if (!busy) { refreshPlaybackState(); statusDelay.restart() }
    readonly property var preferences: WallpaperSettingsStore.savedValues
    readonly property real cacheMiB: cacheBytes / 1048576
    property real cacheBytes: 0
    property real cacheTotalBytes: 0
    property real cachePreviewBytes: 0
    property var cacheEntries: []
    // Coalesce status refreshes so opening Cache cannot interrupt a cache operation.
    property bool cacheMaintenanceActive: false
    property bool cacheRefreshPending: false
    readonly property bool cacheBusy: !!(activeBuild || preloader.running || maintenance.running || cacheMaintenanceActive || cacheRefreshPending || (buildQueue || []).length)
    readonly property bool buildingVideos: !!(activeBuild || preloader.running || (buildQueue || []).length)
    property string cacheMessage: ""
    property string requestedPath: ""
    property string requestedProfile: "screen"

    // Pass paths as arguments so media filenames cannot become shell commands.
    function command(args) {
        return ["sh", "-c", 'script=$1; [ -f "$script" ] || script=$2; shift 2; exec python3 "$script" "$@"',
            "--", Env.binDir + "/wallpaper_ctl.py", Quickshell.shellPath("../../../../core/backend/theme/wallpaper_ctl.py")].concat(args)
    }
    // Encode fragments and non-ASCII paths once for local previews and video URLs.
    function fileUrl(path) { return path ? "file://" + path.split("/").map(encodeURIComponent).join("/") : "" }
    // Resolve a shared proxy large enough for all active physical outputs.
    function dimensions() {
        var width = 2, height = 2
        for (var screen of Quickshell.screens) {
            width = Math.max(width, Math.ceil(screen.width * screen.devicePixelRatio))
            height = Math.max(height, Math.ceil(screen.height * screen.devicePixelRatio))
        }
        return ["--width", String(width), "--height", String(height)]
    }
    // Browser selection starts preparation without touching the committed source.
    function select(path, profile, build) {
        if (!path) return false
        requestedPath = path
        requestedProfile = profile || preferences.playback.profile
        pendingRequest = {id: ++requestSerial, path: path, profile: requestedProfile, build: !!build}
        waitingBuild = null
        error = ""
        advanceRequest()
        return true
    }
    // Cancellation cannot remove a newer backend candidate because tokens are checked.
    function discard(record) {
        if (record && record.token) Quickshell.execDetached(command(["cancel", record.token]))
    }
    // Restore an image cleared for a video that failed or was superseded.
    function restoreImage() {
        if (!imageCleared || current.kind !== "static" || rollback.running) return false
        imageCleared = false
        rollback.command = command(["restore-image"])
        rollback.running = true
        return true
    }
    // Short resolver and handoff steps are serialized; encoding never holds this lane.
    function advanceRequest() {
        if (resolver.running || committer.running || imageClearer.running || rollback.running) return
        if (pendingRequest) {
            discard(candidate); candidate = ({})
            discard(prepared); prepared = ({})
            prepareTimeout.stop()
            rendererSuspended = false
            if (restoreImage()) return
            activeRequest = pendingRequest
            pendingRequest = null
            error = ""
            proxyState = "preparing"
            playbackState = "PREPARING"
            resolver.command = command(["select", activeRequest.path, "--profile", activeRequest.profile, "--probe"]
                .concat(dimensions()).concat(activeRequest.build ? ["--build"] : []))
            resolver.running = true
        } else if (prepared.token) {
            if (!activeRequest || activeRequest.id !== requestSerial) { discard(prepared); prepared = ({}); return }
            if (prepared.kind === "video" && current.kind !== "video" && !imageCleared) {
                imageClearer.command = command(["clear-image"])
                imageClearer.running = true
                return
            }
            rendererSuspended = false
            readyScreens = ({})
            candidate = prepared
            prepared = ({})
            proxyState = candidate.proxyPath !== candidate.path ? "ready" : "original"
            prepareTimeout.restart()
            maybeCommit()
        }
        statusDelay.restart()
    }
    // Adopt persisted or Classic state only after native chrome is enabled.
    function restore() {
        if (initialized || !ShellTransitionState.chromeEnabled || !WallpaperSettingsStore.ready) return
        initialized = true
        activeRequest = {id: ++requestSerial, path: "", profile: preferences.playback.profile, build: false}
        proxyState = "preparing"
        playbackState = "PREPARING"
        resolver.command = command(["restore", "--probe"].concat(dimensions()))
        resolver.running = true
        statusDelay.restart()
    }
    // Track outputs independently so a hotplug cannot strand an in-flight selection.
    function registerSurface(name) {
        var next = Object.assign({}, surfaces); next[name] = true; surfaces = next
    }
    // Removed outputs no longer block the readiness barrier.
    function unregisterSurface(name) {
        var next = Object.assign({}, surfaces); delete next[name]; surfaces = next
        if (!Object.keys(surfaces).length) ownershipTaken = false
        next = Object.assign({}, outputStates); delete next[name]; outputStates = next
        maybeCommit()
    }
    // Stop the legacy renderer once whenever native background ownership resumes.
    function takeOwnership() {
        if (ownershipTaken) return
        ownershipTaken = true
        handoff.command = command(["handoff"])
        handoff.running = true
    }
    // Every required output must show a valid frame before state is persisted.
    function surfaceReady(name, token) {
        if (candidate.token !== token) return
        var next = Object.assign({}, readyScreens); next[name] = true; readyScreens = next
        maybeCommit()
    }
    // Images commit through awww; videos first require a frame on every output.
    function maybeCommit() {
        if (!candidate.token || committer.running || pendingRequest) return
        if (candidate.kind === "video") {
            if (!Object.keys(surfaces).length) return
            for (var name in surfaces) if (!readyScreens[name]) return
        } else {
            rendererSuspended = true
            if (!renderer.stopped) return
        }
        prepareTimeout.stop()
        committer.command = command(["commit", candidate.token])
        committer.running = true
    }
    // Failed preparation preserves every output's currently visible renderer.
    function fail(message) {
        if (candidate.token && !canceller.running) {
            canceller.command = command(["cancel", candidate.token])
            canceller.running = true
        }
        if (error !== message) Quickshell.execDetached(["notify-send", "--app-name=Wallpaper", "Wallpaper could not be applied", message])
        error = message
        proxyState = "error"
        playbackState = "ERROR"
        candidate = ({})
        discard(prepared); prepared = ({})
        waitingBuild = null
        rendererSuspended = false
        restoreImage()
        prepareTimeout.stop()
        publishStatus()
        Qt.callLater(root.advanceRequest)
    }
    // Aggregate output diagnostics without treating a process ID as renderer truth.
    function report(name, state) {
        var next = Object.assign({}, outputStates); next[name] = state; outputStates = next
        refreshPlaybackState()
        statusDelay.restart()
    }
    // Report the visible output state after a preparation barrier has finished.
    function refreshPlaybackState() {
        if (busy || error) return
        if (current.kind !== "video") { playbackState = "STOPPED"; return }
        var states = Object.values(outputStates)
        playbackState = states.includes("PLAYING") ? "PLAYING" : states.includes("PAUSED") ? "PAUSED"
            : states.includes("UNLOADED") ? "UNLOADED" : "STOPPED"
    }
    // Diagnostic writes are coalesced and remain outside the QML render thread.
    function publishStatus() {
        if (statusWriter.running) { statusDelay.restart(); return }
        statusWriter.environment = {HAKUSPACE_WALLPAPER_RUNTIME_JSON: JSON.stringify({playbackState: playbackState,
            proxyState: proxyState, error: error, outputs: outputStates, current: current})}
        statusWriter.command = command(["runtime"])
        statusWriter.running = true
    }
    // Background and explicit builds share one worker without blocking image application.
    function warm(records) {
        if (preferences.proxy.buildPolicy === "background") buildAll(records, preferences.playback.profile)
    }
    // Explicit builds include every video, independent of the browser's current filter.
    function buildAll(records, profile) {
        if (busy || cacheBusy || profile === "original" || !records.some(item => item.kind === "video")) return false
        cacheMessage = "Building video cache…"
        queueBuild(records.filter(item => item.kind === "video").map(item => item.path), profile)
        return true
    }
    // Coalesce duplicate sources while preserving builds superseded by another Apply.
    function queueBuild(sources, profile) {
        var remaining = Array.from(new Set(sources)).filter(path => !activeBuild || activeBuild.profile !== profile || !activeBuild.sources.includes(path))
        if (!remaining.length) return
        var queue = buildQueue.slice()
        var index = queue.findIndex(job => job.profile === profile && !job.rebuild)
        if (index < 0) queue.push({profile: profile, sources: remaining})
        else queue[index] = {profile: profile, sources: Array.from(new Set(queue[index].sources.concat(remaining)))}
        buildQueue = queue
        startNextBuild()
    }
    // Keep one encoder process active while queued work survives picker dismissal.
    function startNextBuild() {
        if (preloader.running || maintenance.running || cacheMaintenanceActive || cacheRefreshPending || !buildQueue.length) return
        activeBuild = buildQueue[0]
        buildQueue = buildQueue.slice(1)
        cacheMessage = "Building video cache…"
        preloader.environment = {HAKUSPACE_WALLPAPER_SOURCES_JSON: JSON.stringify(activeBuild.sources),
            HAKUSPACE_WALLPAPER_REBUILD_SOURCE: activeBuild.sources[0]}
        preloader.command = command((activeBuild.rebuild ? ["proxy", "rebuild-current"] : ["warm"])
            .concat(["--profile", activeBuild.profile]).concat(dimensions()))
        preloader.running = true
    }
    // Cache actions retain the active and prepared proxy pins.
    function clearUnused() {
        if (cacheBusy || busy) return
        cacheMessage = "Clearing unused video cache…"
        cacheMaintenanceActive = true
        maintenance.command = command(["proxy", "clear-unused"].concat(dimensions()))
        maintenance.running = true
    }
    // Read disk usage and prepared copies only on demand or after cache mutations.
    function refreshCache() {
        if (maintenance.running || cacheMaintenanceActive) { cacheRefreshPending = true; return }
        cacheRefreshPending = false
        cacheMaintenanceActive = true
        maintenance.command = command(["status"].concat(dimensions()))
        maintenance.running = true
    }
    // Rebuild through the same safe preparation and readiness barrier.
    function rebuild() {
        if (current.kind !== "video" || busy) return false
        error = ""
        proxyState = "building"
        requestedPath = current.path
        requestedProfile = current.profile
        waitingBuild = {id: ++requestSerial, path: current.path, profile: current.profile, build: true}
        buildQueue = buildQueue.concat([{profile: current.profile, sources: [current.path], rebuild: true, request: waitingBuild}])
        startNextBuild()
        return true
    }
    // Open the managed cache without exposing a command entry field.
    function openCache() { Quickshell.execDetached(["xdg-open", (Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache") + "/hakuspace/wallpaper"]) }

    Component.onCompleted: restore()
    property Connections chromeConnection: Connections {
        target: ShellTransitionState
        function onChromeEnabledChanged() { root.restore() }
    }
    property Connections settingsConnection: Connections {
        target: WallpaperSettingsStore
        function onReadyChanged() { root.restore() }
        function onApplied() {
            if (root.current.path && !root.busy && root.current.profile !== root.preferences.playback.profile)
                root.select(root.current.path, root.preferences.playback.profile, false)
        }
    }
    property Timer prepareTimeout: Timer { interval: 20000; onTriggered: root.fail("Wallpaper did not produce a frame. Previous wallpaper kept.") }
    property Timer statusDelay: Timer { interval: 150; onTriggered: root.publishStatus() }
    property Process resolver: Process {
        stdout: StdioCollector { id: resolveOut }
        stderr: StdioCollector { id: resolveErr }
        onExited: code => {
            if (!root.activeRequest || root.activeRequest.id !== root.requestSerial) {
                try { root.discard(JSON.parse(resolveOut.text)) } catch (e) {}
                Qt.callLater(root.advanceRequest)
                return
            }
            if (code !== 0) { root.fail(resolveErr.text.trim() || "Wallpaper preparation failed"); return }
            try {
                var record = JSON.parse(resolveOut.text)
                if (!record.path) { root.proxyState = "original"; root.playbackState = "STOPPED"; statusDelay.restart(); return }
                if (!root.activeRequest.path) root.activeRequest = Object.assign({}, root.activeRequest, {path: record.path, profile: record.profile})
                if (record.needsBuild) {
                    if (!record.buildAllowed) { root.fail("This video is not prepared. Prepare it in Wallpaper settings or use Original quality."); return }
                    root.waitingBuild = root.activeRequest
                    root.proxyState = "building"
                    root.queueBuild([record.path], record.profile)
                } else root.prepared = record
                Qt.callLater(root.advanceRequest)
            } catch (e) { root.fail(String(e)) }
        }
    }
    property Process committer: Process {
        stdout: StdioCollector { id: commitOut }
        stderr: StdioCollector { id: commitErr }
        onExited: code => {
            if (code !== 0) { root.fail(commitErr.text.trim() || "Could not save wallpaper selection"); return }
            try {
                root.current = JSON.parse(commitOut.text)
                root.candidate = ({})
                root.rendererSuspended = false
                root.imageCleared = false
                root.refreshPlaybackState()
                root.manuallyPaused = false
                accent.command = ["sh", "-c", 'script=$1; [ -f "$script" ] || script=$2; exec bash "$script" sync-accent "$3"',
                    "--", Env.binDir + "/wallpaper_ctl.sh", Quickshell.shellPath("../../../../core/backend/theme/wallpaper_ctl.sh"), root.current.kind === "video" ? root.current.thumbnail || root.current.path : root.current.path]
                accent.running = true
                root.refreshCache()
                root.publishStatus()
                Qt.callLater(root.advanceRequest)
            } catch (e) { root.fail(String(e)) }
        }
    }
    property Process handoff: Process {}
    property Process imageClearer: Process {
        stderr: StdioCollector { id: clearErr }
        onExited: code => {
            if (code !== 0) { root.fail(clearErr.text.trim() || "Could not clear the image wallpaper"); return }
            root.imageCleared = true
            Qt.callLater(root.advanceRequest)
        }
    }
    property Process rollback: Process {
        stderr: StdioCollector { id: rollbackErr }
        onExited: code => {
            if (code !== 0) root.error = rollbackErr.text.trim() || "Could not restore the previous image wallpaper"
            Qt.callLater(root.advanceRequest)
        }
    }
    property Process canceller: Process {}
    property Process accent: Process {}
    property Process maintenance: Process {
        stdout: StdioCollector { id: cacheOut }
        stderr: StdioCollector { id: cacheErr }
        onExited: code => {
            try {
                if (code !== 0) throw new Error(cacheErr.text.trim() || "Could not read the wallpaper cache")
                var status = JSON.parse(cacheOut.text)
                root.cacheBytes = status.cacheBytes || 0
                root.cacheTotalBytes = status.cacheTotalBytes || 0
                root.cachePreviewBytes = status.cachePreviewBytes || 0
                root.cacheEntries = status.cacheEntries || []
                if (command.includes("clear-unused")) root.cacheMessage = "Unused video cache cleared"
            } catch (e) { root.error = String(e) }
            root.cacheMaintenanceActive = false
            if (root.cacheRefreshPending) Qt.callLater(root.refreshCache)
            Qt.callLater(root.startNextBuild)
        }
    }
    property Process statusWriter: Process {}
    property Process preloader: Process {
        stdout: StdioCollector { id: warmOut }
        stderr: StdioCollector { id: warmErr }
        onExited: code => {
            var job = root.activeBuild
            root.activeBuild = null
            var waiting = root.waitingBuild && job && root.waitingBuild.profile === job.profile && job.sources.includes(root.waitingBuild.path)
            try {
                if (code !== 0) throw new Error(warmErr.text.trim() || "Video cache build stopped")
                var result = JSON.parse(warmOut.text)
                if (job.rebuild) {
                    root.cacheMessage = "Video ready"
                    if (job.request.id === root.requestSerial && waiting) {
                        if (result.superseded) throw new Error("Wallpaper changed during the rebuild. Apply it again.")
                        root.activeRequest = job.request
                        root.prepared = result
                    } else {
                        root.discard(result)
                        if (waiting) root.pendingRequest = root.waitingBuild
                    }
                    if (waiting) root.waitingBuild = null
                    root.refreshCache()
                    Qt.callLater(root.advanceRequest)
                    Qt.callLater(root.startNextBuild)
                    return
                }
                var errors = result.errors
                root.cacheMessage = errors.length ? errors.length + " video(s) could not be built: " + errors[0] : "All videos ready"
                if (waiting) {
                    if (result.readySources.includes(root.waitingBuild.path)) root.pendingRequest = root.waitingBuild
                    else root.fail(root.cacheMessage)
                    root.waitingBuild = null
                }
                root.refreshCache()
            } catch (e) { root.cacheMessage = String(e); if (waiting) root.fail(String(e)) }
            Qt.callLater(root.advanceRequest)
            Qt.callLater(root.startNextBuild)
        }
    }
}
