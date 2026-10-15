import QtQuick
import "../../services"
import "../editor"

FocusScope {
    id: root
    signal closeRequested(bool keyboard)
    signal keyboardInteraction()

    // Keep editing focus inside the note.
    function forceFocus() { editor.forceEditorFocus() }

    PlainTextEditor {
        id: editor
        anchors.fill: parent
        text: TextStore.scratchDraft
        placeholderText: "write something temporary here :v"
        onTextEdited: newText => {
            root.keyboardInteraction()
            TextStore.setScratchDraft(newText)
        }
        onEscapeRequested: root.closeRequested(true)
        onSaveRequested: {
            root.keyboardInteraction()
            TextStore.flushScratch()
        }
    }
}
