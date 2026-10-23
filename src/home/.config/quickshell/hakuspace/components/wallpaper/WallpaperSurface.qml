import QtQuick
import Quickshell
import "../../services"

Scope {
    id: root
    required property var modelData
    // The child process owns all Qt Multimedia objects and drawing windows.
    readonly property var state: WallpaperService.rendererStates[modelData.name] || ({})
    readonly property var front: state.front || null
    readonly property var incoming: state.incoming || null
    readonly property bool visible: !!state.visible
    readonly property bool unloaded: !!state.unloaded
    Component.onCompleted: WallpaperService.registerSurface(modelData.name)
    Component.onDestruction: WallpaperService.unregisterSurface(modelData.name)
}
