pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "."

QtObject {
    id: root

    property bool ready: false
    property bool loading: false
    property bool saving: false
    property string error: ""
    property var items: []
    property string selectedDateKey: ""
    property string filterMode: "day" // "day" | "all"

    // Reactive lookup map of YYYY-MM-DD keys with at least one unfinished task.
    readonly property var markedDateKeys: {
        var map = {}
        for (var i = 0; i < items.length; ++i) {
            var item = items[i]
            if (item && !item.done && item.date && item.date.length > 0) {
                map[item.date] = true
            }
        }
        return map
    }

    property bool _loadedOnce: false
    property bool _readFailed: false
    property int _draftGen: 0
    property int _writingGen: 0
    property bool _pendingSave: false
    property int _idSeq: 0

    function _pad2(n) {
        return n < 10 ? ("0" + n) : String(n)
    }

    function formatDateKey(dateObj) {
        var d = dateObj || new Date()
        return d.getFullYear() + "-" + _pad2(d.getMonth() + 1) + "-" + _pad2(d.getDate())
    }

    function todayKey() {
        return formatDateKey(Clock.date || new Date())
    }

    function ensureLoaded() {
        if (_loadedOnce || loading) return
        _loadedOnce = true
        reload()
    }

    function reload() {
        if (loading || readProc.running) return
        loading = true
        error = ""
        readProc.command = [Env.binDir + "/agenda_store_ctl.py", "read"]
        readProc.running = true
    }

    function selectDate(dateKey) {
        if (!dateKey || typeof dateKey !== "string") return
        selectedDateKey = dateKey
    }

    function selectToday() {
        selectedDateKey = todayKey()
    }

    function setFilterMode(mode) {
        if (mode !== "day" && mode !== "all") return
        filterMode = mode
    }

    function addItem(title, dateKey) {
        if (_readFailed) return false
        var trimmed = title !== undefined && title !== null ? String(title).trim() : ""
        if (trimmed.length === 0) return false
        if (trimmed.length > 300) trimmed = trimmed.slice(0, 300)

        var resolvedDate = ""
        if (dateKey !== undefined && dateKey !== null) {
            resolvedDate = String(dateKey)
        } else if (filterMode === "day") {
            resolvedDate = selectedDateKey || todayKey()
        }

        _idSeq++
        var newItem = {
            id: "ag_" + Date.now() + "_" + _idSeq,
            title: trimmed,
            date: resolvedDate,
            done: false,
            createdAt: Date.now()
        }

        items = items.concat([newItem])
        _scheduleSave()
        return true
    }

    function toggleItem(id) {
        if (_readFailed || !id) return
        var changed = false
        var next = []
        for (var i = 0; i < items.length; ++i) {
            var item = items[i]
            if (item.id === id) {
                changed = true
                next.push({
                    id: item.id,
                    title: item.title,
                    date: item.date || "",
                    done: !item.done,
                    createdAt: item.createdAt
                })
            } else {
                next.push(item)
            }
        }
        if (changed) {
            items = next
            _scheduleSave()
        }
    }

    function removeItem(id) {
        if (_readFailed || !id) return
        var next = items.filter(function(item) { return item.id !== id })
        if (next.length !== items.length) {
            items = next
            _scheduleSave()
        }
    }

    function clearCompleted(dateKey) {
        if (_readFailed) return
        var hasScope = dateKey !== undefined && dateKey !== null
        var targetDate = hasScope ? String(dateKey) : ""
        var next = items.filter(function(item) {
            if (!item.done) return true
            if (hasScope) return (item.date || "") !== targetDate
            return false
        })
        if (next.length !== items.length) {
            items = next
            _scheduleSave()
        }
    }

    function visibleItems() {
        var list = []
        if (filterMode === "day") {
            var key = selectedDateKey || todayKey()
            for (var i = 0; i < items.length; ++i) {
                if ((items[i].date || "") === key) list.push(items[i])
            }
            list.sort(function(a, b) {
                if (!!a.done !== !!b.done) return a.done ? 1 : -1
                return (a.createdAt || 0) - (b.createdAt || 0)
            })
            return list
        }

        list = items.slice()
        list.sort(function(a, b) {
            if (!!a.done !== !!b.done) return a.done ? 1 : -1
            var da = a.date || ""
            var db = b.date || ""
            if (da !== db) {
                if (!da) return 1
                if (!db) return -1
                return da < db ? -1 : 1
            }
            return (a.createdAt || 0) - (b.createdAt || 0)
        })
        return list
    }

    function _scheduleSave() {
        if (_readFailed) return
        _draftGen++
        saveDebounceTimer.restart()
    }

    function _performSave() {
        if (!ready || _readFailed) return
        if (saving) {
            _pendingSave = true
            return
        }

        _writingGen = _draftGen
        saving = true
        _pendingSave = false

        var payload = JSON.stringify({
            schema: 1,
            items: items
        })
        writeProc.command = [Env.binDir + "/agenda_store_ctl.py", "write"]
        writeProc.environment = ({
            "HAKUSPACE_AGENDA_JSON": payload
        })
        writeProc.running = true
    }

    property Timer saveDebounceTimer: Timer {
        id: saveDebounceTimer
        interval: 250
        repeat: false
        onTriggered: root._performSave()
    }

    property Process readProc: Process {
        id: readProc
        stdout: StdioCollector { id: readStdout }
        stderr: StdioCollector { id: readStderr }

        onExited: (code, status) => {
            root.loading = false
            if (code === 0) {
                try {
                    var parsed = JSON.parse(readStdout.text.trim() || '{"schema":1,"items":[]}')
                    if (parsed && parsed.schema === 1 && Array.isArray(parsed.items)) {
                        root.items = parsed.items
                        root._readFailed = false
                        root.error = ""
                        root.ready = true
                        return
                    }
                    throw new Error("Invalid agenda payload")
                } catch (e) {
                    root._readFailed = true
                    root.ready = false
                    root.error = "Invalid agenda data: " + e.message
                    return
                }
            }
            root._readFailed = true
            root.ready = false
            root.error = readStderr.text.trim() || "Failed to read agenda"
        }
    }

    property Process writeProc: Process {
        id: writeProc
        stderr: StdioCollector { id: writeStderr }

        onExited: (code, status) => {
            root.saving = false
            if (code === 0) {
                root.error = ""
            } else {
                root.error = writeStderr.text.trim() || "Failed to save agenda"
            }
            if (root._pendingSave || root._draftGen > root._writingGen) {
                root._pendingSave = false
                root.saveDebounceTimer.restart()
            }
        }
    }

    Component.onCompleted: {
        if (!selectedDateKey) {
            selectedDateKey = todayKey()
        }
    }
}
