import QtQuick
import "../../services"
import "../editor" as Editor

Item {
    id: root
    signal closeRequested()
    // Forward layer shortcuts before the editor handles indentation and text input.
    property Item shortcutTarget: null
    // Publish pending input before applying the same guarded Save action.
    function saveFromKeyboard() {
        editor.finishComposition()
        if (!confirmation && canActivate("Save")) activateAction("Save")
    }
    property string confirmation: ""
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
    // Warn that the external editor opens the saved version.
    function requestOpenVsCode() {
        if (!ConfigEditorStore.hasFile) return
        if (ConfigEditorStore.dirty) confirmation = "vscode"
        else ConfigEditorStore.openInVsCode()
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
        } else if (label === "Open Anyway") {
            confirmation = ""
            ConfigEditorStore.openInVsCode()
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
                    : root.confirmation === "vscode" ? "VS Code opens the saved disk version."
                    : ConfigEditorStore.error || ConfigEditorStore.statusMessage
                      || (ConfigEditorStore.saving ? "Saving…" : ConfigEditorStore.loading ? "Loading…"
                          : ConfigEditorStore.listing ? "Refreshing…"
                          : ConfigEditorStore.dirty ? "Unsaved changes — " + ConfigEditorStore.selectedFileId
                          : ConfigEditorStore.skippedCount ? ConfigEditorStore.skippedCount + " files skipped" : "")
    readonly property bool footerDirty: ConfigEditorStore.dirty
    readonly property bool footerError: !!ConfigEditorStore.error

    Column {
        anchors.fill: parent
        spacing: 6
        Text { text: "Config"; color: Theme.fg; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize + 5; font.weight: Font.DemiBold }
        Text { visible: root.height >= 200; width: parent.width; text: "Your configuration files, with draft and revision protection."; color: Theme.fgDescription; font.family: Theme.fontFamily; font.pixelSize: Math.max(10, Theme.fontSize - 1); wrapMode: Text.Wrap }
        Column {
            width: parent.width
            height: Math.max(0, parent.height - y)
            spacing: 6
            Row {
                width: parent.width
                height: 40
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
                    height: 36
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
            Rectangle { width: parent.width; height: 1; color: Theme.hoverMuted }
            Rectangle {
                width: parent.width
                height: Math.max(0, parent.height - y)
                radius: Theme.radius
                color: Qt.tint(Theme.surface, Qt.alpha(Theme.hoverMuted, 0.18))
                border.width: 1
                border.color: Theme.hoverMuted
                Editor.PlainTextEditor {
                    id: editor
                    settingsNavigationEnabled: true
                    shortcutTarget: root.shortcutTarget
                    anchors.fill: parent
                    anchors.margins: parent.height < 100 ? 4 : 10
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
}
