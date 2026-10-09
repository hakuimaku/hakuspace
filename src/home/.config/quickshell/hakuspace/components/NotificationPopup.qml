import QtQuick
import Quickshell
import Quickshell.Wayland
import "../services"
import "notification"

PanelWindow {
    id: root
    required property var modelData
    readonly property int maxVisible: 3
    readonly property real popupWidth: 350
    readonly property real gap: Theme.gap * 2
    readonly property real topOffset: FlareEdges.topOriginY
    readonly property int fitCount: Math.max(0, Math.min(maxVisible,
        Math.floor((modelData.height - topOffset - Theme.pad) / (Theme.fontSize * 12 + gap))))
    readonly property var popups: NotificationStore.popupForScreen(modelData.name).slice(0, fitCount)

    screen: modelData
    anchors { top: true; right: true }
    margins.top: topOffset
    margins.right: Theme.pad
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "hakuspace-notification-popup"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0
    color: "transparent"
    implicitWidth: Math.max(0, Math.min(popupWidth, modelData.width - Theme.pad * 2))
    implicitHeight: stack.implicitHeight
    visible: NotificationStore._started && popups.length > 0
    mask: Region { item: stack }

    ScriptModel {
        id: popupModel
        values: root.popups
        objectProp: "key"
        comparisonMode: ObjectComparison.Structure
    }

    Column {
        id: stack
        width: root.width
        spacing: root.gap

        // ponytail: close removes a delegate immediately; add a visual-only exit lifecycle if needed.
        Repeater {
            model: popupModel
            NotificationCard {
                required property var modelData
                record: modelData
                compact: true
                width: stack.width
                NumberAnimation on opacity { from: 0; to: 1; duration: HAnimation.fast }
            }
        }
    }
}
