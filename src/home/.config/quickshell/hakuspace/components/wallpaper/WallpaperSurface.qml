import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../services"

PanelWindow {
    id: root
    required property var modelData
    // Keep the old renderer visible until every output accepts the next frame.
    property var front: null
    property var incoming: null
    readonly property bool hiddenByFullscreen: ToplevelManager.toplevels.values.some(window => window.fullscreen && window.activated && window.screens.includes(root.modelData))
    readonly property bool paused: WallpaperService.manuallyPaused || (WallpaperService.preferences.playback.pauseWhenFullscreen && hiddenByFullscreen)
    property bool unloaded: false
    visible: !!front || !!incoming
    screen: modelData
    anchors { top: true; bottom: true; left: true; right: true }
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: "hakuspace-wallpaper-background"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0
    color: "transparent"
    mask: Region { width: 0; height: 0 }

    // Apply lifecycle policy to both slots while readiness remains observable.
    function updatePolicy() {
        if (front) { front.paused = paused; front.unloaded = unloaded }
        if (incoming) incoming.paused = paused
        WallpaperService.report(modelData.name, unloaded ? "UNLOADED" : paused ? "PAUSED" : front ? "PLAYING" : "STOPPED")
    }
    // Create Qt Multimedia lazily so missing multimedia support does not break the shell.
    function stage(record) {
        if (!record.token || record.kind !== "video" || (front && front.record.token === record.token)) return
        if (incoming) { incoming.destroy(); incoming = null }
        var component = Qt.createComponent("VideoWallpaperSurface.qml")
        if (component.status === Component.Error) { WallpaperService.fail(component.errorString()); return }
        incoming = component.createObject(root.contentItem, {record: record, width: root.width, height: root.height, opacity: 0})
        if (!incoming) { WallpaperService.fail("Wallpaper renderer unavailable"); return }
        var renderer = incoming
        renderer.ready.connect(function() {
            if (root.incoming !== renderer) return
            if (WallpaperService.candidate.token === record.token) WallpaperService.surfaceReady(root.modelData.name, record.token)
            else if (WallpaperService.current.token === record.token) root.promote()
        })
        renderer.failed.connect(function(message) { WallpaperService.fail(message) })
        if (renderer.announced) {
            if (WallpaperService.candidate.token === record.token) WallpaperService.surfaceReady(modelData.name, record.token)
            else promote()
        }
    }
    // Transfer ownership without reloading the newly prepared player.
    function promote() {
        if (!incoming || incoming.record.token !== WallpaperService.current.token) return
        var old = front
        front = incoming
        incoming = null
        front.opacity = 1
        if (old) old.destroy()
        WallpaperService.takeOwnership()
        updatePolicy()
    }
    onPausedChanged: {
        if (paused && WallpaperService.preferences.playback.unloadWhenHidden) unloadTimer.restart()
        else { unloadTimer.stop(); unloaded = false }
        updatePolicy()
    }
    onUnloadedChanged: updatePolicy()
    onWidthChanged: { if (front) front.width = width; if (incoming) incoming.width = width }
    onHeightChanged: { if (front) front.height = height; if (incoming) incoming.height = height }
    Timer { id: unloadTimer; interval: WallpaperService.preferences.playback.unloadDelaySec * 1000; onTriggered: root.unloaded = true }
    Connections {
        target: WallpaperService
        function onCandidateChanged() {
            if (WallpaperService.candidate.token) root.stage(WallpaperService.candidate)
            else if (root.incoming && root.incoming.record.token !== WallpaperService.current.token) { root.incoming.destroy(); root.incoming = null }
        }
        function onCurrentChanged() {
            if (WallpaperService.current.kind !== "video") {
                if (root.incoming) { root.incoming.destroy(); root.incoming = null }
                if (root.front) { root.front.destroy(); root.front = null }
                unloadTimer.stop()
                root.unloaded = false
                root.updatePolicy()
            } else if (root.incoming && root.incoming.record.token === WallpaperService.current.token) root.promote()
            else root.stage(WallpaperService.current)
        }
        function onPreferencesChanged() {
            unloadTimer.stop()
            if (root.paused && WallpaperService.preferences.playback.unloadWhenHidden) unloadTimer.restart()
            else root.unloaded = false
            root.updatePolicy()
        }
    }
    Component.onCompleted: {
        WallpaperService.registerSurface(modelData.name)
        stage(WallpaperService.candidate.token ? WallpaperService.candidate : WallpaperService.current)
    }
    Component.onDestruction: {
        WallpaperService.unregisterSurface(modelData.name)
        if (front) front.destroy()
        if (incoming) incoming.destroy()
    }
}
