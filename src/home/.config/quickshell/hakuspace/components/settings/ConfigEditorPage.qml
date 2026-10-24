import QtQuick
import QtQuick.Controls
import "../../services"
import "SettingsCatalog.js" as Catalog
import "../editor" as Editor

Item {
    id: root
    signal closeRequested()
    // Forward layer shortcuts before the editor handles indentation and text input.
    property Item shortcutTarget: null
    readonly property var visibleFiles: Catalog.configFiles(ConfigEditorStore.files, WM.backendName)
    // Explicit file selection preserves the editor's existing revision and draft guards.
    function reveal(id) { }
    // Publish pending input before applying the same guarded Save action.
    function saveFromKeyboard() {
        editor.finishComposition()
        if (!confirmation && canActivate("Save")) activateAction("Save")
    }
    property string confirmation: ""
    // Keep file-switch and reload confirmations in the shared footer.
    readonly property var actionLabels: confirmation === "switch" ? ["Cancel", "Discard & Switch", "Save & Switch"]
                                       : confirmation === "reload" ? ["Keep Editing", "Discard & Reload"]
                                       : ["Reload", "Save"]
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
        } else if (label === "Reload") requestReload()
        else if (label === "Save") ConfigEditorStore.save()
    }
    // Preserve save, revision and IO guards for the shared footer.
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

    Column {
        anchors.fill: parent
        spacing: Theme.spaceMd
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
            color: Qt.tint(Theme.surface, Qt.alpha(Theme.hoverMuted, 0.18))
            border.width: 1
            border.color: Theme.hoverMuted
            Editor.PlainTextEditor {
                id: editor
                settingsNavigationEnabled: true
                shortcutTarget: root.shortcutTarget
                anchors.fill: parent
                anchors.margins: Theme.spaceMd
                text: ConfigEditorStore.text
                codeEditingEnabled: true
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
