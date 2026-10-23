import QtQuick
import QtMultimedia
import "../../services"

Item {
    id: root
    // Destroying the loader releases the player, video sink and decoder surfaces.
    required property var record
    property bool paused: false
    property bool unloaded: false
    property bool announced: false
    signal ready()
    signal failed(string message)
    Image {
        anchors.fill: parent
        source: WallpaperService.fileUrl(root.record.thumbnail)
        sourceSize.width: root.width
        sourceSize.height: root.height
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
    }
    Loader {
        anchors.fill: parent
        active: !root.unloaded
        sourceComponent: Item {
            VideoOutput { id: output; anchors.fill: parent; fillMode: VideoOutput.PreserveAspectCrop }
            MediaPlayer {
                id: player
                source: WallpaperService.fileUrl(root.record.proxyPath)
                videoOutput: output
                loops: WallpaperService.preferences.playback.loop ? MediaPlayer.Infinite : 1
                playbackRate: 1
                // No AudioOutput is created; wallpaper audio is always disabled.
                Component.onCompleted: play()
                onErrorOccurred: (error, errorString) => root.failed(errorString)
            }
            Connections {
                target: output.videoSink
                function onVideoFrameChanged() {
                    if (output.videoSink.videoSize.width <= 0 || output.videoSink.videoSize.height <= 0) return
                    if (!root.announced) { root.announced = true; root.ready() }
                    if (root.paused) player.pause()
                }
            }
            Connections {
                target: root
                function onPausedChanged() { if (root.paused && root.announced) player.pause(); else player.play() }
            }
        }
    }
}
