import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: root
    required property var modelData
    required property var controller
    // Keep the old renderer visible until every output accepts the next frame.
    property var front: null
    property var incoming: null
    property var savedFrontRecord: null
    property string candidateToken: ""
    readonly property bool hiddenByFullscreen: ToplevelManager.toplevels.values.some(window => window.fullscreen && window.activated && window.screens.includes(root.modelData))
    readonly property bool paused: root.controller.manuallyPaused || (root.controller.preferences.playback.pauseWhenFullscreen && hiddenByFullscreen)
    property bool unloaded: false
    visible: !!front || !!incoming || frozenImage.visible
    screen: modelData
    anchors { top: true; bottom: true; left: true; right: true }
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: "hakuspace-wallpaper-background"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0
    color: "transparent"
    mask: Region { width: 0; height: 0 }

    Image {
        id: frozenImage
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        visible: false
        cache: false
        asynchronous: false
    }

    // Apply lifecycle policy to both slots while readiness remains observable.
    function updatePolicy() {
        if (front) { front.paused = paused; front.unloaded = unloaded }
        if (incoming) incoming.paused = paused
        root.controller.state(modelData.name, front, incoming, visible, unloaded)
        root.controller.report(modelData.name, unloaded ? "UNLOADED" : paused ? "PAUSED" : (front || incoming || frozenImage.visible) ? "PLAYING" : "STOPPED")
    }
    function createIncomingSurface(record) {
        if (incoming) { incoming.destroy(); incoming = null }
        var component = Qt.createComponent("VideoWallpaperSurface.qml")
        if (component.status === Component.Error) { root.controller.fail(component.errorString(), record.token); return }
        incoming = component.createObject(root.contentItem, {record: record, controller: root.controller, width: root.width, height: root.height, opacity: 0})
        if (!incoming) { root.controller.fail(component.errorString() || "Wallpaper renderer unavailable", record.token); return }
        root.controller.state(modelData.name, front, incoming, visible, unloaded)
        var renderer = incoming
        renderer.ready.connect(function() {
            if (root.incoming !== renderer) return
            if (root.controller.candidate.token === record.token) root.controller.surfaceReady(root.modelData.name, record.token)
            else if (root.controller.current.token === record.token) root.promote()
        })
        renderer.failed.connect(function(message) {
            if (root.incoming === renderer || root.front === renderer) root.controller.fail(message, record.token)
        })
        if (renderer.announced) {
            if (root.controller.candidate.token === record.token) root.controller.surfaceReady(modelData.name, record.token)
            else promote()
        }
    }
    // Create Qt Multimedia lazily so missing multimedia support does not break the shell.
    function stage(record) {
        if (!record.token || record.kind !== "video" || (front && front.record.token === record.token)) return
        root.candidateToken = record.token

        if (root.controller.transitionStrategy !== "stagedStill" || !front) {
            createIncomingSurface(record)
            return
        }

        if (incoming) { incoming.destroy(); incoming = null }
        root.savedFrontRecord = front.record
        var targetToken = record.token
        var targetFront = front
        var grabScheduled = false
        try {
            grabScheduled = targetFront.grabToImage(function(result) {
                if (root.candidateToken !== targetToken) return
                if (result && result.url) {
                    frozenImage.source = result.url
                    frozenImage.visible = true
                    frozenImage.z = 1
                }
                if (root.front === targetFront) {
                    var old = root.front
                    root.front = null
                    old.destroy()
                }
                Qt.callLater(function() {
                    if (root.candidateToken === targetToken && (root.controller.candidate.token === targetToken || root.controller.current.token === targetToken)) {
                        root.createIncomingSurface(record)
                    } else if (!root.controller.candidate.token && root.savedFrontRecord) {
                        root.restorePrevious()
                    }
                })
            }, Qt.size(root.width, root.height))
        } catch (e) {
            grabScheduled = false
        }
        if (!grabScheduled) {
            createIncomingSurface(record)
        }
    }
    function restorePrevious() {
        if (!root.front && root.savedFrontRecord && root.controller.current.kind === "video") {
            var rec = root.savedFrontRecord
            root.savedFrontRecord = null
            createIncomingSurface(rec)
        }
    }
    // Transfer ownership without reloading the newly prepared player.
    function promote() {
        if (!incoming || incoming.record.token !== root.controller.current.token) return
        var old = front
        front = incoming
        incoming = null
        front.opacity = 1
        if (old) old.destroy()
        frozenImage.visible = false
        frozenImage.source = ""
        frozenImage.z = 0
        root.savedFrontRecord = null
        root.controller.takeOwnership()
        updatePolicy()
    }
    onPausedChanged: {
        if (paused && root.controller.preferences.playback.unloadWhenHidden) unloadTimer.restart()
        else { unloadTimer.stop(); unloaded = false }
        updatePolicy()
    }
    onUnloadedChanged: updatePolicy()
    onWidthChanged: { if (front) front.width = width; if (incoming) incoming.width = width }
    onHeightChanged: { if (front) front.height = height; if (incoming) incoming.height = height }
    Timer { id: unloadTimer; interval: root.controller.preferences.playback.unloadDelaySec * 1000; onTriggered: root.unloaded = true }
    Connections {
        target: root.controller
        function onCandidateChanged() {
            if (root.controller.candidate.token) root.stage(root.controller.candidate)
            else {
                if (root.incoming && root.incoming.record.token !== root.controller.current.token) {
                    root.incoming.destroy()
                    root.incoming = null
                    root.updatePolicy()
                }
                if (root.controller.transitionStrategy === "stagedStill" && !root.front && root.savedFrontRecord) {
                    root.restorePrevious()
                }
            }
        }
        function onCurrentChanged() {
            if (root.controller.current.kind !== "video") {
                if (root.incoming) { root.incoming.destroy(); root.incoming = null }
                if (root.front) { root.front.destroy(); root.front = null }
                frozenImage.visible = false
                frozenImage.source = ""
                frozenImage.z = 0
                root.savedFrontRecord = null
                unloadTimer.stop()
                root.unloaded = false
                root.updatePolicy()
            } else if (root.incoming && root.incoming.record.token === root.controller.current.token) root.promote()
            else root.stage(root.controller.current)
        }
        function onPreferencesChanged() {
            unloadTimer.stop()
            if (root.paused && root.controller.preferences.playback.unloadWhenHidden) unloadTimer.restart()
            else root.unloaded = false
            root.updatePolicy()
        }
    }
    Component.onCompleted: {
        stage(root.controller.candidate.token ? root.controller.candidate : root.controller.current)
    }
    Component.onDestruction: {
        if (front) front.destroy()
        if (incoming) incoming.destroy()
        frozenImage.source = ""
    }
}
