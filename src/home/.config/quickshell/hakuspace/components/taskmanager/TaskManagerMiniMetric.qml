import QtQuick
import QtQuick.Layouts
import "../../services"
import "glassgrid" as Glass

Rectangle {
    id: root
    // Match standalone telemetry cards while keeping only the essential sample.
    required property string label
    required property string value
    required property var visuals
    property string secondary: ""
    property real usage: NaN
    // All three gauges follow the dashboard's shared wave clock.
    property real waterWavePhase: 0
    property bool reducedMotion: false
    property bool compact: false
    // Keep the extra card inset local to the Task Manager presentation.
    readonly property int contentPadding: Theme.cardPadding + 4
    implicitHeight: water.diameter + reading.implicitHeight + details.implicitHeight
        + contentPadding * 2 + Theme.spaceSm * 2
    radius: Theme.radius
    color: visuals.cardSurface
    Accessible.role: Accessible.Grouping
    Accessible.name: label + " " + value + (secondary ? ", " + secondary : "")

    // Keep the corner title out of the vertical flow so the large bottle reading stays visible.
    Text {
        anchors { top: parent.top; left: parent.left; right: parent.right; margins: root.contentPadding }
        text: root.label
        color: root.visuals.primaryFg
        font.family: Theme.fontFamily
        font.pixelSize: root.visuals.metaFontSize
        elide: Text.ElideRight
        z: 1
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: root.contentPadding
        spacing: Theme.spaceSm
        Glass.TaskWaterGauge {
            id: water
            objectName: "taskManagerMiniWaterGauge"
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: diameter
            Layout.preferredHeight: diameter
            diameter: Math.max(1, Math.min(root.compact ? 124 : 164, root.width - root.contentPadding * 2))
            metricId: root.label.toLowerCase()
            available: Number.isFinite(root.usage)
            value: available ? root.usage : 0
            wavePhase: root.waterWavePhase
            interactive: false
            reducedMotion: root.reducedMotion || !root.visible
            Accessible.ignored: true
        }
        Text {
            id: reading
            objectName: "taskManagerMiniMetricValue"
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: water.percentText
            color: Theme.accent
            font.family: Theme.fontFamily
            font.pixelSize: root.visuals.heroFontSize
            font.bold: true
            Accessible.ignored: true
        }
        Text {
            id: details
            objectName: "taskManagerMiniMetricDetail"
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: root.secondary
            color: root.visuals.secondaryFg
            font.family: Theme.fontFamily
            font.pixelSize: root.visuals.metaFontSize
            elide: Text.ElideRight
        }
    }
}
