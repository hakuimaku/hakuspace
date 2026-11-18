import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../../services"
import "../../../config/UiCatalog.js" as UiCatalog
import ".." as ActionMenu

ActionMenu.ActionMenuPage {
    id: root

    title: "Shell Backend"
    subtitle: "Current: " + (currentBackend === "hikai" ? "Hikai" : "Classic")
    icon: "󰆧"
    geometryProfile: "option"

    readonly property var backends: UiCatalog.actionMenuShellBackends
    readonly property string currentBackend: AppState.shellBackend
    property int selectedIndex: 0

    Component.onCompleted: {
        for (var i = 0; i < backends.length; i++) {
            if (backends[i].id === currentBackend) {
                selectedIndex = i;
                break;
            }
        }
    }

    // Launches the headless backend transition without binding it to this ephemeral page.
    function activateBackend(backendId) {
        if (!backendId) return;
        if (backendId === root.currentBackend) {
            root.requestClose();
            return;
        }
        Quickshell.execDetached([Env.binDir + "/haku_backend.sh", "set", backendId]);
        root.requestClose();
    }

    function activateIndex(idx) {
        if (idx < 0 || idx >= backends.length) return;
        activateBackend(backends[idx].id);
    }

    function activateCurrent() {
        activateIndex(root.selectedIndex);
    }

    onScrollPrevious: {
        if (backends.length > 0) {
            root.selectedIndex = Math.max(0, root.selectedIndex - 1);
        }
    }

    onScrollNext: {
        if (backends.length > 0) {
            root.selectedIndex = Math.min(backends.length - 1, root.selectedIndex + 1);
        }
    }

    onSelectedIndexChanged: {
        var it = (backendsRepeater.count > root.selectedIndex && root.selectedIndex >= 0)
            ? backendsRepeater.itemAt(root.selectedIndex)
            : null;
        if (it) selectionPill.targetItem = it;
    }

    Keys.onUpPressed: event => {
        if (backends.length > 0) {
            root.selectedIndex = Math.max(0, root.selectedIndex - 1);
            event.accepted = true;
        }
    }

    Keys.onDownPressed: event => {
        if (backends.length > 0) {
            root.selectedIndex = Math.min(backends.length - 1, root.selectedIndex + 1);
            event.accepted = true;
        }
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Home && backends.length > 0) {
            root.selectedIndex = 0;
            event.accepted = true;
        } else if (event.key === Qt.Key_End && backends.length > 0) {
            root.selectedIndex = backends.length - 1;
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
        id: listCol
        z: 1
        anchors.fill: parent
        spacing: Theme.actionLayerListSpacing

        Repeater {
            id: backendsRepeater
            model: root.backends
            delegate: ActionMenu.ActionMenuButton {
                id: btn
                Layout.fillWidth: true
                icon: modelData.icon
                label: modelData.label
                secondaryText: modelData.secondary
                badge: modelData.id === root.currentBackend ? "Active" : ""
                selected: root.selectedIndex === index
                focused: selected

                Component.onCompleted: {
                    if (selected) selectionPill.targetItem = this;
                }

                onSelectedChanged: {
                    if (selected) selectionPill.targetItem = this;
                }

                onPointerSelected: {
                    if (hovered) root.selectedIndex = index;
                }

                onClicked: {
                    root.selectedIndex = index;
                    root.activateBackend(modelData.id);
                }
            }
        }

        Item {
            Layout.fillHeight: true
        }
    }
}
