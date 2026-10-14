import QtQuick
import QtQuick.Controls
import "../../services"

ToolTip {
    id: root
    property Item target: null
    property bool active: false

    parent: target
    x: target ? (target.width - width) / 2 : 0
    y: target ? target.height + 6 : 0
    width: Math.min(380, Math.max(48, label.implicitWidth + 20))
    height: label.implicitHeight + 16
    padding: 8
    closePolicy: Popup.NoAutoClose
    enter: Transition {
        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: HAnimation.fast; easing.bezierCurve: HAnimation.tooltipCurve }
    }
    exit: Transition {
        NumberAnimation { property: "opacity"; from: 1; to: 0; duration: HAnimation.fast; easing.bezierCurve: HAnimation.tooltipCurve }
    }

    onActiveChanged: {
        if (active && text.length) showDelay.restart()
        else { showDelay.stop(); close() }
    }
    onTextChanged: {
        if (active && text.length && !visible) showDelay.restart()
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
        color: Theme.fg
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        wrapMode: Text.Wrap
        lineHeight: 1.15
    }
    background: Rectangle {
        radius: Theme.radius / 2
        color: Theme.hoverMuted
        border.color: Theme.border
        border.width: 1
    }
}
