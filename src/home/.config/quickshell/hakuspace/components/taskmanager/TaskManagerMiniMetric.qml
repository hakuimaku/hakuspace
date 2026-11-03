import QtQuick
import QtQuick.Layouts
import "../../services"
import "../../config/UiCatalog.js" as Catalog
import "glassgrid" as Glass

Rectangle {
    id: root
    // Present the same sample through a category header, water level and secondary detail.
    required property string label
    required property string value
    required property var visuals
    property string secondary: ""
    property real usage: NaN
    property real waterWavePhase: 0
    property bool reducedMotion: false
    property bool compact: false
    readonly property int contentPadding: compact ? Theme.spaceMd : Theme.cardPadding
    implicitHeight: header.implicitHeight + water.diameter + details.implicitHeight
        + contentPadding * 2 + Theme.spaceXs * 2 + Theme.spaceSm
    radius: Theme.radius
    color: visuals.cardSurface
    Accessible.role: Accessible.Grouping
    Accessible.name: label + " " + value + (secondary ? ", " + secondary : "")

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: root.contentPadding
        spacing: Theme.spaceXs
        RowLayout {
            id: header
            Layout.fillWidth: true
            spacing: Theme.spaceXs
            Text {
                text: Catalog.taskManagerIcons[root.label.toLowerCase()]
                color: Theme.accent
                font.family: Theme.iconFontFamily
                font.pixelSize: Theme.fontSize
                Accessible.ignored: true
            }
            Text {
                Layout.fillWidth: true
                text: root.label
                color: root.visuals.primaryFg
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                elide: Text.ElideRight
            }
            Text {
                objectName: "taskManagerMiniMetricValue"
                text: water.percentText
                color: Theme.accent
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize + 6
                font.bold: true
                Accessible.ignored: true
            }
        }
        Glass.TaskWaterGauge {
            id: water
            objectName: "taskManagerMiniWaterGauge"
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: diameter
            Layout.preferredHeight: diameter
            diameter: Math.max(1, Math.min(root.compact ? 110 : 144, root.width - root.contentPadding * 2))
            metricId: root.label.toLowerCase()
            available: Number.isFinite(root.usage)
            value: available ? root.usage : 0
            wavePhase: root.waterWavePhase
            interactive: false
            reducedMotion: root.reducedMotion || !root.visible
            Accessible.ignored: true
        }
        Text {
            id: details
            objectName: "taskManagerMiniMetricDetail"
            Layout.fillWidth: true
            Layout.topMargin: Theme.spaceSm
            horizontalAlignment: Text.AlignHCenter
            text: root.secondary
            color: root.visuals.secondaryFg
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize - 1
            elide: Text.ElideRight
        }
    }
}
