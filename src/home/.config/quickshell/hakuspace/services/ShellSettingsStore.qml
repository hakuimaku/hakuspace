pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "."
import "../config/Defaults.js" as Defaults

QtObject {
    id: root
    // Track backend operations and user-facing feedback independently of General settings.
    property bool ready: false
    property bool loading: false
    property bool saving: false
    // A legacy document can be explicitly applied without editing a preference.
    property bool migrationPending: false
    property string error: ""
    property string statusMessage: ""
    // Shell consumers bind to the draft; autosave confirms the disk snapshot.
    property var values: defaults()
    property var savedValues: defaults()
    // Retain edits made while the submitted snapshot is being saved.
    property var writingSnapshot: defaults()
    readonly property bool dirty: JSON.stringify(values) !== JSON.stringify(savedValues)
    readonly property bool valid: validate(values)
    readonly property int baseRadius: values.appearance.baseRadius
    // Hikai mode previews with the appearance draft.
    readonly property string colorMode: values.appearance.colorMode
    readonly property string surfaceTone: values.appearance.surfaceTone
    readonly property int roundedScreenRadius: values.roundedScreen.radius
    readonly property int roundedScreenBorderThickness: values.roundedScreen.borderThickness
    readonly property bool showWorkspaces: values.topbar.workspaces
    readonly property bool showWindowTitle: values.topbar.windowTitle
    readonly property bool showCenter: values.topbar.center
    readonly property bool showCava: values.topbar.cava
    readonly property bool showTray: values.topbar.tray
    readonly property bool showQuickControls: values.topbar.quickControls
    readonly property bool showPowerProfile: values.topbar.powerProfile
    readonly property bool showWallpaperWorkspace: values.topbar.wallpaperWorkspace
    readonly property bool showRecorder: values.topbar.recorder
    readonly property bool showClock: values.topbar.clock
    readonly property bool showNotifications: values.topbar.notifications
    // Compact Dockbar behavior remains independent from Taskbar topology.
    readonly property string dockVisibilityMode: values.dock.visibilityMode
    readonly property bool dockExclusiveSpace: values.dock.exclusiveSpace
    readonly property int dockIconSize: values.dock.iconSize
    readonly property int dockHoverLift: values.dock.hoverLift
    readonly property int dockHoverScale: values.dock.hoverScale
    readonly property bool dockShowTrash: values.dock.showTrash
    readonly property bool dockShowDevices: values.dock.showDevices
    // Idle consumes only saved policy; editing a timeout cannot suspend during preview.
    readonly property bool idleEnabled: savedValues.idle.enabled

    // Produce independent snapshots so Discard never shares mutable nested objects.
    function defaults() {
        return Defaults.shellDefaults()
    }
    // Mirror the backend contract before applying or accepting a response.
    function validate(draft) {
        var schema = defaults()
        if (!draft || draft.version !== Defaults.shellSchemaVersion || Object.keys(draft).length !== 6) return false
        for (var section of ["appearance", "roundedScreen", "topbar", "dock", "idle"]) {
            if (!draft[section] || Object.keys(draft[section]).length !== Object.keys(schema[section]).length) return false
            for (var key in schema[section]) {
                var value = draft[section][key]
                if (section === "idle") {
                    if (typeof schema.idle[key] === "boolean") { if (typeof value !== "boolean") return false }
                    else if (!Number.isInteger(value) || value < (key === "dimPercent" ? 1 : 10) || value > (key === "dimPercent" ? 100 : 86400) || (key.endsWith("Timeout") && value % 10 !== 0)) return false
                }
                if (section === "topbar" && typeof value !== "boolean") return false
                if (key === "visibilityMode" && ["autohide", "always"].indexOf(value) < 0) return false
                if (["exclusiveSpace", "showTrash", "showDevices"].indexOf(key) >= 0 && typeof value !== "boolean") return false
                if (key === "iconSize" && (!Number.isInteger(value) || value < 24 || value > 72 || value % 4 !== 0)) return false
                if (key === "hoverLift" && (!Number.isInteger(value) || value < 0 || value > 48)) return false
                if (key === "hoverScale" && (!Number.isInteger(value) || value < 0 || value > 100)) return false
                if (section === "roundedScreen" && (!Number.isInteger(value) || value < 0 || value > (key === "radius" ? 24 : 6))) return false
                if (key === "baseRadius" && (!Number.isInteger(value) || value < 4 || value > 24)) return false
                if (key === "colorMode" && ["dark", "light"].indexOf(value) < 0) return false
                if (key === "surfaceTone" && ["ink", "dark", "soft"].indexOf(value) < 0) return false
            }
        }
        return true
    }
    // Resolve the installed controller with the same source-tree fallback as General.
    function command(action) {
        return ["sh", "-c", 'if [ -x "$1" ]; then exec "$1" "$4"; elif [ -x "$2" ]; then exec "$2" "$4"; else exec "$3" "$4"; fi',
            "--", (Quickshell.env("HOME") || "") + "/.local/bin/hikai_settings_ctl.py",
            Env.binDir + "/hikai_settings_ctl.py",
            Quickshell.shellPath("../../../../core/backend/user/hikai_settings_ctl.py"), action]
    }
    // Update a validated draft atomically so Theme and every output react together.
    function setValue(section, key, value) {
        if (!ready || loading) return
        var draft = JSON.parse(JSON.stringify(values))
        if (!draft[section] || !Object.prototype.hasOwnProperty.call(draft[section], key)) return
        draft[section][key] = value
        if (!validate(draft)) { error = section === "idle" ? "Use increasing timeouts for enabled stages: dim, lock, display off, suspend (10–86400 seconds)." : "Invalid shell preference"; return }
        values = draft
        error = ""
        statusMessage = ""
    }
    // Restore the confirmed snapshot immediately without writing to disk.
    function discard() {
        if (saving || loading) return
        values = JSON.parse(JSON.stringify(savedValues))
        error = ""
        statusMessage = ""
    }
    // Reset is a preview; users still choose Apply or Discard.
    function reset() {
        if (!ready || saving || loading) return
        values = defaults()
        error = ""
        statusMessage = ""
    }
    // Explicit reload replaces the draft only after a successful backend read.
    function reload() {
        if (loading || saving) return
        loading = true
        error = ""
        readProc.command = command("read")
        readProc.running = true
    }
    // Send changed fields so unrelated valid disk preferences survive Apply.
    function apply(keys) {
        if (!ready || (!dirty && !migrationPending && !(keys && keys.length)) || !valid || loading || saving) return
        var patch = {}
        for (var section of ["appearance", "roundedScreen", "topbar", "dock", "idle"]) {
            for (var key in values[section]) {
                if (keys ? !keys.includes(section + "." + key) : values[section][key] === savedValues[section][key]) continue
                if (!patch[section]) patch[section] = {}
                patch[section][key] = values[section][key]
            }
        }
        writingSnapshot = JSON.parse(JSON.stringify(savedValues))
        for (var submittedSection in patch) Object.assign(writingSnapshot[submittedSection], patch[submittedSection])
        saving = true
        error = ""
        writeProc.modeOnly = false
        writeProc.command = command("write")
        writeProc.environment = {"HAKUSPACE_HIKAI_SETTINGS_JSON": JSON.stringify(patch)}
        writeProc.running = true
    }
    // Save a quick mode change without applying unrelated Settings drafts.
    function applyColorMode(mode) {
        if (!ready || loading || saving || ["dark", "light"].indexOf(mode) < 0) return
        saving = true
        error = ""
        writingSnapshot = JSON.parse(JSON.stringify(values))
        writeProc.modeOnly = true
        writeProc.command = command("write")
        writeProc.environment = {"HAKUSPACE_HIKAI_SETTINGS_JSON": JSON.stringify({appearance: {colorMode: mode}})}
        writeProc.running = true
    }
    // Accept a valid snapshot while retaining unrelated drafts after a quick mode change.
    function accept(text, preserveDraft) {
        var data = JSON.parse(text)
        if (!data.ok || !validate(data.values)) throw new Error("Invalid shell settings response")
        // Merge pending edits onto the confirmed disk snapshot.
        var draft = JSON.parse(JSON.stringify(data.values))
        if (preserveDraft) {
            for (var section of ["appearance", "roundedScreen", "topbar", "dock", "idle"]) {
                for (var key in values[section]) {
                    if (section === "appearance" && key === "colorMode") continue
                    if (values[section][key] !== savedValues[section][key]) draft[section][key] = values[section][key]
                }
            }
        }
        savedValues = data.values
        migrationPending = data.needsMigration === true
        values = draft
        ready = true
    }
    // Merge newer draft fields onto the response instead of losing in-flight edits.
    function acceptWrite(text, modeOnly) {
        var pending = JSON.parse(JSON.stringify(values))
        accept(text, modeOnly)
        if (modeOnly) {
            if (pending.appearance.colorMode !== writingSnapshot.appearance.colorMode) {
                var modeDraft = JSON.parse(JSON.stringify(values)); modeDraft.appearance.colorMode = pending.appearance.colorMode; values = modeDraft
            }
            return
        }
        var next = JSON.parse(JSON.stringify(savedValues))
        for (var section in pending) {
            if (section === "version") continue
            for (var key in pending[section]) {
                if (pending[section][key] !== writingSnapshot[section][key]) next[section][key] = pending[section][key]
            }
        }
        values = next
        error = ""
    }
    Component.onCompleted: reload()

    property Process readProc: Process {
        stdout: StdioCollector { id: readOut }
        stderr: StdioCollector { id: readErr }
        onExited: (code, status) => {
            root.loading = false
            if (code !== 0) { root.error = readErr.text.trim() || "Could not read shell settings"; return }
            try { root.accept(readOut.text); root.statusMessage = "" }
            catch (e) { root.error = "Invalid shell settings response" }
        }
    }
    property Process writeProc: Process {
        // Mode-only writes leave other settings pending for Apply or Discard.
        property bool modeOnly: false
        stdout: StdioCollector { id: writeOut }
        stderr: StdioCollector { id: writeErr }
        onExited: (code, status) => {
            root.saving = false
            if (code !== 0) { root.error = writeErr.text.trim() || "Could not save shell settings"; return }
            try { root.acceptWrite(writeOut.text, modeOnly); root.statusMessage = "Shell preferences saved." }
            catch (e) { root.error = "Invalid shell save response" }
        }
    }
}
