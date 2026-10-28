pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../config/SettingsCatalog.js" as Catalog

QtObject {
    id: root
    // All outputs share one persistence queue and undo transaction.
    property var transaction: null
    property var pendingIds: ({})
    property string message: ""
    property var runtimePending: ({})
    property string runtimeError: ""
    property string runtimeWritingId: ""
    property var runtimeWritingValue: null
    property string initialDecoder: ""
    readonly property bool busy: SettingsStore.loading || ShellSettingsStore.loading || WallpaperSettingsStore.loading || SettingsStore.saving || ShellSettingsStore.saving || WallpaperSettingsStore.saving || runtimeWriter.running
    readonly property bool dirty: Object.keys(pendingIds).length > 0 || SettingsStore.dirty || ShellSettingsStore.dirty || WallpaperSettingsStore.dirty || Object.keys(runtimePending).length > 0
    readonly property string error: SettingsStore.error || ShellSettingsStore.error || WallpaperSettingsStore.error || runtimeError
    readonly property bool restartRequired: initialDecoder.length > 0 && WallpaperSettingsStore.savedValues.playback.hardwareDecode !== initialDecoder
    readonly property bool closeBlocked: ConfigEditorStore.dirty || (!!error && dirty)
    readonly property string footerStatus: error ? "Could not save changes: " + error : restartRequired ? "Saved decoder change requires Hikai restart" : ""
    readonly property var actionLabels: error ? ["Retry", "Revert"] : restartRequired ? ["Undo", "Restart Hikai"] : []
    readonly property bool footerDirty: dirty
    readonly property bool footerError: !!error
    property Timer debounce: Timer { interval: 400; onTriggered: root.flush() }
    property Timer toast: Timer { interval: 6000; onTriggered: root.message = "" }
    property Connections wallpaperState: Connections {
        target: WallpaperSettingsStore
        function onReadyChanged() { if (WallpaperSettingsStore.ready && !root.initialDecoder) root.initialDecoder = WallpaperSettingsStore.savedValues.playback.hardwareDecode }
        function onSavedValuesChanged() { root.reconcile() }
        function onSavingChanged() { if (!WallpaperSettingsStore.saving && !WallpaperSettingsStore.error && Object.keys(root.pendingIds).length) root.debounce.restart() }
    }
    property Connections shellState: Connections { target: ShellSettingsStore; function onSavedValuesChanged() { root.reconcile() } function onSavingChanged() { if (!ShellSettingsStore.saving && !ShellSettingsStore.error && Object.keys(root.pendingIds).length) root.debounce.restart() } }
    property Connections generalState: Connections { target: SettingsStore; function onSavedValuesChanged() { root.reconcile() } function onSavedFontValuesChanged() { root.reconcile() } function onSavingChanged() { if (!SettingsStore.saving && !SettingsStore.error && Object.keys(root.pendingIds).length) root.debounce.restart() } }
    Component.onCompleted: if (WallpaperSettingsStore.ready) initialDecoder = WallpaperSettingsStore.savedValues.playback.hardwareDecode

    // Resolve each descriptor to its existing store or runtime owner.
    function read(id, saved) {
        var d = Catalog.descriptor(id)
        if (!d) return undefined
        if (d.provider === "general") return (saved ? SettingsStore.savedValues : SettingsStore.values)[d.key]
        if (d.provider === "theme") return (saved ? SettingsStore.savedFontValues : SettingsStore.fontValues)[d.key]
        if (d.provider === "shell" || d.provider === "wallpaper") {
            var store = d.provider === "shell" ? ShellSettingsStore : WallpaperSettingsStore
            return (saved ? store.savedValues : store.values)[d.section][d.key]
        }
        if (!saved && Object.prototype.hasOwnProperty.call(runtimePending, id)) return runtimePending[id]
        return ({layout: AppState.taskbarManualState ? "taskbar" : "topbar", dockbar: AppState.dockbarManualState,
            cava: AppState.cavaLayerState, "cava-color": AppState.cavaColorMode, "cava-dynamic": AppState.cavaDynamicPosition,
            "cava-position": AppState.cavaTopState ? "top" : "bottom", "cava-height": AppState.cavaHeight,
            "idle-keep-awake": AppState.idleInhibited})[id]
    }
    // Compare presentation paths without changing their stored spelling.
    function changed(id) { var d = Catalog.descriptor(id); return d && !Catalog.equal(d, read(id), d.defaultValue, Quickshell.env("HOME")) }
    // Availability and dependency reasons stay visible beside disabled controls.
    function state(id) {
        var d = Catalog.descriptor(id)
        var result = Catalog.dependencyState(d, function(key) { return root.read(key) })
        if (d.provider === "general" && !SettingsStore.isKeyEditable(d.key)) { result.enabled = false; result.reason = SettingsStore.validationMessage(d.key) }
        if (["general", "theme"].includes(d.provider) && SettingsStore.loading || d.provider === "shell" && ShellSettingsStore.loading || d.provider === "wallpaper" && WallpaperSettingsStore.loading) { result.enabled = false; result.reason = "Loading saved preferences…" }
        if (d.provider === "theme" && !SettingsStore.fontsReady) result.enabled = false
        if (d.provider === "shell" && !ShellSettingsStore.ready || d.provider === "wallpaper" && !WallpaperSettingsStore.ready) result.enabled = false
        var shell = ShellTransitionState.chromeEnabled ? "hikai" : "classic"
        if (!d.availability.shell.includes(shell)) { result.enabled = false; result.reason = "Available in Hikai shell" }
        if (!d.availability.wm.includes(WM.backendName)) { result.enabled = false; result.reason = "Unsupported by the active compositor" }
        return result
    }
    // Validate UI values against the provider's own contract.
    function validValue(d, value) {
        if (d.control === "switch" && typeof value !== "boolean") return false
        if (["number", "duration"].includes(d.control) && (!Number.isInteger(value) || value < d.min || value > d.max || (value - d.min) % (d.step || 1))) return false
        if (d.options && !d.options.some(function(option) { return option.value === value })) return false
        if (d.control === "list" && (!Array.isArray(value) || value.some(function(v) { return typeof v !== "string" || !v.trim() || /[\r\n\0]/.test(v) }) || new Set(value).size !== value.length)) return false
        if (["path", "text"].includes(d.control) && (typeof value !== "string" || /[\r\n\0]/.test(value) || (d.control === "path" && !value))) return false
        if (d.provider === "general") {
            if (!SettingsStore.isKeyEditable(d.key)) return false
            var general = Object.assign({}, SettingsStore.values); general[d.key] = value
            return Object.keys(SettingsStore.validateAll(general)).length === 0
        }
        if (d.provider === "theme") { var font = Object.assign({}, SettingsStore.fontValues); font[d.key] = value; return SettingsStore.validateFonts(font) }
        if (["shell", "wallpaper"].includes(d.provider)) {
            var store = d.provider === "shell" ? ShellSettingsStore : WallpaperSettingsStore
            var draft = JSON.parse(JSON.stringify(store.values)); draft[d.section][d.key] = value
            return store.validate(draft)
        }
        return true
    }
    // Merge nearby edits into a single undo transaction with the original value.
    function set(id, value, deferred, undoing) {
        var d = Catalog.descriptor(id)
        if (!d || !validValue(d, value) || Catalog.equal(d, read(id), value, Quickshell.env("HOME"))) return false
        if (["general", "theme"].includes(d.provider) && SettingsStore.loading || d.provider === "shell" && (!ShellSettingsStore.ready || ShellSettingsStore.loading) || d.provider === "wallpaper" && (!WallpaperSettingsStore.ready || WallpaperSettingsStore.loading)) return false
        var before = read(id)
        if (!undoing) {
            var now = Date.now()
            transaction = {descriptorId: id, provider: d.provider, before: transaction && transaction.descriptorId === id && now - transaction.timestamp < 1500 ? transaction.before : before, after: value, timestamp: now}
            message = "Changed “" + d.label + "”"
            toast.restart()
        }
        if (d.provider === "general") SettingsStore.setValue(d.key, value)
        else if (d.provider === "theme") SettingsStore.setFontValue(d.key, value)
        else if (d.provider === "shell") ShellSettingsStore.setValue(d.section, d.key, value)
        else if (d.provider === "wallpaper") WallpaperSettingsStore.setValue(d.section, d.key, value)
        else { var pending = Object.assign({}, runtimePending); pending[id] = value; runtimePending = pending }
        if (d.provider !== "runtime-state") { var pendingPreferences = Object.assign({}, pendingIds); pendingPreferences[id] = value; pendingIds = pendingPreferences }
        if (deferred) debounce.restart()
        else flush()
        return true
    }
    // Save patches only; each provider preserves unrelated disk preferences.
    function flush() {
        var selected = {general: [], shell: [], wallpaper: []}
        for (var id in pendingIds) {
            var d = Catalog.descriptor(id), provider = d.provider === "theme" ? "general" : d.provider
            selected[provider].push(d.section ? d.section + "." + d.key : d.key)
        }
        if (selected.general.length && !SettingsStore.error) SettingsStore.apply(selected.general)
        if (selected.shell.length && !ShellSettingsStore.error) ShellSettingsStore.apply(selected.shell)
        if (selected.wallpaper.length && !WallpaperSettingsStore.error) WallpaperSettingsStore.apply(selected.wallpaper)
        if (!runtimeWriter.running && !runtimeError && Object.keys(runtimePending).length) {
            runtimeWritingId = Object.keys(runtimePending)[0]
            runtimeWritingValue = runtimePending[runtimeWritingId]
            runtimeWriter.command = runtimeCommand(runtimeWritingId, runtimeWritingValue)
            runtimeWriter.running = true
        }
    }
    // Confirm only the requested values; edits made during a write remain queued.
    function reconcile() {
        var pending = Object.assign({}, pendingIds)
        for (var id in pending) if (Catalog.equal(Catalog.descriptor(id), read(id, true), pending[id], Quickshell.env("HOME"))) delete pending[id]
        pendingIds = pending
    }
    // Use argument arrays and explicit targets, never a stale-state toggle.
    function runtimeCommand(id, value) {
        var script = id === "layout" ? "taskbar_manager.sh" : id === "dockbar" ? "dockbar_manager.sh" : id === "idle-keep-awake" ? "idle_inhibit.sh" : "cava_manager.sh"
        var relative = id === "layout" || id === "dockbar" ? "facade/" : id === "idle-keep-awake" ? "sys/" : "app/cava-layer/"
        var args = id === "layout" ? ["--layout", value] : id === "dockbar" ? [value ? "--enable" : "--disable"]
            : id === "idle-keep-awake" ? ["--set", value ? "on" : "off"]
            : [({cava: "--enabled", "cava-color": "--color-mode", "cava-dynamic": "--dynamic", "cava-position": "--position", "cava-height": "--height"})[id], typeof value === "boolean" ? value ? "on" : "off" : String(value)]
        return ["sh", "-c", 'ctl=$1; [ -f "$ctl" ] || ctl=$2; shift 2; exec bash "$ctl" "$@"', "--", Env.binDir + "/" + script, Quickshell.shellPath("../../../../core/" + relative + script)].concat(args)
    }
    // Update shared state immediately after success while FileViews catch up.
    function acceptRuntime(id, value) {
        if (id === "layout") AppState.taskbarManualState = value === "taskbar"
        else if (id === "dockbar") AppState.dockbarManualState = value
        else if (id === "cava") AppState.cavaLayerState = value
        else if (id === "cava-color") AppState.cavaColorMode = value
        else if (id === "cava-dynamic") AppState.cavaDynamicPosition = value
        else if (id === "cava-position") AppState.cavaTopState = value === "top"
        else if (id === "cava-height") AppState.cavaHeight = value
        else if (id === "idle-keep-awake") { AppState.idleInhibited = value; IdleService.refreshInhibit() }
    }
    // Undo restores the draft and submits the old value through the same provider.
    function undo() { if (!transaction || busy) return; var t = transaction; transaction = null; set(t.descriptorId, t.before, false, true); message = "Change undone"; toast.restart() }
    function reset(id) { var d = Catalog.descriptor(id); if (d && d.resettable) set(id, d.defaultValue, false) }
    function canActivate(label) { return !busy && (label !== "Restart Hikai" || (!ConfigEditorStore.dirty && !dirty && !LockState.locked)) && (label !== "Undo" || !!transaction || restartRequired) }
    function activateAction(label) {
        if (label === "Retry") { SettingsStore.error = ""; ShellSettingsStore.error = ""; WallpaperSettingsStore.error = ""; runtimeError = ""; flush() }
        else if (label === "Revert") { SettingsStore.discard(); ShellSettingsStore.discard(); WallpaperSettingsStore.discard(); pendingIds = ({}); runtimePending = ({}); runtimeError = "" }
        else if (label === "Undo" && restartRequired) { set("wallpaper.playback.hardwareDecode", initialDecoder, false, true); message = "Decoder change undone"; toast.restart() }
        else if (label === "Undo") undo()
        else if (label === "Restart Hikai") Quickshell.reload(false)
    }
    // Sidebar dots report action state rather than differences from defaults.
    function categoryStatus(category) {
        if (category === "Advanced" && ConfigEditorStore.dirty) return true
        if (category === "Wallpaper" && restartRequired) return true
        return !!error && Catalog.descriptors.some(function(d) { return d.category === category && JSON.stringify(root.read(d.id)) !== JSON.stringify(root.read(d.id, true)) })
    }
    property Process runtimeWriter: Process {
        stderr: StdioCollector { id: runtimeErr }
        onExited: code => {
            var id = root.runtimeWritingId, value = root.runtimeWritingValue
            root.runtimeWritingId = ""
            if (code !== 0) { root.runtimeError = runtimeErr.text.trim() || "Runtime controller failed"; return }
            root.acceptRuntime(id, value)
            var pending = Object.assign({}, root.runtimePending)
            if (pending[id] === value) delete pending[id]
            root.runtimePending = pending
            root.debounce.restart()
        }
    }
}
