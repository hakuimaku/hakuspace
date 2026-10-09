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

    Repeater {
        model: SystemTray.items

        TopModule {
            id: trayItem
            // We use implicitHeight for width to make it a square
            implicitWidth: implicitHeight
            tooltip: modelData.tooltipTitle !== "" ? modelData.tooltipTitle : (modelData.title !== "" ? modelData.title : modelData.id)

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
