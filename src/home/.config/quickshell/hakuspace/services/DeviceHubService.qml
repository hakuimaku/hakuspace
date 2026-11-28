pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "."

QtObject {
    id: root

    property int _subscribers: 0
    property bool initialized: false
    property bool loading: false
    property bool actionBusy: false
    property string error: ""
    property string backend: "none"
    property var sinks: []
    property var sources: []
    property var streams: []
    property bool _refreshPending: false
    property int _activeDrags: 0
    property bool _volumeWriting: false
    property bool _volumeTouchesSink: false
    property var _pendingVolumeWrites: ({})
    property var _actionQueue: []
    property bool _currentActionTouchesSink: false
    property string _lastSinksJson: ""
    property string _lastSourcesJson: ""
    property string _lastStreamsJson: ""

    readonly property string _ctlPath: Env.binDir + "/dashboard_devices_ctl.py"

    function acquire() {
        _subscribers++
        if (_subscribers === 1) {
            refresh(initialized)
        }
    }

    function release() {
        _subscribers = Math.max(0, _subscribers - 1)
        if (_subscribers === 0) {
            _activeDrags = 0
        }
    }

    function beginDrag() {
        _activeDrags++
    }

    function endDrag() {
        _activeDrags = Math.max(0, _activeDrags - 1)
        if (_activeDrags === 0 && !_volumeWriting && _refreshPending) {
            _refreshPending = false
            Qt.callLater(function() { root.refresh(true) })
        }
    }

    function refresh(silent) {
        if (_activeDrags > 0 || _volumeWriting) {
            _refreshPending = true
            return
        }
        if (statusProc.running) {
            _refreshPending = true
            return
        }
        loading = !silent
        statusProc.command = [_ctlPath, "status"]
        statusProc.running = true
    }

    function _extractError(stdoutText, stderrText, fallback) {
        var msg = (stderrText || "").trim()
        if (!msg && stdoutText && stdoutText.trim().length > 0) {
            try {
                var parsed = JSON.parse(stdoutText.trim())
                if (parsed && parsed.error) msg = String(parsed.error)
            } catch (e) {}
        }
        return msg || fallback
    }

    function _enqueueAction(command, touchesSink) {
        _actionQueue.push({ command: command, touchesSink: !!touchesSink })
        _flushActionQueue()
    }

    function _flushActionQueue() {
        if (actionProc.running) return
        if (_actionQueue.length === 0) {
            actionBusy = false
            refresh(true)
            return
        }
        var next = _actionQueue.shift()
        actionBusy = true
        error = ""
        _currentActionTouchesSink = !!next.touchesSink
        actionProc.command = next.command
        actionProc.running = true
    }

    function _queueVolumeWrite(kind, target, percent) {
        if (target === undefined || target === null) return
        var cleanTarget = String(target).trim()
        if (!cleanTarget) return
        var clamped = Math.max(0, Math.min(150, Math.round(percent)))
        var key = kind + ":" + cleanTarget
        var nextMap = Object.assign({}, _pendingVolumeWrites)
        nextMap[key] = { kind: kind, target: cleanTarget, percent: clamped }
        _pendingVolumeWrites = nextMap
        if (kind === "sink") {
            _volumeTouchesSink = true
        }
        _flushVolumeWrite()
    }

    function _flushVolumeWrite() {
        if (volumeProc.running) return
        var keys = Object.keys(_pendingVolumeWrites)
        if (keys.length === 0) {
            _volumeWriting = false
            if (_volumeTouchesSink) {
                _volumeTouchesSink = false
                Audio.refresh()
            }
            if (_activeDrags === 0) {
                _refreshPending = false
                Qt.callLater(function() { root.refresh(true) })
            } else {
                _refreshPending = true
            }
            return
        }
        var key = keys[0]
        var entry = _pendingVolumeWrites[key]
        var nextMap = Object.assign({}, _pendingVolumeWrites)
        delete nextMap[key]
        _pendingVolumeWrites = nextMap

        var subcmd = entry.kind === "sink" ? "set-sink-volume"
            : (entry.kind === "source" ? "set-source-volume" : "set-stream-volume")
        _volumeWriting = true
        volumeProc.command = [_ctlPath, subcmd, entry.target, String(entry.percent)]
        volumeProc.running = true
    }

    function setDefaultSink(target) {
        if (!target) return
        _enqueueAction([_ctlPath, "set-sink", String(target)], true)
    }

    function setDefaultSource(target) {
        if (!target) return
        _enqueueAction([_ctlPath, "set-source", String(target)], false)
    }

    function setSinkVolume(target, percent) {
        _queueVolumeWrite("sink", target, percent)
    }

    function toggleSinkMute(target) {
        if (!target) return
        _enqueueAction([_ctlPath, "set-sink-mute", String(target), "toggle"], true)
    }

    function setSourceVolume(target, percent) {
        _queueVolumeWrite("source", target, percent)
    }

    function toggleSourceMute(target) {
        if (!target) return
        _enqueueAction([_ctlPath, "set-source-mute", String(target), "toggle"], false)
    }

    function setStreamVolume(streamId, percent) {
        _queueVolumeWrite("stream", streamId, percent)
    }

    function toggleStreamMute(streamId) {
        if (streamId === undefined || streamId === null || String(streamId).trim() === "") return
        _enqueueAction([_ctlPath, "set-stream-mute", String(streamId), "toggle"], false)
    }

    function moveStreamToSink(streamId, sinkTarget) {
        if (streamId === undefined || streamId === null || !sinkTarget) return
        _enqueueAction([_ctlPath, "move-stream", String(streamId), String(sinkTarget)], false)
    }

    property Timer pollTimer: Timer {
        interval: 4000
        repeat: true
        running: root._subscribers > 0 && root._activeDrags === 0 && !root._volumeWriting
        onTriggered: root.refresh(true)
    }

    property Process statusProc: Process {
        id: statusProc
        stdout: StdioCollector { id: statusStdout }
        stderr: StdioCollector { id: statusStderr }

        onExited: (code, status) => {
            root.loading = false
            // Never overwrite list models mid-drag or mid-write to prevent slider snap-back.
            if (root._activeDrags > 0 || root._volumeWriting) {
                root._refreshPending = true
                return
            }
            root.initialized = true
            if (code === 0) {
                try {
                    var parsed = JSON.parse(statusStdout.text.trim() || "{}")
                    var nextSinks = Array.isArray(parsed.sinks) ? parsed.sinks : []
                    var nextSources = Array.isArray(parsed.sources) ? parsed.sources : []
                    var nextStreams = Array.isArray(parsed.streams) ? parsed.streams : []
                    var sinksJson = JSON.stringify(nextSinks)
                    var sourcesJson = JSON.stringify(nextSources)
                    var streamsJson = JSON.stringify(nextStreams)

                    root.backend = parsed.backend || "none"
                    if (sinksJson !== root._lastSinksJson) {
                        root._lastSinksJson = sinksJson
                        root.sinks = nextSinks
                    }
                    if (sourcesJson !== root._lastSourcesJson) {
                        root._lastSourcesJson = sourcesJson
                        root.sources = nextSources
                    }
                    if (streamsJson !== root._lastStreamsJson) {
                        root._lastStreamsJson = streamsJson
                        root.streams = nextStreams
                    }
                    root.error = ""
                } catch (e) {
                    root.error = "Invalid audio status JSON"
                }
            } else {
                root.error = statusStderr.text.trim() || "Failed to read audio status"
            }

            if (root._refreshPending) {
                root._refreshPending = false
                Qt.callLater(function() { root.refresh(true) })
            }
        }
    }

    property Process volumeProc: Process {
        id: volumeProc
        stdout: StdioCollector { id: volumeStdout }
        stderr: StdioCollector { id: volumeStderr }

        onExited: (code, status) => {
            if (code !== 0) {
                root.error = root._extractError(volumeStdout.text, volumeStderr.text, "Volume update failed")
            } else {
                root.error = ""
            }
            Qt.callLater(root._flushVolumeWrite)
        }
    }

    property Process actionProc: Process {
        id: actionProc
        stdout: StdioCollector { id: actionStdout }
        stderr: StdioCollector { id: actionStderr }

        onExited: (code, status) => {
            if (code !== 0) {
                root.error = root._extractError(actionStdout.text, actionStderr.text, "Audio action failed")
            } else {
                root.error = ""
            }
            if (root._currentActionTouchesSink) {
                root._currentActionTouchesSink = false
                Audio.refresh()
            }
            Qt.callLater(root._flushActionQueue)
        }
    }
}
