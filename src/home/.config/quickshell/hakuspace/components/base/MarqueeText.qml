import QtQuick
import "../../services"

Item {
    id: root
    property string text: ""
    property color color: Theme.fg
    property string fontFamily: Theme.fontFamily
    property int fontPixelSize: Theme.fontSize
    property int fontWeight: Font.Normal
    property int horizontalAlignment: Text.AlignLeft
    property int pauseMs: 1200
    property real speedPxPerSec: 36
    property real gapWidth: Theme.spaceLg * 2
    property real scrollOffset: 0

    readonly property real textWidth: primaryText.implicitWidth
    readonly property real textHeight: primaryText.implicitHeight
    readonly property bool overflowing: width > 0 && textWidth > width + 1
    readonly property real cycleDistance: textWidth + gapWidth

    implicitWidth: textWidth
    implicitHeight: textHeight
    clip: true

    onTextChanged: resetScroll()
    onOverflowingChanged: resetScroll()
    onVisibleChanged: if (!visible) resetScroll()

    function resetScroll() {
        ticker.stop()
        scrollOffset = 0
        if (visible && overflowing) ticker.restart()
    }

    Text {
        id: primaryText
        x: root.overflowing ? -root.scrollOffset : 0
        y: (root.height - height) / 2
        width: root.overflowing ? implicitWidth : root.width
        text: root.text
        color: root.color
        font.family: root.fontFamily
        font.pixelSize: root.fontPixelSize
        font.weight: root.fontWeight
        horizontalAlignment: root.overflowing ? Text.AlignLeft : root.horizontalAlignment
        verticalAlignment: Text.AlignVCenter
    }

    Text {
        x: primaryText.x + root.cycleDistance
        y: primaryText.y
        visible: root.overflowing
        text: root.text
        color: root.color
        font.family: root.fontFamily
        font.pixelSize: root.fontPixelSize
        font.weight: root.fontWeight
        verticalAlignment: Text.AlignVCenter
    }

    SequentialAnimation {
        id: ticker
        running: root.visible && root.overflowing
        loops: Animation.Infinite
        ScriptAction { script: root.scrollOffset = 0 }
        PauseAnimation { duration: root.pauseMs }
        NumberAnimation {
            target: root
            property: "scrollOffset"
            from: 0
            to: root.cycleDistance
            duration: Math.max(500, Math.round(root.cycleDistance / Math.max(10, root.speedPxPerSec) * 1000))
            easing.type: Easing.Linear
        }
    }
}
