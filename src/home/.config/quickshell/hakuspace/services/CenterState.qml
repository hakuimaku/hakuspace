pragma Singleton
import QtQuick

QtObject {
    id: root
    property string transientMode: ""
    property string activePromptText: ""
    property int lastPromptIndex: -1
    readonly property bool promptFeatureEnabled: ShellSettingsStore.ready
        && ShellSettingsStore.showCenter
        && ShellSettingsStore.centerPromptEnabled
        && ShellSettingsStore.centerPromptList.length > 0
    readonly property int promptIntervalMs: Math.max(10, ShellSettingsStore.centerPromptInterval) * 1000
    readonly property int promptDurationMs: Math.max(3, ShellSettingsStore.centerPromptDuration) * 1000
    readonly property bool promptVisible: activePromptText !== "" && promptFeatureEnabled
    // Center group is owned by media or periodic prompt. Recording presentation lives exclusively in RecorderGroup.
    readonly property string baseMode: Media.available ? "media" : "idle"
    readonly property string centerMode: promptVisible ? "prompt" : baseMode
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
    function pickPrompt() {
        var list = ShellSettingsStore.centerPromptList
        if (!list || list.length === 0) return ""
        if (list.length === 1) {
            lastPromptIndex = 0
            return list[0]
        }
        var idx = Math.floor(Math.random() * list.length)
        if (idx === lastPromptIndex) {
            idx = (idx + 1 + Math.floor(Math.random() * (list.length - 1))) % list.length
        }
        lastPromptIndex = idx
        return list[idx]
    }

    function triggerPrompt() {
        if (!promptFeatureEnabled) return
        if (osdVisible || UiState.activePanel === "hakumenu" || UiState.dashboardVisuallyActive) {
            promptDeferTimer.restart()
            return
        }
        var next = pickPrompt()
        if (!next) return
        activePromptText = next
        promptDurationTimer.restart()
    }

    onPromptFeatureEnabledChanged: {
        if (!promptFeatureEnabled) {
            activePromptText = ""
            promptDurationTimer.stop()
            promptDeferTimer.stop()
        }
    }
    onPromptIntervalMsChanged: {
        if (promptIntervalTimer.running) promptIntervalTimer.restart()
    }
    onPromptDurationMsChanged: {
        if (promptDurationTimer.running) promptDurationTimer.restart()
    }

    property Timer promptIntervalTimer: Timer {
        interval: root.promptIntervalMs
        repeat: false
        running: root.promptFeatureEnabled && !root.promptVisible && !promptDeferTimer.running
        onTriggered: root.triggerPrompt()
    }

    property Timer promptDeferTimer: Timer {
        interval: 2000
        repeat: false
        onTriggered: root.triggerPrompt()
    }

    property Timer promptDurationTimer: Timer {
        interval: root.promptDurationMs
        repeat: false
        onTriggered: root.activePromptText = ""
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
