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

    Item { width: 4; height: 1; visible: SystemTray.items.length > 0 }

    Repeater {
        model: SystemTray.items

        TopModule {
            id: trayItem
            implicitWidth: implicitHeight
            tooltip: modelData.tooltipTitle !== "" ? modelData.tooltipTitle : (modelData.title !== "" ? modelData.title : modelData.id)

            color: hovered ? Qt.rgba(1, 1, 1, 0.1) : "transparent"

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
                modelData.activate();
            }

            onRightClicked: {
                if (modelData.hasMenu) {
                    var map = trayItem.mapToItem(null, 0, trayItem.height);
                    modelData.display(trayItem.Window.window, map.x, map.y);
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
