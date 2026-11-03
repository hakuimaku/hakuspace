import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../../services"

Rectangle {
    id: root

    property string text: ""
    property string icon: ""
    property int horizontalPadding: compact ? 8 : 10
    property real minimumWidth: compact ? 48 : 56
    property int fontSize: visuals ? visuals.metaFontSize : 11
    property bool fontBold: false
    property bool accent: false
    property bool danger: false
    property bool compact: false
    property var visuals
    property bool reducedMotion: false
    signal clicked()

    activeFocusOnTab: true
    radius: 4
    border.width: 0

    TextMetrics {
        id: metrics
        font.family: Theme.fontFamily
        font.pixelSize: root.fontSize
        font.bold: root.fontBold
        text: root.text
    }

    implicitWidth: Math.max(root.minimumWidth, Math.round(metrics.advanceWidth + root.horizontalPadding * 2
        + (root.icon ? root.fontSize + Theme.spaceSm : 0)))
    implicitHeight: root.compact ? 24 : 26

    color: root.activeFocus
        ? (visuals ? visuals.controlFocusSurface : Theme.surface)
        : (hoverHandler.hovered
            ? (visuals ? visuals.hoverSurface : Theme.hoverMuted)
            : (visuals ? visuals.controlSurface : Theme.surface))

    Behavior on color {
        enabled: !root.reducedMotion
        ColorAnimation { duration: HAnimation.fast }
    }

    Accessible.role: Accessible.Button
    Accessible.name: root.text

    HoverHandler {
        id: hoverHandler
        cursorShape: Qt.PointingHandCursor
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.clicked()
    }

    Keys.onReturnPressed: event => { root.clicked(); event.accepted = true }
    Keys.onEnterPressed: event => { root.clicked(); event.accepted = true }
    Keys.onSpacePressed: event => { root.clicked(); event.accepted = true }

    RowLayout {
        anchors.centerIn: parent
        spacing: Theme.spaceSm
        Text {
            visible: root.icon.length > 0
            text: root.icon
            color: label.color
            font.family: Theme.iconFontFamily
            font.pixelSize: root.fontSize
            Accessible.ignored: true
        }
        Text {
            id: label
            text: root.text
            font.family: Theme.fontFamily
            font.pixelSize: root.fontSize
            font.bold: root.fontBold
            color: root.danger ? Theme.danger : (root.accent ? Theme.accent
                : (hoverHandler.hovered ? (visuals ? visuals.primaryFg : Theme.fg)
                    : (visuals ? visuals.primaryFg : Theme.fgMuted)))
        }
    }
}
