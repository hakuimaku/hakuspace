import QtQuick
import "../../services"
import ".."

TopModule {
    id: root
    required property string screenName
    objectName: "wallpaper-workspace-launcher"
    icon: "\uf03e"
    tooltip: "Open wallpaper workspace"
    Accessible.role: Accessible.Button
    Accessible.name: tooltip

    // Open mode 2 on the output that owns this bar.
    onClicked: UiState.openWallpaperWorkspace(screenName)
}
