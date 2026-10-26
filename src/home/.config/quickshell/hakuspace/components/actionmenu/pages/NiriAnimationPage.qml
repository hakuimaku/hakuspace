import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Io
import "../../../services"
import ".." as ActionMenu

ActionMenu.ActionMenuPage {
    id: root

    title: "Niri Animation"
    subtitle: "Window transition shaders"
    icon: "󰤕"
    geometryProfile: "option"

    signal pushSubmenu(string pageUrl, var props, var seedGeom, string profile)

    property var modes: []
    property int selectedIndex: 0
    property bool loading: true
    property bool showLoadingIndicator: false
    property string statusMessage: ""
    property string rawOutput: ""

    // Formats camelCase option names into spaced, readable labels.
    function formatOptionLabel(opt) {
        if (!opt) return "";
        return opt.replace(/([a-z])([A-Z])/g, "$1 $2");
    }

    Timer {
        id: loadingDelayTimer
        interval: 120
        running: root.loading
        onTriggered: {
            if (root.loading) root.showLoadingIndicator = true;
        }
    }

    function reload() {
        root.rawOutput = "";
        root.loading = true;
        listProc.running = false;
        listProc.running = true;
    }

    Process {
        id: listProc
        command: [Env.binDir + "/niri_animation_ctl.sh", "list", "--json"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                root.rawOutput += data;
            }
        }
        onExited: (exitCode, exitStatus) => {
            root.loading = false;
            if (exitCode !== 0) {
                root.statusMessage = "Niri is currently not in use or animations unavailable";
                return;
            }
            try {
                var parsed = JSON.parse(root.rawOutput.trim());
                if (!Array.isArray(parsed) || parsed.length === 0) {
                    root.statusMessage = "No animation entries found";
                    return;
                }
                var map = {};
                var order = [];
                for (var i = 0; i < parsed.length; i++) {
                    var entry = parsed[i];
                    var m = entry.mode;
                    if (!map[m]) {
                        map[m] = {
                            id: m,
                            label: m === "WindowOpen" ? "Window Open Animation" : (m === "WindowClose" ? "Window Close Animation" : m),
                            icon: m === "WindowOpen" ? "󰐕" : (m === "WindowClose" ? "󰅖" : "󰤕"),
                            activeOption: "",
                            options: []
                        };
                        order.push(m);
                    }
                    map[m].options.push({
                        option: entry.option,
                        active: entry.active
                    });
                    if (entry.active) {
                        map[m].activeOption = entry.option;
                    }
                }
                var result = [];
                for (var j = 0; j < order.length; j++) {
                    var item = map[order[j]];
                    result.push({
                        id: item.id,
                        label: item.label,
                        icon: item.icon,
                        activeOption: item.activeOption,
                        secondary: item.activeOption ? root.formatOptionLabel(item.activeOption) : "None",
                        options: item.options
                    });
                }
                root.modes = result;
                if (root.selectedIndex >= result.length) {
                    root.selectedIndex = 0;
                }
                root.statusMessage = "";
            } catch (e) {
                root.statusMessage = "Failed to parse animation data";
            }
        }
    }

    onVisibleChanged: {
        if (visible && !loading) {
            reload();
        }
    }

    // Pushes corresponding animation mode options submenu onto navigation stack.
    function activateIndex(idx) {
        if (idx < 0 || idx >= modes.length) return;
        var modeItem = modes[idx];
        var btn = modesRepeater.itemAt(idx);
        var geom = btn && btn.getSurfaceGeometry ? btn.getSurfaceGeometry() : null;
        root.pushSubmenu("pages/NiriAnimationOptionPage.qml", {
            mode: modeItem.id,
            modeTitle: modeItem.label,
            modeSubtitle: modeItem.id === "WindowOpen" ? "Select open transition shader" : "Select close transition shader",
            modeIcon: modeItem.icon,
            currentOption: modeItem.activeOption,
            optionsList: modeItem.options
        }, geom, "option");
    }

    function activateCurrent() {
        activateIndex(root.selectedIndex);
    }

    onScrollPrevious: {
        if (modes.length > 0) {
            root.selectedIndex = Math.max(0, root.selectedIndex - 1);
        }
    }

    onScrollNext: {
        if (modes.length > 0) {
            root.selectedIndex = Math.min(modes.length - 1, root.selectedIndex + 1);
        }
    }

    onSelectedIndexChanged: {
        var it = (modesRepeater.count > root.selectedIndex && root.selectedIndex >= 0)
            ? modesRepeater.itemAt(root.selectedIndex)
            : null;
        if (it) selectionPill.targetItem = it;
    }

    Keys.onUpPressed: event => {
        if (modes.length > 0) {
            root.selectedIndex = Math.max(0, root.selectedIndex - 1);
            event.accepted = true;
        }
    }

    Keys.onDownPressed: event => {
        if (modes.length > 0) {
            root.selectedIndex = Math.min(modes.length - 1, root.selectedIndex + 1);
            event.accepted = true;
        }
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Home) {
            if (modes.length > 0) {
                root.selectedIndex = 0;
                event.accepted = true;
            }
        } else if (event.key === Qt.Key_End) {
            if (modes.length > 0) {
                root.selectedIndex = modes.length - 1;
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

    ActionMenu.ActionMenuSelectionPill {
        id: selectionPill
        z: 0
    }

    ColumnLayout {
        id: modesCol
        z: 1
        anchors.fill: parent
        spacing: Theme.pad

        Text {
            visible: root.statusMessage.length > 0
            text: root.statusMessage
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize - 2
            color: Theme.warning
            Layout.alignment: Qt.AlignHCenter
        }

        Text {
            visible: root.loading && root.showLoadingIndicator
            text: "Loading Niri animations..."
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            color: Theme.fgMuted
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: Theme.pad * 2
        }

        Repeater {
            id: modesRepeater
            model: root.modes
            delegate: ActionMenu.ActionMenuButton {
                id: modeBtn
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

                onPointerSelected: {
                    if (hovered) {
                        root.selectedIndex = index;
                    }
                }

                onClicked: {
                    root.selectedIndex = index;
                    root.activateIndex(index);
                }
            }
        }

        Item {
            Layout.fillHeight: true
        }
    }
}
