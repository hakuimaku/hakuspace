pragma Singleton
import QtQuick

QtObject {
    id: root
    property string transientMode: ""
    // Center group is owned by media. Recording presentation lives exclusively in RecorderGroup.
    readonly property string baseMode: Media.available ? "media" : "idle"
    readonly property string centerMode: baseMode
    readonly property bool osdVisible: transientMode !== ""
    property real osdExpansion: osdVisible ? 1 : 0
    // Animates center OSD pill expansion when transient volume or brightness feedback triggers.
    Behavior on osdExpansion {
        NumberAnimation { duration: HAnimation.normal; easing.bezierCurve: HAnimation.moduleCurve }
    }

    // Activates transient OSD mode (volume or brightness) and restarts expiry timer.
    function show(mode) {
        transientMode = mode
        expiry.restart()
    }

    property Timer expiry: Timer {
        interval: 1400
        repeat: false
        onTriggered: {
            // Keep the OSD open until queued actions and feedback finish.
            if (Audio.actionBusy || Brightness.actionBusy
                    || Audio.queuedCommands.length > 0 || Brightness.queuedCommands.length > 0
                    || Audio.pendingFeedback || Brightness.pendingFeedback)
                restart()
            else
                root.transientMode = ""
        }
    }
    property Connections audioEvents: Connections {
        target: Audio
        function onUserInteracted() { root.show("volume") }
        function onUserChanged() { if (root.transientMode === "volume") expiry.restart() }
    }
    property Connections brightnessEvents: Connections {
        target: Brightness
        function onUserInteracted() { root.show("brightness") }
        function onUserChanged() { if (root.transientMode === "brightness") expiry.restart() }
    }
}
