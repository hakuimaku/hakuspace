import QtQuick
import "../../services"
import "../motion" as Motion

Item {
    id: root
    property var bars: CavaService.bars
    property real amplitude: CavaService.amplitude
    readonly property bool isSurfaceMode: CavaService.colorMode === "surface"
    property color barColor: isSurfaceMode ? Theme.surface : Theme.accent
    property real barOpacity: isSurfaceMode ? 1.0 : 0.85

    readonly property int count: bars ? bars.length : 0
    readonly property real spacing: 2
    readonly property bool isTop: AppState.cavaTopState
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
        spacing: root.spacing
        height: parent.height

        Repeater {
            model: root.count
            Item {
                width: root.barWidth
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
                        var idleShape = (Math.sin(normX * Math.PI * 4.0 + root.idlePhase) * 0.5 + 0.5)
                        var idleAmp = Math.max(4.0, Math.min(14.0, targetMaxH * 0.12))
                        var audioH = rawVal * targetMaxH * root.amplitude
                        return Math.max(2.0, Math.min(targetMaxH, audioH + idleShape * idleAmp * idleWeight))
                    }
                    radius: width / 2
                    color: root.barColor
                    opacity: root.barOpacity
                }
            }
        }
    }
}
