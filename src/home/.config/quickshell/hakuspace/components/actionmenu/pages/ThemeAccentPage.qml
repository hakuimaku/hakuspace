import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import "../../../services"
import ".." as ActionMenu

ActionMenu.ActionMenuPage {
    id: root

    title: "Change Accent Color"
    subtitle: "Current: " + Theme.accent
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
            if (allItems[i].hex.toLowerCase() === Theme.accent.toLowerCase()) {
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
    }

    function activateItem(idx) {
        if (idx < 0 || idx >= allItems.length) return;
        var item = allItems[idx];
        if (item.isPicker) {
            pickerProc.command = [Env.binDir + "/accent_color_picker.sh"];
            pickerProc.running = true;
            root.requestClose();
        } else {
            applyAccent(item.hex);
        }
    }

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
        spacing: Theme.pad

        // Error message banner
        Text {
            visible: root.errorMessage.length > 0
            text: root.errorMessage
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            color: "#ff6b6b"
            Layout.alignment: Qt.AlignHCenter
        }

        // Custom Hex input row
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.max(34, Theme.fontSize * 2.2)
            radius: Theme.radiusSm
            color: Qt.rgba(1, 1, 1, 0.06)
            border.color: hexInput.activeFocus ? Theme.accent : "transparent"
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.pad
                anchors.rightMargin: Theme.pad
                spacing: Theme.pad

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
                    font.pixelSize: Theme.fontSize
                    color: Theme.fg

                    Text {
                        anchors.fill: parent
                        text: "Custom #RRGGBB..."
                        font.family: parent.font.family
                        font.pixelSize: parent.font.pixelSize
                        color: Theme.fgMuted
                        visible: !parent.text && !parent.activeFocus
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
            spacing: 2
            model: root.allItems

            ActionMenu.ActionMenuSelectionPill {
                id: selectionPill
                parent: accentList.contentItem
                z: 0
            }

            delegate: ActionMenu.ActionMenuButton {
                id: delegateBtn
                z: 1
                width: accentList.width
                icon: modelData.icon
                label: modelData.label
                secondaryText: modelData.secondary
                selected: root.selectedIndex === index
                focused: selected

                badge: !modelData.isPicker && modelData.hex.toLowerCase() === Theme.accent.toLowerCase() ? "Active" : ""
                badgeColor: modelData.hex ? modelData.hex : Theme.accent

                Component.onCompleted: {
                    if (selected) selectionPill.targetItem = this;
                }
                onSelectedChanged: {
                    if (selected) selectionPill.targetItem = this;
                }
                onHoveredChanged: {
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
