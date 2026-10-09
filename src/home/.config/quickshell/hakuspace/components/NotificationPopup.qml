import QtQuick
import Quickshell
import Quickshell.Wayland
import "../services"
import "flare" as Flare
import "notification"

Item {
    id: root
    required property var modelData

    readonly property int maxVisible: 3
    readonly property real popupWidth: 450
    readonly property real edgeInset: 48
    readonly property real groupPadding: 0
    readonly property real gap: Theme.gap * 2
    readonly property real topOffset: FlareEdges.topOriginY
    readonly property var frameBounds: FlareEdges.getBounds(modelData.width)
    readonly property real popupEnd: frameBounds.end - edgeInset
    readonly property real popupStart: Math.max(frameBounds.start, popupEnd - popupWidth)
    // The Top layer mirrors the tooltip topology: its shallow FlareSurface
    // spans the popup body itself so both top ears are real Flare ears.  The
    // Overlay remains a plain rounded rectangle inset from the screen edge.
    readonly property real flareStart: popupStart
    readonly property real flareEnd: popupEnd
    // Top layer is only the frame-attached flare/bridge. The Overlay owns the
    // full notification body, so never let the Top layer draw a second full
    // height panel behind it.
    readonly property real flareVisualHeight: Math.min(revealHeight, 20 + Theme.tipHugRadius)
    readonly property int fitCount: Math.max(0, Math.min(maxVisible,
        Math.floor((modelData.height - topOffset - Theme.pad) / (Theme.fontSize * 12 + gap))))
    readonly property var livePopups: NotificationStore.popupForScreen(modelData.name).slice(0, fitCount)
    readonly property bool hasLivePopups: NotificationStore._started && livePopups.length > 0

    // The rendered model deliberately survives the final close animation.  A
    // single shared reveal height clips the whole group so first-open, append,
    // and final-close all travel vertically instead of retargeting a horizontal
    // Flare span.
    property var displayPopups: []
    property real revealHeight: 0
    property real revealTarget: 0
    property bool clearingAfterClose: false
    property bool revealUpdateScheduled: false

    function stackTargetHeight() {
        if (!root.hasLivePopups || root.displayPopups.length === 0)
            return 0
        return Math.max(0, popupStack.implicitHeight + root.groupPadding * 2)
    }

    function updateRevealTarget() {
        if (root.revealUpdateScheduled) return
        root.revealUpdateScheduled = true
        Qt.callLater(function() {
            root.revealUpdateScheduled = false
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
            root.revealTarget = 0
            revealAnim.to = 0
            revealAnim.restart()
        }
    }

    function scheduleSync() {
        // Let the store-derived binding settle before copying the concrete
        // array. This also keeps the very first notification deterministic.
        Qt.callLater(function() { root.syncLivePopups() })
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

    // TOP: visual-only Flare shell.  Match TooltipLayer/FlareSurface geometry:
    // the shallow surface spans the popup itself, which gives the popup a real
    // top-left and top-right ear.  The Overlay below stays a plain rounded body
    // and remains inset from the screen edge.
    PanelWindow {
        id: flareLayer
        screen: root.modelData
        anchors { top: true; left: true; right: true }
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "hakuspace-notification-popup-flare"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore
        exclusiveZone: 0
        // Keep the layer-shell surface size stable while the popup animates.
        // Resizing a PanelWindow every animation frame forces repeated Wayland
        // configure cycles and makes the reveal visibly stutter.
        anchors.bottom: true
        color: "transparent"
        visible: root.displayPopups.length > 0 || root.revealHeight > 0
        mask: Region {}

        Flare.FlareSurface {
            y: root.topOffset
            start: root.flareStart
            end: root.flareEnd
            currentHeight: root.flareVisualHeight
            bounds: root.frameBounds
            r: 20
            rf: Theme.tipHugRadius
            bottomRadius: 0
            surfaceColor: Theme.surface
        }
    }

    // OVERLAY: one rounded background wraps the complete notification group.
    // The notification group is inset 48px from the right edge. The Top-layer
    // Flare lives only in the Top layer; the Overlay itself remains a clean
    // rounded body with no Flare geometry.
    PanelWindow {
        id: contentLayer
        screen: root.modelData
        anchors { top: true; right: true }
        margins.right: Math.max(0, root.modelData.width - root.frameBounds.end + root.edgeInset)
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "hakuspace-notification-popup-content"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore
        exclusiveZone: 0
        implicitWidth: Math.max(0, Math.min(root.popupWidth,
            root.modelData.width - root.edgeInset - root.frameBounds.start))
        // Same rule as the visual Top layer: the Wayland surface stays at a
        // stable height; only the inner clipped background animates.
        anchors.bottom: true
        color: "transparent"
        visible: root.displayPopups.length > 0 || root.revealHeight > 0
        mask: Region { item: groupBackground }

        Rectangle {
            id: groupBackground
            x: 0
            y: root.topOffset
            width: contentLayer.width
            height: root.revealHeight
            radius: 20
            color: Theme.surface
            clip: true
            visible: height > 0

            Column {
                id: popupStack
                x: root.groupPadding
                y: root.groupPadding
                width: Math.max(0, parent.width - root.groupPadding * 2)
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
                        cardPadding: 12
                        showBorder: false
                        color: "transparent"
                    }
                }
            }
        }
    }
}
