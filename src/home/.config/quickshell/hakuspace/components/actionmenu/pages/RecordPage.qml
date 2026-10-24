import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../../services"
import ".." as ActionMenu

ActionMenu.ActionMenuPage {
    id: root

    title: "Screen Recording"
    subtitle: "Select capture mode"
    icon: "󰕧"
    geometryProfile: "option"

    signal pushSubmenu(string pageUrl, var props, var seedGeom, string profile)

    property int selectedIndex: 0

    readonly property var modes: [
        {
            id: "system-audio",
            icon: "󰕧",
            label: "Only Sound",
            secondary: "Screen + System Audio",
            isSubmenu: false
        },
        {
            id: "mic-system",
            icon: "󰍬",
            label: "Micro and Sound",
            secondary: "Screen + Mic + System",
            isSubmenu: true
        },
        {
            id: "no-audio",
            icon: "󰕭",
            label: "No Sound",
            secondary: "Video Only",
            isSubmenu: false
        }
    ]

    // Triggers recording mode launch or pushes the audio source submenu.
    function activateIndex(idx) {
        if (idx < 0 || idx >= modes.length) return;
        var mode = modes[idx];
        var btn = modesRepeater.itemAt(idx);

        if (mode.isSubmenu) {
            var geom = btn && btn.getSurfaceGeometry ? btn.getSurfaceGeometry() : null;
            root.pushSubmenu("pages/RecordSourcePage.qml", {}, geom, "option");
        } else {
            Quickshell.execDetached([Env.binDir + "/record_ctl.sh", "start", mode.id]);
            root.requestClose();
        }
    }

    onScrollPrevious: {
        root.selectedIndex = Math.max(0, root.selectedIndex - 1);
    }

    onScrollNext: {
        root.selectedIndex = Math.min(modes.length - 1, root.selectedIndex + 1);
    }

    onSelectedIndexChanged: {
        var it = (modesRepeater.count > root.selectedIndex && root.selectedIndex >= 0)
            ? modesRepeater.itemAt(root.selectedIndex)
            : null;
        if (it) selectionPill.targetItem = it;
    }

    Keys.onUpPressed: event => {
        root.selectedIndex = Math.max(0, root.selectedIndex - 1);
        event.accepted = true;
    }

    Keys.onDownPressed: event => {
        root.selectedIndex = Math.min(modes.length - 1, root.selectedIndex + 1);
        event.accepted = true;
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Home) {
            root.selectedIndex = 0;
            event.accepted = true;
        } else if (event.key === Qt.Key_End) {
            root.selectedIndex = modes.length - 1;
            event.accepted = true;
        }
    }

    // Executes currently selected recording option.
    function activateCurrent() {
        activateIndex(root.selectedIndex);
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
        id: listCol
        z: 1
        anchors.fill: parent
        spacing: Theme.pad

        Repeater {
            id: modesRepeater
            model: root.modes
            delegate: ActionMenu.ActionMenuButton {
                id: btn
                Layout.fillWidth: true
                icon: modelData.icon
                label: modelData.label
                secondaryText: modelData.secondary
                hasSubmenu: modelData.isSubmenu
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

                onPointerSelected: {
                    if (hovered) {
                        root.selectedIndex = index;
                    }
                }

                onClicked: {
                    root.selectedIndex = index;
                    var geom = getSurfaceGeometry();
                    if (modelData.isSubmenu) {
                        root.pushSubmenu("pages/RecordSourcePage.qml", {}, geom, "option");
                    } else {
                        Quickshell.execDetached([Env.binDir + "/record_ctl.sh", "start", modelData.id]);
                        root.requestClose();
                    }
                }
            }
        }

        Item {
            Layout.fillHeight: true
        }
    }
}
