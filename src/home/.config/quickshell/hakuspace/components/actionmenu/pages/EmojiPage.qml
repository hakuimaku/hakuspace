import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Io
import "../../../services"
import ".." as ActionMenu

ActionMenu.ActionMenuPage {
    id: root

    title: "Emoji Picker"
    subtitle: "Select emoji to copy to clipboard"
    icon: "󰞅"
    geometryProfile: "emoji"
    canGoBack: false

    property var allEntries: []
    property var historyEntries: []
    property var filteredEntries: []
    property string searchQuery: ""
    property string activeSection: "history"
    property int historyIndex: 0
    property int catalogIndex: 0
    property bool loading: true
    property bool showLoadingIndicator: false
    property string errorMessage: ""

    readonly property int columnsCount: 8
    readonly property int rowsCount: 6

    Component.onCompleted: {
        searchInput.forceActiveFocus();
    }

    onFocusChanged: {
        if (focus) searchInput.forceActiveFocus();
    }

    Timer {
        id: loadingDelayTimer
        interval: 120
        running: root.loading
        onTriggered: {
            if (root.loading) root.showLoadingIndicator = true;
        }
    }

    property var _pendingEntries: []
    property var _pendingHistory: []
    property bool _listFinished: false
    property bool _historyFinished: false

    Process {
        id: listProc
        command: [Env.binDir + "/emoji_ctl.sh", "list"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                var line = data;
                if (!line) return;
                var parts = line.split("\t");
                if (parts.length < 2) return;
                var glyph = parts[0] ? parts[0].trim() : "";
                if (!glyph) return;
                var category = parts.length > 1 ? parts[1].trim() : "";
                var subcategory = parts.length > 2 ? parts[2].trim() : "";
                var name = parts.length > 3 ? parts[3].trim() : "";
                var keywords = parts.length > 4 ? parts[4].trim() : "";
                root._pendingEntries.push({
                    emoji: glyph,
                    category: category,
                    subcategory: subcategory,
                    name: name,
                    keywords: keywords,
                    searchBlob: (name + " " + keywords + " " + category + " " + subcategory).toLowerCase(),
                    isHistory: false
                });
            }
        }
        onExited: (code, status) => {
            root._listFinished = true;
            if (code !== 0) {
                root.loading = false;
                root.errorMessage = "Failed to load emoji database";
                return;
            }
            root.assembleData();
        }
    }

    Process {
        id: historyProc
        command: [Env.binDir + "/emoji_ctl.sh", "history"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                var line = data ? data.trim() : "";
                if (!line) return;
                root._pendingHistory.push(line);
            }
        }
        onExited: (code, status) => {
            root._historyFinished = true;
            root.assembleData();
        }
    }

    property bool _isCopying: false

    Process {
        id: copyProc
        onExited: (exitCode, exitStatus) => {
            if (!root._isCopying) return;
            root._isCopying = false;
            if (exitCode === 0) {
                root.requestClose();
            } else {
                root.errorMessage = "Failed to copy emoji (exit " + exitCode + ")";
            }
        }
    }

    function assembleData() {
        if (!root._listFinished) return;

        var entryMap = {};
        for (var i = 0; i < root._pendingEntries.length; i++) {
            var ent = root._pendingEntries[i];
            entryMap[ent.emoji] = ent;
        }

        var hist = [];
        var maxHistory = 16;
        for (var j = 0; j < root._pendingHistory.length && hist.length < maxHistory; j++) {
            var glyph = root._pendingHistory[j];
            var match = entryMap[glyph];
            if (match) {
                hist.push({
                    emoji: match.emoji,
                    category: match.category,
                    subcategory: match.subcategory,
                    name: match.name,
                    keywords: match.keywords,
                    searchBlob: match.searchBlob,
                    isHistory: true
                });
            } else {
                hist.push({
                    emoji: glyph,
                    category: "Recent",
                    subcategory: "",
                    name: "Recent emoji",
                    keywords: "",
                    searchBlob: "recent",
                    isHistory: true
                });
            }
        }

        root.historyEntries = hist;
        root.allEntries = root._pendingEntries.slice();
        root.filterEntries();
        root.loading = false;
    }

    function filterEntries() {
        if (!root.searchQuery) {
            root.filteredEntries = root.allEntries;
            if (root.historyEntries.length > 0) {
                root.activeSection = "history";
                root.historyIndex = 0;
            } else {
                root.activeSection = "catalog";
                root.catalogIndex = 0;
            }
            return;
        }
        var q = root.searchQuery.trim().toLowerCase();
        var res = [];
        for (var i = 0; i < root.allEntries.length; i++) {
            var ent = root.allEntries[i];
            if (ent.searchBlob.indexOf(q) !== -1) {
                res.push(ent);
            }
        }
        root.filteredEntries = res;
        root.activeSection = "catalog";
        root.catalogIndex = 0;
    }

    function copyEntry(emojiGlyph) {
        if (!emojiGlyph) return;
        root.errorMessage = "";
        root._isCopying = true;
        copyProc.command = [Env.binDir + "/emoji_ctl.sh", "copy", emojiGlyph];
        copyProc.running = true;
    }

    function navLeft() {
        if (root.activeSection === "history" && !root.searchQuery) {
            root.historyIndex = Math.max(0, root.historyIndex - 1);
        } else if (root.filteredEntries.length > 0) {
            root.catalogIndex = Math.max(0, root.catalogIndex - 1);
            emojiGrid.positionViewAtIndex(root.catalogIndex, GridView.Contain);
        }
    }

    function navRight() {
        if (root.activeSection === "history" && !root.searchQuery) {
            root.historyIndex = Math.min(Math.min(15, root.historyEntries.length - 1), root.historyIndex + 1);
        } else if (root.filteredEntries.length > 0) {
            root.catalogIndex = Math.min(root.filteredEntries.length - 1, root.catalogIndex + 1);
            emojiGrid.positionViewAtIndex(root.catalogIndex, GridView.Contain);
        }
    }

    // Handles upward navigation and boundary transitions between catalog and history.
    function navUp() {
        if (root.activeSection === "history" && !root.searchQuery && root.historyEntries.length > 0) {
            if (root.historyIndex >= root.columnsCount) {
                root.historyIndex -= root.columnsCount;
            } else {
                searchInput.forceActiveFocus();
            }
        } else if (root.filteredEntries.length > 0) {
            if (!root.searchQuery && root.catalogIndex < root.columnsCount && root.historyEntries.length > 0) {
                root.activeSection = "history";
                var historyRows = Math.ceil(root.historyEntries.length / root.columnsCount);
                var targetRow = Math.max(0, historyRows - 1);
                var targetCol = root.catalogIndex % root.columnsCount;
                var targetIdx = (targetRow * root.columnsCount) + targetCol;
                if (targetIdx >= root.historyEntries.length) {
                    targetIdx = root.historyEntries.length - 1;
                }
                root.historyIndex = targetIdx;
            } else if (root.catalogIndex >= root.columnsCount) {
                root.catalogIndex -= root.columnsCount;
                emojiGrid.positionViewAtIndex(root.catalogIndex, GridView.Contain);
            } else {
                searchInput.forceActiveFocus();
            }
        }
    }

    // Handles downward navigation and transitions from history into catalog.
    function navDown() {
        if (root.activeSection === "history" && !root.searchQuery && root.historyEntries.length > 0) {
            if (root.historyIndex < root.columnsCount && (root.historyIndex + root.columnsCount) < root.historyEntries.length) {
                root.historyIndex += root.columnsCount;
            } else if (root.filteredEntries.length > 0) {
                root.activeSection = "catalog";
                root.catalogIndex = Math.min(root.filteredEntries.length - 1, root.historyIndex % root.columnsCount);
                emojiGrid.positionViewAtIndex(root.catalogIndex, GridView.Contain);
            }
        } else if (root.filteredEntries.length > 0) {
            root.catalogIndex = Math.min(root.filteredEntries.length - 1, root.catalogIndex + root.columnsCount);
            emojiGrid.positionViewAtIndex(root.catalogIndex, GridView.Contain);
        }
    }

    function navPageUp() {
        if (root.activeSection === "history" || root.searchQuery) {
            root.historyIndex = 0;
        } else if (root.filteredEntries.length > 0) {
            if (root.catalogIndex < root.columnsCount * 4) {
                root.activeSection = "history";
                root.historyIndex = 0;
            } else {
                root.catalogIndex = Math.max(0, root.catalogIndex - (root.columnsCount * 4));
                emojiGrid.positionViewAtIndex(root.catalogIndex, GridView.Contain);
            }
        }
    }

    function navPageDown() {
        if (root.activeSection === "history" && !root.searchQuery) {
            root.activeSection = "catalog";
            root.catalogIndex = Math.min(root.filteredEntries.length - 1, root.historyIndex % root.columnsCount);
            emojiGrid.positionViewAtIndex(root.catalogIndex, GridView.Contain);
        } else if (root.filteredEntries.length > 0) {
            root.catalogIndex = Math.min(root.filteredEntries.length - 1, root.catalogIndex + (root.columnsCount * 4));
            emojiGrid.positionViewAtIndex(root.catalogIndex, GridView.Contain);
        }
    }

    function activateCurrent() {
        if (root.activeSection === "history" && !root.searchQuery) {
            if (root.historyEntries.length > 0 && root.historyIndex >= 0 && root.historyIndex < root.historyEntries.length) {
                copyEntry(root.historyEntries[root.historyIndex].emoji);
            }
        } else {
            if (root.filteredEntries.length > 0 && root.catalogIndex >= 0 && root.catalogIndex < root.filteredEntries.length) {
                copyEntry(root.filteredEntries[root.catalogIndex].emoji);
            }
        }
    }

    onScrollPrevious: root.navPageUp()
    onScrollNext: root.navPageDown()

    Keys.onLeftPressed: event => {
        root.navLeft();
        event.accepted = true;
    }

    Keys.onRightPressed: event => {
        root.navRight();
        event.accepted = true;
    }

    Keys.onUpPressed: event => {
        root.navUp();
        event.accepted = true;
    }

    Keys.onDownPressed: event => {
        root.navDown();
        event.accepted = true;
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Home) {
            if (root.activeSection === "history" && !root.searchQuery) {
                root.historyIndex = 0;
            } else if (root.filteredEntries.length > 0) {
                root.catalogIndex = 0;
                emojiGrid.positionViewAtIndex(0, GridView.Contain);
            }
            event.accepted = true;
        } else if (event.key === Qt.Key_End) {
            if (root.activeSection === "history" && !root.searchQuery) {
                root.historyIndex = Math.min(15, root.historyEntries.length - 1);
            } else if (root.filteredEntries.length > 0) {
                root.catalogIndex = root.filteredEntries.length - 1;
                emojiGrid.positionViewAtIndex(root.catalogIndex, GridView.Contain);
            }
            event.accepted = true;
        } else if (event.key === Qt.Key_PageUp) {
            root.navPageUp();
            event.accepted = true;
        } else if (event.key === Qt.Key_PageDown) {
            root.navPageDown();
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

    Keys.onTabPressed: event => {
        searchInput.forceActiveFocus();
        event.accepted = true;
    }

    Keys.onBacktabPressed: event => {
        searchInput.forceActiveFocus();
        event.accepted = true;
    }

    Keys.onEscapePressed: event => {
        root.requestClose();
        event.accepted = true;
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Theme.pad

        Text {
            visible: root.errorMessage.length > 0
            text: root.errorMessage
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            color: Theme.danger
            Layout.alignment: Qt.AlignHCenter
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Theme.comfortableControlHeight
            radius: Theme.radius
            color: Qt.alpha(Theme.overlayInk, 0.06)

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.pad
                anchors.rightMargin: Theme.pad
                spacing: Theme.spaceSm

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
                    focus: true

                    Text {
                        anchors.fill: parent
                        text: "Search emojis..."
                        font.family: parent.font.family
                        font.pixelSize: parent.font.pixelSize
                        color: Theme.fgMuted
                        visible: !parent.text && !parent.activeFocus
                    }
                    onTextChanged: {
                        root.searchQuery = text;
                        root.filterEntries();
                    }
                    Keys.onLeftPressed: event => {
                        if (text.length === 0) {
                            root.navLeft();
                            event.accepted = true;
                        }
                    }
                    Keys.onRightPressed: event => {
                        if (text.length === 0) {
                            root.navRight();
                            event.accepted = true;
                        }
                    }
                    Keys.onUpPressed: event => {
                        root.navUp();
                        event.accepted = true;
                    }
                    Keys.onDownPressed: event => {
                        root.navDown();
                        event.accepted = true;
                    }
                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_PageUp) {
                            root.navPageUp();
                            event.accepted = true;
                        } else if (event.key === Qt.Key_PageDown) {
                            root.navPageDown();
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
                        root.requestClose();
                        event.accepted = true;
                    }
                }
            }
        }

        Text {
            visible: root.loading && root.showLoadingIndicator
            text: "Loading emojis..."
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            color: Theme.fgMuted
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: Theme.pad * 2
        }

        Text {
            visible: !root.loading && root.filteredEntries.length === 0
            text: root.allEntries.length === 0 ? "Emoji database is empty" : "No matching emojis found"
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            color: Theme.fgMuted
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: Theme.pad * 2
        }

        Rectangle {
            id: historyBox
            visible: !root.searchQuery && root.historyEntries.length > 0 && !root.loading
            Layout.fillWidth: true
            implicitHeight: {
                var rows = Math.min(2, Math.max(1, Math.ceil(root.historyEntries.length / root.columnsCount)));
                return (historyGrid.cellHeight * rows) + (Theme.spaceSm * 2);
            }
            radius: Theme.largeRadius
            color: Qt.alpha(Theme.overlayInk, 0.08)
            clip: true

            GridView {
                id: historyGrid
                anchors.fill: parent
                anchors.margins: Theme.spaceSm
                interactive: false
                clip: true
                cellWidth: Math.floor(width / root.columnsCount)
                cellHeight: cellWidth
                model: root.historyEntries.slice(0, 16)

                delegate: Item {
                    id: histDelegate
                    width: historyGrid.cellWidth
                    height: historyGrid.cellHeight
                    z: isSelected ? 2 : 1

                    readonly property bool isSelected: root.activeSection === "history" && !root.searchQuery && root.historyIndex === index
                    readonly property bool isHovered: histMouse.containsMouse

                    Rectangle {
                        id: histCellBg
                        anchors.fill: parent
                        anchors.margins: Theme.spaceXs / 2
                        radius: Theme.radius
                        transformOrigin: Item.Center
                        scale: histDelegate.isSelected ? 1.05 : (histDelegate.isHovered ? 1.02 : 1.0)
                        color: histDelegate.isSelected
                            ? Qt.alpha(Theme.overlayInk, 0.20)
                            : (histDelegate.isHovered ? Qt.alpha(Theme.overlayInk, 0.08) : "transparent")

                        Behavior on scale {
                            NumberAnimation {
                                duration: HAnimation.buttonHoverDuration
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: HAnimation.buttonHoverCurve
                            }
                        }
                        Behavior on color {
                            ColorAnimation {
                                duration: HAnimation.buttonHoverDuration
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: HAnimation.buttonHoverCurve
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: modelData.emoji
                            font.family: Theme.fontFamily
                            font.pixelSize: Math.round(parent.height * 0.52)
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                    }

                    MouseArea {
                        id: histMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: {
                            root.activeSection = "history";
                            root.historyIndex = index;
                        }
                        onClicked: {
                            root.activeSection = "history";
                            root.historyIndex = index;
                            root.copyEntry(modelData.emoji);
                        }
                    }
                }
            }
        }

        GridView {
            id: emojiGrid
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
            cellWidth: Math.floor((width - Theme.spaceLg) / root.columnsCount)
            cellHeight: cellWidth
            model: root.filteredEntries

            ScrollBar.vertical: ActionMenu.ActionMenuScrollBar {
                id: vbar
            }

            delegate: Item {
                id: delegateRoot
                width: emojiGrid.cellWidth
                height: emojiGrid.cellHeight
                z: isSelected ? 2 : 1

                readonly property bool isSelected: root.activeSection === "catalog" && root.catalogIndex === index
                readonly property bool isHovered: mouseArea.containsMouse

                Rectangle {
                    id: cellBg
                    anchors.fill: parent
                    anchors.margins: Theme.spaceXs / 2
                    radius: Theme.radius
                    transformOrigin: Item.Center
                    scale: delegateRoot.isSelected ? 1.05 : (delegateRoot.isHovered ? 1.02 : 1.0)
                    color: delegateRoot.isSelected
                        ? Qt.alpha(Theme.overlayInk, 0.20)
                        : (delegateRoot.isHovered ? Qt.alpha(Theme.overlayInk, 0.08) : "transparent")

                    Behavior on scale {
                        NumberAnimation {
                            duration: HAnimation.buttonHoverDuration
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: HAnimation.buttonHoverCurve
                        }
                    }
                    Behavior on color {
                        ColorAnimation {
                            duration: HAnimation.buttonHoverDuration
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: HAnimation.buttonHoverCurve
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: modelData.emoji
                        font.family: Theme.fontFamily
                        font.pixelSize: Math.round(parent.height * 0.52)
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                MouseArea {
                    id: mouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: {
                        root.activeSection = "catalog";
                        root.catalogIndex = index;
                    }
                    onClicked: {
                        root.activeSection = "catalog";
                        root.catalogIndex = index;
                        root.copyEntry(modelData.emoji);
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Theme.comfortableControlHeight
            radius: Theme.radius
            color: Qt.alpha(Theme.overlayInk, 0.05)

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.pad
                anchors.rightMargin: Theme.pad
                spacing: Theme.pad

                readonly property var currentItem: {
                    if (root.activeSection === "history" && !root.searchQuery) {
                        if (root.historyEntries.length > 0 && root.historyIndex >= 0 && root.historyIndex < root.historyEntries.length) {
                            return root.historyEntries[root.historyIndex];
                        }
                    } else {
                        if (root.filteredEntries.length > 0 && root.catalogIndex >= 0 && root.catalogIndex < root.filteredEntries.length) {
                            return root.filteredEntries[root.catalogIndex];
                        }
                    }
                    return null;
                }

                Text {
                    text: parent.currentItem ? parent.currentItem.emoji : ""
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize + 6
                    verticalAlignment: Text.AlignVCenter
                }

                Text {
                    Layout.fillWidth: true
                    text: parent.currentItem ? parent.currentItem.name : (root.loading ? "Loading..." : "No emoji selected")
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                    font.weight: Font.Medium
                    color: Theme.fg
                    elide: Text.ElideRight
                    verticalAlignment: Text.AlignVCenter
                }

                Rectangle {
                    visible: parent.currentItem && parent.currentItem.category && parent.currentItem.category.length > 0
                    implicitWidth: catText.implicitWidth + Theme.spaceMd
                    implicitHeight: Math.max(18, Theme.fontSize * 1.3)
                    radius: Theme.radius / 2
                    color: Qt.alpha(Theme.overlayInk, 0.10)
                    Layout.alignment: Qt.AlignVCenter

                    Text {
                        id: catText
                        anchors.centerIn: parent
                        text: parent.parent.currentItem ? parent.parent.currentItem.category : ""
                        font.family: Theme.fontFamily
                        font.pixelSize: Math.max(9, Theme.fontSize - 2)
                        color: Theme.fgMuted
                    }
                }
            }
        }
    }
}
