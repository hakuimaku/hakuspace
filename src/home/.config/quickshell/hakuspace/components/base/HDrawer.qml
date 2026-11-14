import QtQuick
import "../../services"

Item {
    id: root
    property bool open: false
    property bool leftToRight: true
    property bool vertical: false
    property bool topToBottom: true
    property real spacing: vertical ? ScreenGeometry.leftModuleGap : Theme.gap
    property Item trigger: null
    default property alias content: container.data

    readonly property real activeSpacing: vertical
        ? (container.implicitHeight > 0 ? spacing * Math.min(1, clipArea.height / container.implicitHeight) : 0)
        : (container.implicitWidth > 0 ? spacing * Math.min(1, clipArea.width / container.implicitWidth) : 0)

    implicitWidth: vertical
        ? Math.max(triggerWrapper.width, clipArea.width)
        : triggerWrapper.width + activeSpacing + clipArea.width
    implicitHeight: vertical
        ? triggerWrapper.height + activeSpacing + clipArea.height
        : Math.max(triggerWrapper.height, clipArea.height)

    onTriggerChanged: {
        if (trigger) {
            trigger.parent = triggerWrapper
        }
    }

    Item {
        id: triggerWrapper
        width: root.trigger ? root.trigger.width : 0
        height: root.trigger ? root.trigger.height : 0
        x: root.vertical
            ? (root.implicitWidth - width) / 2
            : (root.leftToRight ? 0 : root.implicitWidth - width)
        y: root.vertical
            ? (root.topToBottom ? 0 : root.implicitHeight - height)
            : (root.implicitHeight - height) / 2
    }

    // Clipping container revealing child content during drawer expansion.
    Item {
        id: clipArea
        clip: true
        visible: root.vertical ? height > 0 : width > 0
        x: root.vertical
            ? (root.implicitWidth - width) / 2
            : (root.leftToRight ? (triggerWrapper.width + root.activeSpacing) : 0)
        y: root.vertical
            ? (root.topToBottom ? (triggerWrapper.height + root.activeSpacing) : 0)
            : (root.implicitHeight - height) / 2
        width: root.vertical ? container.implicitWidth : (root.open ? container.implicitWidth : 0)
        height: root.vertical ? (root.open ? container.implicitHeight : 0) : container.implicitHeight
        opacity: root.open ? 1.0 : 0.0

        // Animates drawer horizontal expansion width when opening or closing.
        Behavior on width {
            enabled: !root.vertical
            NumberAnimation { duration: HAnimation.slow; easing.bezierCurve: HAnimation.shellCurve }
        }
        // Animates drawer vertical expansion height when opening or closing.
        Behavior on height {
            enabled: root.vertical
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
