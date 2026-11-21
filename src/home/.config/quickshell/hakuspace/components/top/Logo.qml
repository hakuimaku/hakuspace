import QtQuick
import Quickshell
import "../../services"
import ".."

TopModule {
    id: root
    required property string screenName
    // Leftbar can hand off its painted circle while keeping a larger pointer wrapper.
    property Item navigationAnchorItem: anchorBox
    Item {
        id: anchorBox
        anchors.centerIn: parent
        width: root.visualItem.width
        height: root.visualItem.height
    }
    icon: "󰮯"
    isAccent: !ShellHealth.degraded
    color: ShellHealth.degraded ? Theme.dangerFill : Theme.accent
    foregroundColor: Theme.onAccentColor
    readonly property bool clickToOpen: ShellSettingsStore.navigationOpenTrigger === "click"
    iconFontSize: Theme.fontSize + (!clickToOpen && hovered ? 2 : 0)

    // Keep a stable layout footprint while Navigation owns the visible Logo.
    implicitWidth: implicitHeight + (!clickToOpen && hovered ? Theme.pad : 0)
    radius: height / 2
    visualScale: clickToOpen && hovered ? 1.3 : 1.0
    Behavior on visualScale {
        NumberAnimation { duration: HAnimation.slow; easing.bezierCurve: HAnimation.moduleCurve }
    }

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
        function onNavigationLogoReturning(screenName, pointerInside) {
            if (root.verticalPresentation && screenName === root.screenName) root.reopenHoverGuard = pointerInside
        }
        function onNavigationVisualScreenNameChanged() {
            if (root.verticalPresentation) return
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
        UiState.openNavigation(root.screenName, ScreenGeometry.itemRect(navigationAnchorItem))
    }

    onHoveredChanged: {
        if (!hovered) {
            reopenHoverGuard = false
            return
        }
        if (!clickToOpen && !navigationVisualActive && !reopenHoverGuard) {
            triggerOpenNavigation()
        }
    }

    onClicked: {
        triggerOpenNavigation()
    }
}
