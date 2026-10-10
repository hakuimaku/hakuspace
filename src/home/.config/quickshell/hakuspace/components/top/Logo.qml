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

    tooltip: UiState.activePanel === "navigation" ? "" : "Have a nice day!"

    // Hide only the TopBar visual while the Navigation proxy owns the morph;
    // the layout footprint remains reserved.
    visible: !navigationVisualActive
    enabled: !navigationVisualActive

    onClicked: {
        TooltipManager.dismiss()
        var point = root.mapToItem(null, 0, 0)
        UiState.toggleNavigation(root.screenName, point.x, root.width, root.height, point.y)
    }
}
