pragma Singleton
import QtQuick
import Quickshell.Io

QtObject {
    id: root
    property bool available: true
    property string bars: ""
    property var levels: []
    property bool soundPresent: false
    property bool audioVisible: false
    readonly property int barCount: 12
    readonly property int soundThreshold: 10

    // Dashboard demand tracking (single shared process)
    property int _dashboardSubscribers: 0
    readonly property bool dashboardRequested: _dashboardSubscribers > 0

    function acquireDashboard() {
        _dashboardSubscribers++
        syncProcess()
    }

    function releaseDashboard() {
        if (_dashboardSubscribers > 0) {
            _dashboardSubscribers--
            syncProcess()
        }
    }

    // Run cava while a player is active in either the media center mode OR requested by Dashboard.
    readonly property bool shouldRun: Media.playing && available && (CenterState.baseMode === "media" || dashboardRequested)
    property bool stoppingForPolicy: false

    function resetSoundDetection() {
        showTimer.stop()
        silenceTimer.stop()
        soundPresent = false
    }

    // Detect sound with generous silence tolerance (1.5s) to avoid resetting on natural musical rests
    function observePeak(peak) {
        if (!shouldRun) return
        if (peak >= soundThreshold) {
            silenceTimer.stop()
            soundPresent = true
            if (!audioVisible && !showTimer.running) {
                showTimer.start()
            }
        } else if (soundPresent && !silenceTimer.running) {
            silenceTimer.start()
        }
    }

    // Distinguish an intentional stop from a failed cava process.
    function syncProcess() {
        if (!shouldRun) {
            bars = ""
            levels = []
            resetSoundDetection()
            if (audioVisible && Media.available && CenterState.centerMode === "media" && !Media.playing)
                hideTimer.restart()
            else {
                hideTimer.stop()
                audioVisible = false
            }
            if (process.running) {
                stoppingForPolicy = true
                process.running = false
            }
        } else {
            hideTimer.stop()
            if (!stoppingForPolicy && !process.running) process.running = true
        }
    }

    Component.onCompleted: syncProcess()
    onShouldRunChanged: {
        if (Media.playing) root.available = true
        syncProcess()
    }

    // Require sustained sound (3 seconds) before revealing TopBar visualizer
    property Timer showTimer: Timer {
        interval: 3000
        repeat: false
        onTriggered: {
            if (root.shouldRun && root.soundPresent)
                root.audioVisible = true
        }
    }

    // Only consider silence real if it persists for 1.5 seconds continuously
    property Timer silenceTimer: Timer {
        interval: 1500
        repeat: false
        onTriggered: root.resetSoundDetection()
    }

    // Keep visualizer visible across 5 seconds of pause to prevent abrupt toggling
    property Timer hideTimer: Timer {
        interval: 5000
        repeat: false
        onTriggered: {
            if (!root.shouldRun) root.audioVisible = false
        }
    }

    // Auto-recovery timer in case cava exits unexpectedly during playback
    property Timer restartTimer: Timer {
        interval: 1000
        repeat: false
        onTriggered: {
            if (root.shouldRun && !root.process.running) {
                root.syncProcess()
            }
        }
    }

    property Process process: Process {
        command: ["cava", "-p", Env.cavaConfig]
        onRunningChanged: {
            if (!running && root.shouldRun && !root.stoppingForPolicy) {
                root.bars = ""
                root.levels = []
                root.resetSoundDetection()
                root.restartTimer.restart()
            }
        }
        stdout: SplitParser {
            onRead: data => {
                if (!root.shouldRun) return
                var values = data.trim().split(";").filter(value => value !== "")
                if (values.length < root.barCount) return
                var glyphLevels = ["▁", "▂", "▃", "▄", "▅", "▆", "▇", "█"]
                var output = ""
                var numericLevels = []
                var peak = 0
                for (var i = 0; i < root.barCount; ++i) {
                    var first = parseInt(values[i])
                    // Merge paired channels when cava emits stereo samples.
                    var second = values.length >= root.barCount * 2
                               ? parseInt(values[i + root.barCount]) : first
                    if (isNaN(first) || isNaN(second)) return
                    var val = Math.max(first, second)
                    peak = Math.max(peak, val)
                    var norm = Math.max(0.0, Math.min(1.0, val / 1000.0))
                    numericLevels.push(norm)
                    var index = Math.max(0, Math.min(7, Math.floor(norm * 7)))
                    output += glyphLevels[index]
                }
                root.bars = output
                root.levels = numericLevels
                root.observePeak(peak)
            }
        }
        onExited: {
            root.bars = ""
            root.levels = []
            root.resetSoundDetection()
            if (root.stoppingForPolicy) {
                root.stoppingForPolicy = false
                if (root.shouldRun) Qt.callLater(root.syncProcess)
            } else if (root.shouldRun) {
                root.restartTimer.restart()
            }
        }
    }
}
