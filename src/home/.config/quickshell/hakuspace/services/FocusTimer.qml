pragma Singleton
import QtQuick
import Quickshell

QtObject {
    id: root

    readonly property int minMinutes: 1
    readonly property int maxMinutes: 180
    readonly property var presetMinutesList: [15, 25, 45]
    property int selectedMinutes: 25
    property int durationSec: 25 * 60
    property int remainingSec: 25 * 60
    property bool running: false
    property bool paused: false
    readonly property bool active: running || paused
    readonly property bool canDecrease: active ? (remainingSec > minMinutes * 60) : (selectedMinutes > minMinutes)
    readonly property bool canIncrease: active ? (remainingSec < maxMinutes * 60) : (selectedMinutes < maxMinutes)
    readonly property real progress: durationSec > 0
        ? Math.max(0, Math.min(1, (durationSec - remainingSec) / durationSec))
        : 0
    readonly property string formattedTime: _formatTime(remainingSec)

    // Wall-clock anchor prevents drift across compositor pauses or timer jitter.
    property double _targetEpochMs: 0

    function _pad2(n) {
        return n < 10 ? ("0" + n) : String(n)
    }

    function _formatTime(totalSec) {
        var s = Math.max(0, Math.floor(totalSec))
        var hours = Math.floor(s / 3600)
        var mins = Math.floor((s % 3600) / 60)
        var secs = s % 60
        if (hours > 0) {
            return hours + ":" + _pad2(mins) + ":" + _pad2(secs)
        }
        return _pad2(mins) + ":" + _pad2(secs)
    }

    function setPresetMinutes(mins) {
        var m = Math.max(minMinutes, Math.min(maxMinutes, Math.round(mins)))
        selectedMinutes = m
        durationSec = m * 60
        remainingSec = durationSec
        running = false
        paused = false
        _targetEpochMs = 0
    }

    function adjustMinutes(deltaMinutes) {
        var delta = Math.round(Number(deltaMinutes) || 0)
        if (delta === 0) return
        if (!active) {
            var nextMin = Math.max(minMinutes, Math.min(maxMinutes, selectedMinutes + delta))
            selectedMinutes = nextMin
            durationSec = nextMin * 60
            remainingSec = durationSec
            return
        }
        var currentLeft = running
            ? Math.max(0, Math.ceil((_targetEpochMs - Date.now()) / 1000))
            : remainingSec
        var nextSec = Math.max(minMinutes * 60, Math.min(maxMinutes * 60, currentLeft + delta * 60))
        remainingSec = nextSec
        durationSec = Math.max(durationSec, nextSec)
        if (running) {
            _targetEpochMs = Date.now() + nextSec * 1000
        }
    }

    function toggle() {
        if (running) {
            var left = Math.max(0, Math.ceil((_targetEpochMs - Date.now()) / 1000))
            remainingSec = left
            running = false
            paused = true
            return
        }
        if (remainingSec <= 0) {
            remainingSec = durationSec
        }
        _targetEpochMs = Date.now() + remainingSec * 1000
        running = true
        paused = false
    }

    function reset() {
        running = false
        paused = false
        _targetEpochMs = 0
        remainingSec = durationSec
    }

    function _tick() {
        if (!running) return
        var left = Math.ceil((_targetEpochMs - Date.now()) / 1000)
        if (left <= 0) {
            var completedMinutes = selectedMinutes
            reset()
            Quickshell.execDetached([
                "notify-send",
                "-a", "HakuSpace",
                "Focus Timer",
                completedMinutes + " min session complete"
            ])
            return
        }
        if (left !== remainingSec) {
            remainingSec = left
        }
    }

    property Timer tickTimer: Timer {
        id: tickTimer
        interval: 500
        repeat: true
        running: root.running
        onTriggered: root._tick()
    }
}
