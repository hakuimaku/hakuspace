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
    readonly property bool busy: resolver.running || committer.running || !!candidate.token
    // Process exit signals can run before their running property settles.
    onBusyChanged: if (!busy) { refreshPlaybackState(); statusDelay.restart() }
    readonly property var preferences: WallpaperSettingsStore.savedValues
    readonly property real cacheMiB: cacheBytes / 1048576
    property real cacheBytes: 0
    readonly property bool cacheBusy: !!(preloader.running || maintenance.running)
    readonly property bool buildingVideos: !!preloader.running
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
        if (busy || !path) return false
        preloader.running = false
        requestedPath = path
        requestedProfile = profile || preferences.playback.profile
        error = ""
        proxyState = "building"
        playbackState = "PREPARING"
        resolver.command = command(["select", path, "--profile", requestedProfile].concat(dimensions()).concat(build ? ["--build"] : []))
        resolver.running = true
        statusDelay.restart()
        return true
    }
    // Adopt persisted or Classic state only after native chrome is enabled.
    function restore() {
        if (initialized || !ShellTransitionState.chromeEnabled || !WallpaperSettingsStore.ready) return
        initialized = true
        proxyState = "building"
        playbackState = "PREPARING"
        resolver.command = command(["restore"].concat(dimensions()))
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
        if (!candidate.token || committer.running) return
        if (candidate.kind === "video") {
            if (!Object.keys(surfaces).length) return
            for (var name in surfaces) if (!readyScreens[name]) return
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
        error = message
        proxyState = "error"
        playbackState = "ERROR"
        candidate = ({})
        prepareTimeout.stop()
        publishStatus()
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
    // Background builds share one bounded worker and yield to an explicit selection.
    function warm(records) {
        if (preferences.proxy.buildPolicy === "background") buildAll(records, preferences.playback.profile)
    }
    // Explicit builds include every video, independent of the browser's current filter.
    function buildAll(records, profile) {
        if (busy || cacheBusy || profile === "original" || !records.some(item => item.kind === "video")) return false
        cacheMessage = "Building video cache…"
        preloader.environment = {HAKUSPACE_WALLPAPER_SOURCES_JSON: JSON.stringify(records.filter(item => item.kind === "video").map(item => item.path))}
        preloader.command = command(["warm", "--profile", profile].concat(dimensions()))
        preloader.running = true
        return true
    }
    // Cache actions retain the active and prepared proxy pins.
    function clearUnused() {
        if (cacheBusy || busy) return
        cacheMessage = "Clearing unused video cache…"
        maintenance.command = command(["proxy", "clear-unused"])
        maintenance.running = true
    }
    // Rebuild through the same safe preparation and readiness barrier.
    function rebuild() {
        if (current.kind !== "video" || busy) return
        error = ""
        preloader.running = false
        proxyState = "building"
        resolver.command = command(["proxy", "rebuild-current"].concat(dimensions()))
        resolver.running = true
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
            if (code !== 0) { root.fail(resolveErr.text.trim() || "Wallpaper preparation failed"); return }
            try {
                var record = JSON.parse(resolveOut.text)
                if (!record.path) { root.proxyState = "original"; root.playbackState = "STOPPED"; statusDelay.restart(); return }
                root.readyScreens = ({})
                root.candidate = record
                root.proxyState = record.proxyPath !== record.path ? "ready" : "original"
                prepareTimeout.restart()
                if (record.kind !== "video") root.maybeCommit()
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
                root.refreshPlaybackState()
                root.manuallyPaused = false
                accent.command = ["sh", "-c", 'script=$1; [ -f "$script" ] || script=$2; exec bash "$script" sync-accent "$3"',
                    "--", Env.binDir + "/wallpaper_ctl.sh", Quickshell.shellPath("../../../../core/backend/theme/wallpaper_ctl.sh"), root.current.kind === "video" ? root.current.thumbnail || root.current.path : root.current.path]
                accent.running = true
                if (!maintenance.running) { maintenance.command = root.command(["status"]); maintenance.running = true }
                root.publishStatus()
            } catch (e) { root.fail(String(e)) }
        }
    }
    property Process handoff: Process {}
    property Process canceller: Process {}
    property Process accent: Process {}
    property Process maintenance: Process {
        stdout: StdioCollector { id: cacheOut }
        stderr: StdioCollector { id: cacheErr }
        onExited: code => {
            if (code !== 0) { root.error = cacheErr.text.trim(); return }
            try {
                root.cacheBytes = JSON.parse(cacheOut.text).cacheBytes || 0
                if (command.includes("clear-unused")) root.cacheMessage = "Unused video cache cleared"
            } catch (e) { root.error = String(e) }
        }
    }
    property Process statusWriter: Process {}
    property Process preloader: Process {
        stdout: StdioCollector { id: warmOut }
        stderr: StdioCollector { id: warmErr }
        onExited: code => {
            if (code !== 0) { root.cacheMessage = code === 143 ? "" : warmErr.text.trim() || "Video cache build stopped"; return }
            try {
                var errors = JSON.parse(warmOut.text).errors
                root.cacheMessage = errors.length ? errors.length + " video(s) could not be built: " + errors[0] : "All videos ready"
                if (!maintenance.running) { maintenance.command = root.command(["status"]); maintenance.running = true }
            } catch (e) { root.cacheMessage = String(e) }
        }
    }
}
