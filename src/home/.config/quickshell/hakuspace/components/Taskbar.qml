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
    readonly property real targetHeight: ScreenGeometry.taskbarHeight
    readonly property var safeRect: Safe.rect((taskbarWindow.width - appContent.viewportWidth) / 2 - Theme.hugRadius,
        taskbarWindow.height - targetHeight - appContent.headroom, appContent.viewportWidth + Theme.hugRadius * 2,
        targetHeight + appContent.headroom)

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
        active: root.active
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
        visible: root.active
        color: "transparent"
        mask: Region {
            y: taskbarWindow.height - root.targetHeight
            width: root.active ? taskbarWindow.width : 0
            height: root.active ? root.targetHeight : 0
            Region {
                x: root.safeRect.x; y: root.safeRect.y
                width: root.active ? root.safeRect.width : 0
                height: root.active ? root.safeRect.height : 0
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
            y: taskbarWindow.height - root.targetHeight
            width: taskbarWindow.width
            height: root.targetHeight
            color: Theme.surface
            border.width: 0
        }
        Bar.StatusModules {
            id: statusModules
            y: taskbarWindow.height - root.targetHeight
            ownerWindow: taskbarWindow
            screenName: root.modelData ? root.modelData.name : ""
            presentation: "fullBottom"
        }
        AppBar.AppBarContent {
            id: appContent
            anchors.fill: parent
            modelData: root.modelData
            hostWindow: taskbarWindow
            inputLifetime: lifetime
            activationSource: "taskbar"
            active: root.active
            shown: root.active
            targetHeight: root.targetHeight
            safeRect: root.safeRect
            viewportLimit: statusModules.centerViewportWidth
            pointerX: hover.hovered ? hover.point.position.x : NaN
            pointerY: hover.hovered ? hover.point.position.y : NaN
        }
    }
}
