import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root
    // Record native composited frames and finite geometry traces in a private test session.
    property string directory: ""
    property string name: ""
    property var owner: null
    property var sample: null
    property var samples: []
    property int shots: 0
    property real startedAt: 0
    readonly property bool writing: writer.running
    readonly property bool ready: shots >= 12 && !capture.running
    signal failed(string message)
    // Replace the bounded trace when the next transition takes visual ownership.
    function start(label, window, measure) {
        name = label; owner = window; sample = measure
        samples = []; shots = 0; startedAt = Date.now()
    }
    // Publish the completed trace without retaining frame images in QML memory.
    function finish() {
        writer.command = ["python3", "-c", "import pathlib,sys; pathlib.Path(sys.argv[1]).write_text(sys.argv[2])",
            directory + "/" + name + ".json", JSON.stringify({name: name, frames: shots, samples: samples})]
        writer.running = true
        name = ""
    }
    Process {
        id: capture
        onExited: code => { if (code !== 0) root.failed("native animation capture failed") }
    }
    Process { id: writer; onExited: code => { if (code !== 0) root.failed("animation trace write failed") } }
    FrameAnimation {
        running: root.name.length > 0
        onTriggered: {
            var geometry = root.sample()
            if (root.samples.length < 180) root.samples.push(Object.assign({timeMs: Date.now() - root.startedAt}, geometry))
            if (root.shots > 0 && root.name.endsWith("-open") && geometry.depth <= 0) return
            if (capture.running || root.shots >= 16) return
            var path = root.directory + "/" + root.name + "-" + String(root.shots++).padStart(2, "0") + ".png"
            capture.command = ["grim", "-o", root.owner.screen.name, path]
            capture.running = true
        }
    }
}
