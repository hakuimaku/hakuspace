import QtQuick
import QtQuick.Layouts
import "../../services"
import "../../config/UiCatalog.js" as Catalog
import "glassgrid" as Glass

Item {
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
    // Keep the hit box fixed while only the painted card lifts.
    readonly property bool hovered: metricHover.hovered
    HoverHandler { id: metricHover; cursorShape: Qt.ArrowCursor }
    Accessible.role: Accessible.Grouping
    Accessible.name: label + " " + value + (secondary ? ", " + secondary : "")

    Rectangle {
        id: surface
        objectName: "taskManagerMiniMetricSurface"
        anchors.fill: parent
        radius: Theme.radius
        color: root.hovered ? root.visuals.hoverSurface : root.visuals.cardSurface
        border.width: 1
        border.color: Qt.alpha(Theme.accent, root.hovered ? 0.18 : 0)
        transform: Translate {
            y: root.hovered && !root.reducedMotion ? -2 : 0
            Behavior on y {
                enabled: !root.reducedMotion
                NumberAnimation { duration: HAnimation.fast; easing.type: Easing.BezierSpline; easing.bezierCurve: HAnimation.moduleCurve }
            }
        }
        Behavior on color {
            enabled: !root.reducedMotion
            ColorAnimation { duration: HAnimation.fast; easing.type: Easing.BezierSpline; easing.bezierCurve: HAnimation.moduleCurve }
        }
        Behavior on border.color {
            enabled: !root.reducedMotion
            ColorAnimation { duration: HAnimation.fast; easing.type: Easing.BezierSpline; easing.bezierCurve: HAnimation.moduleCurve }
        }

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
                    color: Qt.alpha(Theme.accent, root.hovered ? 1 : 0.72)
                    Behavior on color {
                        enabled: !root.reducedMotion
                        ColorAnimation { duration: HAnimation.fast; easing.type: Easing.BezierSpline; easing.bezierCurve: HAnimation.moduleCurve }
                    }
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
                    color: Qt.alpha(Theme.accent, root.hovered ? 1 : 0.90)
                    Behavior on color {
                        enabled: !root.reducedMotion
                        ColorAnimation { duration: HAnimation.fast; easing.type: Easing.BezierSpline; easing.bezierCurve: HAnimation.moduleCurve }
                    }
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
                emphasized: root.hovered
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
}
