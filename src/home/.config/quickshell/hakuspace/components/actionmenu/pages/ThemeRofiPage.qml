import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Io
import "../../../services"
import ".." as ActionMenu

ActionMenu.ActionMenuPage {
    id: root

    title: "Change Rofi Theme"
    subtitle: "Rofi launcher styling"
    icon: ""
    geometryProfile: "option"
    canGoBack: true

    property var themes: []
    property string currentTheme: ""
    property int selectedIndex: 0
    property string rawList: ""
    property var _pendingThemes: []
    property bool loading: true
    property bool showLoadingIndicator: false

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
        command: [Env.binDir + "/rofi_theme_ctl.sh", "current"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                var c = data.trim();
                if (c) root.currentTheme = c;
            }
        }
    }

    Process {
        id: listProc
        command: [Env.binDir + "/rofi_theme_ctl.sh", "list"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                var t = data.trim();
                if (t && root._pendingThemes.indexOf(t) === -1) {
                    root._pendingThemes.push(t);
                }
            }
        }
        onExited: {
            root.themes = root._pendingThemes.slice();
            var targetIdx = 0;
            for (var j = 0; j < root.themes.length; j++) {
                if (root.themes[j] === root.currentTheme) {
                    targetIdx = j;
                    break;
                }
            }
            root.selectedIndex = targetIdx;
            themesList.positionViewAtIndex(targetIdx, ListView.Center);
            root.loading = false;
        }
    }

    property string errorMessage: ""

    Process {
        id: setProc
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                root.requestClose();
            } else {
                root.errorMessage = "Failed to set Rofi theme (exit " + exitCode + ")";
            }
        }
    }

    // Applies selected Rofi theme preset via control script.
    function applyTheme(themeId) {
        if (!themeId) return;
        root.errorMessage = "";
        setProc.command = [Env.binDir + "/rofi_theme_ctl.sh", "set", themeId];
        setProc.running = true;
    }

    onScrollPrevious: {
        if (themes.length > 0) {
            root.selectedIndex = Math.max(0, root.selectedIndex - 1);
            themesList.positionViewAtIndex(root.selectedIndex, ListView.Contain);
        }
    }

    onScrollNext: {
        if (themes.length > 0) {
            root.selectedIndex = Math.min(themes.length - 1, root.selectedIndex + 1);
            themesList.positionViewAtIndex(root.selectedIndex, ListView.Contain);
        }
    }

    Keys.onUpPressed: event => {
        if (themes.length > 0) {
            root.selectedIndex = Math.max(0, root.selectedIndex - 1);
            themesList.positionViewAtIndex(root.selectedIndex, ListView.Contain);
            event.accepted = true;
        }
    }

    Keys.onDownPressed: event => {
        if (themes.length > 0) {
            root.selectedIndex = Math.min(themes.length - 1, root.selectedIndex + 1);
            themesList.positionViewAtIndex(root.selectedIndex, ListView.Contain);
            event.accepted = true;
        }
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Home) {
            if (themes.length > 0) {
                root.selectedIndex = 0;
                themesList.positionViewAtIndex(root.selectedIndex, ListView.Contain);
                event.accepted = true;
            }
        } else if (event.key === Qt.Key_End) {
            if (themes.length > 0) {
                root.selectedIndex = themes.length - 1;
                themesList.positionViewAtIndex(root.selectedIndex, ListView.Contain);
                event.accepted = true;
            }
        }
    }

    // Applies the currently highlighted Rofi theme option.
    function activateCurrent() {
        if (themes.length > 0 && root.selectedIndex < themes.length) {
            applyTheme(themes[root.selectedIndex]);
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

        // Error message banner
        Text {
            visible: root.errorMessage.length > 0
            text: root.errorMessage
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            color: "#ff6b6b"
            Layout.alignment: Qt.AlignHCenter
        }

        // Loading state indicator
        Text {
            visible: root.loading && root.showLoadingIndicator
            text: "Loading Rofi themes..."
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            color: Theme.fgMuted
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: Theme.pad * 2
        }

        // Empty state indicator
        Text {
            visible: !root.loading && root.themes.length === 0
            text: "No themes found"
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            color: Theme.fgMuted
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: Theme.pad * 2
        }

        ListView {
            id: themesList
            visible: root.themes.length > 0
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
            model: root.themes

            ActionMenu.ActionMenuSelectionPill {
                id: selectionPill
                parent: themesList.contentItem
                z: 0
            }

            ScrollBar.vertical: ActionMenu.ActionMenuScrollBar {
                id: vbar
            }

            delegate: ActionMenu.ActionMenuButton {
                id: delegateBtn
                z: 1
                width: themesList.width - vbar.reservedGutter
                icon: ""
                label: modelData
                secondaryText: modelData === root.currentTheme ? "Active" : ""
                selected: root.selectedIndex === index
                focused: selected

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
                    applyTheme(modelData);
                }
            }
        }
    }
}
