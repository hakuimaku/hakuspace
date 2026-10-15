import QtQuick
import "../../services"

Row {
    id: root
    property bool open: false
    property bool leftToRight: true
    property Item trigger: null
    default property alias content: container.data

    spacing: Theme.gap
    layoutDirection: leftToRight ? Qt.LeftToRight : Qt.RightToLeft

    onTriggerChanged: {
        if (trigger) {
            trigger.parent = triggerWrapper
        }
    }

    Item {
        id: triggerWrapper
        width: root.trigger ? root.trigger.width : 0
        height: root.trigger ? root.trigger.height : 0
    }
    
    // Clipping container revealing child content during drawer expansion.
    Item {
        id: clipArea
        clip: true
        height: container.implicitHeight
        width: root.open ? container.implicitWidth : 0
        opacity: root.open ? 1.0 : 0.0
        
        // Animates drawer horizontal expansion width when opening or closing.
        Behavior on width {
            NumberAnimation { duration: HAnimation.slow; easing.bezierCurve: HAnimation.shellCurve }
        }
        // Animates drawer content fade opacity during open/close transitions.
        Behavior on opacity {
            NumberAnimation { duration: HAnimation.slow; easing.bezierCurve: HAnimation.shellCurve }
        }
        
        Item {
            id: container
            implicitHeight: childrenRect.height
            implicitWidth: childrenRect.width
        }
    }
}
