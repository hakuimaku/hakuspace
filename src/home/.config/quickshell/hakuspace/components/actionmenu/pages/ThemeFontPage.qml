import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Io
import "../../../services"
import ".." as ActionMenu

ActionMenu.ActionMenuPage {
    id: root

    title: "Change Font"
    subtitle: "Current: " + Theme.fontFamily
    icon: ""
    geometryProfile: "option"
    canGoBack: true

    property var allFonts: []
    property var filteredFonts: []
    property string searchQuery: ""
    property int selectedIndex: 0
    property var _pendingFonts: []
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
        id: listFontsProc
        command: [Env.binDir + "/change_theme.sh", "--list-fonts"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                var f = data.trim();
                if (f && root._pendingFonts.indexOf(f) === -1) {
                    root._pendingFonts.push(f);
                }
            }
        }
        onExited: {
            root.allFonts = root._pendingFonts.slice();
            root.filterFonts();
            var targetIdx = 0;
            for (var j = 0; j < root.filteredFonts.length; j++) {
                if (root.filteredFonts[j] === Theme.fontFamily) {
                    targetIdx = j;
                    break;
                }
            }
            root.selectedIndex = targetIdx;
            fontListView.positionViewAtIndex(targetIdx, ListView.Center);
            root.loading = false;
        }
    }

    property string errorMessage: ""

    Process {
        id: setFontProc
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                root.requestClose();
            } else {
                root.errorMessage = "Failed to set font (exit " + exitCode + ")";
            }
        }
    }

    // Filters available fonts based on search query.
    function filterFonts() {
        if (!root.searchQuery) {
            root.filteredFonts = root.allFonts;
            return;
        }
        var q = root.searchQuery.toLowerCase();
        var res = [];
        for (var i = 0; i < root.allFonts.length; i++) {
            if (root.allFonts[i].toLowerCase().indexOf(q) !== -1) {
                res.push(root.allFonts[i]);
            }
        }
        root.filteredFonts = res;
        root.selectedIndex = 0;
    }

    // Applies selected system font family across HakuSpace themes.
    function applyFont(fontName) {
        if (!fontName) return;
        root.errorMessage = "";
        setFontProc.command = [Env.binDir + "/change_theme.sh", "--font", fontName];
        setFontProc.running = true;
    }

    onScrollPrevious: {
        if (filteredFonts.length > 0) {
            root.selectedIndex = Math.max(0, root.selectedIndex - 1);
            fontListView.positionViewAtIndex(root.selectedIndex, ListView.Contain);
        }
    }

    onScrollNext: {
        if (filteredFonts.length > 0) {
            root.selectedIndex = Math.min(filteredFonts.length - 1, root.selectedIndex + 1);
            fontListView.positionViewAtIndex(root.selectedIndex, ListView.Contain);
        }
    }

    Keys.onUpPressed: event => {
        if (filteredFonts.length > 0) {
            root.selectedIndex = Math.max(0, root.selectedIndex - 1);
            fontListView.positionViewAtIndex(root.selectedIndex, ListView.Contain);
            event.accepted = true;
        }
    }

    Keys.onDownPressed: event => {
        if (filteredFonts.length > 0) {
            root.selectedIndex = Math.min(filteredFonts.length - 1, root.selectedIndex + 1);
            fontListView.positionViewAtIndex(root.selectedIndex, ListView.Contain);
            event.accepted = true;
        }
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Home) {
            if (filteredFonts.length > 0) {
                root.selectedIndex = 0;
                fontListView.positionViewAtIndex(root.selectedIndex, ListView.Contain);
                event.accepted = true;
            }
        } else if (event.key === Qt.Key_End) {
            if (filteredFonts.length > 0) {
                root.selectedIndex = filteredFonts.length - 1;
                fontListView.positionViewAtIndex(root.selectedIndex, ListView.Contain);
                event.accepted = true;
            }
        }
    }

    // Applies the currently highlighted font from the filtered font list.
    function activateCurrent() {
        if (filteredFonts.length > 0 && root.selectedIndex < filteredFonts.length) {
            applyFont(filteredFonts[root.selectedIndex]);
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

    Keys.onTabPressed: event => {
        searchInput.forceActiveFocus();
        event.accepted = true;
    }

    Keys.onBacktabPressed: event => {
        searchInput.forceActiveFocus();
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

        // Search input
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.max(34, Theme.fontSize * 2.2)
            radius: Theme.radius
            color: Qt.rgba(1, 1, 1, 0.06)
            border.color: searchInput.activeFocus ? Theme.accent : "transparent"
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.pad
                anchors.rightMargin: Theme.pad
                spacing: Theme.pad / 2

                Text {
                    text: ""
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                    color: Theme.fgMuted
                }

                TextInput {
                    id: searchInput
                    Layout.fillWidth: true
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                    color: Theme.fg
                    clip: true

                    Text {
                        anchors.fill: parent
                        text: "Search fonts..."
                        font.family: parent.font.family
                        font.pixelSize: parent.font.pixelSize
                        color: Theme.fgMuted
                        visible: !parent.text && !parent.activeFocus
                    }

                    onTextChanged: {
                        root.searchQuery = text;
                        root.filterFonts();
                    }
                    Keys.onUpPressed: event => {
                        if (filteredFonts.length > 0) {
                            root.selectedIndex = Math.max(0, root.selectedIndex - 1);
                            fontListView.positionViewAtIndex(root.selectedIndex, ListView.Contain);
                            event.accepted = true;
                        }
                    }
                    Keys.onDownPressed: event => {
                        if (filteredFonts.length > 0) {
                            root.selectedIndex = Math.min(filteredFonts.length - 1, root.selectedIndex + 1);
                            fontListView.positionViewAtIndex(root.selectedIndex, ListView.Contain);
                            event.accepted = true;
                        }
                    }
                    Keys.onReturnPressed: event => {
                        root.activateCurrent();
                        event.accepted = true;
                    }
                    Keys.onEnterPressed: event => {
                        root.activateCurrent();
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

        // Loading state indicator
        Text {
            visible: root.loading && root.showLoadingIndicator
            text: "Loading fonts..."
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            color: Theme.fgMuted
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: Theme.pad * 2
        }

        // Empty state indicator
        Text {
            visible: !root.loading && root.filteredFonts.length === 0
            text: "No matching fonts found"
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            color: Theme.fgMuted
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: Theme.pad * 2
        }

        // Font list
        ListView {
            id: fontListView
            visible: root.filteredFonts.length > 0
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
            model: root.filteredFonts

            ActionMenu.ActionMenuSelectionPill {
                id: selectionPill
                parent: fontListView.contentItem
                z: 0
            }

            ScrollBar.vertical: ActionMenu.ActionMenuScrollBar {
                id: vbar
            }

            delegate: ActionMenu.ActionMenuButton {
                id: delegateBtn
                z: 1
                width: fontListView.width - vbar.reservedGutter
                icon: ""
                label: modelData
                secondaryText: modelData === Theme.fontFamily ? "Active" : ""
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
                    applyFont(modelData);
                }
            }
        }
    }
}
