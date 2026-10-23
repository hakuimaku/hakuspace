pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root
    // Draft preferences stay separate from the renderer's confirmed snapshot.
    property var values: defaults()
    property var savedValues: defaults()
    property bool ready: false
    property bool loading: false
    property bool saving: false
    property string error: ""
    property string statusMessage: ""
    readonly property bool dirty: JSON.stringify(values) !== JSON.stringify(savedValues)
    readonly property bool valid: validate(values)
    signal applied()

    // Mirror the small backend schema for immediate draft feedback.
    function defaults() {
        return {version: 1, playback: {profile: "screen", hardwareDecode: "auto", pauseWhenFullscreen: true,
            unloadWhenHidden: true, unloadDelaySec: 20, loop: true}, proxy: {buildPolicy: "on-select", maxCacheMiB: 4096},
            browser: {filter: "static", sort: "name", showMetadata: true, motionPreview: false}}
    }
    // Reject invalid drafts before they reach the persistence boundary.
    function validate(draft) {
        var schema = defaults()
        if (!draft || draft.version !== 1 || Object.keys(draft).length !== 4) return false
        var enums = {profile: ["low-memory", "screen", "original"], hardwareDecode: ["auto", "prefer", "software"],
            buildPolicy: ["on-select", "background", "manual"], filter: ["static", "video"], sort: ["name"]}
        for (var section of ["playback", "proxy", "browser"]) {
            if (!draft[section] || Object.keys(draft[section]).length !== Object.keys(schema[section]).length) return false
            for (var key in schema[section]) {
                var value = draft[section][key]
                if (enums[key]) { if (!enums[key].includes(value)) return false }
                else if (key === "maxCacheMiB") { if (!Number.isInteger(value) || value < 64 || value > 65536) return false }
                else if (key === "unloadDelaySec") { if (!Number.isInteger(value) || value < 1 || value > 600) return false }
                else if (typeof value !== "boolean" || (key === "motionPreview" && value)) return false
            }
        }
        return true
    }
    // Resolve either an installed script or its repository counterpart.
    function command(action) {
        return ["sh", "-c", 'if [ -f "$1" ]; then exec python3 "$1" "$3"; else exec python3 "$2" "$3"; fi',
            "--", Env.binDir + "/hikai_wallpaper_settings_ctl.py",
            Quickshell.shellPath("../../../../core/backend/user/hikai_wallpaper_settings_ctl.py"), action]
    }
    // Replace the draft atomically so Discard retains independent nested objects.
    function setValue(section, key, value) {
        if (!ready || loading || saving) return
        var next = JSON.parse(JSON.stringify(values))
        if (!next[section] || !Object.prototype.hasOwnProperty.call(next[section], key)) return
        next[section][key] = value
        if (validate(next)) { values = next; error = ""; statusMessage = "" }
    }
    // Restore the saved snapshot without affecting persistence or playback.
    function discard() { if (!loading && !saving) { values = JSON.parse(JSON.stringify(savedValues)); error = "" } }
    // Defaults are a draft until Apply succeeds.
    function reset() { if (ready && !loading && !saving) values = defaults() }
    // Read preferences asynchronously while preserving failed drafts.
    function reload() {
        if (loading || saving) return
        loading = true
        reader.command = command("read")
        reader.running = true
    }
    // Merge changed fields on disk instead of replacing unrelated saved preferences.
    function apply() {
        if (!ready || !dirty || !valid || loading || saving) return
        var patch = {}
        for (var section of ["playback", "proxy", "browser"]) {
            for (var key in values[section]) {
                if (values[section][key] === savedValues[section][key]) continue
                if (!patch[section]) patch[section] = {}
                patch[section][key] = values[section][key]
            }
        }
        saving = true
        writer.environment = {HAKUSPACE_WALLPAPER_SETTINGS_JSON: JSON.stringify(patch)}
        writer.command = command("write")
        writer.running = true
    }
    // Accept only a complete validated backend response.
    function accept(text) {
        var data = JSON.parse(text)
        if (!data.ok || !validate(data.values)) throw new Error("Invalid wallpaper settings response")
        savedValues = data.values
        values = JSON.parse(JSON.stringify(data.values))
        ready = true
        error = ""
    }
    Component.onCompleted: reload()
    property Process reader: Process {
        stdout: StdioCollector { id: readOut }
        stderr: StdioCollector { id: readErr }
        onExited: code => {
            root.loading = false
            if (code !== 0) { root.error = readErr.text.trim() || "Could not read wallpaper settings"; return }
            try { root.accept(readOut.text) } catch (e) { root.error = String(e) }
        }
    }
    property Process writer: Process {
        stdout: StdioCollector { id: writeOut }
        stderr: StdioCollector { id: writeErr }
        onExited: code => {
            root.saving = false
            if (code !== 0) { root.error = writeErr.text.trim() || "Could not save wallpaper settings"; return }
            try {
                var decodeChanged = root.savedValues.playback.hardwareDecode !== root.values.playback.hardwareDecode
                root.accept(writeOut.text)
                root.statusMessage = decodeChanged ? "Saved · decoder policy applies on next Hikai start" : "Wallpaper settings saved"
                root.applied()
            } catch (e) { root.error = String(e) }
        }
    }
}
