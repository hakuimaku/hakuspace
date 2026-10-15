import QtQuick
import QtQuick.Controls
import "../../services"
import "../editor" as Editor
import "../motion" as Motion
import "ConfigTreeModel.js" as TreeModel

Item {
    id: root
    signal closeRequested()
    property string confirmation: ""
    // Adjust the browser's left inset here; the file list and Refresh stay aligned.
    readonly property real fileListLeftPadding: 16
    // The footer changes actions while a switch, reload, or VS Code warning is pending.
    readonly property var actionLabels: confirmation === "switch" ? ["Cancel", "Discard & Switch", "Save & Switch"]
                                       : confirmation === "reload" ? ["Keep Editing", "Discard & Reload"]
                                       : confirmation === "vscode" ? ["Cancel", "Open Anyway"]
                                       : ["Reload", "Save"]
    readonly property var actionHints: ({
        "Cancel": "Keep the current draft and cancel this action.",
        "Discard & Switch": "Discard this draft and open the selected file.",
        "Save & Switch": "Save this draft, then open the selected file.",
        "Keep Editing": "Keep the current unsaved draft.",
        "Discard & Reload": "Discard this draft and reload the file from disk.",
        "Open Anyway": "Open the saved disk version in VS Code.",
        "Reload": "Reload the selected file from disk.",
        "Save": "Save the selected file if its disk revision is unchanged."
    })

    function requestSelect(fileId) {
        if (fileId === ConfigEditorStore.selectedFileId) return
        ConfigEditorStore.selectFile(fileId)
        if (ConfigEditorStore.pendingFileId) confirmation = "switch"
    }
    function requestReload() {
        if (ConfigEditorStore.dirty) confirmation = "reload"
        else ConfigEditorStore.reload()
    }
    function requestOpenVsCode() {
        if (!ConfigEditorStore.hasFile) return
        if (ConfigEditorStore.dirty) confirmation = "vscode"
        else ConfigEditorStore.openInVsCode()
    }
    function cancelConfirmation() {
        confirmation = ""
        ConfigEditorStore.pendingFileId = ""
    }
    // Route each footer action through the existing save and dirty-draft flow.
    function activateAction(label) {
        if (label === "Keep Editing" || label === "Cancel") cancelConfirmation()
        else if (label === "Discard & Switch") {
            confirmation = ""
            ConfigEditorStore.discardAndSwitch()
        } else if (label === "Save & Switch") {
            confirmation = ""
            ConfigEditorStore.saveAndSwitch()
        } else if (label === "Discard & Reload") {
            confirmation = ""
            ConfigEditorStore.discard()
            ConfigEditorStore.reload()
        } else if (label === "Open Anyway") {
            confirmation = ""
            ConfigEditorStore.openInVsCode()
        } else if (label === "Reload") requestReload()
        else if (label === "Save") ConfigEditorStore.save()
    }
    function canActivate(label) {
        if (label === "Save") return ConfigEditorStore.canSave
        if (label === "Save & Switch") return ConfigEditorStore.canSave
        if (label === "Reload") return ConfigEditorStore.hasFile && !ConfigEditorStore.loading && !ConfigEditorStore.saving
        return true
    }
    onVisibleChanged: {
        if (visible && !ConfigEditorStore.ready && !ConfigEditorStore.listing)
            ConfigEditorStore.loadFiles()
    }
    Column {
        anchors.fill: parent
        spacing: Theme.pad
        Text {
            text: "Config"
            color: Theme.fg
            font.family: Theme.fontFamily
            font.pixelSize: Math.round(Theme.fontSize * 1.18)
            font.weight: Font.DemiBold
        }
        Row {
            id: contentRow
            width: parent.width
            height: parent.height - 90
            spacing: Theme.pad
            readonly property real browserWidth: Math.min(205, Math.max(125, width * 0.22))
            Column {
                width: contentRow.browserWidth
                height: parent.height
                spacing: Theme.pad
                Flickable {
                    id: fileScroll
                    x: root.fileListLeftPadding
                    width: Math.max(0, parent.width - root.fileListLeftPadding)
                    height: parent.height - 40
                    contentWidth: width
                    contentHeight: fileColumn.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    ScrollBar.vertical: Motion.HScrollBar { id: fileBar }
                    Column {
                        id: fileColumn
                        z: 1
                        onImplicitHeightChanged: Qt.callLater(function() { fileSelectionPill.syncTarget(true) })
                        // Reserve space only while the scrollbar is visible.
                        width: Math.max(0, fileScroll.width - fileBar.reservedGutter)
                        // Gap between the wm and config groups.
                        spacing: 18
                        Motion.SelectionPill {
                            id: fileSelectionPill
                            // Keep the pill outside Column positioning but inside scroll content.
                            parent: fileScroll.contentItem
                            coordinateSpace: fileScroll.contentItem
                            normalColor: Theme.accent
                            z: 0
                        }
                        Repeater {
                            model: ["wm", "config"]
                            delegate: Column {
                                id: fileGroup
                                required property string modelData
                                // Tree rows are sorted directories first, then files by name.
                                readonly property var groupRows: TreeModel.rows(ConfigEditorStore.files, modelData)
                                width: fileColumn.width
                                z: 1
                                // Keep tree rows adjacent so continuation lines stay unbroken.
                                spacing: 0
                                // Adjust height and text margins to change accent header padding.
                                Rectangle {
                                    width: parent.width
                                    height: 32
                                    radius: Theme.radius
                                    color: Theme.accent
                                    Text {
                                        anchors.fill: parent
                                        anchors.leftMargin: 12
                                        anchors.rightMargin: 12
                                        verticalAlignment: Text.AlignVCenter
                                        elide: Text.ElideRight
                                        text: modelData
                                        color: "black"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSize
                                        font.weight: Font.DemiBold
                                    }
                                }
                                Item { width: 1; height: 3 }
                                Repeater {
                                    model: fileGroup.groupRows
                                    delegate: Item {
                                        id: treeRow
                                        required property var modelData
                                        width: fileColumn.width
                                        height: 30
                                        SettingsActionButton {
                                            id: fileRow
                                            property bool selectionReady: false
                                            anchors.fill: parent
                                            visible: treeRow.modelData.type === "file"
                                            radius: Theme.radius
                                            text: ""
                                            selected: ConfigEditorStore.selectedFileId === treeRow.modelData.fileId
                                            selectedOverridesHover: true
                                            idleColor: "transparent"
                                            hoverColor: Qt.lighter(Theme.hoverMuted, 1.18)
                                            pressedColor: Qt.lighter(Theme.hoverMuted, 1.18)
                                            selectedColor: "transparent"
                                            foregroundColor: Theme.fgDim
                                            selectedForegroundColor: Theme.onAccentColor
                                            hoverForegroundColor: Theme.fg
                                            activeFocusOnTab: true
                                            focused: activeFocus
                                            border.width: activeFocus ? 1 : 0
                                            border.color: Theme.accent
                                            onSelectedChanged: {
                                                if (selectionReady && selected) fileSelectionPill.targetItem = fileRow
                                            }
                                            Component.onCompleted: {
                                                selectionReady = true
                                                if (selected) Qt.callLater(function() {
                                                    if (fileRow.selected) fileSelectionPill.snapToItem(fileRow)
                                                })
                                            }
                                            onClicked: root.requestSelect(treeRow.modelData.fileId)
                                            Keys.onReturnPressed: clicked()
                                            Keys.onSpacePressed: clicked()
                                            SettingsTooltip {
                                                target: fileRow
                                                active: fileRow.hovered || fileRow.activeFocus
                                                text: treeRow.modelData.fileId
                                            }
                                        }
                                        Row {
                                            z: 2
                                            anchors.fill: parent
                                            anchors.leftMargin: 8
                                            spacing: 4
                                            ConfigTreeConnector {
                                                height: parent.height
                                                depth: treeRow.modelData.depth
                                                ancestorLast: treeRow.modelData.ancestorLast
                                                isLast: treeRow.modelData.isLast
                                                lineColor: treeRow.modelData.type === "file" ? fileRow.foreground : Theme.fgMuted
                                            }
                                            Text {
                                                width: Math.max(0, parent.width - (treeRow.modelData.depth + 1) * 14 - 4 - parent.spacing)
                                                height: parent.height
                                                verticalAlignment: Text.AlignVCenter
                                                text: treeRow.modelData.label
                                                color: treeRow.modelData.type === "file" ? fileRow.foreground : Theme.fgDim
                                                font.family: Theme.fontFamily
                                                font.pixelSize: Math.max(10, Theme.fontSize - 1)
                                                font.weight: treeRow.modelData.type === "directory" ? Font.DemiBold : Font.Normal
                                                elide: Text.ElideMiddle
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                SettingsActionButton {
                    id: refreshButton
                    x: root.fileListLeftPadding
                    width: Math.max(0, parent.width - root.fileListLeftPadding)
                    height: 30
                    radius: Theme.radius
                    text: "Refresh files"
                    idleColor: Theme.hoverMuted
                    hoverColor: Qt.lighter(Theme.hoverMuted, 1.18)
                    foregroundColor: Theme.fg
                    hoverForegroundColor: Theme.fg
                    activeFocusOnTab: true
                    focused: activeFocus
                    onClicked: ConfigEditorStore.refreshFiles()
                    Keys.onReturnPressed: clicked()
                    Keys.onSpacePressed: clicked()
                    SettingsTooltip {
                        target: refreshButton
                        active: refreshButton.hovered || refreshButton.activeFocus
                        text: "Scan wm and config folders for files again."
                    }
                }
            }
            Rectangle { width: 1; height: parent.height; color: Theme.border }
            Column {
                width: Math.max(0, contentRow.width - contentRow.browserWidth - Theme.pad - 1)
                height: parent.height
                spacing: 6
                Row {
                    width: parent.width
                    height: 34
                    spacing: 6
                    Text {
                        id: selectedPathText
                        width: Math.max(30, parent.width - 145)
                        height: parent.height
                        verticalAlignment: Text.AlignVCenter
                        text: ConfigEditorStore.selectedFileId || "Select a file"
                        color: Theme.fg
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                        elide: Text.ElideMiddle
                        HoverHandler { id: selectedPathHover }
                        SettingsTooltip {
                            target: selectedPathText
                            active: selectedPathHover.hovered && ConfigEditorStore.hasFile
                            text: ConfigEditorStore.selectedFileId
                        }
                    }
                    SettingsActionButton {
                        id: openButton
                        width: 139
                        height: 30
                        radius: Theme.radius
                        text: "Open in VS Code"
                        fontSize: Math.max(10, Theme.fontSize - 1)
                        idleColor: Theme.hoverMuted
                        hoverColor: Qt.lighter(Theme.hoverMuted, 1.18)
                        foregroundColor: Theme.fg
                        hoverForegroundColor: Theme.fg
                        enabled: ConfigEditorStore.hasFile
                        activeFocusOnTab: enabled
                        focused: activeFocus
                        onClicked: root.requestOpenVsCode()
                        Keys.onReturnPressed: clicked()
                        Keys.onSpacePressed: clicked()
                        SettingsTooltip {
                            target: openButton
                            active: openButton.hovered || openButton.activeFocus
                            text: "Open the saved disk version of this file in VS Code."
                        }
                    }
                }
                Rectangle { width: parent.width; height: 1; color: Theme.border }
                Rectangle {
                    width: parent.width
                    height: parent.height - 41
                    radius: Theme.radius
                    color: Theme.hoverMuted
                    Editor.PlainTextEditor {
                        id: editor
                        anchors.fill: parent
                        anchors.margins: 6
                        text: ConfigEditorStore.text
                        codeEditingEnabled: true
                        fileId: ConfigEditorStore.selectedFileId
                        readOnly: !ConfigEditorStore.hasFile || ConfigEditorStore.loading
                        placeholderText: ConfigEditorStore.loading ? "Loading…" : "Select a config file"
                        fontFamily: "monospace"
                        wrapMode: TextEdit.NoWrap
                        onTextEdited: newText => ConfigEditorStore.setText(newText)
                        onSaveRequested: ConfigEditorStore.save()
                        onEscapeRequested: {
                            if (root.confirmation) root.cancelConfirmation()
                            else root.closeRequested()
                        }
                    }
                }
            }
        }
        Rectangle { width: parent.width; height: 1; color: Theme.border }
        Row {
            id: footer
            width: parent.width
            height: 38
            spacing: 6
            Text {
                width: Math.max(80, footer.width - actionRow.width - 8)
                height: parent.height
                verticalAlignment: Text.AlignVCenter
                text: root.confirmation === "switch" ? "Unsaved changes to " + ConfigEditorStore.selectedFileId
                    : root.confirmation === "reload" ? "Discard edits and reload?"
                    : root.confirmation === "vscode" ? "VS Code opens the saved disk version."
                    : ConfigEditorStore.error || ConfigEditorStore.statusMessage
                      || (ConfigEditorStore.saving ? "Saving…" : ConfigEditorStore.loading ? "Loading…"
                          : ConfigEditorStore.listing ? "Refreshing…"
                          : ConfigEditorStore.dirty ? "Unsaved changes — " + ConfigEditorStore.selectedFileId
                          : ConfigEditorStore.skippedCount ? ConfigEditorStore.skippedCount + " files skipped" : "")
                color: ConfigEditorStore.error ? Theme.accent : Theme.fgDim
                font.family: Theme.fontFamily
                font.pixelSize: Math.max(10, Theme.fontSize - 2)
                elide: Text.ElideRight
            }
            Row {
                id: actionRow
                spacing: 5
                Repeater {
                    model: root.actionLabels
                    delegate: SettingsActionButton {
                        id: actionButton
                        required property string modelData
                        readonly property bool allowed: root.canActivate(modelData)
                        TextMetrics { id: actionMetrics; font.family: Theme.fontFamily; font.pixelSize: Math.max(10, Theme.fontSize - 1); text: actionButton.modelData }
                        width: Math.max(72, actionMetrics.width + 16)
                        height: 32
                        radius: Theme.radius
                        text: modelData
                        fontSize: Math.max(10, Theme.fontSize - 1)
                        readonly property bool primary: modelData === "Save" || modelData === "Save & Switch"
                        idleColor: primary ? Theme.accent : Theme.hoverMuted
                        hoverColor: primary ? Theme.accent : Qt.lighter(Theme.hoverMuted, 1.18)
                        pressedColor: primary ? Theme.accent : Qt.lighter(Theme.hoverMuted, 1.18)
                        disabledColor: Theme.hoverMuted
                        foregroundColor: primary ? Theme.onAccentColor : Theme.fg
                        hoverForegroundColor: primary ? Theme.onAccentColor : Theme.fg
                        enabled: allowed
                        activeFocusOnTab: enabled
                        focused: activeFocus
                        onClicked: root.activateAction(modelData)
                        Keys.onReturnPressed: clicked()
                        Keys.onSpacePressed: clicked()
                        SettingsTooltip {
                            target: actionButton
                            active: actionButton.hovered || actionButton.activeFocus
                            text: root.actionHints[actionButton.modelData] || actionButton.modelData
                        }
                    }
                }
            }
        }
    }
}
