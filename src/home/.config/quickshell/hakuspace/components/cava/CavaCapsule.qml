import QtQuick
import "../../services"
import "../motion" as Motion

Item {
    id: root
    property var bars: CavaService.bars
    property real amplitude: CavaService.amplitude
    property color barColor: CavaService.underbarColor
    property real barOpacity: 1.0

    readonly property int count: bars ? bars.length : 0
    readonly property real spacing: 2
    property bool isTop: CavaService.top
    property real bloom: 1.0
    readonly property real clampedBloom: Math.max(0.0, Math.min(1.0, bloom))
    readonly property real curtainSpan: clampedBloom >= 0.999 ? 1.0 : (0.28 + 0.72 * Math.pow(clampedBloom, 0.72))
    readonly property real barWidth: count > 0 ? Math.max(2, (width - (count - 1) * spacing) / count) : 4

    // Continuous idle ripple animation with exact harmonic periodicity
    property real idlePhase: 0.0
    readonly property real targetIdleWeight: (CavaService.sleeping || CavaService.overallEnergy < 0.015) ? 1.0 : Math.max(0.0, 1.0 - CavaService.overallEnergy * 15.0)
    property real idleWeight: targetIdleWeight
    Behavior on idleWeight {
        NumberAnimation { duration: 350; easing.type: Easing.InOutQuad }
    }

    NumberAnimation on idlePhase {
        from: 0.0
        to: Math.PI * 2
        duration: 4800
        loops: Animation.Infinite
        running: root.visible && CavaService.enabled && CavaService.available
    }

    Row {
        anchors.top: root.isTop ? parent.top : undefined
        anchors.bottom: !root.isTop ? parent.bottom : undefined
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: root.spacing * root.curtainSpan
        height: parent.height

        Repeater {
            model: root.count
            Item {
                width: root.barWidth * root.curtainSpan
                height: root.height

                Rectangle {
                    anchors.top: root.isTop ? parent.top : undefined
                    anchors.bottom: !root.isTop ? parent.bottom : undefined
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width
                    height: {
                        var rawVal = (root.bars && index < root.bars.length) ? root.bars[index] : 0.0
                        var targetMaxH = Math.max(20.0, CavaService.height - 4.0)
                        var idleWeight = root.idleWeight
                        var normX = (root.count > 1) ? (index / (root.count - 1)) : 0.5
                        var centerDist = Math.abs(normX - 0.5) * 2.0
                        var b = root.clampedBloom
                        var curtainT = b >= 0.999 ? 1.0 : Math.max(0.0, Math.min(1.0, b * 1.5 - centerDist * 0.5))
                        var curtain = curtainT * curtainT * (3.0 - 2.0 * curtainT)
                        var idleShape = (Math.sin(normX * Math.PI * 4.0 + root.idlePhase) * 0.5 + 0.5)
                        var idleAmp = Math.max(4.0, Math.min(14.0, targetMaxH * 0.12))
                        var audioH = rawVal * targetMaxH * root.amplitude
                        return Math.max(2.0 * curtain, Math.min(targetMaxH, (audioH + idleShape * idleAmp * idleWeight) * curtain))
                    }
                    radius: width / 2
                    color: root.barColor
                    opacity: root.barOpacity
                }
            }
        }
    }
}
