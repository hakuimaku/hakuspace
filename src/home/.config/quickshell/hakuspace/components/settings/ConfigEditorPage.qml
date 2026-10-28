import QtQuick
import QtQuick.Controls
import "../../services"
import "../../config/SettingsCatalog.js" as Catalog
import "../editor" as Editor

Item {
    id: root
    signal closeRequested()
    // Forward layer shortcuts before the editor handles indentation and text input.
    property Item shortcutTarget: null
    readonly property bool popupOpen: draftDialog.visible
    readonly property var visibleFiles: Catalog.configFiles(ConfigEditorStore.files, WM.backendName)
    // Explicit file selection preserves the editor's existing revision and draft guards.
    function reveal(id) { }
    // Publish pending input before applying the same guarded Save action.
    function saveFromKeyboard() {
        editor.finishComposition()
        if (!confirmation) { var action = ConfigEditorStore.reloadSupported ? "Save & Reload" : "Save only"; if (canActivate(action)) activateAction(action) }
    }
    property string confirmation: ""
    // Draft replacement remains explicit without reserving a toolbar row.
    function focusConfirmation() { if (confirmationActions.count) confirmationActions.itemAt(0).forceActiveFocus() }
    // Only a pending destructive draft action needs visible buttons.
    readonly property var actionLabels: confirmation === "switch" ? ["Cancel", "Discard & Switch", "Save & Switch"]
                                       : confirmation === "reload" ? ["Keep Editing", "Discard & Reload"]
                                       : []
    readonly property var actionHints: ({
        "Cancel": "Keep the current draft and cancel this action.",
        "Discard & Switch": "Discard this draft and open the selected file.",
        "Save & Switch": "Save this draft, then open the selected file.",
        "Keep Editing": "Keep the current unsaved draft.",
        "Discard & Reload": "Discard this draft and reload the file from disk.",
        "Reload": "Reload the selected file from disk.",
        "Save": "Save the selected file if its disk revision is unchanged."
    })

    // Guard the current draft before selecting another file.
    function requestSelect(fileId) {
        if (fileId === ConfigEditorStore.selectedFileId) return
        ConfigEditorStore.selectFile(fileId)
        if (ConfigEditorStore.pendingFileId) confirmation = "switch"
    }
    // Confirm before replacing an unsaved draft with the disk version.
    function requestReload() {
        if (ConfigEditorStore.dirty) confirmation = "reload"
        else ConfigEditorStore.reload()
    }
    // Keep the current draft and clear any pending file selection.
    function cancelConfirmation() {
        confirmation = ""
        ConfigEditorStore.pendingFileId = ""
    }
    // Route document actions through the existing save and dirty-draft guards.
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
        } else if (label === "Reload from disk") requestReload()
        else if (label === "Validate") ConfigEditorStore.validateDraft()
        else if (label === "Save only") ConfigEditorStore.save("write")
        else if (label === "Save & Reload") ConfigEditorStore.save("save-reload")
        else if (label === "Revert to last working") ConfigEditorStore.save("restore-backup")
        else if (label === "Open in VS Code") ConfigEditorStore.openInVsCode()
    }
    // Preserve save, revision and IO guards for document actions.
    function canActivate(label) {
        if (label === "Save only") return ConfigEditorStore.canSave
        if (label === "Save & Reload") return ConfigEditorStore.canSave && ConfigEditorStore.reloadSupported
        if (label === "Validate") return ConfigEditorStore.hasFile && !ConfigEditorStore.busy
        if (label === "Save & Switch") return ConfigEditorStore.canSave
        if (label === "Revert to last working") return ConfigEditorStore.reloadSupported && ConfigEditorStore.hasFile && !ConfigEditorStore.dirty && !ConfigEditorStore.busy
        if (label === "Open in VS Code") return ConfigEditorStore.hasFile && !ConfigEditorStore.openingExternal
        if (label === "Reload from disk") return ConfigEditorStore.hasFile && !ConfigEditorStore.loading && !ConfigEditorStore.saving
        return true
    }
    onVisibleChanged: {
        if (visible && !ConfigEditorStore.ready && !ConfigEditorStore.listing)
            ConfigEditorStore.loadFiles()
    }

    // Status and actions stay driven by the existing confirmation state machine.
    readonly property string footerStatus: root.confirmation === "switch" ? "Unsaved changes to " + ConfigEditorStore.selectedFileId
                    : root.confirmation === "reload" ? "Discard edits and reload?"
                    : ConfigEditorStore.error || ConfigEditorStore.statusMessage
                      || (ConfigEditorStore.saving ? "Saving…" : ConfigEditorStore.loading ? "Loading…"
                          : ConfigEditorStore.listing ? "Refreshing…"
                          : ConfigEditorStore.dirty ? "Unsaved changes — " + ConfigEditorStore.selectedFileId
                          : ConfigEditorStore.skippedCount ? ConfigEditorStore.skippedCount + " files skipped" : "")
    readonly property bool footerDirty: ConfigEditorStore.dirty
    readonly property bool footerError: !!ConfigEditorStore.error

    Dialog {
        id: draftDialog
        parent: Overlay.overlay
        anchors.centerIn: parent
        width: Math.min(520, root.width)
        modal: true; focus: true
        visible: root.visible && root.confirmation.length > 0
        closePolicy: Popup.CloseOnEscape
        onOpened: root.focusConfirmation()
        onRejected: root.cancelConfirmation()
        background: Rectangle { color: Theme.surface; radius: Theme.largeRadius; border.width: 0; border.color: Theme.hoverMuted }
        contentItem: Column {
            spacing: Theme.spaceMd
            Text { width: parent.width; text: root.footerStatus; color: Theme.fg; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize; wrapMode: Text.Wrap; horizontalAlignment: Text.AlignHCenter }
            Flow {
                width: parent.width; spacing: Theme.spaceSm
                Repeater {
                    id: confirmationActions
                    model: root.actionLabels
                    delegate: SettingsActionButton {
                        required property string modelData
                        TextMetrics { id: actionMetrics; text: modelData; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize - 1 }
                        width: Math.min(draftDialog.availableWidth, actionMetrics.width + 28); height: Theme.comfortableControlHeight
                        text: modelData; fontSize: Theme.fontSize - 1
                        enabled: root.canActivate(modelData); activeFocusOnTab: true; focused: activeFocus
                        onClicked: root.activateAction(modelData)
                        Keys.onReturnPressed: clicked()
                        Keys.onSpacePressed: clicked()
                    }
                }
            }
        }
    }
    Column {
        anchors.fill: parent
        spacing: Theme.spaceMd
        Text { width: parent.width; visible: !!ConfigEditorStore.error; text: ConfigEditorStore.error; color: Theme.fgDescription; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize - 2; wrapMode: Text.Wrap }
        SettingsChoiceRow {
            width: parent.width
            options: root.visibleFiles.map(file => ({label: file.id, value: file.id}))
            value: ConfigEditorStore.selectedFileId
            shortcutTarget: root.shortcutTarget
            Accessible.name: "Configuration file"
            onChosen: fileId => root.requestSelect(fileId)
        }
        Rectangle {
            width: parent.width
            height: Math.max(0, root.height - y)
            radius: Theme.radius
            color: Qt.tint(Theme.surface, Qt.alpha(Theme.hoverMuted, 0.35))
            border.width: 0
            border.color: Theme.hoverMuted
            Editor.PlainTextEditor {
                id: editor
                settingsNavigationEnabled: true
                shortcutTarget: root.shortcutTarget
                anchors.fill: parent
                anchors.margins: Theme.spaceMd
                text: ConfigEditorStore.text
                codeEditingEnabled: true
                showLineNumbers: true
                fileId: ConfigEditorStore.selectedFileId
                readOnly: !ConfigEditorStore.hasFile || ConfigEditorStore.loading
                placeholderText: ConfigEditorStore.loading ? "Loading…" : "Select a config file"
                fontFamily: "monospace"
                wrapMode: TextEdit.NoWrap
                onTextEdited: newText => ConfigEditorStore.setText(newText)
                onSaveRequested: root.saveFromKeyboard()
                onEscapeRequested: {
                    if (root.confirmation) root.cancelConfirmation()
                    else root.closeRequested()
                }
            }
        }
    }
}
