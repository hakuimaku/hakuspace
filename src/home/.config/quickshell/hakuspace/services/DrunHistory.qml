pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    // Store disposable launch frecency in XDG cache; never block launches on IO.
    property var entries: ({})
    property int revision: 0
    property string error: ""
    property bool storageReady: false
    readonly property int maxEntries: 100
    readonly property real halfLifeHours: 72.0
    readonly property string path: Quickshell.env("HAKUSPACE_DRUN_HISTORY_FILE")
        || ((Quickshell.env("XDG_CACHE_HOME") || ((Quickshell.env("HOME") || "") + "/.cache"))
            + "/hakuspace/hakumenu/drun-history.json")

    function normalizeId(appId) {
        return typeof appId === "string" ? appId.trim() : ""
    }

    // Balance launch count against recency with a 3-day decay half-life.
    function scoreEntry(entry, nowMs) {
        if (!entry || !Number.isFinite(entry.count) || entry.count <= 0) return 0
        var lastUsedMs = Number.isFinite(entry.lastUsed) ? entry.lastUsed : 0
        var ageHours = Math.max(0, (nowMs - lastUsedMs) / 3600000)
        return Math.log2(entry.count + 1) / (1 + ageHours / halfLifeHours)
    }

    function score(appId, nowMs) {
        var key = normalizeId(appId)
        if (!key || !entries[key]) return 0
        return scoreEntry(entries[key], nowMs === undefined ? Date.now() : nowMs)
    }

    function lastUsed(appId) {
        var key = normalizeId(appId)
        return (key && entries[key] && Number.isFinite(entries[key].lastUsed)) ? entries[key].lastUsed : 0
    }

    function pruneEntries(map, nowMs) {
        var keys = Object.keys(map)
        if (keys.length <= maxEntries) return map
        keys.sort(function(a, b) {
            var diff = scoreEntry(map[b], nowMs) - scoreEntry(map[a], nowMs)
            if (Math.abs(diff) > 1e-9) return diff > 0 ? 1 : -1
            return (map[b].lastUsed || 0) - (map[a].lastUsed || 0)
        })
        var kept = ({})
        for (var i = 0; i < maxEntries; ++i) {
            kept[keys[i]] = map[keys[i]]
        }
        return kept
    }

    // Preserve the last valid cache in memory when disk content is malformed.
    function accept(text) {
        var trimmed = (text || "").trim()
        if (!trimmed) {
            entries = ({})
            revision++
            error = ""
            return
        }
        try {
            var parsed = JSON.parse(trimmed)
            if (!parsed || typeof parsed !== "object" || parsed.version !== 1
                    || !parsed.entries || typeof parsed.entries !== "object" || Array.isArray(parsed.entries)) {
                throw new Error("Invalid drun history schema")
            }
            var validated = ({})
            var rawKeys = Object.keys(parsed.entries)
            for (var i = 0; i < rawKeys.length; ++i) {
                var key = normalizeId(rawKeys[i])
                var item = parsed.entries[rawKeys[i]]
                if (!key || !item || typeof item !== "object") continue
                var count = Math.floor(Number(item.count))
                var ts = Number(item.lastUsed)
                if (!Number.isFinite(count) || count <= 0) continue
                validated[key] = {
                    count: count,
                    lastUsed: Number.isFinite(ts) && ts > 0 ? ts : 0
                }
            }
            entries = pruneEntries(validated, Date.now())
            revision++
            error = ""
        } catch (exception) {
            error = "Could not read drun history: " + exception.message
        }
    }

    function save() {
        if (!storageReady) {
            if (!directory.running) directory.running = true
            return
        }
        historyFile.setText(JSON.stringify({ version: 1, entries: entries }))
    }

    function record(appId) {
        var key = normalizeId(appId)
        if (!key) return
        var nowMs = Date.now()
        var next = Object.assign({}, entries)
        var prev = next[key]
        var count = (prev && Number.isFinite(prev.count) && prev.count > 0) ? (prev.count + 1) : 1
        next[key] = { count: count, lastUsed: nowMs }
        entries = pruneEntries(next, nowMs)
        revision++
        save()
    }

    Component.onCompleted: accept(historyFile.text())

    property FileView historyFile: FileView {
        path: root.path
        watchChanges: true
        blockLoading: true
        blockWrites: true
        printErrors: false
        atomicWrites: true
        onFileChanged: reload()
        onTextChanged: root.accept(text())
        onSaved: root.error = ""
        onSaveFailed: root.error = "Could not save drun history"
    }

    property Process directory: Process {
        command: ["mkdir", "-p", "--", root.path.substring(0, root.path.lastIndexOf("/")) || "."]
        onExited: code => {
            if (code !== 0) {
                root.error = "Could not create drun history cache directory"
                return
            }
            root.storageReady = true
            root.save()
        }
    }
}
