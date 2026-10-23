import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../services"

// TopBar mode owns this trigger independently of compact Dockbar lifetime.
HakuMenuAttachedFlare {
    id: root
    readonly property real triggerHeight: 4
    readonly property real triggerWidth: screenWidth * 0.20
    readonly property var triggerRect: ({x: (screenWidth - triggerWidth) / 2,
        y: 0, width: triggerWidth, height: triggerHeight})

    HakuMenuTrigger { modelData: root.modelData; owner: root }
}
