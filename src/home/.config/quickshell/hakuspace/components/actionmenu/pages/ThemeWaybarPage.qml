import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import "../../../services"
import ".." as ActionMenu

ActionMenu.ActionMenuPage {
    id: root

    title: "Change Waybar Theme"
    subtitle: "Waybar variant layout"
    icon: ""
    geometryProfile: "option"
    canGoBack: true

    property var modes: []
    property string currentMode: ""
    property int selectedIndex: 0
    property string rawList: ""
    property var _pendingModes: []
    property bool loading: true
    property bool showLoadingIndicator: false
    property string statusMessage: ""

    Timer {
        id: loadingDelayTimer
        interval: 120
        running: root.loading
        onTriggered: {
            if (root.loading) root.showLoadingIndicator = true;
        }
    }

    Process {
        id: currentProc
        command: [Env.binDir + "/waybar_ctl.sh", "current"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                var c = data.trim();
                if (c) root.currentMode = c;
            }
        }
    }

    Process {
        id: listProc
        command: [Env.binDir + "/waybar_ctl.sh", "list"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                var m = data.trim();
                if (m && root._pendingModes.indexOf(m) === -1) {
                    root._pendingModes.push(m);
                }
            }
        }
        onExited: {
            root.modes = root._pendingModes.slice();
            var targetIdx = 0;
            for (var j = 0; j < root.modes.length; j++) {
                if (root.modes[j] === root.currentMode) {
                    targetIdx = j;
                    break;
                }
            }
            root.selectedIndex = targetIdx;
            modesList.positionViewAtIndex(targetIdx, ListView.Center);
            root.loading = false;
        }
    }

    Process {
        id: setProc
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                root.requestClose();
            } else {
                root.statusMessage = "Failed to select Waybar configuration (exit " + exitCode + ")";
            }
        }
    }

    // Applies selected Waybar layout configuration via waybar control script.
    function applyMode(modeId) {
        if (!modeId) return;
        root.statusMessage = "";
        setProc.command = [Env.binDir + "/waybar_ctl.sh", "select-config", modeId];
        setProc.running = true;
    }

    onScrollPrevious: {
        if (modes.length > 0) {
            root.selectedIndex = Math.max(0, root.selectedIndex - 1);
            modesList.positionViewAtIndex(root.selectedIndex, ListView.Contain);
        }
    }

    onScrollNext: {
        if (modes.length > 0) {
            root.selectedIndex = Math.min(modes.length - 1, root.selectedIndex + 1);
            modesList.positionViewAtIndex(root.selectedIndex, ListView.Contain);
        }
    }

    Keys.onUpPressed: event => {
        if (modes.length > 0) {
            root.selectedIndex = Math.max(0, root.selectedIndex - 1);
            modesList.positionViewAtIndex(root.selectedIndex, ListView.Contain);
            event.accepted = true;
        }
    }

    Keys.onDownPressed: event => {
        if (modes.length > 0) {
            root.selectedIndex = Math.min(modes.length - 1, root.selectedIndex + 1);
            modesList.positionViewAtIndex(root.selectedIndex, ListView.Contain);
            event.accepted = true;
        }
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Home) {
            if (modes.length > 0) {
                root.selectedIndex = 0;
                modesList.positionViewAtIndex(root.selectedIndex, ListView.Contain);
                event.accepted = true;
            }
        } else if (event.key === Qt.Key_End) {
            if (modes.length > 0) {
                root.selectedIndex = modes.length - 1;
                modesList.positionViewAtIndex(root.selectedIndex, ListView.Contain);
                event.accepted = true;
            }
        }
    }

    // Applies currently focused Waybar mode item.
    function activateCurrent() {
        if (modes.length > 0 && root.selectedIndex < modes.length) {
            applyMode(modes[root.selectedIndex]);
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

        // Loading state indicator
        Text {
            visible: root.loading && root.showLoadingIndicator
            text: "Loading Waybar layouts..."
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            color: Theme.fgMuted
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: Theme.pad * 2
        }

        // Empty state indicator
        Text {
            visible: !root.loading && root.modes.length === 0
            text: "No configurations found"
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            color: Theme.fgMuted
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: Theme.pad * 2
        }

        ListView {
            id: modesList
            visible: root.modes.length > 0
            opacity: root.loading ? 0.0 : 1.0
            Behavior on opacity {
                NumberAnimation {
                    duration: HAnimation.actionLayerDataFadeDuration
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: HAnimation.actionLayerDataFadeCurve
                }
            }
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 2
            model: root.modes

            ActionMenu.ActionMenuSelectionPill {
                id: selectionPill
                parent: modesList.contentItem
                z: 0
            }

            delegate: ActionMenu.ActionMenuButton {
                id: delegateBtn
                z: 1
                width: modesList.width
                icon: ""
                label: modelData
                secondaryText: modelData === root.currentMode ? "Active" : ""
                badge: modelData === "top" ? "Hikai" : "Classic"
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
                    applyMode(modelData);
                }
            }
        }
    }
}
