pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "."

QtObject {
    id: root
    property bool ready: false
    property bool readingSettings: false
    property bool readingFonts: false
    readonly property bool loading: readingSettings || readingFonts
    property bool saving: false
    property string error: ""
    property string statusMessage: ""
    property string settingPath: ""
    property string settingVersion: ""
    // values is the live draft; savedValues is the last confirmed disk snapshot.
    property var values: ({})
    property var savedValues: ({})
    property var unsupportedKeys: []
    property var missingKeys: []
    property var duplicateKeys: []
    // Typography uses canonical theme state rather than adding setting.sh assignments.
    property var fontValues: ({family: "", size: 14})
    property var savedFontValues: ({family: "", size: 14})
    property var writingFonts: ({})
    property var writingFontKeys: []
    property bool fontsReady: false
    readonly property bool fontsDirty: JSON.stringify(fontValues) !== JSON.stringify(savedFontValues)
    readonly property bool dirty: fontsDirty || JSON.stringify(values) !== JSON.stringify(savedValues)
    readonly property var validityByKey: validateAll(values)
    readonly property bool valid: Object.keys(validityByKey).length === 0 && duplicateKeys.length === 0 && (!fontsDirty || validateFonts(fontValues))
    // Keep the submitted draft so later edits survive an in-flight save.
    property var writingSnapshot: ({})

    readonly property var catalog: [
        { key: "WELCOME_MSG", group: "General", label: "Welcome message", type: "bool", hint: "Show the welcome message on startup." },
        { key: "NIGHT_LIGHT_TEMPERATURE", group: "General", label: "Night light temperature", type: "int", hint: "Color temperature used by night light." },
        { key: "SCREENSHOT_DIR", group: "General", label: "Screenshot directory", type: "path", hint: "Directory where HakuSpace screenshots are saved. Niri uses its built-in screenshot tool, so this setting does not apply there. Configure Niri in ~/hakucfg/wm/niri-custom.kdl, or bind the HakuSpace screenshot script." },
        { key: "WALL_DIR", group: "Wallpaper", label: "Wallpaper directory", type: "path", hint: "Directory containing static wallpapers." },
        { key: "WALL_MPV_DIR", group: "Wallpaper", label: "Video wallpaper directory", type: "path", hint: "Directory for lively video wallpapers." },
        { key: "WALL_INTERVAL", group: "Wallpaper", label: "Change interval (seconds)", type: "int", hint: "Interval in seconds between random wallpaper changes." },
        { key: "ACCENT_COLOR_BASED_ON_WALLPAPER", group: "Wallpaper", label: "Accent from wallpaper", type: "bool", hint: "Derive the accent color from the wallpaper." },
        { key: "AWWW_OPTS", group: "Wallpaper", label: "Awww options", type: "text", hint: "Options for awww wallpaper transitions." },
        { key: "ACCENT_COLOR_MODE", group: "Wallpaper", label: "Accent color mode", type: "enum", hint: "Extract an accent from the wallpaper:\nvivid — most vivid color\ndominant — dominant color\nbrightest — brightest color\nsaturated — most saturated color" },
        { key: "SCREENREC_SAVE_DIR", group: "Screen Recording", label: "Recording directory", type: "path", hint: "Directory where screen recordings are saved." },
        { key: "REC_COMMAND", group: "Screen Recording", label: "Recording command", type: "required", hint: "Command for wl-screenrec. Ensure it is in PATH, or use the full path if installed with Cargo." },
        { key: "REC_OPTS", group: "Screen Recording", label: "Recording options", type: "text", hint: "Options passed to wl-screenrec; customize them as needed." },
        { key: "HAKU_CLOCK_FONT_SIZE", group: "Haku Widget", label: "Clock font size", type: "int", hint: "Clock text size in Haku Widget." },
        { key: "HAKU_GENERAL_FONT_SIZE", group: "Haku Widget", label: "General font size", type: "int", hint: "General text size in Haku Widget." },
        { key: "HAKU_TERMINAL_FONT_SIZE", group: "Haku Widget", label: "Terminal font size", type: "int", hint: "Terminal text size in Haku Widget." },
        { key: "WAYBAR_MODE_USER", group: "Waybar", label: "Custom Waybar themes", type: "list", hint: "Classic theme folder names under ~/hakucfg/config/waybar." },
        { key: "RAM_THRESHOLD_MB", group: "Exit", label: "RAM warning threshold (MB)", type: "int", hint: "RAM warning threshold in megabytes when exiting the window manager." },
        { key: "EXIT_APP_LIST_USER", group: "Exit", label: "Apps to close", type: "list", hint: "Apps targeted for graceful shutdown, then forced termination, when exiting the window manager. Example: discord, firefox, code." }
    ]
    readonly property var groups: ["General"]
    readonly property string deployedScript: (Quickshell.env("HOME") || "") + "/.local/bin/setting_ctl.py"
    readonly property string repoScript: Quickshell.shellPath("../../../../core/backend/user/setting_ctl.py")
    readonly property string envScript: Env.binDir + "/setting_ctl.py"

    function command(action) {
        return ["sh", "-c", 'if [ -x "$1" ]; then exec "$1" "$4"; elif [ -x "$2" ]; then exec "$2" "$4"; elif [ -x "$3" ]; then exec "$3" "$4"; else exec setting_ctl.py "$4"; fi',
                "--", deployedScript, envScript, repoScript, action]
    }

    // Pass font values as arguments to the existing theme controller.
    function themeCommand(action) {
        return ["sh", "-c", 'if [ -x "$1" ]; then ctl=$1; elif [ -x "$2" ]; then ctl=$2; else ctl=$3; fi; if [ "$4" = read ]; then exec "$ctl" status; elif [ "$4" = list-fonts ]; then exec "$ctl" list-fonts; fi; if [ "$5" = 1 ]; then "$ctl" set-font "$6" || exit $?; fi; if [ "$7" = 1 ]; then "$ctl" set-size "$8" || exit $?; fi; exec "$ctl" status',
            "--", (Quickshell.env("HOME") || "") + "/.local/bin/theme_ctl.sh", Env.binDir + "/theme_ctl.sh",
            Quickshell.shellPath("../../../../core/backend/theme/theme_ctl.sh"), action,
            writingFontKeys.includes("family") ? "1" : "0", writingFonts.family || "",
            writingFontKeys.includes("size") ? "1" : "0", String(writingFonts.size || 14)]
    }
    function validateFonts(draft) {
        return typeof draft.family === "string" && draft.family.trim().length > 0 && !/[\r\n\0]/.test(draft.family)
            && Number.isInteger(draft.size) && draft.size > 0
    }
    function setFontValue(key, value) {
        if (!fontsReady || loading || !["family", "size"].includes(key)) return
        var draft = Object.assign({}, fontValues)
        draft[key] = value
        if (!validateFonts(draft)) return
        fontValues = draft
        error = ""
        statusMessage = ""
    }
    // Read controller status without recovering state from generated theme files.
    function acceptFonts(text, preserveDraft) {
        var data = {}
        for (var line of text.trim().split("\n")) {
            if (line.startsWith("font=")) data.family = line.substring(5)
            if (line.startsWith("size=")) data.size = Number(line.substring(5))
        }
        if (!validateFonts(data)) throw new Error("Invalid font settings")
        savedFontValues = data
        if (!preserveDraft || JSON.stringify(fontValues) === JSON.stringify(writingFonts)) fontValues = Object.assign({}, data)
        fontsReady = true
    }
    // Keep one Apply operation active until both preference stores finish.
    function saveFontsOrFinish() {
        if (writingFontKeys.length) { fontWrite.command = themeCommand("write"); fontWrite.running = true; return }
        saving = false
        statusMessage = "Preferences saved."
    }

    // Mirror backend validation before Apply becomes available.
    function validateAll(draft) {
        var errors = {}
        for (var i = 0; i < catalog.length; i++) {
            var item = catalog[i]
            if (!Object.prototype.hasOwnProperty.call(draft, item.key)) continue
            var value = draft[item.key]
            // Only the RAM threshold accepts zero; other integer settings stay positive.
            if (item.type === "int" && (!/^(0|[1-9][0-9]*)$/.test(String(value)) || !Number.isSafeInteger(Number(value)) || Number(value) < (item.key === "RAM_THRESHOLD_MB" ? 0 : 1))) errors[item.key] = item.key === "RAM_THRESHOLD_MB" ? "Enter a non-negative integer" : "Enter a positive integer"
            else if ((item.type === "path" || item.type === "required") && (!String(value).length || /[\r\n\0]/.test(value))) errors[item.key] = "Enter a value on one line"
            else if (item.type === "enum" && ["vivid", "dominant", "brightest", "saturated"].indexOf(value) < 0) errors[item.key] = "Choose a listed mode"
            else if (item.type === "list" && (!Array.isArray(value) || value.some(function(entry) { return !entry || /[\r\n\0]/.test(entry) }))) errors[item.key] = "Invalid list item"
            else if (item.type === "text" && /[\r\n\0]/.test(value)) errors[item.key] = "Use one line"
        }
        return errors
    }

    function value(key) { return values[key] }
    function isKeyEditable(key) {
        return ready && missingKeys.indexOf(key) < 0 && unsupportedKeys.indexOf(key) < 0 && duplicateKeys.length === 0
    }
    function validationMessage(key) {
        if (missingKeys.indexOf(key) >= 0) return "This preference is unavailable in your installed configuration."
        if (unsupportedKeys.indexOf(key) >= 0) return "Edit this customized assignment directly in setting.sh."
        if (duplicateKeys.length) return "Remove duplicate assignments in setting.sh before saving."
        return validityByKey[key] || ""
    }
    function setValue(key, value) {
        if (!isKeyEditable(key)) return
        var draft = Object.assign({}, values)
        draft[key] = value
        values = draft
        statusMessage = ""
    }
    function discard() { values = Object.assign({}, savedValues); fontValues = Object.assign({}, savedFontValues); error = ""; statusMessage = "" }
    function load() { reload() }
    function reload() {
        if (loading || saving) return
        readingSettings = true
        readingFonts = true
        error = ""
        fontRead.command = themeCommand("read")
        fontRead.running = true
        readProc.command = command("read")
        readProc.running = true
    }
    // Send changed keys only; the backend preserves unrelated setting.sh lines.
    function apply(keys) {
        if (!ready || (!dirty && !(keys && keys.length)) || !valid || loading || saving) return
        var changes = {}
        for (var key in values) {
            if (keys ? keys.includes(key) : JSON.stringify(values[key]) !== JSON.stringify(savedValues[key])) {
                var item = values[key]
                changes[key] = typeof item === "string" && /^[1-9][0-9]*$/.test(item) && catalog.some(function(c) { return c.key === key && c.type === "int" }) ? Number(item) : item
            }
        }
        writingSnapshot = Object.assign({}, savedValues, changes)
        writingFonts = Object.assign({}, savedFontValues)
        writingFontKeys = ["family", "size"].filter(function(key) { return keys ? keys.includes(key) : fontValues[key] !== savedFontValues[key] })
        for (var fontKey of writingFontKeys) writingFonts[fontKey] = fontValues[fontKey]
        saving = true
        error = ""
        if (!Object.keys(changes).length) { saveFontsOrFinish(); return }
        writeProc.command = command("write")
        writeProc.environment = { "HAKUSPACE_SETTINGS_JSON": JSON.stringify(changes) }
        writeProc.running = true
    }
    function accept(data, preserveDraft) {
        settingPath = data.path || ""
        settingVersion = data.settingVersion || ""
        unsupportedKeys = data.unsupportedKeys || []
        missingKeys = data.missingKeys || []
        duplicateKeys = data.duplicateKeys || []
        savedValues = data.values || ({})
        if (!preserveDraft) values = Object.assign({}, savedValues)
        ready = true
    }

    property Process readProc: Process {
        id: readProc
        stdout: StdioCollector { id: readOut }
        stderr: StdioCollector { id: readErr }
        onExited: (code, status) => {
            root.readingSettings = false
            if (code !== 0) { root.ready = false; root.error = readErr.text.trim() || "Could not read setting.sh"; return }
            try { root.accept(JSON.parse(readOut.text), false); root.statusMessage = "" }
            catch (e) { root.ready = false; root.error = "Invalid settings response" }
        }
    }
    property Process writeProc: Process {
        id: writeProc
        stdout: StdioCollector { id: writeOut }
        stderr: StdioCollector { id: writeErr }
        onExited: (code, status) => {
            if (code !== 0) { root.saving = false; root.error = writeErr.text.trim() || "Could not save setting.sh"; return }
            try {
                var current = root.values
                root.accept(JSON.parse(writeOut.text), true)
                if (JSON.stringify(current) === JSON.stringify(root.writingSnapshot)) root.values = Object.assign({}, root.savedValues)
                root.saveFontsOrFinish()
            } catch (e) { root.saving = false; root.error = "Invalid save response" }
        }
    }
    property Process fontRead: Process {
        stdout: StdioCollector { id: fontReadOut }
        stderr: StdioCollector { id: fontReadErr }
        onExited: code => {
            root.readingFonts = false
            if (code !== 0) { root.fontsReady = false; root.error = fontReadErr.text.trim() || "Could not read font settings"; return }
            try { root.acceptFonts(fontReadOut.text, false) }
            catch (error) { root.fontsReady = false; root.error = "Invalid font settings response" }
        }
    }
    property Process fontWrite: Process {
        stdout: StdioCollector { id: fontWriteOut }
        stderr: StdioCollector { id: fontWriteErr }
        onExited: code => {
            root.saving = false
            if (code !== 0) { root.error = fontWriteErr.text.trim() || "Could not save font settings"; return }
            try { root.acceptFonts(fontWriteOut.text, true); root.statusMessage = "Preferences saved." }
            catch (error) { root.error = "Could not confirm saved font settings" }
        }
    }

}
