import QtQuick
import "../../services"

Rectangle {
    id: root

    // Generic absolute-target mode.
    property real targetX: 0
    property real targetY: 0
    property real targetWidth: 0
    property real targetHeight: 0

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
    property real animatedIndex: 0

    property int duration: HAnimation.buttonSelectDuration
    property var curve: HAnimation.buttonSelectCurve
    property bool shown: true

    readonly property real laneSlotWidth: indexedMode
        ? Math.max(0, (parent.width - slotSpacing * Math.max(0, slotCount - 1)) / slotCount)
        : 0

    x: indexedMode ? animatedIndex * (laneSlotWidth + slotSpacing) : targetX
    y: indexedMode ? 0 : targetY
    width: indexedMode ? laneSlotWidth : targetWidth
    height: indexedMode ? parent.height : targetHeight
    radius: Theme.radiusSm
    color: Theme.accent
    opacity: shown ? 1 : 0

    function syncIndexedTarget() {
        if (targetIndex < 0 || slotCount <= 0 || !shown) {
            indexAnimation.stop()
            indexInitialized = false
            animatedIndex = 0
            return
        }

        if (!indexInitialized) {
            indexAnimation.stop()
            animatedIndex = targetIndex
            indexInitialized = true
            return
        }

        if (Math.abs(animatedIndex - targetIndex) < 0.0001)
            return

        indexAnimation.stop()
        indexAnimation.from = animatedIndex
        indexAnimation.to = targetIndex
        indexAnimation.restart()
    }

    onTargetIndexChanged: syncIndexedTarget()
    onSlotCountChanged: syncIndexedTarget()
    onShownChanged: syncIndexedTarget()

    NumberAnimation {
        id: indexAnimation
        target: root
        property: "animatedIndex"
        duration: root.duration
        easing.type: Easing.BezierSpline
        easing.bezierCurve: root.curve
    }

    Behavior on opacity {
        NumberAnimation {
            duration: HAnimation.buttonReleaseDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: HAnimation.buttonReleaseCurve
        }
    }

    // Absolute-target mode keeps the old behavior for other consumers.
    Behavior on x {
        enabled: !root.indexedMode
        NumberAnimation {
            duration: root.duration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: root.curve
        }
    }
    Behavior on y {
        enabled: !root.indexedMode
        NumberAnimation {
            duration: root.duration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: root.curve
        }
    }
    Behavior on width {
        enabled: !root.indexedMode
        NumberAnimation {
            duration: root.duration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: root.curve
        }
    }
    Behavior on height {
        enabled: !root.indexedMode
        NumberAnimation {
            duration: root.duration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: root.curve
        }
    }
}
