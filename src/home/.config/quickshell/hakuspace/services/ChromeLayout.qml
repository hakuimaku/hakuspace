pragma Singleton
import QtQuick

QtObject {
    // Taskbar owns topology; Dockbar keeps its requested state while suppressed.
    readonly property bool taskbarMode: AppState.taskbarManualState
    readonly property bool statusBarMode: !taskbarMode
    readonly property bool leftBarMode: statusBarMode && ShellSettingsStore.statusEdge === "left"
    readonly property bool topBarMode: statusBarMode && !leftBarMode
    readonly property bool dockbarRequested: AppState.dockbarManualState
    readonly property bool dockbarActive: statusBarMode && dockbarRequested
    readonly property bool taskbarActive: taskbarMode
    readonly property bool topStatusBarVisible: topBarMode
    readonly property bool topEdgeHakuMenuEnabled: statusBarMode
    readonly property bool bottomStatusModulesVisible: taskbarMode
    readonly property bool centerModulesVisible: topBarMode
    readonly property bool statusAtBottom: taskbarMode
    readonly property string statusEdge: taskbarMode ? "bottom" : leftBarMode ? "left" : "top"
    readonly property string defaultHakuMenuPresentation: taskbarMode ? "bottomFlare" : "topFlare"
}
