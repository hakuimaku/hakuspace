pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Mpris

QtObject {
    id: root
    property int revision: 0
    property var players: Mpris.players.values
    property var selected: choosePlayer(players, revision)
    property bool available: selected !== null
    property bool playing: available && selected.isPlaying
    property string title: available ? (selected.trackTitle || selected.identity || "Media") : ""
    property string artist: available ? selected.trackArtist : ""

    // The revision forces reevaluation when an existing MPRIS player changes.
    function choosePlayer(list, ignoredRevision) {
        var candidates = []
        for (var i = 0; i < list.length; ++i) {
            if (list[i].playbackState !== MprisPlaybackState.Stopped)
                candidates.push(list[i])
        }
        // Prefer playback; D-Bus names break ties without jumping between players.
        candidates.sort((a, b) => {
            if (a.isPlaying !== b.isPlaying) return a.isPlaying ? -1 : 1
            return a.dbusName < b.dbusName ? -1 : (a.dbusName > b.dbusName ? 1 : 0)
        })
        return candidates.length ? candidates[0] : null
    }

    function togglePlaying() {
        if (selected && selected.canTogglePlaying) selected.togglePlaying()
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
            }
        }
    }
}
