pragma Singleton
import QtQuick
import Quickshell.Io

QtObject {
    id: root
    property bool available: true
    property string bars: ""
    property bool soundPresent: false
    property bool audioVisible: false
    readonly property int barCount: 12
    readonly property int soundThreshold: 30
    // Run cava only while a player is active in the media center mode.
    readonly property bool shouldRun: Media.playing && CenterState.baseMode === "media" && available
    property bool stoppingForPolicy: false

    function resetActivity() {
        showTimer.stop()
        silenceTimer.stop()
        soundPresent = false
        audioVisible = false
    }

    // Require sustained sound before showing bars; hide after brief silence.
    function observePeak(peak) {
        if (!shouldRun) return
        if (peak >= soundThreshold) {
            silenceTimer.stop()
            if (!soundPresent) {
                soundPresent = true
                showTimer.restart()
            } else if (!audioVisible && !showTimer.running) {
                showTimer.restart()
            }
        } else if (soundPresent && !silenceTimer.running) {
            silenceTimer.start()
        }
    }

    // Distinguish an intentional stop from a failed cava process.
    function syncProcess() {
        if (!shouldRun) {
            bars = ""
            resetActivity()
            if (process.running) {
                stoppingForPolicy = true
                process.running = false
            }
        } else if (!stoppingForPolicy && !process.running) {
            process.running = true
        }
    }

    Component.onCompleted: syncProcess()
    onShouldRunChanged: syncProcess()

    property Timer showTimer: Timer {
        interval: 3000
        repeat: false
        onTriggered: {
            if (root.shouldRun && root.soundPresent && !root.silenceTimer.running)
                root.audioVisible = true
        }
    }

    property Timer silenceTimer: Timer {
        interval: 500
        repeat: false
        onTriggered: root.resetActivity()
    }

    property Process process: Process {
        command: ["cava", "-p", Env.home + "/.config/cava/config_waybar"]
        onRunningChanged: {
            if (!running && root.shouldRun && !root.stoppingForPolicy) {
                root.bars = ""
                root.available = false
            }
        }
        stdout: SplitParser {
            onRead: data => {
                if (!root.shouldRun) return
                var values = data.trim().split(";").filter(value => value !== "")
                if (values.length < root.barCount) return
                var levels = ["▁", "▂", "▃", "▄", "▅", "▆", "▇", "█"]
                var output = ""
                var peak = 0
                for (var i = 0; i < root.barCount; ++i) {
                    var first = parseInt(values[i])
                    // Merge paired channels when cava emits stereo samples.
                    var second = values.length >= root.barCount * 2
                               ? parseInt(values[i + root.barCount]) : first
                    if (isNaN(first) || isNaN(second)) return
                    peak = Math.max(peak, first, second)
                    var index = Math.max(0, Math.min(7, Math.floor(Math.max(first, second) / 1000 * 7)))
                    output += levels[index]
                }
                root.bars = output
                root.observePeak(peak)
            }
        }
        onExited: {
            root.bars = ""
            root.resetActivity()
            if (root.stoppingForPolicy) {
                root.stoppingForPolicy = false
                if (root.shouldRun) Qt.callLater(root.syncProcess)
            }
        }
    }
}
