import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Io
import "../../../services"
import ".." as ActionMenu

ActionMenu.ActionMenuPage {
    id: root

    title: "Clipboard History"
    subtitle: "Select entry to copy to clipboard"
    icon: "󰅌"
    geometryProfile: "option"
    canGoBack: false

    property var allEntries: []
    property var filteredEntries: []
    property string searchQuery: ""
    property int selectedIndex: 0
    property bool loading: true
    property bool showLoadingIndicator: false
    property string errorMessage: ""

    Timer {
        id: loadingDelayTimer
        interval: 120
        running: root.loading
        onTriggered: {
            if (root.loading) root.showLoadingIndicator = true;
        }
    }

    Process {
        id: ensureWatchersProc
        command: [Env.binDir + "/clipboard_ctl.sh", "ensure-watchers"]
        running: true
        onExited: {
            root._pendingEntries = [];
            listProc.running = true;
        }
    }

    property var _pendingEntries: []

    Process {
        id: listProc
        command: [Env.binDir + "/clipboard_ctl.sh", "list"]
        stdout: SplitParser {
            onRead: data => {
                var line = data;
                if (!line) return;
                var tabIdx = line.indexOf("\t");
                var id = "";
                var preview = line;
                if (tabIdx !== -1) {
                    id = line.substring(0, tabIdx).trim();
                    preview = line.substring(tabIdx + 1).trim();
                }
                var isImage = preview.indexOf("[[ binary data") !== -1 || preview.match(/\.(png|jpe?g|webp|gif|svg)$/i);
                root._pendingEntries.push({
                    raw: line,
                    id: id,
                    preview: preview,
                    isImage: isImage
                });
            }
        }
        onExited: (code, status) => {
            if (code !== 0) {
                root.loading = false;
                root.errorMessage = "Failed to list clipboard history";
                return;
            }
            root.allEntries = root._pendingEntries.slice();
            root.filterEntries();
            root.selectedIndex = 0;
            root.loading = false;
        }
    }

    Process {
        id: copyProc
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                root.requestClose();
            } else {
                root.errorMessage = "Failed to copy entry (exit " + exitCode + ")";
            }
        }
    }

    // Filters clipboard history entries based on user search query.
    function filterEntries() {
        if (!root.searchQuery) {
            root.filteredEntries = root.allEntries;
            return;
        }
        var q = root.searchQuery.toLowerCase();
        var res = [];
        for (var i = 0; i < root.allEntries.length; i++) {
            var ent = root.allEntries[i];
            if (ent.preview.toLowerCase().indexOf(q) !== -1 || ent.id.indexOf(q) !== -1) {
                res.push(ent);
            }
        }
        root.filteredEntries = res;
        root.selectedIndex = 0;
    }

    // Invokes clipboard script to copy the selected item into system clipboard.
    function copyEntry(rawRow) {
        if (!rawRow) return;
        root.errorMessage = "";
        copyProc.command = [Env.binDir + "/clipboard_ctl.sh", "copy", rawRow];
        copyProc.running = true;
    }

    onScrollPrevious: {
        if (filteredEntries.length > 0) {
            root.selectedIndex = Math.max(0, root.selectedIndex - 1);
            clipList.positionViewAtIndex(root.selectedIndex, ListView.Contain);
        }
    }

    onScrollNext: {
        if (filteredEntries.length > 0) {
            root.selectedIndex = Math.min(filteredEntries.length - 1, root.selectedIndex + 1);
            clipList.positionViewAtIndex(root.selectedIndex, ListView.Contain);
        }
    }

    Keys.onUpPressed: event => {
        if (filteredEntries.length > 0) {
            root.selectedIndex = Math.max(0, root.selectedIndex - 1);
            clipList.positionViewAtIndex(root.selectedIndex, ListView.Contain);
            event.accepted = true;
        }
    }

    Keys.onDownPressed: event => {
        if (filteredEntries.length > 0) {
            root.selectedIndex = Math.min(filteredEntries.length - 1, root.selectedIndex + 1);
            clipList.positionViewAtIndex(root.selectedIndex, ListView.Contain);
            event.accepted = true;
        }
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Home) {
            if (filteredEntries.length > 0) {
                root.selectedIndex = 0;
                clipList.positionViewAtIndex(root.selectedIndex, ListView.Contain);
                event.accepted = true;
            }
        } else if (event.key === Qt.Key_End) {
            if (filteredEntries.length > 0) {
                root.selectedIndex = filteredEntries.length - 1;
                clipList.positionViewAtIndex(root.selectedIndex, ListView.Contain);
                event.accepted = true;
            }
        }
    }

    // Copies the currently focused clipboard row to system clipboard.
    function activateCurrent() {
        if (filteredEntries.length > 0 && root.selectedIndex < filteredEntries.length) {
            copyEntry(filteredEntries[root.selectedIndex].raw);
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

    Keys.onEscapePressed: event => {
        if (searchInput.text.length > 0) {
            searchInput.text = "";
            event.accepted = true;
        } else {
            root.requestClose();
            event.accepted = true;
        }
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
                        text: "Search clipboard history..."
                        font.family: parent.font.family
                        font.pixelSize: parent.font.pixelSize
                        color: Theme.fgMuted
                        visible: !parent.text && !parent.activeFocus
                    }
                    onTextChanged: {
                        root.searchQuery = text;
                        root.filterEntries();
                    }
                    Keys.onUpPressed: event => {
                        if (filteredEntries.length > 0) {
                            root.selectedIndex = Math.max(0, root.selectedIndex - 1);
                            clipList.positionViewAtIndex(root.selectedIndex, ListView.Contain);
                            event.accepted = true;
                        }
                    }
                    Keys.onDownPressed: event => {
                        if (filteredEntries.length > 0) {
                            root.selectedIndex = Math.min(filteredEntries.length - 1, root.selectedIndex + 1);
                            clipList.positionViewAtIndex(root.selectedIndex, ListView.Contain);
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
                            root.requestClose();
                            event.accepted = true;
                        }
                    }
                }
            }
        }

        // Loading state indicator
        Text {
            visible: root.loading && root.showLoadingIndicator
            text: "Loading clipboard..."
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            color: Theme.fgMuted
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: Theme.pad * 2
        }

        // Empty state indicator
        Text {
            visible: !root.loading && root.filteredEntries.length === 0
            text: root.allEntries.length === 0 ? "Clipboard is empty" : "No matches found"
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            color: Theme.fgMuted
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: Theme.pad * 2
        }

        // Clipboard entries list
        ListView {
            id: clipList
            visible: root.filteredEntries.length > 0
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
            model: root.filteredEntries

            ActionMenu.ActionMenuSelectionPill {
                id: selectionPill
                parent: clipList.contentItem
                z: 0
            }

            ScrollBar.vertical: ActionMenu.ActionMenuScrollBar {
                id: vbar
            }

            delegate: ActionMenu.ActionMenuButton {
                id: delegateBtn
                z: 1
                width: clipList.width - vbar.reservedGutter
                icon: modelData.isImage ? "" : "󰅌"
                label: modelData.preview
                badge: modelData.id ? ("#" + modelData.id) : ""
                badgeColor: Theme.accent
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
                    copyEntry(modelData.raw);
                }
            }
        }
    }
}
