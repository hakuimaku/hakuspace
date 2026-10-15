import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Io
import "../../../services"
import ".." as ActionMenu

ActionMenu.ActionMenuPage {
    id: root

    property string mode: ""
    property string modeTitle: "Niri Animation"
    property string modeSubtitle: "Select transition shader"
    property string modeIcon: "󰤕"
    property string currentOption: ""
    property var optionsList: []
    property var options: []
    property int selectedIndex: 0
    property string statusMessage: ""
    property string pendingOption: ""

    title: modeTitle
    subtitle: modeSubtitle
    icon: modeIcon
    geometryProfile: "option"
    canGoBack: true

    // Formats camelCase option names into spaced, readable labels.
    function formatOptionLabel(opt) {
        if (!opt) return "";
        return opt.replace(/([a-z])([A-Z])/g, "$1 $2");
    }

    Component.onCompleted: {
        var opts = [];
        if (root.optionsList && root.optionsList.length > 0) {
            for (var i = 0; i < root.optionsList.length; i++) {
                var it = root.optionsList[i];
                var optName = typeof it === "string" ? it : it.option;
                opts.push(optName);
            }
            root.options = opts;
            var targetIdx = 0;
            for (var j = 0; j < opts.length; j++) {
                if (opts[j] === root.currentOption) {
                    targetIdx = j;
                    break;
                }
            }
            root.selectedIndex = targetIdx;
            optionsListView.positionViewAtIndex(targetIdx, ListView.Center);
        } else if (root.mode) {
            fallbackProc.running = true;
        }
    }

    property string rawFallback: ""
    Process {
        id: fallbackProc
        command: [Env.binDir + "/niri_animation_ctl.sh", "list", "--json"]
        running: false
        stdout: SplitParser {
            onRead: data => {
                root.rawFallback += data;
            }
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                try {
                    var parsed = JSON.parse(root.rawFallback.trim());
                    var opts = [];
                    var activeOpt = "";
                    for (var i = 0; i < parsed.length; i++) {
                        if (parsed[i].mode === root.mode) {
                            opts.push(parsed[i].option);
                            if (parsed[i].active) activeOpt = parsed[i].option;
                        }
                    }
                    root.options = opts;
                    if (activeOpt) root.currentOption = activeOpt;
                    var targetIdx = 0;
                    for (var j = 0; j < opts.length; j++) {
                        if (opts[j] === root.currentOption) {
                            targetIdx = j;
                            break;
                        }
                    }
                    root.selectedIndex = targetIdx;
                    optionsListView.positionViewAtIndex(targetIdx, ListView.Center);
                } catch (e) {}
            }
        }
    }

    Process {
        id: setProc
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                notifyProc.command = [
                    "notify-send",
                    "Niri animation",
                    root.mode.replace("Window", "") + ": " + root.formatOptionLabel(root.pendingOption)
                ];
                notifyProc.running = true;
                root.requestClose();
            } else {
                root.statusMessage = "Failed to select animation (exit " + exitCode + ")";
            }
        }
    }

    Process {
        id: notifyProc
    }

    // Applies selected Niri animation shader via control script.
    function applyOption(optionId) {
        if (!optionId || !root.mode) return;
        root.statusMessage = "";
        root.pendingOption = optionId;
        setProc.command = [Env.binDir + "/niri_animation_ctl.sh", "set", root.mode, optionId];
        setProc.running = true;
    }

    function activateCurrent() {
        if (options.length > 0 && root.selectedIndex < options.length) {
            applyOption(options[root.selectedIndex]);
        }
    }

    onScrollPrevious: {
        if (options.length > 0) {
            root.selectedIndex = Math.max(0, root.selectedIndex - 1);
            optionsListView.positionViewAtIndex(root.selectedIndex, ListView.Contain);
        }
    }

    onScrollNext: {
        if (options.length > 0) {
            root.selectedIndex = Math.min(options.length - 1, root.selectedIndex + 1);
            optionsListView.positionViewAtIndex(root.selectedIndex, ListView.Contain);
        }
    }

    Keys.onUpPressed: event => {
        if (options.length > 0) {
            root.selectedIndex = Math.max(0, root.selectedIndex - 1);
            optionsListView.positionViewAtIndex(root.selectedIndex, ListView.Contain);
            event.accepted = true;
        }
    }

    Keys.onDownPressed: event => {
        if (options.length > 0) {
            root.selectedIndex = Math.min(options.length - 1, root.selectedIndex + 1);
            optionsListView.positionViewAtIndex(root.selectedIndex, ListView.Contain);
            event.accepted = true;
        }
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Home) {
            if (options.length > 0) {
                root.selectedIndex = 0;
                optionsListView.positionViewAtIndex(root.selectedIndex, ListView.Contain);
                event.accepted = true;
            }
        } else if (event.key === Qt.Key_End) {
            if (options.length > 0) {
                root.selectedIndex = options.length - 1;
                optionsListView.positionViewAtIndex(root.selectedIndex, ListView.Contain);
                event.accepted = true;
            }
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

    ColumnLayout {
        anchors.fill: parent
        spacing: Theme.pad

        Text {
            visible: root.statusMessage.length > 0
            text: root.statusMessage
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize - 2
            color: "#ffaa00"
            Layout.alignment: Qt.AlignHCenter
        }

        Text {
            visible: root.options.length === 0
            text: "No animation options available"
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            color: Theme.fgMuted
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: Theme.pad * 2
        }

        ListView {
            id: optionsListView
            visible: root.options.length > 0
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 2
            model: root.options

            ActionMenu.ActionMenuSelectionPill {
                id: selectionPill
                parent: optionsListView.contentItem
                z: 0
            }

            ScrollBar.vertical: ActionMenu.ActionMenuScrollBar {
                id: vbar
            }

            delegate: ActionMenu.ActionMenuButton {
                id: delegateBtn
                z: 1
                width: optionsListView.width - vbar.reservedGutter
                icon: root.modeIcon
                label: root.formatOptionLabel(modelData)
                secondaryText: modelData === root.currentOption ? "Active" : ""
                badge: modelData === root.currentOption ? "Selected" : ""
                selected: root.selectedIndex === index
                focused: selected

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
                    applyOption(modelData);
                }
            }
        }
    }
}
