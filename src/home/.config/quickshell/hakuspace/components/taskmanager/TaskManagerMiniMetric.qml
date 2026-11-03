import QtQuick
import QtQuick.Controls
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
    property bool subdued: false
    property var detailRows: []
    property var coreUsage: []
    // Paint details over the next row without reserving layout space.
    property real detailProgress: hovered ? 1 : 0
    readonly property real visualScale: surface.scale
    readonly property real detailHeight: detailLoader.item ? detailLoader.item.implicitHeight + Theme.spaceSm : 0
    property real maximumOverlayHeight: height
    readonly property real detailViewportHeight: Math.min(detailHeight, Math.max(0, maximumOverlayHeight / visualScale - height))
    Layout.alignment: Qt.AlignTop
    z: hovered ? 2 : detailProgress > 0 ? 1 : 0
    Behavior on detailProgress {
        enabled: !root.reducedMotion
        NumberAnimation { duration: HAnimation.buttonHoverDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: HAnimation.moduleCurve }
    }
    opacity: subdued ? 0.92 : 1
    Behavior on opacity {
        enabled: !root.reducedMotion
        NumberAnimation { duration: HAnimation.fast; easing.type: Easing.BezierSpline; easing.bezierCurve: HAnimation.moduleCurve }
    }
    readonly property int contentPadding: compact ? Theme.spaceMd : Theme.cardPadding
    implicitHeight: header.implicitHeight + water.diameter + details.implicitHeight
        + contentPadding * 2 + Theme.spaceXs * 2 + Theme.spaceSm
    // Keep hover parameters separate from telemetry and settle from their current value.
    readonly property bool hovered: visible && enabled && (metricHover.hovered || surfaceHover.hovered)
    readonly property point pointerPosition: surfaceHover.hovered
        ? surface.mapToItem(root, surfaceHover.point.position.x, surfaceHover.point.position.y) : metricHover.point.position
    property real hoverStrength: hovered && !reducedMotion ? 1 : 0
    property real hoverBiasX: hovered && !reducedMotion && width > 0
        ? Math.round(Math.max(-1, Math.min(1, pointerPosition.x / width * 2 - 1)) * 16) / 16 : 0
    // Damped ink returns to the category icon instead of following the pointer outside.
    property real inkX: hovered && !reducedMotion ? Math.round(pointerPosition.x / 4) * 4 : contentPadding + Theme.fontSize / 2
    property real inkY: hovered && !reducedMotion ? Math.round(pointerPosition.y / 4) * 4 : contentPadding + Theme.fontSize / 2
    Behavior on inkX {
        enabled: !root.reducedMotion
        NumberAnimation { duration: HAnimation.taskBarFillDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: HAnimation.moduleCurve }
    }
    Behavior on inkY {
        enabled: !root.reducedMotion
        NumberAnimation { duration: HAnimation.taskBarFillDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: HAnimation.moduleCurve }
    }
    Behavior on hoverStrength {
        enabled: !root.reducedMotion
        NumberAnimation { duration: HAnimation.taskBarFillDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: HAnimation.moduleCurve }
    }
    Behavior on hoverBiasX {
        enabled: !root.reducedMotion
        NumberAnimation { duration: HAnimation.taskBarFillDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: HAnimation.moduleCurve }
    }
    HoverHandler { id: metricHover; cursorShape: Qt.ArrowCursor }
    Accessible.role: Accessible.Grouping
    Accessible.name: label + " " + value + (secondary ? ", " + secondary : "")

    Rectangle {
        id: surface
        objectName: "taskManagerMiniMetricSurface"
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: root.height + root.detailProgress * root.detailViewportHeight
        transformOrigin: Item.Top
        scale: root.hovered && !root.reducedMotion ? 1.05 : 1
        Behavior on scale {
            enabled: !root.reducedMotion
            NumberAnimation { duration: HAnimation.buttonHoverDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: HAnimation.moduleCurve }
        }
        radius: Theme.radius
        // An opaque backing keeps covered process text from showing through the card.
        color: Qt.tint(Theme.surface, root.hovered ? root.visuals.hoverSurface : root.visuals.cardSurface)
        border.width: 1
        border.color: Qt.alpha(Theme.accent, root.hovered ? 0.18 : 0)
        HoverHandler { id: surfaceHover; cursorShape: Qt.ArrowCursor }
        // Prevent clicks in the expanded surface from reaching pinned rows underneath.
        MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons }
        Behavior on color {
            enabled: !root.reducedMotion
            ColorAnimation { duration: HAnimation.fast; easing.type: Easing.BezierSpline; easing.bezierCurve: HAnimation.moduleCurve }
        }
        Behavior on border.color {
            enabled: !root.reducedMotion
            ColorAnimation { duration: HAnimation.fast; easing.type: Easing.BezierSpline; easing.bezierCurve: HAnimation.moduleCurve }
        }

        Canvas {
            id: ink
            objectName: "taskManagerMiniInk"
            anchors.fill: parent
            visible: !root.reducedMotion && root.hoverStrength > 0.001
            renderTarget: Canvas.Image
            // Quantized paint inputs avoid repainting for subpixel pointer noise.
            readonly property real paintX: Math.round(root.inkX / 3) * 3
            readonly property real paintY: Math.round(root.inkY / 3) * 3
            readonly property real amount: Math.round(root.hoverStrength * 24) / 24
            onPaintXChanged: if (visible) requestPaint()
            onPaintYChanged: if (visible) requestPaint()
            onAmountChanged: if (visible) requestPaint()
            onVisibleChanged: if (visible) requestPaint()
            Connections {
                target: Theme
                function onAccentChanged() { if (ink.visible) ink.requestPaint() }
            }
            onPaint: {
                var ctx = getContext("2d")
                ctx.reset()
                var r = Math.min(Theme.radius, width / 2, height / 2)
                ctx.save()
                ctx.beginPath()
                ctx.moveTo(r, 0)
                ctx.lineTo(width - r, 0)
                ctx.quadraticCurveTo(width, 0, width, r)
                ctx.lineTo(width, height - r)
                ctx.quadraticCurveTo(width, height, width - r, height)
                ctx.lineTo(r, height)
                ctx.quadraticCurveTo(0, height, 0, height - r)
                ctx.lineTo(0, r)
                ctx.quadraticCurveTo(0, 0, r, 0)
                ctx.clip()
                // Layer broad asymmetric ink shapes; total accent alpha stays below 0.055.
                for (var i = 0; i < 5; i++) {
                    var spread = (0.2 + 0.8 * amount) * (1 - i * 0.14)
                    var rx = width * 0.44 * spread
                    var ry = height * 0.23 * spread
                    ctx.beginPath()
                    ctx.moveTo(paintX - rx, paintY)
                    ctx.bezierCurveTo(paintX - rx * 0.8, paintY - ry, paintX + rx * 0.6, paintY - ry * 0.9, paintX + rx, paintY)
                    ctx.bezierCurveTo(paintX + rx * 0.6, paintY + ry * 0.8, paintX - rx * 0.65, paintY + ry, paintX - rx, paintY)
                    ctx.fillStyle = Qt.alpha(Theme.accent, 0.011 * amount)
                    ctx.fill()
                }
                ctx.restore()
            }
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
                hoverStrength: root.hoverStrength
                hoverBiasX: root.hoverBiasX
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
            Flickable {
                objectName: "taskManagerMiniMetricExpanded"
                Layout.fillWidth: true
                Layout.minimumHeight: 0
                Layout.preferredHeight: root.detailProgress * root.detailViewportHeight
                Layout.maximumHeight: Layout.preferredHeight
                // Cancel layout spacing so a collapsed card retains its original height.
                Layout.topMargin: -Theme.spaceXs
                clip: true
                opacity: root.detailProgress
                contentWidth: width
                contentHeight: root.detailHeight
                interactive: contentHeight > height
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar {}
                Loader {
                    id: detailLoader
                    objectName: "taskManagerMiniDetailLoader"
                    anchors { top: parent.top; left: parent.left; right: parent.right; topMargin: Theme.spaceSm }
                    active: root.hovered || root.detailProgress > 0
                    sourceComponent: ColumnLayout {
                        spacing: Theme.spaceSm
                        Repeater {
                            model: root.detailRows
                            RowLayout {
                                required property var modelData
                                Layout.fillWidth: true
                                spacing: Theme.spaceXs
                                Text {
                                    Layout.maximumWidth: (root.width - root.contentPadding * 2) * 0.45
                                    text: modelData.label
                                    color: root.visuals.secondaryFg
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSize - 2
                                    wrapMode: Text.Wrap
                                }
                                Text {
                                    Layout.fillWidth: true
                                    Layout.minimumWidth: 0
                                    text: modelData.value
                                    color: root.visuals.primaryFg
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSize - 2
                                    horizontalAlignment: Text.AlignRight
                                    wrapMode: Text.Wrap
                                }
                            }
                        }
                        Text {
                            visible: root.coreUsage.length > 0
                            text: "Cores · " + root.coreUsage.length
                            color: root.visuals.secondaryFg
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize - 2
                        }
                        GridLayout {
                            Layout.fillWidth: true
                            visible: root.coreUsage.length > 0
                            columns: root.compact ? 2 : 3
                            columnSpacing: Theme.spaceXs
                            rowSpacing: Theme.spaceXs
                            Repeater {
                                model: root.coreUsage
                                ColumnLayout {
                                    required property int index
                                    required property var modelData
                                    Layout.fillWidth: true
                                    spacing: 2
                                    Text {
                                        text: index + " · " + root.visuals.dashMetric(modelData, "%", 0)
                                        color: root.visuals.primaryFg
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSize - 3
                                    }
                                    Glass.TaskMetricBar {
                                        Layout.fillWidth: true
                                        implicitHeight: 2
                                        value: root.visuals.clampPercent(modelData)
                                        available: Number.isFinite(modelData)
                                        reducedMotion: root.reducedMotion
                                        trackColor: root.visuals.trackSurface
                                        fillColor: Theme.accent
                                    }
                                }
                            }
                        }
                        Text {
                            visible: !root.detailRows.length && !root.coreUsage.length
                            Layout.fillWidth: true
                            text: "No additional data"
                            color: root.visuals.secondaryFg
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize - 2
                            wrapMode: Text.Wrap
                        }
                    }
                }
            }
        }
    }
}
