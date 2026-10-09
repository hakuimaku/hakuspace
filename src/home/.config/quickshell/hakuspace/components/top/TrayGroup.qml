import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import "../../services"
import "../base"
import "../"

Row {
    id: root
    spacing: Theme.gap
    property var menuOpenItem: null
    signal menuRequested(var item, var anchor)

    Item { width: 4; height: 1; visible: SystemTray.items.length > 0 }

    Repeater {
        model: SystemTray.items

        TopModule {
            id: trayItem
            implicitWidth: implicitHeight
            tooltip: root.menuOpenItem === modelData ? ""
                     : (modelData.tooltipTitle !== "" ? modelData.tooltipTitle
                        : (modelData.title !== "" ? modelData.title : modelData.id))

            color: hovered ? Theme.hoverMuted : Theme.surface

            IconImage {
                anchors.centerIn: parent
                width: Theme.fontSize + 4
                height: Theme.fontSize + 4
                source: {
                    var iconName = modelData.icon;
                    if (!iconName) return "";
                    if (iconName.startsWith("file://") || iconName.startsWith("image://")) {
                        return iconName;
                    } else if (iconName.startsWith("/")) {
                        return "file://" + iconName;
                    } else {
                        return "image://icon/" + iconName;
                    }
                }
            }

            onClicked: {
                if (modelData.onlyMenu) {
                    if (modelData.hasMenu) root.menuRequested(modelData, trayItem)
                    else modelData.secondaryActivate()
                } else modelData.activate()
            }

            onRightClicked: {
                if (modelData.hasMenu) {
                    root.menuRequested(modelData, trayItem)
                } else {
                    modelData.secondaryActivate();
                }
            }

            onScrolled: (delta) => {
                modelData.scroll(delta, false);
            }
        }
    }
}
