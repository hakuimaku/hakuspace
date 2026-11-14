import QtQuick
import "../../services"

Rectangle {
    id: root
    property Item target: null
    property Item boundsItem: parent
    property bool active: false
    property string text: ""
    property int delayMs: 1000
    property int fadeDuration: HAnimation.slow

    // Hold the last target and text through exit fades so the bubble stays anchored.
    property Item _displayTarget: null
    property string _displayText: ""
    property bool shown: false

    z: 80
    radius: Theme.radius
    color: Theme.surface
    border.color: Theme.border
    border.width: 1
    width: label.implicitWidth + 20
    height: label.implicitHeight + 10
    opacity: shown ? 1 : 0
    visible: _displayTarget !== null && _displayText.length > 0 && (shown || opacity > 0.001)

    x: {
        if (!_displayTarget || !boundsItem) return 0
        var center = boundsItem.mapFromItem(_displayTarget, _displayTarget.width / 2, 0)
        return Math.max(0, Math.min(boundsItem.width - width, Math.round(center.x - width / 2)))
    }
    y: {
        if (!_displayTarget || !boundsItem) return 0
        var topPos = boundsItem.mapFromItem(_displayTarget, _displayTarget.width / 2, 0)
        var aboveY = Math.round(topPos.y - height - 8)
        if (aboveY >= 0) return aboveY
        var bottomPos = boundsItem.mapFromItem(_displayTarget, _displayTarget.width / 2, _displayTarget.height)
        return Math.round(bottomPos.y + 8)
    }

    Behavior on opacity {
        NumberAnimation {
            duration: root.fadeDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: HAnimation.tooltipCurve
        }
    }

    onOpacityChanged: {
        if (opacity <= 0.001 && !shown && !active) {
            _displayTarget = null
            _displayText = ""
        }
    }

    function resetImmediate() {
        showDelay.stop()
        shown = false
        _displayTarget = null
        _displayText = ""
    }

    function syncState(targetChanged) {
        if (active && target && target.visible && text.length > 0) {
            if (targetChanged && shown) shown = false
            if (!shown) {
                if (!_displayTarget) {
                    _displayTarget = target
                    _displayText = text
                }
            } else {
                _displayTarget = target
                _displayText = text
            }
            showDelay.restart()
        } else {
            showDelay.stop()
            shown = false
        }
    }

    onActiveChanged: syncState(false)
    onTargetChanged: syncState(true)
    onTextChanged: {
        if (shown && active && target && text.length > 0) _displayText = text
        else if (!active || text.length === 0) syncState(false)
    }

    Timer {
        id: showDelay
        interval: root.delayMs
        onTriggered: {
            if (root.active && root.target && root.target.visible && root.text.length > 0) {
                root._displayTarget = root.target
                root._displayText = root.text
                root.shown = true
            }
        }
    }

    Text {
        id: label
        anchors.centerIn: parent
        text: root._displayText
        color: Theme.fg
        font.family: Theme.fontFamily
        font.pixelSize: Math.max(10, Theme.fontSize - 2)
    }
}
