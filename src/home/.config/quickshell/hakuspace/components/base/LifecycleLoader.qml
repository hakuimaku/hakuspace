import QtQuick
import Quickshell

LazyLoader {
    id: root
    // Keep the item alive until its own visual close has completed.
    property bool requested: false
    active: false

    // Defer release until state handlers have started or reversed their animations.
    function sync() {
        if (requested) active = true
        else if (active && item && item.releaseReady) active = false
    }

    onRequestedChanged: {
        if (requested) active = true
        else Qt.callLater(sync)
    }
    onItemChanged: Qt.callLater(sync)
    Component.onCompleted: sync()
    property Connections lifecycleEvents: Connections {
        target: root.active ? root.item : null
        function onReleaseReadyChanged() { Qt.callLater(root.sync) }
    }
}
