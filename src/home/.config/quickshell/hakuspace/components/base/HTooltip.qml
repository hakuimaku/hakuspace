import QtQuick

import Quickshell
import Quickshell.Wayland
import "../../services"

PopupWindow {
    id: root
    property string text: ""
    property Item target: null
    property bool active: false

    property real popupOpacity: (active && text.length > 0) ? 1.0 : 0.0
    visible: popupOpacity > 0
    
    Behavior on popupOpacity {
        NumberAnimation { duration: HAnimation.fast; easing.bezierCurve: HAnimation.tooltipCurve }
    }
    
    anchor.window: target && target.Window.window ? target.Window.window : null
    anchor.rect: target ? Qt.rect(0, 0, target.width, target.height) : Qt.rect(0,0,0,0)
    
    color: "transparent"
    
    Rectangle {
        opacity: root.popupOpacity
        color: Theme.inkBg
        radius: 12
        border.color: Theme.scrim
        border.width: 1
        
        implicitWidth: Math.min(400, contentText.implicitWidth + 24)
        implicitHeight: contentText.implicitHeight + 16
        
        Text {
            id: contentText
            anchors.centerIn: parent
            width: Math.min(376, implicitWidth)
            text: root.text
            color: Theme.accent
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            wrapMode: Text.Wrap
            horizontalAlignment: Text.AlignHCenter
        }
    }
}
