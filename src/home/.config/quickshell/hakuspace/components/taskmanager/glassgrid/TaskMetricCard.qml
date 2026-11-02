import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../../services"

Rectangle {
    id: root
    required property string metricId
    required property string title
    property string primaryValue: "—"
    property string secondaryValue: ""
    property real barValue: 0
    property bool barAvailable: false
    property bool selected: false
    property bool visualSuppressed: false
    property bool compact: false
    property bool ultraCompact: false
    property bool reducedMotion: false
    property real waterWavePhase: 0.0
    property var visuals
    property var memory: ({})
    property var gpus: []
    property var disks: ({})
    property var network: ({})
    signal activated(string metricId)

    objectName: "taskMetricCard_" + metricId
    activeFocusOnTab: true
    radius: Theme.radius
    border.width: 0
    // Keep the background opaque while the compact presentation is suppressed.
    color: root.activeFocus ? visuals.keyFocusSurface
        : (root.selected ? visuals.activeCardSurface
            : (hoverHandler.hovered ? visuals.hoverSurface : visuals.cardSurface))
    clip: true

    readonly property string metricIcon: {
        if (metricId === "gpu") return "󰢮"
        if (metricId === "disk") return "󰋊"
        if (metricId === "network") return "󰖩"
        return "󰍛"
    }

    Accessible.role: Accessible.Button
    Accessible.name: root.title + " " + root.primaryValue + (root.selected ? " active" : "")
    Accessible.description: root.secondaryValue

    Behavior on color {
        enabled: !root.reducedMotion && !root.visualSuppressed
        ColorAnimation { duration: HAnimation.fast }
    }

    Keys.onReturnPressed: event => { root.activated(root.metricId); event.accepted = true }
    Keys.onEnterPressed: event => { root.activated(root.metricId); event.accepted = true }
    Keys.onSpacePressed: event => { root.activated(root.metricId); event.accepted = true }

    HoverHandler {
        id: hoverHandler
        cursorShape: Qt.PointingHandCursor
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.activated(root.metricId)
    }

    // Keep the icon in its grid slot during the focus-card morph.
    Item {
        id: iconBackingLayer
        objectName: "taskMetricFocusedIcon_" + root.metricId
        anchors.fill: parent
        visible: root.selected || root.visualSuppressed

        Column {
            anchors.centerIn: parent
            spacing: root.ultraCompact ? 2 : 4

            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.metricIcon
                font.family: Theme.fontFamily
                font.pixelSize: root.ultraCompact ? 24 : (root.compact ? 28 : 34)
                color: Theme.accent
            }

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 14
                height: 3
                radius: 1.5
                border.width: 0
                color: Theme.accent
            }
        }
    }

    Rectangle {
        id: normalCardLayer
        objectName: "taskMetricNormalLayer_" + root.metricId
        anchors.fill: parent
        radius: root.radius
        border.width: 0
        color: root.activeFocus ? visuals.keyFocusSurface
            : (hoverHandler.hovered ? visuals.hoverSurface : visuals.cardSurface)
        visible: !root.selected && !root.visualSuppressed
        clip: true

        TaskMetricPresentation {
            id: visualLayer
            objectName: "taskMetricVisualLayer_" + root.metricId
            anchors.fill: parent
            metricId: root.metricId
            expansionProgress: 0.0
            interactive: false
            waterWavePhase: root.waterWavePhase
            visuals: root.visuals
            compact: root.compact
            ultraCompact: root.ultraCompact
            reducedMotion: root.reducedMotion
            primaryValue: root.primaryValue
            secondaryValue: root.secondaryValue
            customBarValue: root.barValue
            customBarAvailable: root.barAvailable
            memory: root.memory
            gpus: root.gpus
            disks: root.disks
            network: root.network
        }
    }
}
