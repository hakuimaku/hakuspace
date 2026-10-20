pragma Singleton
import QtQuick

QtObject {
    // Taskbar owns topology; Dockbar keeps its requested state while suppressed.
    readonly property bool taskbarMode: AppState.taskbarManualState
    readonly property bool topBarMode: !taskbarMode
    readonly property bool dockbarRequested: AppState.dockbarManualState
    readonly property bool dockbarActive: topBarMode && dockbarRequested
    readonly property bool taskbarActive: taskbarMode
    readonly property bool topStatusBarVisible: topBarMode
    readonly property bool topEdgeHakuMenuEnabled: topBarMode
    readonly property bool bottomStatusModulesVisible: taskbarMode
    readonly property bool centerModulesVisible: topBarMode
    readonly property bool statusAtBottom: taskbarMode
    readonly property string statusEdge: taskbarMode ? "bottom" : "top"
    readonly property string defaultHakuMenuPresentation: taskbarMode ? "bottomFlare" : "topFlare"
}
