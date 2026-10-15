import QtQuick
import "../../services"

Rectangle {
    id: root

    // Generic absolute-target mode.
    property real targetX: 0
    property real targetY: 0
    property real targetWidth: 0
    property real targetHeight: 0
    property real targetRadius: Theme.radius
    property color targetColor: Theme.accent
    property bool absoluteInitialized: false
    readonly property bool absoluteTargetValid: !indexedMode && targetWidth > 0 && targetHeight > 0

    // Internal coordinates for asymmetric leading/trailing edge morph
    property real currentStartX: 0
    property real currentEndX: 0
    property real currentStartY: 0
    property real currentEndY: 0
    property real currentRadius: Theme.radius
    property color currentColor: Theme.accent

    // Optional indexed-lane mode. This is preferred for tab strips whose own
    // width is morphing: only the logical index animates, while the pill
    // geometry follows the lane continuously without restarting x/width
    // animations every frame.
    property int targetIndex: -1
    property int slotCount: 0
    property real slotSpacing: 0
    readonly property bool indexedMode: slotCount > 0 && targetIndex >= 0

    // The first valid indexed target must snap into place. Otherwise reopening
    // HakuMenu can animate from the index used before close (for example Theme
    // -> General), which makes the initially selected General pill appear
    // displaced while the menu is opening.
    property bool indexInitialized: false
    property real animatedStartIndex: 0
    property real animatedEndIndex: 0
    readonly property real animatedIndex: animatedStartIndex

    // Optional Item-target mode. Automatically maps geometry from a target Item.
    property Item targetItem: null
    property Item coordinateSpace: null
    property color normalColor: Theme.accent
    property color dangerColor: "#e05555"

    // Maps geometry from target Item into container coordinates and updates target bounds.
    function syncTarget(forceSnap) {
        if (!targetItem) return;
        if (targetItem.width <= 0 || targetItem.height <= 0) return;

        var container = coordinateSpace || parent;
        if (!container) return;

        var pt = container.mapFromItem(targetItem, 0, 0);
        var tw = targetItem.width;
        var th = targetItem.height;
        var tr = (targetItem.radius !== undefined && targetItem.radius > 0) ? targetItem.radius : Theme.radius;
        var isDanger = targetItem.danger === true;
        var tc = isDanger ? dangerColor : normalColor;

        targetX = pt.x;
        targetY = pt.y;
        targetWidth = tw;
        targetHeight = th;
        targetRadius = tr;
        targetColor = tc;

        if (!absoluteInitialized || forceSnap) {
            snap();
        }
    }

    // Assigns target item and immediately snaps selection pill geometry to it.
    function snapToItem(item) {
        targetItem = item;
        syncTarget(true);
    }

    onTargetItemChanged: {
        if (targetItem) {
            syncTarget(!absoluteInitialized);
        }
    }

    Connections {
        target: root.targetItem
        ignoreUnknownSignals: true
        function onXChanged() { root.syncTarget(false); }
        function onYChanged() { root.syncTarget(false); }
        function onWidthChanged() { root.syncTarget(false); }
        function onHeightChanged() { root.syncTarget(false); }
        function onDangerChanged() { root.syncTarget(false); }
    }

    property int duration: HAnimation.spatial
    property var curve: HAnimation.spatialCurve
    property real trailFactor: HAnimation.trailFactor
    property bool shown: indexedMode ? true : (targetItem !== null && (targetItem.visible !== undefined ? targetItem.visible : true))

    readonly property real laneSlotWidth: indexedMode
        ? Math.max(0, (parent.width - slotSpacing * Math.max(0, slotCount - 1)) / slotCount)
        : 0
    readonly property real laneSlotPitch: laneSlotWidth + slotSpacing
    readonly property real indexedStartX: animatedStartIndex * laneSlotPitch
    readonly property real indexedEndX: animatedEndIndex * laneSlotPitch - (slotCount > 0 ? slotSpacing : 0)
    readonly property real indexedWidth: Math.max(0, indexedEndX - indexedStartX)

    x: indexedMode ? indexedStartX : currentStartX
    y: indexedMode ? 0 : currentStartY
    width: indexedMode ? indexedWidth : Math.max(0, currentEndX - currentStartX)
    height: indexedMode ? parent.height : Math.max(0, currentEndY - currentStartY)
    radius: indexedMode ? Theme.radius : currentRadius
    color: indexedMode ? Theme.accent : currentColor
    opacity: shown ? 1 : 0

    // Immediately snaps pill coordinates and styling to target bounds without animation.
    function snap() {
        if (indexedMode) {
            startIndexAnim.stop();
            endIndexAnim.stop();
            if (targetIndex >= 0 && slotCount > 0) {
                animatedStartIndex = targetIndex;
                animatedEndIndex = targetIndex + 1;
                indexInitialized = true;
            }
            return;
        }
        startXAnim.stop();
        endXAnim.stop();
        startYAnim.stop();
        endYAnim.stop();
        radiusAnim.stop();
        colorAnim.stop();

        currentStartX = targetX;
        currentEndX = targetX + targetWidth;
        currentStartY = targetY;
        currentEndY = targetY + targetHeight;
        currentRadius = targetRadius;
        currentColor = targetColor;

        if (absoluteTargetValid) {
            absoluteInitialized = true;
        }
    }

    // Calculates directional lead/trail timing and restarts asymmetric morph animations for absolute mode.
    function retargetAbsolute() {
        if (indexedMode) return;
        if (!absoluteTargetValid) return;

        if (!absoluteInitialized) {
            snap();
            return;
        }

        var targetStartX = targetX;
        var targetEndX = targetX + targetWidth;
        var targetStartY = targetY;
        var targetEndY = targetY + targetHeight;

        // Horizontal retargeting with asymmetric leading/trailing edge
        var deltaStartX = targetStartX - currentStartX;
        var deltaEndX = targetEndX - currentEndX;
        if (Math.abs(deltaStartX) > 0.5 || Math.abs(deltaEndX) > 0.5) {
            var goingLeft = targetStartX < currentStartX;
            var leadX = root.duration;
            var trailX = Math.round(root.duration * root.trailFactor);
            startXAnim.duration = goingLeft ? leadX : trailX;
            endXAnim.duration = goingLeft ? trailX : leadX;
            startXAnim.to = targetStartX;
            endXAnim.to = targetEndX;
            startXAnim.restart();
            endXAnim.restart();
        } else {
            startXAnim.stop();
            endXAnim.stop();
            currentStartX = targetStartX;
            currentEndX = targetEndX;
        }

        // Vertical retargeting with asymmetric leading/trailing edge
        var deltaStartY = targetStartY - currentStartY;
        var deltaEndY = targetEndY - currentEndY;
        if (Math.abs(deltaStartY) > 0.5 || Math.abs(deltaEndY) > 0.5) {
            var goingUp = targetStartY < currentStartY;
            var leadY = root.duration;
            var trailY = Math.round(root.duration * root.trailFactor);
            startYAnim.duration = goingUp ? leadY : trailY;
            endYAnim.duration = goingUp ? trailY : leadY;
            startYAnim.to = targetStartY;
            endYAnim.to = targetEndY;
            startYAnim.restart();
            endYAnim.restart();
        } else {
            startYAnim.stop();
            endYAnim.stop();
            currentStartY = targetStartY;
            currentEndY = targetEndY;
        }

        // Radius morph
        if (Math.abs(currentRadius - targetRadius) > 0.5) {
            radiusAnim.to = targetRadius;
            radiusAnim.restart();
        } else {
            radiusAnim.stop();
            currentRadius = targetRadius;
        }

        // Color morph
        if (currentColor != targetColor) {
            colorAnim.to = targetColor;
            colorAnim.restart();
        }
    }

    onTargetXChanged: { if (!indexedMode) Qt.callLater(root.retargetAbsolute); }
    onTargetYChanged: { if (!indexedMode) Qt.callLater(root.retargetAbsolute); }
    onTargetWidthChanged: { if (!indexedMode) Qt.callLater(root.retargetAbsolute); }
    onTargetHeightChanged: { if (!indexedMode) Qt.callLater(root.retargetAbsolute); }
    onTargetRadiusChanged: { if (!indexedMode) Qt.callLater(root.retargetAbsolute); }
    onTargetColorChanged: { if (!indexedMode) Qt.callLater(root.retargetAbsolute); }

    // Computes directional lead/trail times and triggers indexed tab lane slide animations.
    function syncIndexedTarget() {
        if (targetIndex < 0 || slotCount <= 0 || !shown) {
            startIndexAnim.stop();
            endIndexAnim.stop();
            indexInitialized = false;
            animatedStartIndex = 0;
            animatedEndIndex = 0;
            return;
        }

        var targetStart = targetIndex;
        var targetEnd = targetIndex + 1;

        if (!indexInitialized) {
            startIndexAnim.stop();
            endIndexAnim.stop();
            animatedStartIndex = targetStart;
            animatedEndIndex = targetEnd;
            indexInitialized = true;
            return;
        }

        if (Math.abs(animatedStartIndex - targetStart) < 0.0001 &&
            Math.abs(animatedEndIndex - targetEnd) < 0.0001)
            return;

        var goingLeft = targetStart < animatedStartIndex;
        var lead = root.duration;
        var trail = Math.round(root.duration * root.trailFactor);

        startIndexAnim.duration = goingLeft ? lead : trail;
        endIndexAnim.duration = goingLeft ? trail : lead;
        startIndexAnim.to = targetStart;
        endIndexAnim.to = targetEnd;
        startIndexAnim.restart();
        endIndexAnim.restart();
    }

    onTargetIndexChanged: syncIndexedTarget()
    onSlotCountChanged: syncIndexedTarget()
    onShownChanged: {
        syncIndexedTarget();
        if (!shown) {
            absoluteInitialized = false;
        }
    }

    // Animates indexed leading edge position across lane slots.
    NumberAnimation {
        id: startIndexAnim
        target: root
        property: "animatedStartIndex"
        easing.type: Easing.BezierSpline
        easing.bezierCurve: root.curve
    }

    // Animates indexed trailing edge position across lane slots.
    NumberAnimation {
        id: endIndexAnim
        target: root
        property: "animatedEndIndex"
        easing.type: Easing.BezierSpline
        easing.bezierCurve: root.curve
    }

    // Animates pill fade in and out when shown state toggles.
    Behavior on opacity {
        NumberAnimation {
            duration: HAnimation.buttonReleaseDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: HAnimation.buttonReleaseCurve
        }
    }

    // Asymmetric leading/trailing edge morph animations for absolute mode
    // Animates leading horizontal edge with directional timing.
    NumberAnimation {
        id: startXAnim
        target: root
        property: "currentStartX"
        easing.type: Easing.BezierSpline
        easing.bezierCurve: root.curve
    }

    // Animates trailing horizontal edge with directional timing.
    NumberAnimation {
        id: endXAnim
        target: root
        property: "currentEndX"
        easing.type: Easing.BezierSpline
        easing.bezierCurve: root.curve
    }

    // Animates leading vertical edge with directional timing.
    NumberAnimation {
        id: startYAnim
        target: root
        property: "currentStartY"
        easing.type: Easing.BezierSpline
        easing.bezierCurve: root.curve
    }

    // Animates trailing vertical edge with directional timing.
    NumberAnimation {
        id: endYAnim
        target: root
        property: "currentEndY"
        easing.type: Easing.BezierSpline
        easing.bezierCurve: root.curve
    }

    // Animates corner radius morph to target shape.
    NumberAnimation {
        id: radiusAnim
        target: root
        property: "currentRadius"
        duration: root.duration
        easing.type: Easing.BezierSpline
        easing.bezierCurve: root.curve
    }

    // Animates background fill color transition to target color.
    ColorAnimation {
        id: colorAnim
        target: root
        property: "currentColor"
        duration: root.duration
        easing.type: Easing.BezierSpline
        easing.bezierCurve: root.curve
    }
}
