import QtQuick
import "../../services"
import "../editor"

FocusScope {
    id: root
    signal closeRequested()
    signal interactionRequested()

    // Keep editing focus inside the note.
    function forceFocus() { editor.forceEditorFocus() }

    // Commit focused input, flush the draft and release the note's focus scope.
    function finishEditing() {
        if (activeFocus) Qt.inputMethod.commit()
        editor.finishComposition()
        TextStore.flushScratch()
        focus = false
    }

    PlainTextEditor {
        id: editor
        anchors.fill: parent
        text: TextStore.scratchDraft
        placeholderText: "write something temporary here :v"
        onInteractionRequested: root.interactionRequested()
        onTextEdited: newText => TextStore.setScratchDraft(newText)
        onEscapeRequested: root.closeRequested()
        onSaveRequested: TextStore.flushScratch()
    }
}
