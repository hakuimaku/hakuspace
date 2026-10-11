import QtQuick
import "../../services"

Item {
    id: root

    anchors.fill: parent
    enabled: false
    visible: bubbleOpacity > 0.001
    z: 100

    property real bubbleOpacity: 0.0
    property real bubbleX: 0
    property real bubbleY: 0
    property string displayText: ""

    Timer {
        id: delayTimer
        interval: 380
        repeat: false
        onTriggered: {
            if (DashboardTooltip.active && DashboardTooltip.currentTarget && root.parent && root.parent.isFullyOpen) {
                root.displayText = DashboardTooltip.currentText
                root.positionBubble()
                root.bubbleOpacity = 1.0
            } else {
                root.bubbleOpacity = 0.0
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
                root.bubbleOpacity = 0.0
            }
        }
        function onCurrentTextChanged() {
            if (DashboardTooltip.active && root.bubbleOpacity > 0.001) {
                root.displayText = DashboardTooltip.currentText
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
                root.bubbleOpacity = 0.0
            }
        }
    }

    function positionBubble() {
        var target = DashboardTooltip.currentTarget
        if (!target) return
        try {
            var pt = target.mapToItem(root, 0, 0)
            var targetWidth = target.width || 0
            var targetHeight = target.height || 0

            // Prefer placing below the target; flip above if near bottom edge
            var tx = pt.x + (targetWidth - bubble.width) / 2
            var ty = pt.y + targetHeight + 6

            // Horizontal clamping within envelope
            var pad = 12
            if (tx < pad) tx = pad
            if (tx + bubble.width > root.width - pad) {
                tx = Math.max(pad, root.width - bubble.width - pad)
            }

            // Vertical flipping if overflow
            if (ty + bubble.height > root.height - pad) {
                ty = Math.max(pad, pt.y - bubble.height - 6)
            }

            root.bubbleX = Math.round(tx)
            root.bubbleY = Math.round(ty)
        } catch (e) {
            root.bubbleOpacity = 0.0
        }
    }

    Rectangle {
        id: bubble
        x: root.bubbleX
        y: root.bubbleY
        width: Math.min(260, Math.max(56, label.implicitWidth + 18))
        height: Math.max(24, label.implicitHeight + 10)
        radius: Theme.radiusSm
        color: Qt.darker(Theme.surface, 1.15)
        border.width: 1
        border.color: Qt.lighter(Theme.hoverMuted, 1.35)
        opacity: root.bubbleOpacity

        Behavior on opacity {
            NumberAnimation {
                duration: HAnimation.fast
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
