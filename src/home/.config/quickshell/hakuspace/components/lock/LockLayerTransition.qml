import QtQuick

Item {
    id: root

    // Render exactly one pressure front above the permanent opaque cover.
    required property var metrics
    required property var motionState
    required property color inkColor

    LiquidSealWave {
        anchors.fill: parent
        metrics: root.metrics
        inkColor: root.inkColor
        mode: root.motionState.releaseProgress > 0 ? "release" : "capture"
        progress: mode === "release" ? root.motionState.releaseProgress : root.motionState.captureProgress
        reducedMotion: root.motionState.reducedMotion
    }
}
