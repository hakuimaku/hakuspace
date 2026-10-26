import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Io
import "../../../services"
import ".." as ActionMenu

ActionMenu.ActionMenuPage {
    id: root

    title: "Change Accent Color"
    subtitle: "Current: " + Theme.accentSeed
    icon: ""
    geometryProfile: "option"
    canGoBack: true

    property string errorMessage: ""
    property int selectedIndex: 0
    property string customHexInput: ""

    readonly property var allItems: [
        { isPicker: true, label: "Pick Color", secondary: "[Press Enter]", icon: "󰈊", hex: "" },
        { isPicker: false, label: "Slate Blue", secondary: "#7288AE", icon: "", hex: "#7288AE" },
        { isPicker: false, label: "Green", secondary: "#A2CB8B", icon: "", hex: "#A2CB8B" },
        { isPicker: false, label: "Peach", secondary: "#FFB399", icon: "", hex: "#FFB399" },
        { isPicker: false, label: "Yellow", secondary: "#EFBF04", icon: "", hex: "#EFBF04" },
        { isPicker: false, label: "Pink", secondary: "#F9B2D7", icon: "", hex: "#F9B2D7" },
        { isPicker: false, label: "White", secondary: "#FFFFFF", icon: "", hex: "#FFFFFF" },
        { isPicker: false, label: "Grey", secondary: "#BFC9D1", icon: "", hex: "#BFC9D1" }
    ]

    Component.onCompleted: {
        for (var i = 1; i < allItems.length; i++) {
            if (allItems[i].hex.toLowerCase() === Theme.accentSeed.toLowerCase()) {
                selectedIndex = i;
                break;
            }
        }
    }

    Process {
        id: setAccentProc
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                root.requestClose();
            } else {
                root.errorMessage = "Failed to apply accent color (exit " + exitCode + ")";
            }
        }
    }

    Process {
        id: pickerProc
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                root.requestClose();
            } else {
                root.errorMessage = "Failed to launch color picker (exit " + exitCode + ")";
            }
        }
    }

    // Triggers custom color picker or applies the preset accent color.
    function activateItem(idx) {
        if (idx < 0 || idx >= allItems.length) return;
        var item = allItems[idx];
        if (item.isPicker) {
            if (pickerProc.running) return;
            root.errorMessage = "";
            // Detach the interactive picker before closing ActionMenu. The picker
            // intentionally waits briefly before invoking hyprpicker; running it as
            // a page-owned Process would otherwise kill it when this page is destroyed.
            pickerProc.command = [
                "sh",
                "-c",
                'setsid -f "$1" >/dev/null 2>&1',
                "haku-accent-picker",
                Env.binDir + "/accent_color_picker.sh"
            ];
            pickerProc.running = true;
        } else {
            applyAccent(item.hex);
        }
    }

    // Executes theme control script to set system-wide accent color.
    function applyAccent(hex) {
        if (!hex || !hex.match(/^#[0-9a-fA-F]{6}$/)) return;
        root.errorMessage = "";
        setAccentProc.command = [Env.binDir + "/theme_ctl.sh", "set-accent", hex];
        setAccentProc.running = true;
    }

    onScrollPrevious: {
        root.selectedIndex = Math.max(0, root.selectedIndex - 1);
        accentList.positionViewAtIndex(root.selectedIndex, ListView.Contain);
    }

    onScrollNext: {
        root.selectedIndex = Math.min(allItems.length - 1, root.selectedIndex + 1);
        accentList.positionViewAtIndex(root.selectedIndex, ListView.Contain);
    }

    Keys.onUpPressed: event => {
        root.selectedIndex = Math.max(0, root.selectedIndex - 1);
        accentList.positionViewAtIndex(root.selectedIndex, ListView.Contain);
        event.accepted = true;
    }

    Keys.onDownPressed: event => {
        root.selectedIndex = Math.min(allItems.length - 1, root.selectedIndex + 1);
        accentList.positionViewAtIndex(root.selectedIndex, ListView.Contain);
        event.accepted = true;
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Home) {
            root.selectedIndex = 0;
            accentList.positionViewAtIndex(root.selectedIndex, ListView.Contain);
            event.accepted = true;
        } else if (event.key === Qt.Key_End) {
            root.selectedIndex = allItems.length - 1;
            accentList.positionViewAtIndex(root.selectedIndex, ListView.Contain);
            event.accepted = true;
        }
    }

    // Activates currently focused accent color item.
    function activateCurrent() {
        activateItem(root.selectedIndex);
    }

    Keys.onReturnPressed: event => {
        activateCurrent();
        event.accepted = true;
    }

    Keys.onEnterPressed: event => {
        activateCurrent();
        event.accepted = true;
    }

    Keys.onTabPressed: event => {
        hexInput.forceActiveFocus();
        event.accepted = true;
    }

    Keys.onBacktabPressed: event => {
        hexInput.forceActiveFocus();
        event.accepted = true;
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Theme.spaceMd

        // Error message banner
        Text {
            visible: root.errorMessage.length > 0
            text: root.errorMessage
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            color: Theme.danger
            Layout.alignment: Qt.AlignHCenter
        }

        // Custom Hex input row
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Theme.comfortableControlHeight
            radius: Theme.radius
            color: Theme.surface
            border.color: hexInput.activeFocus ? Theme.accent : Theme.hoverMuted
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.spaceLg
                anchors.rightMargin: Theme.spaceLg
                spacing: Theme.spaceMd

                Rectangle {
                    width: 16
                    height: 16
                    radius: 8
                    color: hexInput.text.match(/^#[0-9a-fA-F]{6}$/) ? hexInput.text : Theme.accent
                }

                TextInput {
                    id: hexInput
                    Layout.fillWidth: true
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize - 1
                    color: Theme.fg
                    clip: true
                    selectByMouse: true
                    selectionColor: Theme.accent
                    selectedTextColor: Theme.onAccentColor
                    Accessible.name: "Custom accent color"

                    Text {
                        anchors.fill: parent
                        text: "Custom #RRGGBB..."
                        font.family: parent.font.family
                        font.pixelSize: parent.font.pixelSize
                        color: Theme.fgMuted
                        visible: !parent.text
                    }
                    onAccepted: {
                        if (text.match(/^#[0-9a-fA-F]{6}$/)) {
                            applyAccent(text);
                        }
                    }
                    Keys.onUpPressed: event => {
                        root.selectedIndex = Math.max(0, root.selectedIndex - 1);
                        accentList.positionViewAtIndex(root.selectedIndex, ListView.Contain);
                        event.accepted = true;
                    }
                    Keys.onDownPressed: event => {
                        root.selectedIndex = Math.min(allItems.length - 1, root.selectedIndex + 1);
                        accentList.positionViewAtIndex(root.selectedIndex, ListView.Contain);
                        event.accepted = true;
                    }
                    Keys.onTabPressed: event => {
                        root.forceActiveFocus();
                        event.accepted = true;
                    }
                    Keys.onBacktabPressed: event => {
                        root.forceActiveFocus();
                        event.accepted = true;
                    }
                    Keys.onEscapePressed: event => {
                        if (text.length > 0) {
                            text = "";
                            event.accepted = true;
                        } else {
                            event.accepted = false;
                        }
                    }
                }
            }
        }

        // Accent & Picker list
        ListView {
            id: accentList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: Theme.spaceXs
            model: root.allItems

            ActionMenu.ActionMenuSelectionPill {
                id: selectionPill
                parent: accentList.contentItem
                z: 0
            }

            ScrollBar.vertical: ActionMenu.ActionMenuScrollBar {
                id: vbar
            }

            delegate: ActionMenu.ActionMenuButton {
                id: delegateBtn
                z: 1
                width: accentList.width - vbar.reservedGutter
                icon: modelData.icon
                label: modelData.label
                secondaryText: modelData.secondary
                selected: root.selectedIndex === index
                focused: selected

                badge: !modelData.isPicker && modelData.hex.toLowerCase() === Theme.accentSeed.toLowerCase() ? "Active" : ""
                badgeColor: modelData.hex ? modelData.hex : Theme.accent

                Component.onCompleted: {
                    if (selected) selectionPill.targetItem = this;
                }
                onSelectedChanged: {
                    if (selected) selectionPill.targetItem = this;
                }
                onPointerSelected: {
                    if (hovered) {
                        root.selectedIndex = index;
                    }
                }

                onClicked: {
                    root.selectedIndex = index;
                    activateItem(index);
                }
            }
        }
    }
}
