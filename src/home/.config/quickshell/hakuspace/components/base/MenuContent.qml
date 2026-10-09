import QtQuick
import "../../services"

Item {
    id: root
    property var menuHandle: null
    property var lastHandle: null
    property real maxHeight: 144
    implicitWidth: Math.min(300, Math.max(220, Theme.fontSize * 19))
    implicitHeight: Math.min(maxHeight, page.implicitHeight)
    clip: true

    signal dismissed()

    onMenuHandleChanged: {
        if (menuHandle === lastHandle) return
        lastHandle = menuHandle
        page.reset()
    }

    MenuPage {
        id: page
        anchors.fill: parent
        menuHandle: root.menuHandle
        maxHeight: root.maxHeight
        onDismissed: root.dismissed()
    }
}
