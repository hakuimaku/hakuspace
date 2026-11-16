import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import Quickshell.Io
import "../../../services"
import ".." as ActionMenu
import "../../motion" as Motion

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
            color: Theme.danger
            Layout.alignment: Qt.AlignHCenter
        }

        // Search input
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Theme.actionLayerRowHeight
            radius: Theme.radius
            color: Qt.alpha(Theme.overlayInk, 0.06)
            border.color: searchInput.activeFocus ? Theme.accent : "transparent"
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.actionLayerButtonPaddingX
                anchors.rightMargin: Theme.actionLayerButtonPaddingX
                spacing: Theme.actionLayerButtonSpacing

                Text {
                    text: ""
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize + Theme.actionLayerIconOffset
                    color: Theme.fgMuted
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    Layout.preferredWidth: Theme.fontSize * 2.2
                }

                TextInput {
                    id: searchInput
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    verticalAlignment: TextInput.AlignVCenter
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                    color: Theme.fg
                    clip: true

                    Text {
                        anchors.fill: parent
                        verticalAlignment: Text.AlignVCenter
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
            spacing: Theme.actionLayerListSpacing
            model: root.filteredEntries

            ActionMenu.ActionMenuSelectionPill {
                id: selectionPill
                parent: clipList.contentItem
                z: 0
            }

            ScrollBar.vertical: ActionMenu.ActionMenuScrollBar {
                id: vbar
            }

            delegate: Motion.MorphButton {
                id: delegateBtn
                required property int index
                required property var modelData

                readonly property Item page: root
                readonly property real selectionOpacity: page ? page.selectionPillOpacity : 1
                readonly property color contentForeground: (selected || focused) && page
                    ? page.selectionColor(Theme.fg, foreground) : foreground
                readonly property color badgeColor: Theme.accent
                property string previewSource: ""
                property string _requestedRaw: ""

                function loadPreview() {
                    previewSource = "";
                    if (!modelData || !modelData.isImage || !modelData.raw) {
                        _requestedRaw = "";
                        return;
                    }
                    _requestedRaw = modelData.raw;
                    previewProc.command = [Env.binDir + "/clipboard_ctl.sh", "preview", modelData.raw];
                    previewProc.running = false;
                    previewProc.running = true;
                }

                z: 1
                width: clipList.width - vbar.reservedGutter
                height: implicitHeight
                implicitHeight: modelData.isImage
                    ? Math.round(Theme.actionLayerRowHeight * 2.5)
                    : Theme.actionLayerRowHeight
                radius: Theme.radius
                text: ""
                selected: root.selectedIndex === index
                focused: selected
                selectedOverridesHover: true
                idleColor: "transparent"
                hoverColor: "transparent"
                pressedColor: (selected || focused) ? "transparent" : Theme.hoverMuted
                selectedColor: "transparent"
                focusColor: "transparent"
                foregroundColor: Theme.fg
                hoverForegroundColor: (selected || focused) ? selectedForegroundColor : Theme.fg
                pressedForegroundColor: selectedForegroundColor
                selectedForegroundColor: Theme.onAccentColor
                Accessible.role: Accessible.Button
                Accessible.name: modelData.preview + (modelData.id ? (", #" + modelData.id) : "")
                Accessible.onPressAction: clicked()

                Connections {
                    target: root
                    function onPointerSelectionMoved() {
                        if (delegateBtn.hovered) {
                            root.selectedIndex = delegateBtn.index;
                        }
                    }
                }

                Process {
                    id: previewProc
                    stdout: StdioCollector {
                        id: previewCollector
                        waitForEnd: true
                    }
                    onExited: code => {
                        if (code !== 0 || !delegateBtn.modelData || delegateBtn.modelData.raw !== delegateBtn._requestedRaw) {
                            return;
                        }
                        var path = previewCollector.text.trim();
                        if (path.length > 0) {
                            delegateBtn.previewSource = "file://" + path;
                        }
                    }
                }

                Component.onCompleted: {
                    if (selected) selectionPill.targetItem = this;
                    loadPreview();
                }
                onModelDataChanged: loadPreview()
                onSelectedChanged: {
                    if (selected) selectionPill.targetItem = this;
                }
                onClicked: {
                    root.selectedIndex = index;
                    copyEntry(modelData.raw);
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.actionLayerButtonPaddingX
                    anchors.rightMargin: Theme.actionLayerButtonPaddingX
                    spacing: Theme.actionLayerButtonSpacing

                    Text {
                        visible: !delegateBtn.modelData.isImage
                        text: "󰅌"
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize + Theme.actionLayerIconOffset
                        color: delegateBtn.contentForeground
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        Layout.preferredWidth: visible ? Theme.fontSize * 2.2 : 0
                    }

                    Rectangle {
                        id: thumbContainer
                        visible: delegateBtn.modelData.isImage
                        Layout.preferredWidth: visible ? Math.round((delegateBtn.implicitHeight - 16) * 1.6) : 0
                        Layout.fillHeight: true
                        Layout.topMargin: 8
                        Layout.bottomMargin: 8
                        radius: Math.max(4, Theme.radius - 4)
                        color: Qt.rgba(0, 0, 0, 0.18)
                        clip: true

                        Text {
                            anchors.centerIn: parent
                            visible: thumbImage.status !== Image.Ready
                            text: ""
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize + Theme.actionLayerIconOffset + 4
                            color: delegateBtn.contentForeground
                            opacity: 0.75
                        }

                        Image {
                            id: thumbImage
                            anchors.fill: parent
                            anchors.margins: 2
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                            cache: false
                            source: delegateBtn.previewSource
                            visible: status === Image.Ready
                            sourceSize: Qt.size(
                                Math.max(1, Math.ceil(width * (delegateBtn.Window.window ? delegateBtn.Window.window.devicePixelRatio : 1))),
                                Math.max(1, Math.ceil(height * (delegateBtn.Window.window ? delegateBtn.Window.window.devicePixelRatio : 1)))
                            )
                        }
                    }

                    Text {
                        text: delegateBtn.modelData.preview
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                        color: delegateBtn.contentForeground
                        elide: Text.ElideRight
                        maximumLineCount: delegateBtn.modelData.isImage ? 2 : 1
                        wrapMode: delegateBtn.modelData.isImage ? Text.Wrap : Text.NoWrap
                        Layout.fillWidth: true
                        verticalAlignment: Text.AlignVCenter
                    }

                    Rectangle {
                        visible: delegateBtn.modelData.id.length > 0
                        implicitWidth: badgeText.implicitWidth + 8
                        implicitHeight: Math.max(16, Theme.fontSize * 1.2)
                        radius: 4
                        readonly property color normalBackground: Qt.rgba(delegateBtn.badgeColor.r, delegateBtn.badgeColor.g, delegateBtn.badgeColor.b, 0.2)
                        color: (delegateBtn.selected || delegateBtn.focused) && delegateBtn.page
                            ? delegateBtn.page.selectionColor(normalBackground, Qt.rgba(0, 0, 0, 0.22))
                            : normalBackground
                        Layout.alignment: Qt.AlignVCenter

                        Behavior on color {
                            enabled: delegateBtn.selectionOpacity >= 0.999
                            ColorAnimation {
                                duration: delegateBtn.transitionDuration
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: delegateBtn.transitionCurve
                            }
                        }

                        Text {
                            id: badgeText
                            anchors.centerIn: parent
                            text: delegateBtn.modelData.id ? ("#" + delegateBtn.modelData.id) : ""
                            font.family: Theme.fontFamily
                            font.pixelSize: Math.max(8, Theme.fontSize - 4)
                            font.weight: Font.Medium
                            color: (delegateBtn.selected || delegateBtn.focused) && delegateBtn.page
                                ? delegateBtn.page.selectionColor(delegateBtn.badgeColor, Theme.onAccentColor)
                                : delegateBtn.badgeColor

                            Behavior on color {
                                enabled: delegateBtn.selectionOpacity >= 0.999
                                ColorAnimation {
                                    duration: delegateBtn.transitionDuration
                                    easing.type: Easing.BezierSpline
                                    easing.bezierCurve: delegateBtn.transitionCurve
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
