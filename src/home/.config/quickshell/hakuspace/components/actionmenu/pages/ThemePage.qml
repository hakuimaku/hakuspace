import QtQuick
import QtQuick.Layouts
import "../../../services"
import ".." as ActionMenu

ActionMenu.ActionMenuPage {
    id: root

    title: "Change Theme"
    subtitle: "Customise appearance & styling"
    icon: ""
    geometryProfile: "option"

    signal pushSubmenu(string pageUrl, var props, var seedGeom, string profile)

    property int selectedIndex: 0

    readonly property var items: [
        {
            id: "waybar",
            icon: "",
            label: "Change Waybar Theme",
            secondary: "Waybar Panel",
            page: "pages/ThemeWaybarPage.qml"
        },
        {
            id: "rofi",
            icon: "",
            label: "Change Rofi Theme",
            secondary: "Rofi Launcher",
            page: "pages/ThemeRofiPage.qml"
        },
        {
            id: "font",
            icon: "",
            label: "Change Font",
            secondary: Theme.fontFamily,
            page: "pages/ThemeFontPage.qml"
        },
        {
            id: "size",
            icon: "",
            label: "Change Font Size",
            secondary: Theme.fontSize + "px",
            page: "pages/ThemeFontSizePage.qml"
        },
        {
            id: "accent",
            icon: "",
            label: "Change Accent Color",
            secondary: Theme.accent,
            page: "pages/ThemeAccentPage.qml"
        }
    ]

    // Pushes corresponding theme configuration submenu onto stack with seed geometry.
    function activateIndex(idx) {
        if (idx < 0 || idx >= items.length) return;
        var item = items[idx];
        var btn = itemsCol.children[idx];
        var geom = btn && btn.getSurfaceGeometry ? btn.getSurfaceGeometry() : null;
        root.pushSubmenu(item.page, {}, geom, "option");
    }

    // Activates currently focused theme category.
    function activateCurrent() {
        activateIndex(root.selectedIndex);
    }

    onScrollPrevious: {
        root.selectedIndex = Math.max(0, root.selectedIndex - 1);
    }

    onScrollNext: {
        root.selectedIndex = Math.min(items.length - 1, root.selectedIndex + 1);
    }

    onSelectedIndexChanged: {
        var it = (itemsRepeater.count > root.selectedIndex && root.selectedIndex >= 0)
            ? itemsRepeater.itemAt(root.selectedIndex)
            : null;
        if (it) selectionPill.targetItem = it;
    }

    Keys.onUpPressed: event => {
        root.selectedIndex = Math.max(0, root.selectedIndex - 1);
        event.accepted = true;
    }

    Keys.onDownPressed: event => {
        root.selectedIndex = Math.min(items.length - 1, root.selectedIndex + 1);
        event.accepted = true;
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Home) {
            root.selectedIndex = 0;
            event.accepted = true;
        } else if (event.key === Qt.Key_End) {
            root.selectedIndex = items.length - 1;
            event.accepted = true;
        }
    }

    Keys.onReturnPressed: event => {
        activateCurrent();
        event.accepted = true;
    }

    Keys.onEnterPressed: event => {
        activateCurrent();
        event.accepted = true;
    }

    ActionMenu.ActionMenuSelectionPill {
        id: selectionPill
        z: 0
    }

    ColumnLayout {
        id: itemsCol
        z: 1
        anchors.fill: parent
        spacing: Theme.pad

        Repeater {
            id: itemsRepeater
            model: root.items
            delegate: ActionMenu.ActionMenuButton {
                id: itemBtn
                Layout.fillWidth: true
                icon: modelData.icon
                label: modelData.label
                secondaryText: modelData.secondary
                hasSubmenu: true
                selected: root.selectedIndex === index
                focused: selected

                Component.onCompleted: {
                    if (selected) {
                        selectionPill.targetItem = this;
                    }
                }

                onSelectedChanged: {
                    if (selected) {
                        selectionPill.targetItem = this;
                    }
                }

                onHoveredChanged: {
                    if (hovered) {
                        root.selectedIndex = index;
                    }
                }

                onClicked: {
                    root.selectedIndex = index;
                    var geom = getSurfaceGeometry();
                    root.pushSubmenu(modelData.page, {}, geom, "option");
                }
            }
        }

        Item {
            Layout.fillHeight: true
        }
    }
}
