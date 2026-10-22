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
                        var val = (root.bars && index < root.bars.length) ? root.bars[index] : 0.0
                        return Math.max(2, Math.min(parent.height, val * parent.height * root.amplitude))
                    }
                    radius: width / 2
                    color: root.barColor
                    opacity: root.barOpacity
                }
            }
        }
    }
}
