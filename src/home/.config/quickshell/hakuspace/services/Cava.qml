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

    // Registers a subscriber demanding cava visualizer output for the Dashboard.
    function acquireDashboard() {
        _dashboardSubscribers++
        syncProcess()
    }

    // Releases a dashboard subscriber demanding cava visualizer output.
    function releaseDashboard() {
        if (_dashboardSubscribers > 0) {
            _dashboardSubscribers--
            syncProcess()
        }
    }

    // Run cava while a player is active in either the media center mode (if TopBar Cava is enabled) OR requested by Dashboard.
    readonly property bool topbarRequested: ShellSettingsStore.showCava && CenterState.baseMode === "media"
    readonly property bool shouldRun: Media.playing && Media.title !== "" && available && (topbarRequested || dashboardRequested)
    property bool stoppingForPolicy: false

    // Resets active sound detection flags and pending silence timers.
    function resetSoundDetection() {
        showTimer.stop()
        silenceTimer.stop()
        soundPresent = false
    }

    // Evaluates audio peak against threshold with generous silence tolerance for rests.
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

    // Synchronizes the cava backend process lifecycle according to playback and subscriber state.
    function syncProcess() {
        if (!shouldRun) {
            bars = ""
            levels = []
            resetSoundDetection()
            hideTimer.stop()
            audioVisible = false
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

    // Sustained sound (700ms) before revealing TopBar visualizer to ensure musical start
    property Timer showTimer: Timer {
        interval: 700
        repeat: false
        onTriggered: {
            if (root.shouldRun && root.soundPresent)
                root.audioVisible = true
        }
    }

    // Retract visualizer if silence persists for 1.2 seconds continuously
    property Timer silenceTimer: Timer {
        interval: 1200
        repeat: false
        onTriggered: {
            root.soundPresent = false
            root.audioVisible = false
        }
    }

    // Keep visualizer visible across pause transition to prevent abrupt toggling
    property Timer hideTimer: Timer {
        interval: 300
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
                var trimmed = data.trim()
                if (trimmed.length === 0) return
                var values = trimmed.split(";")
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
                if (peak === 0 && !root.soundPresent && root.bars === "") {
                    return
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
