import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import "../../services"
import "../base"
import "../"

Grid {
    id: root
    // Tray ordering and native actions are shared across both orientations.
    property bool vertical: false
    columns: vertical ? 1 : Math.max(1, trayRepeater.count + 2)
    spacing: vertical ? Math.max(2, Math.ceil(Theme.fontSize / 7)) : Theme.gap
    // Trim four pixels from each vertical inset while preserving the pointer width.
    readonly property real verticalControlHeight: ScreenGeometry.leftTouchSize - 8
    property var menuOpenItem: null
    signal menuRequested(var item, var anchor)

    Item { width: 4; height: 1; visible: !root.vertical && trayRepeater.count > 0 }

    Repeater {
        id: trayRepeater
        model: SystemTray.items

        TopModule {
            id: trayItem
            hoverAxis: root.vertical ? "vertical" : "horizontal"
            implicitWidth: root.vertical ? ScreenGeometry.leftTouchSize : implicitHeight
            implicitHeight: root.vertical ? root.verticalControlHeight : Theme.fontSize * 1.8
            tooltip: root.menuOpenItem === modelData ? ""
                     : (modelData.tooltipTitle !== "" ? modelData.tooltipTitle
                        : (modelData.title !== "" ? modelData.title : modelData.id))

            color: hovered ? Theme.hoverMuted : Theme.surface

            IconImage {
                anchors.centerIn: parent
                width: root.vertical ? ScreenGeometry.leftIconSize : Theme.fontSize + 4
                height: width
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
                    if (modelData.hasMenu) root.menuRequested(modelData, trayItem.interactionItem)
                    else modelData.secondaryActivate()
                } else modelData.activate()
            }

            onRightClicked: {
                if (modelData.hasMenu) {
                    root.menuRequested(modelData, trayItem.interactionItem)
                } else {
                    modelData.secondaryActivate();
                }
            }

            onScrolled: (delta) => {
                modelData.scroll(delta, false);
            }
        }
    }

    Item { width: 4; height: 1; visible: !root.vertical && trayRepeater.count > 0 }
}
