import QtQuick
import "../../services"
import "../editor"

FocusScope {
    id: root
    signal closeRequested(bool keyboard)

    // Keep editing focus inside the note.
    function forceFocus() { editor.forceEditorFocus() }

    PlainTextEditor {
        id: editor
        anchors.fill: parent
        text: TextStore.scratchDraft
        placeholderText: "write something temporary here :v"
        onTextEdited: newText => TextStore.setScratchDraft(newText)
        onEscapeRequested: root.closeRequested(true)
        onSaveRequested: TextStore.flushScratch()
    }
}
