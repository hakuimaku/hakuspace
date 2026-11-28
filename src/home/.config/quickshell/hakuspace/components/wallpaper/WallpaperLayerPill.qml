import QtQuick
import "../../services"

Rectangle {
    id: root
    property string text: ""
    property bool hiddenLayerActive: false
    property bool compact: false
    property real maxPillWidth: 260
    property color surfaceColor: Qt.alpha(Theme.surface, 0.94)
    signal stepRequested(int step)

    readonly property real navSize: compact ? 28 : 32
    readonly property real innerPad: compact ? 20 : 28
    height: compact ? 38 : 42
    width: Math.min(maxPillWidth, navSize * 2 + labelRow.implicitWidth + innerPad)
    Behavior on width {
        NumberAnimation {
            duration: HAnimation.effects
            easing.type: Easing.BezierSpline
            easing.bezierCurve: HAnimation.moduleCurve
        }
    }
    radius: height / 2
    color: surfaceColor
    border.width: 0

    WallpaperToolbarButton {
        id: prevButton
        objectName: "wallpaper-layer-prev"
        anchors.left: parent.left
        anchors.leftMargin: 4
        anchors.verticalCenter: parent.verticalCenter
        width: root.navSize
        height: root.navSize
        radius: height / 2
        border.width: 0
        horizontalPadding: 0
        icon: "\uf104"
        iconSize: root.compact ? 14 : 16
        description: "Previous layer ([)"
        showTooltip: false
        idleColor: "transparent"
        hoverColor: "transparent"
        pressedColor: Qt.tint(Theme.surface, Qt.alpha(Theme.accent, 0.18))
        foregroundColor: Theme.fg
        hoverForegroundColor: Theme.fg
        hoverScaleDelta: 0.05
        hoverXScaleDelta: 0
        pressScaleDelta: 0.03
        pressXScaleDelta: 0
        onClicked: root.stepRequested(-1)
    }

    Item {
        anchors.left: prevButton.right
        anchors.right: nextButton.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        clip: true
        Row {
            id: labelRow
            anchors.centerIn: parent
            spacing: 6
            Rectangle {
                visible: root.hiddenLayerActive
                anchors.verticalCenter: parent.verticalCenter
                width: 6
                height: 6
                radius: 3
                color: Theme.accent
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, Math.max(32, root.maxPillWidth - root.navSize * 2
                    - (root.hiddenLayerActive ? 20 : 8) - root.innerPad))
                text: root.text
                textFormat: Text.PlainText
                elide: Text.ElideRight
                color: Theme.fg
                font.family: Theme.fontFamily
                font.pixelSize: root.compact ? Theme.fontSize - 1 : Theme.fontSize
                font.weight: Font.DemiBold
            }
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.stepRequested(1)
        }
    }

    WallpaperToolbarButton {
        id: nextButton
        objectName: "wallpaper-layer-next"
        anchors.right: parent.right
        anchors.rightMargin: 4
        anchors.verticalCenter: parent.verticalCenter
        width: root.navSize
        height: root.navSize
        radius: height / 2
        border.width: 0
        horizontalPadding: 0
        icon: "\uf105"
        iconSize: root.compact ? 14 : 16
        description: "Next layer (])"
        showTooltip: false
        idleColor: "transparent"
        hoverColor: "transparent"
        pressedColor: Qt.tint(Theme.surface, Qt.alpha(Theme.accent, 0.18))
        foregroundColor: Theme.fg
        hoverForegroundColor: Theme.fg
        hoverScaleDelta: 0.05
        hoverXScaleDelta: 0
        pressScaleDelta: 0.03
        pressXScaleDelta: 0
        onClicked: root.stepRequested(1)
    }
}
