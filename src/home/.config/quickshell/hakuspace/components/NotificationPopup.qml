import QtQuick
import Quickshell
import Quickshell.Wayland
import "../services"
import "flare" as Flare
import "flare/FlareGeometry.js" as FlareGeometry
import "notification"

Item {
    id: root
    // Release only after the surface has finished its visual close.
    readonly property bool releaseReady: !hasLivePopups && displayPopups.length === 0 && !revealAnim.running && !leftSpanAnim.running
    required property var modelData

    readonly property int maxVisible: 3
    readonly property real popupWidth: 450
    readonly property real gap: Theme.spaceSm
    readonly property bool attachedMode: ShellSettingsStore.notificationPopupPosition === "anchor"
    readonly property bool leftAttached: attachedMode && ChromeLayout.leftBarMode
    readonly property bool bottomAttached: attachedMode && !leftAttached && ScreenGeometry.bottomAttached
    readonly property int attachMode: leftAttached ? Flare.FlareHost.Left : bottomAttached ? Flare.FlareHost.Bottom : Flare.FlareHost.Top
    readonly property real topOffset: ChromeLayout.topBarMode ? Theme.topBarHeight : ScreenGeometry.topBorderThickness
    readonly property real attachmentY: attachedMode ? (leftAttached ? 0 : ScreenGeometry.chromeAttachmentY(modelData.height)) : topOffset
    readonly property var frameBounds: ScreenGeometry.horizontalBounds(modelData.width)
    readonly property var spanBounds: leftAttached
        ? ({ start: ScreenGeometry.topBorderThickness,
             end: Math.max(ScreenGeometry.topBorderThickness, modelData.height - ScreenGeometry.bottomReservation(modelData.name)) })
        : frameBounds
    readonly property real bodyWidth: leftAttached
        ? Math.max(0, Math.min(popupWidth, modelData.width - ScreenGeometry.contentLeftEdge - ScreenGeometry.rightInset - Theme.pad))
        : Math.max(0, Math.min(popupWidth, frameBounds.end - frameBounds.start))
    readonly property var bellItem: NotificationStore.bellItemForScreen(modelData ? modelData.name : "", ChromeLayout.statusEdge)
    readonly property var anchorRect: {
        var item = bellItem
        var parent = item && item.parent ? item.parent.parent : null
        var _ = (item ? item.width + item.height : 0) + (parent ? parent.x + parent.y : 0)
        return NotificationStore.anchorRectForScreen(modelData)
    }
    readonly property var resolvedSpan: {
        if (!attachedMode) {
            var centeredStart = (modelData.width - bodyWidth) / 2
            return { start: centeredStart, end: centeredStart + bodyWidth }
        }
        return FlareGeometry.resolveSpan({
            anchorStart: leftAttached ? anchorRect.y : anchorRect.x,
            anchorEnd: leftAttached ? anchorRect.y + anchorRect.height : anchorRect.x + anchorRect.width,
            contentW: leftAttached ? leftSpanHeight : bodyWidth,
            padX: 0,
            minW: 80,
            maxW: leftAttached ? Math.max(0, spanBounds.end - spanBounds.start) : bodyWidth,
            bounds: spanBounds,
            snap: 2 * Theme.hugRadius
        })
    }
    readonly property real popupStart: resolvedSpan.start
    readonly property real popupEnd: resolvedSpan.end
    readonly property int fitCount: Math.max(0, Math.min(maxVisible,
        Math.floor((modelData.height - topOffset - ScreenGeometry.taskbarReservation() - ScreenGeometry.bottomInset - Theme.pad) / (Theme.fontSize * 12 + gap))))
    readonly property var livePopups: NotificationStore.popupForScreen(modelData.name).slice(0, fitCount)
    readonly property bool hasLivePopups: NotificationStore._started && livePopups.length > 0

    // The rendered model deliberately survives the final close animation.  A
    // single shared reveal height clips the whole group so first-open, append,
    // and final-close all travel vertically instead of retargeting a horizontal
    // Flare span.
    property var displayPopups: []
    property real revealHeight: 0
    property real revealTarget: 0
    property real leftSpanHeight: 0
    property real leftSpanTarget: 0
    property bool clearingAfterClose: false
    property bool revealUpdateScheduled: false

    function stackTargetHeight() {
        if (!root.hasLivePopups || root.displayPopups.length === 0)
            return 0
        var stackH = Math.max(0, popupStack.implicitHeight)
        if (stackH <= 0)
            return 0
        return root.leftAttached ? root.bodyWidth : stackH
    }

    function updateRevealTarget() {
        if (root.revealUpdateScheduled) return
        root.revealUpdateScheduled = true
        Qt.callLater(function() {
            if (!root) return
            root.revealUpdateScheduled = false
            if (root.leftAttached && root.hasLivePopups && root.displayPopups.length > 0) {
                var nextSpan = Math.max(0, popupStack.implicitHeight)
                root.leftSpanTarget = nextSpan
                if (root.revealHeight <= 0.5 && !leftSpanAnim.running || Math.abs(nextSpan - root.leftSpanHeight) < 0.5) {
                    leftSpanAnim.stop()
                    root.leftSpanHeight = nextSpan
                } else if (Math.abs(leftSpanAnim.to - nextSpan) >= 0.5 || !leftSpanAnim.running) {
                    leftSpanAnim.to = nextSpan
                    leftSpanAnim.restart()
                }
            }
            var nextTarget = root.stackTargetHeight()
            if (Math.abs(nextTarget - root.revealTarget) < 0.5 && revealAnim.running)
                return
            root.revealTarget = nextTarget
            if (Math.abs(root.revealTarget - root.revealHeight) < 0.5) {
                root.revealHeight = root.revealTarget
                return
            }
            revealAnim.to = root.revealTarget
            revealAnim.restart()
        })
    }

    function syncLivePopups() {
        if (root.hasLivePopups) {
            root.clearingAfterClose = false
            root.displayPopups = root.livePopups.slice(0)
            root.updateRevealTarget()
        } else if (root.displayPopups.length > 0) {
            root.clearingAfterClose = true
            leftSpanAnim.stop()
            root.revealTarget = 0
            revealAnim.to = 0
            revealAnim.restart()
        }
    }

    function scheduleSync() {
        // Let the store-derived binding settle before copying the concrete
        // array. This also keeps the very first notification deterministic.
        Qt.callLater(function() { if (root) root.syncLivePopups() })
    }

    onLeftAttachedChanged: {
        leftSpanAnim.stop()
        if (hasLivePopups && displayPopups.length > 0) {
            var stackH = Math.max(0, popupStack.implicitHeight)
            leftSpanHeight = leftAttached ? stackH : 0
            leftSpanTarget = leftSpanHeight
            revealHeight = leftAttached ? bodyWidth : stackH
            revealTarget = revealHeight
        } else {
            leftSpanHeight = 0
            leftSpanTarget = 0
        }
    }
    onLivePopupsChanged: scheduleSync()
    Component.onCompleted: scheduleSync()

    Connections {
        target: NotificationStore
        function onRecordsChanged() { root.scheduleSync() }
        function onDndChanged() { root.scheduleSync() }
    }

    Connections {
        target: UiState
        function onActivePanelChanged() { root.scheduleSync() }
    }

    NumberAnimation {
        id: leftSpanAnim
        target: root
        property: "leftSpanHeight"
        duration: HAnimation.normal
        easing.bezierCurve: HAnimation.spatialCurve
    }

    NumberAnimation {
        id: revealAnim
        target: root
        property: "revealHeight"
        duration: HAnimation.normal
        easing.bezierCurve: root.revealTarget > root.revealHeight
            ? HAnimation.shellCurve
            : HAnimation.moduleCurve
        onFinished: {
            if (root.clearingAfterClose && root.revealHeight <= 0.5 && !root.hasLivePopups) {
                root.revealHeight = 0
                root.leftSpanHeight = 0
                root.leftSpanTarget = 0
                root.displayPopups = []
                root.clearingAfterClose = false
            }
        }
    }

    // Preserve existing delegates when another notification is appended or
    // removed. Replacing the raw JS array directly on a Repeater recreates the
    // whole visible stack and causes an extra hitch during the height reveal.
    ScriptModel {
        id: popupModel
        values: root.displayPopups
        objectProp: "key"
        comparisonMode: ObjectComparison.Structure
    }

    // The Overlay owns the rounded group, input and notification actions.
    PanelWindow {
        id: contentLayer
        screen: root.modelData
        anchors {
            top: true
            bottom: true
            left: root.attachedMode
            right: root.attachedMode
        }
        WlrLayershell.layer: ShellTransitionState.chromeOverlayLayer
        WlrLayershell.namespace: "hakuspace-notification-popup-content"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore
        exclusiveZone: 0
        implicitWidth: root.attachedMode ? root.modelData.width : root.bodyWidth
        // Same rule as the visual Top layer: the Wayland surface stays at a
        // stable height; only the inner clipped background animates.
        color: "transparent"
        visible: root.displayPopups.length > 0 || root.revealHeight > 0
        mask: Region { item: groupBackground }

        Rectangle {
            id: groupBackground
            x: root.attachedMode ? (root.leftAttached ? ScreenGeometry.contentLeftEdge : root.popupStart) : 0
            y: root.leftAttached ? root.popupStart : root.bottomAttached ? root.attachmentY - height : root.attachmentY
            width: root.leftAttached ? root.revealHeight : Math.max(0, root.popupEnd - root.popupStart)
            height: root.leftAttached ? Math.max(0, root.popupEnd - root.popupStart) : root.revealHeight
            radius: (Theme.largeRadius + 4)
            color: Theme.surface
            clip: true
            visible: width > 0 && height > 0

            Column {
                id: popupStack
                width: root.bodyWidth
                spacing: root.gap

                onImplicitHeightChanged: {
                    if (root.hasLivePopups)
                        root.updateRevealTarget()
                }

                Repeater {
                    id: popupRepeater
                    model: popupModel
                    onItemAdded: function(index, item) {
                        root.updateRevealTarget()
                    }
                    onItemRemoved: function(index, item) {
                        root.updateRevealTarget()
                    }

                    NotificationCard {
                        required property var modelData
                        record: modelData
                        compact: true
                        width: popupStack.width
                        cardRadius: 0
                        cardPadding: Theme.cardPadding + Theme.spaceXs
                        showBorder: false
                        color: "transparent"
                    }
                }
            }
        }
    }
}
