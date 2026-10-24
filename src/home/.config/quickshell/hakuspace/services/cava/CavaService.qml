pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import ".."
import "CavaFrameParser.js" as Parser
import "CavaMath.js" as CMath

QtObject {
    id: root

    // Only the isolated renderer owns audio processing and frame buffers.
    readonly property bool rendererProcess: !!Quickshell.env("HAKUSPACE_CAVA_RENDER_SOCKET")
    property var renderer: null
    property var rendererState: ({})
    readonly property var rendererPid: renderer ? renderer.processId : 0
    // Preserve the shell's IPC status without transferring spectrum frames back to it.
    readonly property bool running: rendererProcess ? process.running : !!rendererState.running
    property bool available: true
    property bool sleeping: true
    property string errorString: ""

    // Configuration
    property bool enabled: !rendererProcess && AppState.cavaLayerState
    property string colorMode: rendererProcess ? "accent" : AppState.cavaColorMode
    property color surfaceColor: rendererProcess ? "#0b0b0b" : Theme.surface
    property color accentColor: rendererProcess ? "#ffffff" : Theme.accent
    readonly property color underbarColor: colorMode === "surface" ? surfaceColor : accentColor
    // The parent publishes screen geometry and live settings previews as one snapshot.
    property bool top: rendererProcess ? true : AppState.cavaTopState
    property bool needsSurface: !rendererProcess && WM.backendName === "niri"
    property real leftInset: rendererProcess ? 0 : ScreenGeometry.leftInset
    property real rightInset: rendererProcess ? 0 : ScreenGeometry.rightInset
    property int edgeInset: rendererProcess ? 0 : (top
        ? (ChromeLayout.taskbarMode ? ScreenGeometry.topBorderThickness : Theme.topBarHeight)
        : (ChromeLayout.taskbarMode ? ScreenGeometry.taskbarReservation() : ScreenGeometry.bottomInset))
    property int barCount: 64
    property real sensitivity: 1.0
    property real smoothing: 0.5
    property string style: "liquid" // "liquid" or "capsule"
    property real height: rendererProcess ? 72 : AppState.cavaHeight
    readonly property real ceilingHeadroom: Math.max(20, Math.round(height * 0.35))
    property real amplitude: 1.0
    property real motionStrength: 1.0

    // Spectrum outputs
    readonly property var rawBars: _rawBars
    readonly property var bars: _smoothedBars

    // Semantic audio energy model
    readonly property real overallEnergy: _energies.overall
    readonly property real bassEnergy: _energies.bass
    readonly property real midEnergy: _energies.mid
    readonly property real trebleEnergy: _energies.treble
    readonly property real peakEnergy: _energies.peak

    // Diagnostic properties
    readonly property int malformedFrames: rendererProcess ? _malformedFrames : (rendererState.malformedFrames || 0)
    readonly property int totalFrames: rendererProcess ? _totalFrames : (rendererState.totalFrames || 0)
    property int restartCount: 0

    // Internal data buffers
    property var _parser: null
    // Parser counters need explicit notifications because the parser itself is plain JavaScript.
    property int _malformedFrames: 0
    property int _totalFrames: 0
    property var _rawBars: []
    property var _smoothedBars: []
    property var _energies: ({ overall: 0.0, bass: 0.0, mid: 0.0, treble: 0.0, peak: 0.0 })
    property bool _stoppingIntentionally: false

    readonly property bool shouldRun: rendererProcess && enabled && available && Quickshell.screens.length > 0

    function start() {
        if (!enabled) {
            enabled = true
        }
        syncProcess()
    }

    function stop() {
        if (enabled) {
            enabled = false
        }
        syncProcess()
    }

    function toggle() {
        if (enabled) stop()
        else start()
    }

    function restart() {
        if (!rendererProcess) {
            if (renderer) renderer.restart()
            return
        }
        if (process.running) {
            _stoppingIntentionally = true
            process.running = false
        }
        Qt.callLater(syncProcess)
    }

    function reload() {
        restart()
    }

    function syncProcess() {
        if (!root || !rendererProcess) return
        if (!shouldRun) {
            if (process.running) {
                _stoppingIntentionally = true
                process.running = false
            }
            restartTimer.stop()
            idleTimer.stop()
            sleeping = true
            decayTimer.start()
        } else {
            decayTimer.stop()
            if (!process.running && !_stoppingIntentionally) {
                if (_parser) _parser.reset()
                _malformedFrames = 0
                _totalFrames = 0
                process.running = true
            }
        }
    }

    onShouldRunChanged: syncProcess()
    onBarCountChanged: {
        if (_parser) _parser.setBarCount(barCount)
    }

    Component.onCompleted: {
        if (!rendererProcess) return
        _parser = Parser.createParser({ barCount: root.barCount, maxRange: 1000 })
        _initBuffers(root.barCount)
        syncProcess()
    }

    Component.onDestruction: {
        _stoppingIntentionally = true
        // Audio owns no pending saves; a blocked input thread must not survive its renderer.
        if (process.running) {
            process.signal(9)
        }
    }

    function _initBuffers(count) {
        var raw = new Array(count)
        var smoothed = new Array(count)
        for (var i = 0; i < count; ++i) {
            raw[i] = 0.0
            smoothed[i] = 0.0
        }
        _rawBars = raw
        _smoothedBars = smoothed
    }

    // Smooth decay when sleeping or when audio stops
    property Timer decayTimer: Timer {
        id: decayTimer
        interval: 33
        repeat: true
        running: false
        onTriggered: {
            var allZero = true
            var count = root.barCount
            var nextBars = new Array(count)
            for (var i = 0; i < count; ++i) {
                var v = root._smoothedBars[i] || 0.0
                v = v * 0.82
                if (v < 0.001) v = 0.0
                else allZero = false
                nextBars[i] = v
            }
            root._smoothedBars = nextBars
            root._energies = CMath.computeEnergies(nextBars)
            if (allZero) decayTimer.stop()
        }
    }

    // Idle threshold detection: if sound is below threshold continuously, mark sleeping
    property Timer idleTimer: Timer {
        id: idleTimer
        interval: 800
        repeat: false
        onTriggered: {
            root.sleeping = true
        }
    }

    // Auto-recovery timer with exponential backoff
    property Timer restartTimer: Timer {
        id: restartTimer
        interval: 500
        repeat: false
        onTriggered: {
            if (root.shouldRun && !root.process.running) {
                root.syncProcess()
            }
        }
    }

    property FileView configFileView: FileView {
        path: root.rendererProcess ? Quickshell.env("HOME") + "/hakucfg/config/cava-layer" : ""
        watchChanges: true
        printErrors: false
        onFileChanged: {
            if (root.running) {
                root.restart()
            }
        }
    }

    property Process process: Process {
        id: process
        command: [Env.binDir + "/cava_manager.sh", "--run-hikai"]

        stdout: SplitParser {
            onRead: data => {
                if (!root.shouldRun) return
                var frame = root._parser ? root._parser.feedLine(data) : null
                root._malformedFrames = root._parser ? root._parser.getMalformedCount() : 0
                root._totalFrames = root._parser ? root._parser.getTotalFrameCount() : 0
                if (!frame) return

                root._rawBars = frame

                // Two-stage visual smoothing: temporal then spatial
                var temporal = CMath.applyTemporalSmoothing(root._smoothedBars, frame, 0.45, 0.20, 0.85)
                var spatial = CMath.applySpatialSmoothing(temporal, root.smoothing)
                root._smoothedBars = spatial

                var energies = CMath.computeEnergies(spatial)
                root._energies = energies

                // Idle / wake evaluation
                if (energies.overall > 0.015) {
                    idleTimer.stop()
                    if (root.sleeping) root.sleeping = false
                } else if (!root.sleeping && !idleTimer.running) {
                    idleTimer.restart()
                }
            }
        }

        onRunningChanged: {
            if (!running) {
                if (root.shouldRun && !root._stoppingIntentionally) {
                    root.restartCount++
                    var delay = Math.min(250 * Math.pow(2, root.restartCount - 1), 3000)
                    restartTimer.interval = delay
                    restartTimer.restart()
                }
            } else {
                root.restartCount = 0
                root.errorString = ""
            }
        }

        onExited: (exitCode, exitStatus) => {
            if (root._stoppingIntentionally) {
                root._stoppingIntentionally = false
                if (root.shouldRun) Qt.callLater(root.syncProcess)
            } else if (exitCode !== 0) {
                root.errorString = "CAVA exited with code " + exitCode
            }
        }
    }
}
