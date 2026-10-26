import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import "../../../services"
import ".." as ActionMenu

ActionMenu.ActionMenuPage {
    id: root

    title: "Change Font Size"
    subtitle: "Current: " + Theme.fontSize + " px"
    icon: ""
    geometryProfile: "option"
    canGoBack: true

    readonly property var sizes: [10, 12, 14, 16, 18]
    property int selectedIndex: 0

    Component.onCompleted: {
        for (var i = 0; i < sizes.length; i++) {
            if (sizes[i] === Theme.fontSize) {
                selectedIndex = i;
                break;
            }
        }
    }

    property string errorMessage: ""

    Process {
        id: setSizeProc
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                root.requestClose();
            } else {
                root.errorMessage = "Failed to set font size (exit " + exitCode + ")";
            }
        }
    }

    // Executes theme control script to set system font size point value.
    function applySize(sz) {
        root.errorMessage = "";
        setSizeProc.command = [Env.binDir + "/theme_ctl.sh", "set-size", String(sz)];
        setSizeProc.running = true;
    }

    onScrollPrevious: {
        root.selectedIndex = Math.max(0, root.selectedIndex - 1);
    }

    onScrollNext: {
        root.selectedIndex = Math.min(sizes.length - 1, root.selectedIndex + 1);
    }

    onSelectedIndexChanged: {
        var it = (sizesRepeater.count > root.selectedIndex && root.selectedIndex >= 0)
            ? sizesRepeater.itemAt(root.selectedIndex)
            : null;
        if (it) selectionPill.targetItem = it;
    }

    Keys.onUpPressed: event => {
        root.selectedIndex = Math.max(0, root.selectedIndex - 1);
        event.accepted = true;
    }

    Keys.onDownPressed: event => {
        root.selectedIndex = Math.min(sizes.length - 1, root.selectedIndex + 1);
        event.accepted = true;
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Home) {
            root.selectedIndex = 0;
            event.accepted = true;
        } else if (event.key === Qt.Key_End) {
            root.selectedIndex = sizes.length - 1;
            event.accepted = true;
        }
    }

    // Applies the currently selected font size value.
    function activateCurrent() {
        if (root.selectedIndex >= 0 && root.selectedIndex < sizes.length) {
            applySize(sizes[root.selectedIndex]);
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
        id: col
        z: 1
        anchors.fill: parent
        spacing: Theme.spaceSm

        // Error message banner
        Text {
            visible: root.errorMessage.length > 0
            text: root.errorMessage
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            color: Theme.danger
            Layout.alignment: Qt.AlignHCenter
        }

        Repeater {
            id: sizesRepeater
            model: root.sizes
            delegate: ActionMenu.ActionMenuButton {
                id: sizeBtn
                Layout.fillWidth: true
                icon: ""
                label: modelData + " px"
                secondaryText: modelData === Theme.fontSize ? "Active" : ""
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
                    applySize(modelData);
                }
            }
        }

        Item {
            Layout.fillHeight: true
        }
    }
}
