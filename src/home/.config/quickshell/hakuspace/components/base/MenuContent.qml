import QtQuick
import "../../services"

Item {
    id: root
    property var menuHandle: null
    property var lastHandle: null
    property real maxHeight: 144
    // Side menus honor the host width budget while keeping the original default width.
    property real maxWidth: 300
    implicitWidth: Math.min(maxWidth, Math.max(220, Theme.fontSize * 19))
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
