import QtQuick
import QtMultimedia
import Quickshell

// Construct both playback types without opening a desktop window.
ShellRoot {
    Item {
        MediaPlayer { videoOutput: output }
        VideoOutput { id: output }
        Timer {
            interval: 1
            running: true
            onTriggered: { console.log("QtMultimedia runtime passed"); Qt.quit() }
        }
    }
}
