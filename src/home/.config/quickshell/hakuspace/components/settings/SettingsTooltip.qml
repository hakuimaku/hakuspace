import QtQuick
import QtQuick.Controls
import "../../services"

ToolTip {
    id: root
    property Item target: null
    property bool active: false
    property bool immediate: false

    parent: target
    x: target ? (target.width - width) / 2 : 0
    y: target ? target.height + 6 : 0
    width: Math.min(400, Math.max(48, label.implicitWidth + 24))
    height: label.implicitHeight + 20
    padding: 10
    closePolicy: Popup.NoAutoClose
    enter: Transition {
        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: root.immediate ? 0 : HAnimation.slow; easing.bezierCurve: HAnimation.tooltipCurve }
    }
    exit: Transition {
        NumberAnimation { property: "opacity"; from: 1; to: 0; duration: root.immediate ? 0 : HAnimation.slow; easing.bezierCurve: HAnimation.tooltipCurve }
    }

    onActiveChanged: {
        if (active && text.length) { if (immediate) open(); else showDelay.restart() }
        else { showDelay.stop(); close() }
    }
    onTextChanged: {
        if (active && text.length && !visible) { if (immediate) open(); else showDelay.restart() }
        else if (!text.length) { showDelay.stop(); close() }
    }

    Timer {
        id: showDelay
        interval: 450
        onTriggered: { if (root.active && root.target && root.target.visible) root.open() }
    }
    contentItem: Text {
        id: label
        text: root.text
        color: Qt.hsla(0, 0, Qt.darker(Theme.fgDim, 1).hslLightness, 1)
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        wrapMode: Text.Wrap
        lineHeight: 1.15
    }
    background: Rectangle {
        radius: Theme.radius
        color: Theme.hoverMuted
        border.color: Theme.border
        border.width: 1
    }
}
