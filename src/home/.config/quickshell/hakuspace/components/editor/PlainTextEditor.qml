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
    property bool showLineNumbers: false
    // Owners can compact surrounding chrome without replacing the editor or its draft.
    readonly property real contentY: scrollView.contentItem ? scrollView.contentItem.contentY || 0 : 0
    readonly property real textContentHeight: textArea.contentHeight
    property bool leftBoundaryNavigationEnabled: false
    property string fileId: ""
    property string indentText: "    "
    // Owners may handle layer shortcuts before native text-editing keys.
    property Item shortcutTarget: null
    // Settings opts into the native editor target without affecting other consumers.
    property bool settingsNavigationEnabled: false
    property bool _syncingExternal: false
    property var _undoGroups: []
    property var _redoGroups: []
    // Expose native preedit ownership to editor consumers.
    readonly property bool imeComposing: textArea.inputMethodComposing
    // Delay reconciliation until Qt finishes the input-method event.
    property bool _compositionPending: false
    // Keep the latest owner value in root.text until composition finishes.
    property bool _hasPendingExternalText: false

    // Surface owners transfer the keyboard lease before native editor focus changes.
    signal interactionRequested()
    signal textEdited(string newText)
    signal escapeRequested()
    signal saveRequested()
    signal leftBoundaryRequested()

    // Focus the input after its parent panel opens.
    function forceEditorFocus() {
        textArea.forceActiveFocus()
    }

    // Apply a bounded edit so Qt retains its native undo history.
    function applyEdit(operation) {
        if (imeComposing || !operation.changed || readOnly) return false
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
        if (imeComposing) return false
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

    // Apply owner updates without resetting native preedit or echoing edits.
    function syncExternalText() {
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

    // Publish the final commit, or apply a newer value supplied by the owner.
    function finishComposition() {
        if (imeComposing) return
        _compositionPending = false
        if (_hasPendingExternalText) {
            _hasPendingExternalText = false
            syncExternalText()
        } else publishText()
    }

    // Wait for Qt's preedit state before forwarding selection replacements.
    function publishText() {
        if (!_syncingExternal && !imeComposing && !_compositionPending
                && root.text !== textArea.text) root.textEdited(textArea.text)
    }

    onTextChanged: {
        if (imeComposing || _compositionPending) _hasPendingExternalText = true
        else syncExternalText()
    }
    Component.onCompleted: syncExternalText()

    TextMetrics {
        id: tabMetrics
        font.family: root.fontFamily
        font.pixelSize: root.fontPixelSize
        text: "    "
    }

    // Let long notes scroll within the available space.
    ScrollView {
        id: scrollView
        anchors.fill: parent
        clip: true

        // Display source and notes literally.
        TextArea {
            id: textArea
            readonly property bool settingsNavItem: root.settingsNavigationEnabled
            property string settingsNavRole: "editor"
            readonly property bool settingsNavOwnsHorizontal: true
            readonly property bool settingsNavOwnsVertical: true
            Keys.forwardTo: root.shortcutTarget ? [root.shortcutTarget] : []
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
            leftPadding: root.showLineNumbers ? 56 : 4
            FontMetrics { id: lineMetrics; font: textArea.font }
            // Native layout spacing keeps line numbers aligned at fractional font sizes and scales.
            readonly property real codeLineHeight: {
                var layoutHeight = textArea.contentHeight
                if (!root.showLineNumbers || !layoutHeight) return lineMetrics.lineSpacing
                var nextLine = textArea.text.indexOf("\n") + 1
                var spacing = nextLine > 0 ? textArea.positionToRectangle(nextLine).y - textArea.positionToRectangle(0).y : 0
                return spacing > 0 ? spacing : lineMetrics.lineSpacing
            }
            Rectangle { visible: root.showLineNumbers; x: 52; y: textArea.cursorRectangle.y; width: Math.max(0, textArea.width - 52); height: textArea.codeLineHeight; color: Qt.alpha(Theme.hoverMuted, 0.5); z: -1 }
            Item {
                visible: root.showLineNumbers
                readonly property int firstLine: Math.max(0, Math.floor((scrollView.contentItem.contentY || 0) / textArea.codeLineHeight))
                readonly property int count: Math.min(Math.ceil(scrollView.height / textArea.codeLineHeight) + 2, textArea.lineCount - firstLine)
                x: 0; y: 4 + firstLine * textArea.codeLineHeight; width: 48
                Repeater {
                    model: Math.max(0, parent.count)
                    Text { required property int index; y: index * textArea.codeLineHeight; width: 42; height: textArea.codeLineHeight; text: parent.firstLine + index + 1; horizontalAlignment: Text.AlignRight; color: Theme.fgMuted; font: textArea.font }
                }
            }
            background: null

            onPressed: root.interactionRequested()

            // Qt may emit text changes before its composition-end signal.
            onInputMethodComposingChanged: {
                root._compositionPending = true
                if (!inputMethodComposing) Qt.callLater(root.finishComposition)
            }

            // Forward only text entered by the user.
            onTextChanged: {
                if (!root._syncingExternal) Qt.callLater(root.publishText)
            }

            // Insert a tab instead of moving focus.
            Keys.onTabPressed: event => {
                if (root.imeComposing) { event.accepted = false; return }
                if (root.codeEditingEnabled && !root.readOnly)
                    root.applyEdit(EditOps.indent(text, selectionStart, selectionEnd, cursorPosition, root.indentText, false))
                else if (!root.codeEditingEnabled) insert(cursorPosition, "\t")
                event.accepted = true
            }

            // Keep reverse Tab from moving focus.
            Keys.onBacktabPressed: event => {
                if (root.imeComposing) { event.accepted = false; return }
                if (root.codeEditingEnabled && !root.readOnly)
                    root.applyEdit(EditOps.indent(text, selectionStart, selectionEnd, cursorPosition, root.indentText, true))
                event.accepted = true
            }

            Keys.onLeftPressed: event => {
                event.accepted = false
                if (root.imeComposing) return
                if (root.leftBoundaryNavigationEnabled && event.modifiers === Qt.NoModifier
                        && cursorPosition === 0 && selectionStart === selectionEnd) {
                    root.leftBoundaryRequested()
                    event.accepted = true
                }
            }

            // Let the parent close its editor panel.
            Keys.onEscapePressed: event => {
                // Prevent unhandled IME cancellation from reaching parent close handlers.
                if (!root.imeComposing) {
                    root.finishComposition()
                    root.escapeRequested()
                }
                event.accepted = true
            }

            // Let the parent handle Ctrl+S.
            Keys.onPressed: event => {
                if (root.imeComposing) { event.accepted = false; return }
                if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_S) {
                    root.finishComposition()
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
