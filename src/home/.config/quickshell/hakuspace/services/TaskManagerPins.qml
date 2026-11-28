pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    // Persistent pin rules survive restarts/reboots; signals still target exact pid:startTime only.
    property var pins: []
    readonly property var keys: pinnedKeys
    readonly property var pinnedKeys: {
        var procs = TaskManagerService.processes || []
        var out = []
        var seen = Object.create(null)
        for (var i = 0; i < procs.length; ++i) {
            var proc = procs[i]
            if (proc && proc.key && isPinned(proc) && !seen[proc.key]) {
                seen[proc.key] = true
                out.push(proc.key)
            }
        }
        for (var j = 0; j < pins.length; ++j) {
            var rule = pins[j]
            if (rule.kind === "legacy" && rule.legacyKey && !seen[rule.legacyKey]) {
                seen[rule.legacyKey] = true
                out.push(rule.legacyKey)
            }
        }
        return out
    }
    readonly property var pinnedProcesses: {
        var procs = TaskManagerService.processes || []
        var usedRowKeys = Object.create(null)
        var rows = []
        for (var i = 0; i < pins.length; ++i) {
            var rule = pins[i]
            var matched = []
            for (var j = 0; j < procs.length; ++j) {
                if (matchesRule(rule, procs[j])) matched.push(procs[j])
            }
            if (matched.length === 0) {
                // Keep persistent rules visible as offline rows so users can manage them after reboot.
                if (rule.kind === "legacy") continue
                rows.push({
                    key: rule.id,
                    pinId: rule.id,
                    name: rule.label || rule.name || rule.matchExe,
                    cpuTotalPercent: null,
                    rss: null,
                    online: false,
                    matchCount: 0,
                    matchedKeys: []
                })
                continue
            }
            var totalCpu = 0
            var hasCpu = false
            var totalRss = 0
            var hasRss = false
            var matchedKeys = []
            for (var k = 0; k < matched.length; ++k) {
                var item = matched[k]
                matchedKeys.push(item.key)
                if (Number.isFinite(item.cpuTotalPercent)) { totalCpu += item.cpuTotalPercent; hasCpu = true }
                if (Number.isFinite(item.rss)) { totalRss += item.rss; hasRss = true }
            }
            var preferredKey = matched.length === 1 ? matched[0].key : rule.id
            var rowKey = usedRowKeys[preferredKey] ? rule.id : preferredKey
            usedRowKeys[rowKey] = true
            var baseName = rule.kind === "legacy"
                ? String(matched[0].name || rule.legacyKey)
                : (matched.length === 1
                    ? String(rule.matchScript ? rule.label : (matched[0].name || rule.label))
                    : String(rule.label || matched[0].name))
            rows.push({
                key: rowKey,
                pinId: rule.id,
                name: matched.length > 1 ? (baseName + " (" + matched.length + ")") : baseName,
                cpuTotalPercent: hasCpu ? totalCpu : null,
                rss: hasRss ? totalRss : null,
                online: true,
                matchCount: matched.length,
                matchedKeys: matchedKeys
            })
        }
        return rows
    }
    property string error: ""
    property bool storageReady: false
    // Track missed frames only for legacy ephemeral pid:startTime entries.
    property var missingFramesByKey: ({})
    readonly property string path: Quickshell.env("HAKUSPACE_TM_PINS_FILE")
        || ((Quickshell.env("XDG_STATE_HOME") || ((Quickshell.env("HOME") || "") + "/.local/state")) + "/hakuspace/task_manager_pins.json")

    function basename(rawPath) {
        if (typeof rawPath !== "string") return ""
        var cleaned = rawPath.trim()
        if ((cleaned.startsWith('"') && cleaned.endsWith('"'))
                || (cleaned.startsWith("'") && cleaned.endsWith("'"))) {
            cleaned = cleaned.slice(1, -1).trim()
        }
        if (cleaned.endsWith(" (deleted)")) cleaned = cleaned.slice(0, -10).trim()
        cleaned = cleaned.replace(/[\\/]+$/, "")
        if (!cleaned) return ""
        var parts = cleaned.split(/[\\/]/)
        for (var i = parts.length - 1; i >= 0; --i) {
            if (parts[i]) return parts[i]
        }
        return cleaned
    }

    function splitCmdline(cmdline) {
        if (typeof cmdline !== "string") return []
        var text = cmdline.trim()
        if (!text) return []
        var tokens = []
        var current = ""
        var quote = ""
        for (var i = 0; i < text.length; ++i) {
            var ch = text.charAt(i)
            if (quote) {
                if (ch === quote) quote = ""
                else current += ch
            } else if (ch === '"' || ch === "'") {
                quote = ch
            } else if (/\s/.test(ch)) {
                if (current.length > 0) {
                    tokens.push(current)
                    current = ""
                }
            } else {
                current += ch
            }
        }
        if (current.length > 0) tokens.push(current)
        return tokens
    }

    function isGenericRuntime(exeLower) {
        return /^(python(\d+(\.\d+)*)?|node(js)?|deno|bun|bash|sh|zsh|fish|dash|ash|java[w]?|ruby(\d+(\.\d+)*)?|perl|php(\d+(\.\d+)*)?|lua(\d+(\.\d+)*)?|pwsh|dotnet|wine(64)?|electron(\d+)?|env)$/.test(exeLower)
    }

    // Strip minor version suffixes on generic runtimes so pins survive runtime upgrades (e.g. python3.14 -> python).
    function normalizeRuntimeName(exeLower) {
        if (/^python(\d+(\.\d+)*)?$/.test(exeLower)) return "python"
        if (/^node(js)?$/.test(exeLower)) return "node"
        if (/^ruby(\d+(\.\d+)*)?$/.test(exeLower)) return "ruby"
        if (/^php(\d+(\.\d+)*)?$/.test(exeLower)) return "php"
        if (/^lua(\d+(\.\d+)*)?$/.test(exeLower)) return "lua"
        if (/^electron(\d+)?$/.test(exeLower)) return "electron"
        if (/^wine(64)?$/.test(exeLower)) return "wine"
        return exeLower
    }

    function extractTargetScript(cmdline, exeLower) {
        var tokens = splitCmdline(cmdline)
        if (tokens.length <= 1) return ""
        var idx = 1
        var runtime = exeLower

        if (runtime === "env") {
            while (idx < tokens.length) {
                var tok = tokens[idx]
                if (tok === "--") { idx++; break }
                if (tok.startsWith("-") || tok.indexOf("=") > 0) { idx++; continue }
                break
            }
            if (idx >= tokens.length) return ""
            var innerExe = basename(tokens[idx]).toLowerCase()
            if (!innerExe) return ""
            if (!isGenericRuntime(innerExe)) return innerExe.slice(0, 120)
            runtime = innerExe
            idx++
        }

        var isJava = /^java[w]?$/.test(runtime)
        var isPython = /^python(\d+(\.\d+)*)?$/.test(runtime)

        while (idx < tokens.length) {
            var arg = tokens[idx]
            if (!arg) { idx++; continue }
            if (arg === "--") { idx++; break }
            if (isPython && arg === "-m" && idx + 1 < tokens.length) {
                return basename(tokens[idx + 1]).toLowerCase().slice(0, 120)
            }
            if (isJava && (arg === "-jar" || arg === "-m" || arg === "--module") && idx + 1 < tokens.length) {
                return basename(tokens[idx + 1]).toLowerCase().slice(0, 120)
            }
            if (arg === "-c" || arg === "-e" || arg === "--eval") return ""
            if ((isJava && (arg === "-cp" || arg === "-classpath" || arg === "-p" || arg === "--module-path"))
                    || (!isJava && (arg === "-r" || arg === "--require" || arg === "-I" || arg === "-W" || arg === "-X"))) {
                idx += 2
                continue
            }
            if (arg.startsWith("-")) { idx++; continue }
            return basename(arg).toLowerCase().slice(0, 120)
        }
        return idx < tokens.length ? basename(tokens[idx]).toLowerCase().slice(0, 120) : ""
    }

    function signatureFor(process) {
        if (!process || typeof process !== "object") return null
        var tokens = splitCmdline(process.cmdline || "")
        var exeSource = (typeof process.exe === "string" && process.exe.trim().length > 0)
            ? process.exe
            : (tokens.length > 0 ? tokens[0] : (process.name || ""))
        var exeBase = basename(exeSource)
        var rawExeLower = exeBase.toLowerCase()
        if (!rawExeLower) return null
        var genericRuntime = isGenericRuntime(rawExeLower)
        var matchExe = genericRuntime ? normalizeRuntimeName(rawExeLower) : rawExeLower
        var matchScript = genericRuntime ? extractTargetScript(process.cmdline || "", rawExeLower) : ""
        var label = String(process.name || exeBase).trim()
        if (matchScript) {
            if (matchExe === "wine" && matchScript.endsWith(".exe")) {
                label = matchScript
            } else {
                label = matchScript + " (" + matchExe + ")"
            }
        }
        return {
            id: "rule:" + matchExe + (matchScript ? ":" + matchScript : ""),
            kind: "rule",
            label: label,
            name: String(process.name || exeBase).trim(),
            matchExe: matchExe,
            matchScript: matchScript
        }
    }

    function matchesRule(rule, process) {
        if (!rule || !process) return false
        if (rule.kind === "legacy") return process.key === rule.legacyKey
        var sig = signatureFor(process)
        return !!sig && sig.matchExe === rule.matchExe && sig.matchScript === rule.matchScript
    }

    function normalizeStoredRule(item) {
        if (typeof item === "string") {
            if (!/^[1-9]\d*:\d+$/.test(item)) throw new Error("Invalid legacy process pin")
            return {
                id: "legacy:" + item,
                kind: "legacy",
                legacyKey: item,
                label: "",
                name: "",
                matchExe: "",
                matchScript: ""
            }
        }
        if (!item || typeof item !== "object" || item.kind !== "rule") {
            throw new Error("Invalid process pin entry")
        }
        var matchExe = typeof item.matchExe === "string" ? item.matchExe.trim().toLowerCase() : ""
        var matchScript = typeof item.matchScript === "string" ? item.matchScript.trim().toLowerCase() : ""
        if (!matchExe) throw new Error("Missing process pin matcher")
        var id = "rule:" + matchExe + (matchScript ? ":" + matchScript : "")
        var name = typeof item.name === "string" && item.name.trim() ? item.name.trim() : matchExe
        var label = typeof item.label === "string" && item.label.trim() ? item.label.trim() : name
        return {
            id: id,
            kind: "rule",
            label: label,
            name: name,
            matchExe: matchExe,
            matchScript: matchScript
        }
    }

    // Preserve the last valid model when a file on disk is malformed.
    function accept(text) {
        var trimmed = (text || "").trim()
        if (!trimmed) {
            pins = []
            error = ""
            return
        }
        try {
            var parsed = JSON.parse(trimmed)
            var rawList = null
            if (Array.isArray(parsed)) {
                rawList = parsed
            } else if (parsed && typeof parsed === "object" && parsed.version === 2 && Array.isArray(parsed.pins)) {
                rawList = parsed.pins
            } else {
                throw new Error("Invalid process pins")
            }
            var seen = Object.create(null)
            var next = []
            for (var i = 0; i < rawList.length; ++i) {
                var rule = normalizeStoredRule(rawList[i])
                if (seen[rule.id]) continue
                seen[rule.id] = true
                next.push(rule)
            }
            pins = next
            error = ""
        } catch (exception) {
            error = "Could not read process pins: " + exception.message
        }
    }

    // Upgrade any live legacy pin to a persistent rule when explicitly saving mutations.
    function serializedPins() {
        var procs = TaskManagerService.processes || []
        var byKey = Object.create(null)
        for (var i = 0; i < procs.length; ++i) byKey[procs[i].key] = procs[i]
        var seen = Object.create(null)
        var out = []
        for (var j = 0; j < pins.length; ++j) {
            var rule = pins[j]
            if (rule.kind === "legacy") {
                var liveProc = byKey[rule.legacyKey]
                if (liveProc) {
                    var upgraded = signatureFor(liveProc)
                    if (upgraded && !seen[upgraded.id]) {
                        seen[upgraded.id] = true
                        out.push({
                            kind: "rule",
                            label: upgraded.label,
                            name: upgraded.name,
                            matchExe: upgraded.matchExe,
                            matchScript: upgraded.matchScript
                        })
                    }
                } else if (!seen[rule.id]) {
                    seen[rule.id] = true
                    out.push(rule.legacyKey)
                }
            } else if (!seen[rule.id]) {
                seen[rule.id] = true
                out.push({
                    kind: "rule",
                    label: rule.label,
                    name: rule.name,
                    matchExe: rule.matchExe,
                    matchScript: rule.matchScript
                })
            }
        }
        return out
    }

    // Serialize the newest model after creating its state directory once.
    function save() {
        if (!storageReady) {
            if (!directory.running) directory.running = true
            return
        }
        pinFile.setText(JSON.stringify({ version: 2, pins: serializedPins() }))
    }
    function reload() { pinFile.reload() }
    function isPinned(process) {
        if (!process) return false
        for (var i = 0; i < pins.length; ++i) {
            if (matchesRule(pins[i], process)) return true
        }
        return false
    }

    // Accept only live processes currently supplied by the process model.
    function pin(process) {
        if (!process || isPinned(process) || !TaskManagerService.processes.some(row => row.key === process.key)) return
        var rule = signatureFor(process)
        if (!rule) return
        if (pins.some(existing => existing.id === rule.id)) return
        pins = pins.concat([rule])
        save()
    }
    function unpin(target) {
        if (!target) return
        var next = pins.filter(rule => {
            if (typeof target === "string") {
                return rule.id !== target && rule.legacyKey !== target
            }
            if (target.pinId && rule.id === target.pinId) return false
            if (matchesRule(rule, target)) return false
            return true
        })
        if (next.length === pins.length) return
        pins = next
        save()
    }
    function toggle(process) { if (isPinned(process)) unpin(process); else pin(process) }

    // Keep counters bounded to legacy pins only.
    onPinsChanged: {
        var retained = ({})
        for (var i = 0; i < pins.length; ++i) {
            var rule = pins[i]
            if (rule.kind === "legacy" && missingFramesByKey[rule.legacyKey]) {
                retained[rule.legacyKey] = missingFramesByKey[rule.legacyKey]
            }
        }
        missingFramesByKey = retained
    }

    // Prune only legacy pid:startTime entries after 3 misses; persistent rules stay until unpinned.
    function prune() {
        if (!TaskManagerService.ready || TaskManagerService.warmingUp || TaskManagerService.processTimestamp < 0
            || TaskManagerService.monitorRestartPending || TaskManagerService.monitorStopPending) return
        if (!pins.some(rule => rule.kind === "legacy")) return
        if (!TaskManagerService.processes.every(process => process && typeof process.key === "string" && /^[1-9]\d*:\d+$/.test(process.key))) return
        var live = new Set(TaskManagerService.processes.map(process => process.key))
        var missing = ({})
        var retained = pins.filter(rule => {
            if (rule.kind !== "legacy") return true
            if (live.has(rule.legacyKey)) return true
            var count = (missingFramesByKey[rule.legacyKey] || 0) + 1
            if (count >= 3) return false
            missing[rule.legacyKey] = count
            return true
        })
        missingFramesByKey = missing
        if (retained.length === pins.length) return
        pins = retained
        save()
    }

    Component.onCompleted: accept(pinFile.text())
    property FileView pinFile: FileView {
        path: root.path
        watchChanges: true
        blockLoading: true
        blockWrites: true
        printErrors: false
        atomicWrites: true
        onFileChanged: reload()
        onTextChanged: root.accept(text())
        onSaved: root.error = ""
        onSaveFailed: root.error = "Could not save process pins"
    }
    property Process directory: Process {
        command: ["mkdir", "-p", "--", root.path.substring(0, root.path.lastIndexOf("/")) || "."]
        onExited: code => {
            if (code !== 0) { root.error = "Could not create process pin storage"; return }
            root.storageReady = true
            root.save()
        }
    }
    property Connections processEvents: Connections {
        target: TaskManagerService
        function onReadyChanged() { if (!TaskManagerService.ready) root.missingFramesByKey = ({}) }
        function onWarmingUpChanged() { if (TaskManagerService.warmingUp) root.missingFramesByKey = ({}) }
        function onMonitorRestartPendingChanged() { if (TaskManagerService.monitorRestartPending) root.missingFramesByKey = ({}) }
        function onProcessTimestampChanged() { root.prune() }
    }
}
