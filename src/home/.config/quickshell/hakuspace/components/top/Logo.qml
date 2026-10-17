import QtQuick
import Quickshell
import "../../services"
import ".."

TopModule {
    id: root
    required property string screenName
    icon: "󰮯"
    isAccent: true
    color: Theme.accent
    foregroundColor: Theme.onAccentColor
    iconFontSize: Theme.fontSize + (hovered ? 2 : 0)

    // Keep a stable layout footprint while Navigation owns the visible Logo.
    implicitWidth: implicitHeight + (hovered ? Theme.pad : 0)
    radius: height / 2

    readonly property bool navigationVisualActive: UiState.navigationVisualScreenName === root.screenName

    tooltip: ""

    // Hide only the TopBar visual while the Navigation proxy owns the morph;
    // the layout footprint remains reserved.
    visible: !navigationVisualActive
    enabled: !navigationVisualActive

    // Disable color animation on Logo to guarantee immediate rock-solid Theme.accent
    Behavior on color { enabled: false }

    // When Navigation releases visual ownership, Logo may reappear directly
    // underneath a stationary pointer. Suppress only that synthetic re-entry;
    // do not impose a time cooldown that can swallow the user's first real hover.
    property bool reopenHoverGuard: false
    Connections {
        target: UiState
        function onNavigationVisualScreenNameChanged() {
            if (UiState.navigationVisualScreenName !== "") {
                root.reopenHoverGuard = false
                return
            }

            root.reopenHoverGuard = true
            Qt.callLater(function() {
                // If Logo came back with the pointer elsewhere, there is no
                // synthetic hover to guard against, so the next enter opens
                // Navigation immediately. If it came back under the pointer,
                // keep the guard until that pointer leaves once.
                if (!root.hovered) root.reopenHoverGuard = false
            })
        }
    }

    // Calculates top bar anchor coordinates and dispatches request to open navigation surface.
    function triggerOpenNavigation() {
        TooltipManager.dismiss()
        UiState.openNavigation(root.screenName, ScreenGeometry.itemRect(root))
    }

    onHoveredChanged: {
        if (!hovered) {
            reopenHoverGuard = false
            return
        }
        if (!navigationVisualActive && !reopenHoverGuard) {
            triggerOpenNavigation()
        }
    }

    onClicked: {
        triggerOpenNavigation()
    }
}
