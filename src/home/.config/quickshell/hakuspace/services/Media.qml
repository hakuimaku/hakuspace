pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Mpris

QtObject {
    id: root
    property int revision: 0
    property var players: Mpris.players.values
    property string preferredDbusName: ""
    readonly property var availablePlayers: collectCandidates(players, revision)
    property var selected: choosePlayer(players, revision, preferredDbusName)
    property bool available: selected !== null
    property bool playing: available && selected.isPlaying
    property string title: available ? (selected.trackTitle || selected.identity || "Media") : ""
    property string artist: available ? selected.trackArtist : ""
    property string artUrl: available ? (selected.trackArtUrl || "") : ""
    property string album: available ? selected.trackAlbum : ""
    property bool canTogglePlaying: available && selected.canTogglePlaying
    property bool canGoPrevious: available && selected.canGoPrevious
    property bool canGoNext: available && selected.canGoNext

    property real position: 0
    property int _positionSubscribers: 0
    readonly property real length: (available && selected.length !== undefined && Number.isFinite(selected.length) && selected.length > 0)
        ? selected.length
        : 0
    readonly property bool canSeek: available && !!selected.canSeek && length > 0

    function collectCandidates(list, ignoredRevision) {
        if (!list) return []
        var candidates = []
        for (var i = 0; i < list.length; ++i) {
            if (list[i] && list[i].playbackState !== MprisPlaybackState.Stopped)
                candidates.push(list[i])
        }
        // Prefer playback; D-Bus names break ties without jumping between players.
        candidates.sort((a, b) => {
            if (a.isPlaying !== b.isPlaying) return a.isPlaying ? -1 : 1
            return a.dbusName < b.dbusName ? -1 : (a.dbusName > b.dbusName ? 1 : 0)
        })
        return candidates
    }

    // Selects the preferred active MPRIS player from available candidates.
    function choosePlayer(list, ignoredRevision, preferred) {
        var candidates = collectCandidates(list, ignoredRevision)
        if (!candidates.length) return null
        if (preferred && preferred.length > 0) {
            for (var i = 0; i < candidates.length; ++i) {
                if (candidates[i].dbusName === preferred) return candidates[i]
            }
        }
        return candidates[0]
    }

    function selectPlayer(dbusName) {
        preferredDbusName = dbusName || ""
        revision++
    }

    function cyclePlayer(delta) {
        var candidates = availablePlayers
        if (!candidates || candidates.length <= 1) return
        var currentIndex = 0
        if (selected) {
            for (var i = 0; i < candidates.length; ++i) {
                if (candidates[i].dbusName === selected.dbusName) {
                    currentIndex = i
                    break
                }
            }
        }
        var step = (delta === undefined || delta === 0) ? 1 : delta
        var nextIndex = ((currentIndex + step) % candidates.length + candidates.length) % candidates.length
        selectPlayer(candidates[nextIndex].dbusName)
    }

    function syncPosition() {
        if (!available || !selected) {
            position = 0
            return
        }
        var raw = selected.position
        position = (raw !== undefined && Number.isFinite(raw) && raw >= 0) ? raw : 0
    }

    function seekTo(seconds) {
        if (!canSeek || !selected) return
        var clamped = Math.max(0, Math.min(length, seconds))
        try {
            selected.position = clamped
            position = clamped
        } catch (e) {
            syncPosition()
        }
    }

    function acquirePosition() {
        _positionSubscribers++
        syncPosition()
    }

    function releasePosition() {
        _positionSubscribers = Math.max(0, _positionSubscribers - 1)
    }

    onSelectedChanged: syncPosition()
    onPlayingChanged: syncPosition()

    property Timer positionTimer: Timer {
        interval: 1000
        repeat: true
        running: root.available && root.playing && root._positionSubscribers > 0
        onTriggered: root.syncPosition()
    }

    // Toggles playback state (play/pause) on the active media player.
    function togglePlaying() {
        if (selected && selected.canTogglePlaying) selected.togglePlaying()
    }

    // Triggers previous track action on the active media player.
    function previous() {
        if (selected && selected.canGoPrevious) selected.previous()
    }

    // Triggers next track action on the active media player.
    function next() {
        if (selected && selected.canGoNext) selected.next()
    }

    property Instantiator watcher: Instantiator {
        model: Mpris.players
        delegate: QtObject {
            required property var modelData
            property Connections connections: Connections {
                target: modelData
                function onPlaybackStateChanged() { root.revision++ }
                function onTrackTitleChanged() { root.revision++ }
                function onTrackArtistChanged() { root.revision++ }
                function onTrackAlbumChanged() { root.revision++ }
                function onTrackArtUrlChanged() { root.revision++ }
                function onCanTogglePlayingChanged() { root.revision++ }
                function onCanGoPreviousChanged() { root.revision++ }
                function onCanGoNextChanged() { root.revision++ }
                function onLengthChanged() { root.revision++ }
                function onCanSeekChanged() { root.revision++ }
                function onPositionChanged() {
                    if (root.selected === modelData) root.syncPosition()
                }
            }
        }
    }
}
