import QtQuick
import Quickshell
import Quickshell.Widgets
import "../../services"
import "../settings"
import "DockGeometry.js" as Geometry

Item {
    id: root
    // Slot geometry remains fixed while the visual icon responds to interaction.
    property string label: ""
    property string icon: "application-x-executable"
    property int iconSize: 48
    property int runningCount: 0
    property bool active: false
    property bool appActions: false
    property string actionMessage: ""
    property bool tooltipEnabled: true
    // Pointer clicks retain keyboard access without keeping a hover tooltip alive.
    property bool pointerFocus: false
    property bool tooltipDismissed: false
    onActiveFocusChanged: if (!activeFocus) pointerFocus = false
    readonly property bool hovered: pointer.containsMouse
    // Pointer coordinates are shared across slots to keep the lift wave continuous.
    property real hoverX: NaN
    readonly property real hoverWeight: Geometry.hoverInfluence(hoverX, width / 2, width * 2.5)
    property real iconLift: hoverWeight * ShellSettingsStore.dockHoverLift
    property real iconScale: 1 + hoverWeight * ShellSettingsStore.dockHoverScale / 100
    // Reserve the full configured rise before the pointer reaches enlarged artwork.
    readonly property real hoverHeadroom: ShellSettingsStore.dockHoverLift + iconSize * ShellSettingsStore.dockHoverScale / 100
    // Captured launcher seeds follow the actual lifted artwork inside this fixed slot.
    readonly property rect iconRect: Qt.rect((width - iconSize * iconScale) / 2,
        7 - iconLift - iconSize * (iconScale - 1), iconSize * iconScale, iconSize * iconScale)
    Behavior on iconLift {
        NumberAnimation {
            duration: HAnimation.buttonHoverDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: HAnimation.buttonHoverCurve
        }
    }
    Behavior on iconScale {
        NumberAnimation {
            duration: HAnimation.buttonHoverDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: HAnimation.buttonHoverCurve
        }
    }
    signal activated()
    signal pinRequested()
    signal terminateRequested()
    signal dismissRequested()
    width: iconSize + 16
    // Reserve seven pixels above artwork, a two-pixel gap and four-pixel dots.
    height: iconSize + 13
    activeFocusOnTab: true
    Accessible.role: Accessible.Button
    Accessible.name: label
    Accessible.onPressAction: activated()
    Keys.onReturnPressed: activated()
    Keys.onSpacePressed: activated()
    Keys.onMenuPressed: if (appActions) pinRequested()
    Keys.onDeletePressed: {
        if (appActions && runningCount) {
            pointerFocus = false
            tooltipDismissed = false
            terminateRequested()
        }
    }
    Keys.onEscapePressed: {
        tooltipDismissed = true
        dismissRequested()
    }

    IconImage {
        id: image
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.iconRect.y
        width: root.iconRect.width
        height: width
        source: DockApps.iconSourcesReady
            ? DockApps.iconSources[root.icon] || DockApps.iconSources["application-x-executable"] || ""
            : root.icon.startsWith("/") ? "file://" + root.icon : Quickshell.iconPath(root.icon)
        backer.cache: false
        visible: status !== Image.Error
    }
    // Missing theme assets still expose a recognizable, accessible application action.
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.iconRect.y
        width: root.iconRect.width
        height: width
        visible: image.status === Image.Error || image.source.toString() === ""
        text: root.icon === "user-trash" ? "♲" : root.icon === "view-app-grid" ? "▦" : "◇"
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        color: Theme.accent
        font.pixelSize: root.iconRect.width * 0.8
    }
    DockIndicator {
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.iconSize + 9
        count: root.runningCount
    }
    MouseArea {
        id: pointer
        // A fixed extended hit area lets the pointer follow the raised artwork.
        x: 0
        y: -root.hoverHeadroom
        width: parent.width
        height: parent.height + root.hoverHeadroom
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onEntered: root.tooltipDismissed = false
        onExited: root.tooltipDismissed = false
        onClicked: mouse => {
            root.pointerFocus = true
            root.tooltipDismissed = false
            root.forceActiveFocus(Qt.MouseFocusReason)
            if (mouse.button === Qt.RightButton && root.appActions) root.pinRequested()
            else if (mouse.button === Qt.MiddleButton && root.appActions && root.runningCount) root.terminateRequested()
            else if (mouse.button === Qt.LeftButton) root.activated()
        }
        // Treat rapid repeated clicks as separate activation requests.
        onDoubleClicked: mouse => { mouse.accepted = false }
    }
    SettingsTooltip {
        target: root
        immediate: true
        active: root.visible && root.enabled && root.tooltipEnabled && !root.tooltipDismissed
            && (root.hovered || (root.activeFocus && !root.pointerFocus))
        text: root.actionMessage || root.label
        y: -height - 10 - root.iconLift - root.iconSize * (root.iconScale - 1)
    }
}
