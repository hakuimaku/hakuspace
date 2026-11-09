import QtQuick
import QtQuick.Controls
import Quickshell
import "../../services"
import "../../config/UiCatalog.js" as UiCatalog
import "../motion" as Motion
import "../settings" as Settings
import "../base" as Base

Item {
    id: root

    property string query: ""
    property bool panelOpen: true
    // Keep row context and delete confirmation tied to a single custom identity.
    property string actionRowId: ""
    property string deleteRowId: ""
    property string pendingDeleteId: ""
    property int pendingDeleteIndex: -1
    property int selectionHint: -1
    property string actionError: ""
    // Retain editor ownership until its closing animation and pending save complete.
    property bool editorRequested: false
    property var editorEntry: null
    readonly property var itemEditor: editorLoader.active ? editorLoader.item : null
    // Keep the host expanded until the editor completes its closing fade.
    readonly property real editorHeight: itemEditor ? itemEditor.implicitHeight : 0
    readonly property alias currentIndex: generalList.currentIndex
    readonly property var customItems: GeneralMenuService.items.filter(function(item) {
        return item.enabled && item.id !== "app-menu" && item.systemAction !== "app-menu"
    }).map(function(item) { return Object.assign({}, item, {kind: "custom"}) })
    readonly property var staticItems: UiCatalog.hakuMenuGeneralItems.map(function(item) {
        return Object.assign({}, item, {kind: "static", mutable: false})
    })
    property color rowHoverColor: Theme.hoverMuted
    property color rowSelectedColor: Theme.accent
    readonly property real itemGap: Math.max(3, Math.round(Theme.gap * 0.35) + 1)
    readonly property real rowHeight: Math.max(46, Theme.fontSize * 3.0)
    readonly property real sectionGap: Math.max(32, Theme.controlHeight)
    // Compose actions while keeping structural controls outside the selectable model.
    readonly property var visibleItems: filteredItems()
    signal restoreSearchFocus()
    signal launched()
    signal highlightedLabelChanged(string label)

    // Normalize the General tab search prefix.
    function normalizedQuery() {
        var text = query.trim()
        if (text.startsWith(">")) text = text.slice(1)
        return text.trim().toLowerCase()
    }

    // Search presentation labels without using them as identity.
    function matches(item) {
        var q = normalizedQuery()
        if (q.length === 0) return true
        return item.label.toLowerCase().indexOf(q) >= 0
    }

    // Merge filtered custom and static blocks only at the presentation boundary.
    function filteredItems() {
        var custom = customItems.filter(root.matches)
        var fixed = staticItems.filter(root.matches).map(function(item, index) {
            return Object.assign({}, item, {sectionStart: index === 0 && custom.length > 0})
        })
        return custom.concat(fixed)
    }

    // Close the previous row's controls without changing keyboard selection.
    function closeRail() {
        actionRowId = ""
        deleteRowId = ""
        actionError = ""
    }

    // Right click toggles only custom controls and never launches an action.
    function rowClicked(index, button) {
        var item = visibleItems[index]
        if (!item || editorRequested || itemEditor) return
        if (button === Qt.RightButton) {
            var next = item.kind === "custom" && actionRowId !== item.id ? item.id : ""
            closeRail()
            actionRowId = next
        } else if (button === Qt.LeftButton) {
            closeRail()
            activateIndex(index)
        }
    }

    // Add appends to the custom document; editing keeps the selected stable ID.
    function openEditor(item) {
        if (GeneralMenuService.busy || (item && item.kind !== "custom")) return
        closeRail()
        editorEntry = item || null
        editorRequested = true
    }

    // Hand keyboard focus back only while the General view still owns interaction.
    function closeEditor() {
        editorRequested = false
        if (visible && panelOpen) restoreSearchFocus()
    }

    // Confirm deletion inside the row before sending a mutation to the backend.
    function deleteAction(item) {
        if (item.kind !== "custom" || actionRowId !== item.id || GeneralMenuService.busy) return
        if (deleteRowId !== item.id) { deleteRowId = item.id; return }
        if (GeneralMenuService.remove(item.id)) {
            pendingDeleteId = item.id
            pendingDeleteIndex = visibleItems.findIndex(function(row) { return row.id === item.id })
            actionError = ""
        }
    }

    // Discard transient controls when query, tab or menu ownership changes.
    function resetContext() {
        closeRail()
        editorRequested = false
    }

    // Select the first row after a snapshot or query change.
    function resetSelection() {
        generalList.currentIndex = visibleItems.length > 0 ? Math.min(Math.max(0, selectionHint), visibleItems.length - 1) : -1
        selectionHint = -1
        if (generalList.currentIndex >= 0)
            generalList.positionViewAtIndex(generalList.currentIndex, ListView.Beginning)
        syncSelectionLabel()
    }

    // Expose the highlighted label to the menu host.
    function syncSelectionLabel() {
        if (!visible) return
        var index = generalList.currentIndex
        if (index < 0 || index >= visibleItems.length) {
            root.highlightedLabelChanged("")
            return
        }
        root.highlightedLabelChanged(visibleItems[index].label || "")
    }

    // Clamp keyboard navigation to visible rows.
    function moveSelection(delta) {
        if (editorRequested || itemEditor) return
        var count = visibleItems.length
        if (count === 0) return
        var next = generalList.currentIndex
        if (next < 0) next = 0
        else next = Math.max(0, Math.min(count - 1, next + delta))
        generalList.currentIndex = next
        generalList.positionViewAtIndex(next, ListView.Contain)
        syncSelectionLabel()
    }

    // Launch the selected backend identity.
    function activateIndex(index) {
        if (index < 0 || index >= visibleItems.length) return
        var item = visibleItems[index]
        if (!item) return

        if (editorRequested || itemEditor) return
        closeRail()
        if (item.kind === "static") {
            if (item.action === "taskManager") {
                UiState.openTaskManagerFromHakuMenu()
                return
            }
            if (item.action === "settings") {
                // Closing the menu clears its output name before Settings takes ownership.
                var screenName = UiState.hakuMenuScreenName
                root.launched()
                UiState.openSettings(screenName)
                return
            }
            if (item.action === "shellSwitcher") {
                var screenName = UiState.hakuMenuScreenName
                root.launched()
                UiState.openActionMenu(screenName, "shell")
                return
            }
            Quickshell.execDetached(item.command)
            root.launched()
        } else if (GeneralMenuService.run(item.id)) root.launched()
    }

    // Activate the current keyboard selection.
    function activateCurrent() {
        activateIndex(generalList.currentIndex)
    }

    onVisibleItemsChanged: Qt.callLater(resetSelection)
    onQueryChanged: resetContext()
    onPanelOpenChanged: if (!panelOpen) resetContext()
    onVisibleChanged: {
        if (visible) {
            GeneralMenuService.refresh()
            resetSelection()
        } else {
            resetContext()
            root.highlightedLabelChanged("")
        }
    }
    Component.onCompleted: if (visible) GeneralMenuService.refresh()

    Connections {
        target: GeneralMenuService
        function onMutationFinished(operation, success) {
            if (operation !== "remove" || !root.pendingDeleteId) return
            root.pendingDeleteId = ""
            if (success) {
                root.selectionHint = root.pendingDeleteIndex
                root.closeRail()
                Qt.callLater(root.resetSelection)
            } else root.actionError = GeneralMenuService.error === "conflict"
                ? "Actions changed elsewhere. Review and try again." : GeneralMenuService.error
        }
    }

    Base.LifecycleLoader {
        id: editorLoader
        requested: root.editorRequested
        GeneralItemEditor {
            parent: root
            anchors.fill: parent
            requested: root.editorRequested
            entry: root.editorEntry
            onCloseRequested: root.closeEditor()
        }
    }

    ListView {
        id: generalList
        anchors.fill: parent
        anchors.margins: Theme.gap
        anchors.bottomMargin: actionMessage.visible ? actionMessage.height + Theme.gap : Theme.gap
        enabled: !editorLoader.active
        clip: true
        spacing: root.itemGap
        boundsBehavior: Flickable.StopAtBounds
        currentIndex: count > 0 ? 0 : -1
        model: root.visibleItems
        // Keep Add reachable when every custom row is hidden, disabled or removed.
        header: GeneralDivider {
            width: generalList.width - vbar.reservedGutter
            height: visible ? implicitHeight : 0
            visible: root.customItems.length === 0 && root.normalizedQuery().length === 0
            showLine: false
            showAdd: !GeneralMenuService.busy
            onAddRequested: root.openEditor(null)
        }
        onCurrentIndexChanged: {
            root.syncSelectionLabel();
            if (currentIndex < 0) {
                selectionPill.targetItem = null;
            }
        }

        Motion.SelectionPill {
            id: selectionPill
            parent: generalList.contentItem
            z: 0
            normalColor: Theme.accent
        }

        ScrollBar.vertical: Motion.HScrollBar {
            id: vbar
        }

        delegate: Item {
            id: rowWrap
            required property var modelData
            required property int index
            width: generalList.width
            height: row.height + (modelData.sectionStart ? root.sectionGap : 0)

            GeneralDivider {
                anchors { left: parent.left; right: parent.right; rightMargin: vbar.reservedGutter }
                height: root.sectionGap
                visible: !!rowWrap.modelData.sectionStart
                showAdd: root.normalizedQuery().length === 0
                enabled: !GeneralMenuService.busy
                onAddRequested: root.openEditor(null)
            }

            Motion.MorphButton {
                id: row
                objectName: "general-row-" + rowWrap.modelData.id
                z: 1
                interactive: false
                externalHovered: rowInput.containsMouse
                externalPressed: rowInput.pressed
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.rightMargin: vbar.reservedGutter + (rail.visible ? rail.width + Theme.spaceMd : 0)
                anchors.bottom: parent.bottom
                height: root.rowHeight
                radius: Theme.radius
                selected: generalList.currentIndex === rowWrap.index
                selectedOverridesHover: true
                idleColor: "transparent"
                hoverColor: (selected || focused) ? "transparent" : root.rowHoverColor
                pressedColor: (selected || focused) ? "transparent" : root.rowHoverColor
                selectedColor: "transparent"
                foregroundColor: Theme.fg
                hoverForegroundColor: (selected || focused) ? Theme.onAccentColor : Theme.fg
                pressedForegroundColor: (selected || focused) ? Theme.onAccentColor : Theme.fg
                selectedForegroundColor: Theme.onAccentColor
                hoverScaleDelta: 0.003
                pressScaleDelta: 0.012

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

                onHoveredChanged: {
                    if (hovered) {
                        generalList.currentIndex = rowWrap.index
                        root.syncSelectionLabel()
                    }
                }
                Accessible.role: Accessible.Button
                Accessible.name: rowWrap.modelData.label
                Accessible.onPressAction: root.activateIndex(rowWrap.index)
                MouseArea {
                    id: rowInput
                    objectName: "general-row-input-" + rowWrap.modelData.id
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    cursorShape: Qt.PointingHandCursor
                    onClicked: mouse => root.rowClicked(rowWrap.index, mouse.button)
                }

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.pad * 1.5
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.pad * 1.5
                    anchors.verticalCenter: parent.verticalCenter
                    text: rowWrap.modelData.icon + "  " + rowWrap.modelData.label
                    color: row.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize + 1
                    font.weight: (row.selected || row.focused) ? Font.Medium : Font.Normal
                    elide: Text.ElideRight
                }
            }

            Row {
                id: rail
                objectName: "general-rail-" + rowWrap.modelData.id
                anchors { right: parent.right; rightMargin: vbar.reservedGutter; verticalCenter: row.verticalCenter }
                visible: rowWrap.modelData.kind === "custom" && root.actionRowId === rowWrap.modelData.id
                enabled: !GeneralMenuService.busy
                z: 2
                spacing: Theme.spaceSm
                Settings.SettingsActionButton {
                    id: editButton
                    objectName: "general-edit-" + rowWrap.modelData.id
                    width: 32; height: 32
                    visible: root.deleteRowId !== rowWrap.modelData.id
                    text: ""
                    idleColor: Theme.hoverMuted
                    hoverColor: Qt.tint(Theme.hoverMuted, Qt.alpha(Theme.accent, 0.12))
                    pressedColor: Qt.tint(Theme.hoverMuted, Qt.alpha(Theme.accent, 0.2))
                    foregroundColor: Theme.fg
                    hoverForegroundColor: foregroundColor
                    pressedForegroundColor: foregroundColor
                    activeFocusOnTab: true; focused: activeFocus
                    Accessible.name: "Edit " + rowWrap.modelData.label
                    onClicked: root.openEditor(rowWrap.modelData)
                    Keys.onReturnPressed: clicked()
                    Keys.onSpacePressed: clicked()
                    Settings.SettingsTooltip { target: editButton; active: editButton.hovered; text: "Edit custom action" }
                }
                Settings.SettingsActionButton {
                    id: deleteButton
                    objectName: "general-delete-" + rowWrap.modelData.id
                    width: root.deleteRowId === rowWrap.modelData.id ? 84 : 32
                    height: 32
                    text: root.deleteRowId === rowWrap.modelData.id ? "Delete?" : "󰆴"
                    idleColor: Theme.hoverMuted
                    hoverColor: Qt.tint(Theme.hoverMuted, Qt.alpha(Theme.accent, 0.12))
                    pressedColor: Qt.tint(Theme.hoverMuted, Qt.alpha(Theme.accent, 0.2))
                    foregroundColor: Theme.fg
                    hoverForegroundColor: foregroundColor
                    pressedForegroundColor: foregroundColor
                    activeFocusOnTab: true; focused: activeFocus
                    Accessible.name: root.deleteRowId === rowWrap.modelData.id ? "Confirm delete " + rowWrap.modelData.label : "Delete " + rowWrap.modelData.label
                    onClicked: root.deleteAction(rowWrap.modelData)
                    Keys.onReturnPressed: clicked()
                    Keys.onSpacePressed: clicked()
                    Behavior on width { NumberAnimation { duration: HAnimation.fast } }
                    Settings.SettingsTooltip {
                        objectName: "general-delete-tooltip-" + rowWrap.modelData.id
                        target: deleteButton
                        active: deleteButton.hovered || deleteButton.activeFocus
                        text: root.deleteRowId === rowWrap.modelData.id ? "Confirm deletion" : "Delete custom action"
                    }
                }
                Settings.SettingsActionButton {
                    objectName: "general-delete-cancel-" + rowWrap.modelData.id
                    width: 32; height: 32
                    visible: root.deleteRowId === rowWrap.modelData.id
                    text: "×"
                    idleColor: Theme.hoverMuted
                    hoverColor: Qt.tint(Theme.hoverMuted, Qt.alpha(Theme.accent, 0.12))
                    pressedColor: Qt.tint(Theme.hoverMuted, Qt.alpha(Theme.accent, 0.2))
                    foregroundColor: Theme.fg
                    hoverForegroundColor: foregroundColor
                    pressedForegroundColor: foregroundColor
                    activeFocusOnTab: true; focused: activeFocus
                    Accessible.name: "Cancel delete"
                    onClicked: root.deleteRowId = ""
                    Keys.onReturnPressed: clicked()
                    Keys.onSpacePressed: clicked()
                }
            }
        }

        Text {
            anchors.centerIn: parent
            text: GeneralMenuService.error || (root.normalizedQuery().length > 0 ? "No General actions found" : "No General actions")
            color: Theme.fgMuted
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize + 1
            visible: generalList.count === 0 && !GeneralMenuService.busy
        }
    }

    Text {
        id: actionMessage
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: Theme.gap }
        text: root.actionError || GeneralMenuService.error
        visible: text.length > 0 && !root.editorRequested
        color: Theme.danger
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize - 1
        wrapMode: Text.Wrap
    }
}
