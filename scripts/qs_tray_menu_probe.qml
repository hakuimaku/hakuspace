// Run with: timeout 12s qs -p scripts/qs_tray_menu_probe.qml
// Read-only tray protocol probe. It never triggers menu actions.
import QtQuick
import Quickshell
import Quickshell.Services.SystemTray

ShellRoot {
    id: root
    property var opened: []

    Component { id: openerFactory; QsMenuOpener {} }

    function openerFor(handle) {
        for (var i = 0; i < opened.length; i++) {
            if (opened[i].handle === handle) return opened[i].opener
        }
        var opener = openerFactory.createObject(root, { menu: handle })
        opened.push({ handle: handle, opener: opener })
        return opener
    }

    function dump(handle, prefix, depth) {
        if (!handle || depth > 4) return
        var entries = openerFor(handle).children.values
        console.log(prefix + " children=" + entries.length)
        for (var i = 0; i < entries.length; i++) {
            var entry = entries[i]
            console.log(prefix + " [" + i + "] text=" + JSON.stringify(entry.text)
                + " icon=" + JSON.stringify(entry.icon)
                + " enabled=" + entry.enabled
                + " separator=" + entry.isSeparator
                + " buttonType=" + QsMenuButtonType.toString(entry.buttonType)
                + " checkState=" + entry.checkState
                + " hasChildren=" + entry.hasChildren)
            if (entry.hasChildren) dump(entry, prefix + "/" + i, depth + 1)
        }
    }

    Timer {
        interval: 2000
        repeat: true
        running: true
        onTriggered: {
            var items = SystemTray.items.values
            console.log("TRAY items=" + items.length)
            for (var i = 0; i < items.length; i++) {
                var item = items[i]
                console.log("ITEM id=" + item.id + " title=" + JSON.stringify(item.title)
                    + " onlyMenu=" + item.onlyMenu + " hasMenu=" + item.hasMenu
                    + " menuHandle=" + Boolean(item.menu))
                if (item.menu) root.dump(item.menu, "  " + item.id, 0)
            }
        }
    }
}
