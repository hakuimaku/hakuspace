import QtQuick
import Quickshell
import Quickshell.Wayland
import "../services"
import "appbar" as AppBar
import "bar" as Bar
import "base" as Base
import "base/SafeZoneGeometry.js" as Safe

Item {
    id: root
    required property var modelData
    readonly property bool active: !!modelData && ChromeLayout.taskbarMode
    readonly property bool visualActive: !!modelData && (BarTransitionState.hostActive ? (BarTransitionState.visualEdge === "bottom") : ChromeLayout.taskbarMode)
    // Default and IPC callers share the same output-specific bottom presentation.
    readonly property bool menuOwned: active && UiState.activePanel === "hakumenu"
        && UiState.hakuMenuStyle === "bottomFlare" && UiState.hakuMenuMode !== "closed"
        && UiState.hakuMenuScreenName === modelData.name
    readonly property real targetHeight: ScreenGeometry.taskbarHeight
    readonly property var safeRect: Safe.rect((taskbarWindow.width - appContent.viewportWidth) / 2 - Theme.hugRadius,
        taskbarWindow.height - targetHeight - appContent.headroom, appContent.viewportWidth + Theme.hugRadius * 2,
        targetHeight + appContent.headroom)
    // Publish only the live center lane; status modules keep their own input.
    readonly property var centerRect: active ? Safe.rect(
        (taskbarWindow.width - Math.min(taskbarWindow.width, statusModules.centerViewportWidth)) / 2,
        taskbarWindow.height - targetHeight,
        Math.min(taskbarWindow.width, statusModules.centerViewportWidth), targetHeight) : null
    property string registeredOutput: ""
    onCenterRectChanged: syncGeometry()
    onModelDataChanged: syncGeometry()
    Component.onCompleted: syncGeometry()
    Component.onDestruction: ScreenGeometry.setTaskbarCenterRect(registeredOutput, null)

    // Revoke the previous output before publishing resized or restored geometry.
    function syncGeometry() {
        var name = modelData ? modelData.name : ""
        if (registeredOutput && registeredOutput !== name) ScreenGeometry.setTaskbarCenterRect(registeredOutput, null)
        registeredOutput = name
        ScreenGeometry.setTaskbarCenterRect(name, centerRect)
    }
    // Cancel transient feedback without interrupting persisted pin mutations.
    onMenuOwnedChanged: {
        if (!menuOwned) return
        if (TooltipManager.activeBar === taskbarWindow) TooltipManager.dismiss()
        appContent.cancelTermination()
        appContent.cancelReorder()
        appContent.clearPinFeedback()
        appContent.pendingPin = null
        lifetime.reset()
    }

    // Taskbar reserves exactly one fixed bottom zone for its entire lifetime.
    PanelWindow {
        screen: root.modelData
        anchors { bottom: true; left: true; right: true }
        WlrLayershell.layer: WlrLayer.Bottom
        WlrLayershell.namespace: "hakuspace-taskbar-reservation"
        visible: root.active
        color: "transparent"
        implicitHeight: root.targetHeight
        exclusiveZone: root.targetHeight
        mask: Region {}
    }
    Base.SafeZoneController {
        id: lifetime
        active: root.active && !root.menuOwned
        containsPoint: function(x, y) { return Safe.contains(root.safeRect, x, y) }
        onCloseRequested: appContent.cancelTermination()
    }
    PanelWindow {
        id: taskbarWindow
        readonly property bool bottomChromeHost: true
        screen: root.modelData
        // Keep one physical coordinate plane while status tooltips change size.
        anchors { top: true; bottom: true; left: true; right: true }
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "hakuspace-taskbar"
        WlrLayershell.keyboardFocus: root.active ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore
        // Preserve rendering resources while Settings can switch back to this bar.
        visible: BarTransitionState.hostActive || root.visualActive || UiState.activePanel === "settings"
        contentItem.visible: BarTransitionState.hostActive ? true : root.visualActive
        color: "transparent"
        mask: Region {
            y: taskbarWindow.height - root.targetHeight
            width: root.visualActive ? taskbarWindow.width : 0
            height: root.visualActive ? root.targetHeight : 0
            Region {
                x: root.safeRect.x; y: root.safeRect.y
                width: root.visualActive && !root.menuOwned ? root.safeRect.width : 0
                height: root.visualActive && !root.menuOwned ? root.safeRect.height : 0
            }
        }
        Connections {
            target: taskbarWindow.contentItem.Window.window
            function onActiveChanged() {
                if (!taskbarWindow.contentItem.Window.active) lifetime.releaseKeyboardLease()
            }
        }
        HoverHandler {
            id: hover
            onHoveredChanged: {
                if (!hovered) lifetime.pointerExited()
                else lifetime.pointerEntered(point.position.x, point.position.y)
            }
            onPointChanged: lifetime.pointerMoved(point.position.x, point.position.y)
        }
        Rectangle {
            objectName: "taskbar-surface"
            visible: root.visualActive
            y: taskbarWindow.height - root.targetHeight
            width: taskbarWindow.width
            height: root.targetHeight
            color: Theme.surface
            border.width: 0
        }
        Bar.StatusModules {
            id: statusModules
            visible: root.visualActive
            y: taskbarWindow.height - root.targetHeight
            ownerWindow: taskbarWindow
            screenName: root.modelData ? root.modelData.name : ""
            presentation: "fullBottom"
            opacity: BarTransitionState.hostActive ? BarTransitionState.modulesOpacity : 1
        }
        AppBar.AppBarContent {
            id: appContent
            visible: root.visualActive
            anchors.fill: parent
            modelData: root.modelData
            hostWindow: taskbarWindow
            inputLifetime: lifetime
            activationSource: "taskbar"
            active: root.active
            shown: root.active && !root.menuOwned
            suppressTooltips: root.menuOwned
            enabled: !root.menuOwned
            opacity: (root.menuOwned ? 0 : 1) * (BarTransitionState.hostActive ? BarTransitionState.modulesOpacity : 1)
            targetHeight: root.targetHeight
            safeRect: root.safeRect
            viewportLimit: statusModules.centerViewportWidth
            pointerX: hover.hovered ? hover.point.position.x : NaN
            pointerY: hover.hovered ? hover.point.position.y : NaN
        }
    }
}
