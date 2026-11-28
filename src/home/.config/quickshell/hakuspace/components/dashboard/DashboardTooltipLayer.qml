import QtQuick
import Quickshell
import "../../services"

Item {
    id: root

    anchors.fill: parent
    enabled: false
    visible: bubble.opacity > 0.001
    z: 100

    readonly property bool reducedMotion: Quickshell.env("HAKUSPACE_REDUCED_MOTION") === "1"
    property bool bubbleShown: false
    property real bubbleX: 0
    property real bubbleY: 0
    property bool flippedAbove: false
    property string displayText: ""

    Timer {
        id: delayTimer
        interval: 380
        repeat: false
        onTriggered: {
            if (DashboardTooltip.active && DashboardTooltip.currentTarget && root.parent && root.parent.isFullyOpen) {
                root.displayText = DashboardTooltip.currentText
                root.positionBubble()
                root.bubbleShown = true
            } else {
                root.bubbleShown = false
            }
        }
    }

    Connections {
        target: DashboardTooltip
        function onActiveChanged() {
            if (DashboardTooltip.active) {
                delayTimer.restart()
            } else {
                delayTimer.stop()
                root.bubbleShown = false
            }
        }
        function onCurrentTextChanged() {
            if (DashboardTooltip.active && root.bubbleShown) {
                root.displayText = DashboardTooltip.currentText
                root.positionBubble()
            }
        }
        function onPlacementChanged() {
            if (DashboardTooltip.active && root.bubbleShown) {
                root.positionBubble()
            }
        }
    }

    Connections {
        target: root.parent
        function onMorphProgressChanged() {
            if (root.parent.morphProgress < 0.95) {
                DashboardTooltip.dismiss()
                delayTimer.stop()
                root.bubbleShown = false
            }
        }
    }

    // Computes clamped x/y coordinates to position tooltip bubble relative to target item.
    function positionBubble() {
        var target = DashboardTooltip.currentTarget
        if (!target) return
        try {
            var pt = target.mapToItem(root, 0, 0)
            var targetWidth = target.width || 0
            var targetHeight = target.height || 0
            var pad = 12
            var minX = pad
            var maxX = (root.parent && root.parent.currentBodyWidth > 0)
                ? Math.min(root.width, root.parent.currentBodyWidth) - pad
                : root.width - pad
            var originY = (root.parent && root.parent.contentOriginY !== undefined)
                ? Math.max(0, root.parent.contentOriginY) : 0
            var minY = originY + pad
            var maxY = (root.parent && root.parent.currentBodyHeight > 0)
                ? Math.min(root.height, originY + root.parent.currentBodyHeight) - pad
                : root.height - pad

            var tx
            var ty
            root.flippedAbove = false
            if (DashboardTooltip.placement === "right") {
                tx = pt.x + targetWidth + 10
                if (tx + bubble.width > maxX) {
                    var flippedLeft = pt.x - bubble.width - 10
                    if (flippedLeft >= minX) tx = flippedLeft
                }
                tx = Math.max(minX, Math.min(tx, Math.max(minX, maxX - bubble.width)))
                ty = pt.y + (targetHeight - bubble.height) / 2
                ty = Math.max(minY, Math.min(ty, Math.max(minY, maxY - bubble.height)))
            } else {
                // Prefer placing below the target; flip above if near bottom edge
                tx = pt.x + (targetWidth - bubble.width) / 2
                ty = pt.y + targetHeight + 6
                tx = Math.max(minX, Math.min(tx, Math.max(minX, maxX - bubble.width)))
                if (ty + bubble.height > maxY) {
                    root.flippedAbove = true
                    ty = Math.max(minY, pt.y - bubble.height - 6)
                }
                ty = Math.max(minY, Math.min(ty, Math.max(minY, maxY - bubble.height)))
            }

            root.bubbleX = Math.round(tx)
            root.bubbleY = Math.round(ty)
        } catch (e) {
            root.bubbleShown = false
        }
    }

    // Floating tooltip bubble visual container.
    Rectangle {
        id: bubble
        x: root.bubbleX
        y: root.bubbleY
        width: Math.min(260, Math.max(56, label.implicitWidth + 18))
        height: Math.max(24, label.implicitHeight + 10)
        radius: Theme.radius
        color: Qt.darker(Theme.surface, 1.15)
        border.width: 1
        border.color: Theme.surfaceHighlight(1.35)
        opacity: root.bubbleShown ? 1.0 : 0.0
        scale: (root.bubbleShown || root.reducedMotion) ? 1.0 : 0.92
        transformOrigin: Item.Center

        transform: Translate {
            x: (root.bubbleShown || root.reducedMotion) ? 0
                : (DashboardTooltip.placement === "right" ? -4 : 0)
            y: (root.bubbleShown || root.reducedMotion) ? 0
                : (DashboardTooltip.placement === "right" ? 0 : (root.flippedAbove ? 4 : -4))

            Behavior on x {
                enabled: !root.reducedMotion
                NumberAnimation {
                    duration: HAnimation.tooltipDuration
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: HAnimation.tooltipCurve
                }
            }
            Behavior on y {
                enabled: !root.reducedMotion
                NumberAnimation {
                    duration: HAnimation.tooltipDuration
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: HAnimation.tooltipCurve
                }
            }
        }

        Behavior on opacity {
            enabled: !root.reducedMotion
            NumberAnimation {
                duration: HAnimation.tooltipDuration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: HAnimation.tooltipCurve
            }
        }
        Behavior on scale {
            enabled: !root.reducedMotion
            NumberAnimation {
                duration: HAnimation.tooltipDuration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: HAnimation.tooltipCurve
            }
        }

        Text {
            id: label
            anchors.centerIn: parent
            width: parent.width - 16
            text: root.displayText
            font.family: Theme.fontFamily
            font.pixelSize: Math.max(10, Theme.fontSize - 2)
            color: Theme.fg
            wrapMode: Text.Wrap
            horizontalAlignment: Text.AlignHCenter
        }
    }
}
