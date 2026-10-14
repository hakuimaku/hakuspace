import QtQuick
import QtQuick.Controls
import "../../services"
import "PlainTextEditOps.js" as EditOps

// Reusable multiline editor that keeps input as plain text.
Item {
    id: root

    property string text: ""
    property bool readOnly: false
    property string placeholderText: ""
    property string fontFamily: Theme.fontFamily
    property int fontPixelSize: Math.max(12, Theme.fontSize - 1)
    property int wrapMode: TextEdit.Wrap
    property bool codeEditingEnabled: false
    property string fileId: ""
    property string indentText: "    "
    property bool _syncingExternal: false
    property var _undoGroups: []
    property var _redoGroups: []

    signal textEdited(string newText)
    signal escapeRequested()
    signal saveRequested()

    // Focus the input after its parent panel opens.
    function forceEditorFocus() {
        textArea.forceActiveFocus()
    }

    // Apply a bounded edit so Qt retains its native undo history.
    function applyEdit(operation) {
        if (!operation.changed || readOnly) return false
        if (!operation.selectionOnly) {
            var before = textArea.text
            var priorStart = textArea.selectionStart
            var priorEnd = textArea.selectionEnd
            _syncingExternal = true
            if (operation.rangeStart !== operation.rangeEnd)
                textArea.remove(operation.rangeStart, operation.rangeEnd)
            if (operation.replacement.length)
                textArea.insert(operation.rangeStart, operation.replacement)
            _syncingExternal = false
            root.textEdited(textArea.text)
            if (operation.rangeStart !== operation.rangeEnd && operation.replacement.length)
                _undoGroups = _undoGroups.concat([{ before: before, after: textArea.text,
                    beforeStart: priorStart, beforeEnd: priorEnd,
                    afterStart: operation.selectionStart, afterEnd: operation.selectionEnd }])
            _redoGroups = []
        }
        if (operation.selectionStart !== operation.selectionEnd)
            textArea.select(operation.selectionStart, operation.selectionEnd)
        else textArea.cursorPosition = operation.cursorPosition
        return true
    }

    // Qt records remove and insert separately; group only our own adjacent edits.
    function undoSmart(redo) {
        var source = redo ? _redoGroups : _undoGroups
        var group = source[source.length - 1]
        if (!group || textArea.text !== (redo ? group.before : group.after)) return false
        _syncingExternal = true
        for (var i = 0; i < 2; i++) {
            if (redo) textArea.redo()
            else textArea.undo()
        }
        _syncingExternal = false
        root.textEdited(textArea.text)
        source = source.slice(0, -1)
        if (redo) { _redoGroups = source; _undoGroups = _undoGroups.concat([group]) }
        else { _undoGroups = source; _redoGroups = _redoGroups.concat([group]) }
        var from = redo ? group.afterStart : group.beforeStart
        var to = redo ? group.afterEnd : group.beforeEnd
        if (from !== to) textArea.select(from, to)
        else textArea.cursorPosition = to
        return true
    }

    // Apply external updates without reporting them as user edits.
    onTextChanged: {
        if (textArea.text !== root.text) {
            _undoGroups = []
            _redoGroups = []
            _syncingExternal = true
            var cursor = textArea.cursorPosition
            textArea.text = root.text
            textArea.cursorPosition = Math.min(cursor, textArea.text.length)
            _syncingExternal = false
        }
    }

    TextMetrics {
        id: tabMetrics
        font.family: root.fontFamily
        font.pixelSize: root.fontPixelSize
        text: "    "
    }

    // Let long notes scroll within the available space.
    ScrollView {
        anchors.fill: parent
        clip: true

        // Display source and notes literally.
        TextArea {
            id: textArea
            text: root.text
            readOnly: root.readOnly
            textFormat: TextEdit.PlainText
            wrapMode: root.wrapMode
            tabStopDistance: root.codeEditingEnabled ? tabMetrics.width : 80
            selectByMouse: true
            ContextMenu.menu: null
            color: Theme.fg
            selectionColor: Theme.accent
            selectedTextColor: Theme.onAccentColor
            placeholderText: root.placeholderText
            placeholderTextColor: Theme.fgMuted
            font.family: root.fontFamily
            font.pixelSize: root.fontPixelSize
            padding: 4
            background: null

            // Forward only text entered by the user.
            onTextChanged: {
                if (!root._syncingExternal && root.text !== text) {
                    root.textEdited(text)
                }
            }

            // Insert a tab instead of moving focus.
            Keys.onTabPressed: event => {
                if (root.codeEditingEnabled && !root.readOnly)
                    root.applyEdit(EditOps.indent(text, selectionStart, selectionEnd, cursorPosition, root.indentText, false))
                else if (!root.codeEditingEnabled) insert(cursorPosition, "\t")
                event.accepted = true
            }

            // Keep reverse Tab from moving focus.
            Keys.onBacktabPressed: event => {
                if (root.codeEditingEnabled && !root.readOnly)
                    root.applyEdit(EditOps.indent(text, selectionStart, selectionEnd, cursorPosition, root.indentText, true))
                event.accepted = true
            }

            // Let the parent close its editor panel.
            Keys.onEscapePressed: event => {
                root.escapeRequested()
                event.accepted = true
            }

            // Let the parent handle Ctrl+S.
            Keys.onPressed: event => {
                if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_S) {
                    root.saveRequested()
                    event.accepted = true
                    return
                }
                if (!root.codeEditingEnabled || root.readOnly) return
                if (event.modifiers === Qt.ControlModifier && event.key === Qt.Key_Z) {
                    if (root.undoSmart(false)) event.accepted = true
                    else if (textArea.canUndo) { textArea.undo(); event.accepted = true }
                    return
                }
                if (((event.modifiers === (Qt.ControlModifier | Qt.ShiftModifier)) && event.key === Qt.Key_Z)
                        || (event.modifiers === Qt.ControlModifier && event.key === Qt.Key_Y)) {
                    if (root.undoSmart(true)) event.accepted = true
                    else if (textArea.canRedo) { textArea.redo(); event.accepted = true }
                    return
                }
                var operation = null
                if (event.modifiers === Qt.ControlModifier && event.key === Qt.Key_Slash)
                    operation = EditOps.toggleComment(text, selectionStart, selectionEnd, cursorPosition, EditOps.profileForFile(root.fileId))
                else if (event.modifiers === (Qt.ControlModifier | Qt.ShiftModifier) && event.key === Qt.Key_K)
                    operation = EditOps.lineCommand(text, selectionStart, selectionEnd, cursorPosition, "delete")
                else if (event.modifiers === Qt.AltModifier && event.key === Qt.Key_Up)
                    operation = EditOps.lineCommand(text, selectionStart, selectionEnd, cursorPosition, "moveUp")
                else if (event.modifiers === Qt.AltModifier && event.key === Qt.Key_Down)
                    operation = EditOps.lineCommand(text, selectionStart, selectionEnd, cursorPosition, "moveDown")
                else if (event.modifiers === (Qt.ShiftModifier | Qt.AltModifier) && event.key === Qt.Key_Up)
                    operation = EditOps.lineCommand(text, selectionStart, selectionEnd, cursorPosition, "duplicateUp")
                else if (event.modifiers === (Qt.ShiftModifier | Qt.AltModifier) && event.key === Qt.Key_Down)
                    operation = EditOps.lineCommand(text, selectionStart, selectionEnd, cursorPosition, "duplicateDown")
                else if (event.modifiers === Qt.ControlModifier && event.key === Qt.Key_L)
                    operation = EditOps.selectLine(text, selectionStart, selectionEnd, cursorPosition)
                else if (event.modifiers === Qt.NoModifier && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter))
                    operation = EditOps.newline(text, selectionStart, selectionEnd)
                if (operation && root.applyEdit(operation)) event.accepted = true
            }
        }
    }
}
