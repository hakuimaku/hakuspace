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
    // The Dock owns reorder state so Escape and external pin changes can cancel it.
    property bool reorderable: false
    property bool reordering: false
    property real reorderOffset: 0
    transform: Translate { x: root.reorderOffset }
    onReorderingChanged: if (reordering) {
        tooltipDismissed = true
        forceActiveFocus(Qt.MouseFocusReason)
    }
    // Window focus restoration does not count as keyboard navigation.
    property bool keyboardMode: false
    property bool tooltipDismissed: false
    readonly property bool hovered: pointer.containsMouse
    // Pointer coordinates are shared across slots to keep the lift wave continuous.
    property real hoverX: NaN
    readonly property real hoverWeight: reordering ? 1 : Geometry.hoverInfluence(hoverX, width / 2, width * 2.5)
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
    signal inputModeRequested(bool keyboard)
    signal reorderStarted(real x, real y)
    signal reorderMoved(real x, real y)
    signal reorderFinished(real x, real y)
    signal reorderCanceled()
    width: iconSize + 16
    // Reserve seven pixels above artwork, a two-pixel gap and four-pixel dots.
    height: iconSize + 13
    activeFocusOnTab: true
    Accessible.role: Accessible.Button
    Accessible.name: label
    Accessible.onPressAction: if (!reordering) activated()
    Keys.onPressed: event => { inputModeRequested(true); event.accepted = false }
    Keys.onReturnPressed: if (!reordering) { inputModeRequested(true); activated() }
    Keys.onSpacePressed: if (!reordering) { inputModeRequested(true); activated() }
    Keys.onMenuPressed: if (appActions && !reordering) { inputModeRequested(true); pinRequested() }
    Keys.onDeletePressed: {
        if (appActions && runningCount && !reordering) {
            inputModeRequested(true)
            tooltipDismissed = false
            terminateRequested()
        }
    }
    Keys.onEscapePressed: {
        if (reordering) reorderCanceled()
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
        property bool held: false
        property point pressPoint: Qt.point(0, 0)
        pressAndHoldInterval: 250
        // Reserve pin gestures before the Flickable can claim the initial movement.
        preventStealing: root.reorderable || root.reordering
        cursorShape: root.reordering ? Qt.ClosedHandCursor : Qt.ArrowCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onPressed: mouse => {
            if (root.reordering) return
            root.inputModeRequested(false)
            held = false
            pressPoint = Qt.point(mouse.x, mouse.y)
        }
        // Preserve the original grab point when motion starts before the hold timeout.
        function startReorder() {
            held = true
            var point = mapToItem(root, pressPoint.x, pressPoint.y)
            root.reorderStarted(point.x, point.y)
        }
        onPressAndHold: mouse => {
            if (held || !root.reorderable || mouse.button !== Qt.LeftButton) { mouse.accepted = false; return }
            startReorder()
        }
        onPositionChanged: mouse => {
            if (!held && root.reorderable && (pressedButtons & Qt.LeftButton)
                && Math.hypot(mouse.x - pressPoint.x, mouse.y - pressPoint.y) >= drag.threshold)
                startReorder()
            if (!root.reordering) return
            var point = mapToItem(root, mouse.x, mouse.y)
            root.reorderMoved(point.x, point.y)
        }
        onReleased: mouse => {
            if (!root.reordering || mouse.button !== Qt.LeftButton) return
            var point = mapToItem(root, mouse.x, mouse.y)
            root.reorderFinished(point.x, point.y)
        }
        onCanceled: if (root.reordering) root.reorderCanceled()
        onEntered: root.tooltipDismissed = false
        onExited: root.tooltipDismissed = false
        onClicked: mouse => {
            if (held || root.reordering) return
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
            && (root.keyboardMode ? root.activeFocus && root.Window.active
                : root.hovered && root.hoverX >= 0 && root.hoverX < root.width)
        text: root.actionMessage || root.label
        y: -height - 10 - root.iconLift - root.iconSize * (root.iconScale - 1)
    }
}
