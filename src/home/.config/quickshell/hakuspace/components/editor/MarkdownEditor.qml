import QtQuick
import QtQuick.Controls
import "../../services"

Item {
    id: root

    property string text: ""
    property bool readOnly: false
    property string placeholderText: "Type note in Markdown..."
    property bool showToolbar: true
    property bool previewMode: false

    signal textEdited(string newText)
    signal textChangedByUser(string newText)
    signal escapeRequested()
    signal saveRequested()

    property bool _syncingExternal: false

    function forceEditorFocus() {
        if (!root.previewMode && textArea.visible) {
            textArea.forceActiveFocus()
        }
    }

    function wrapSelection(prefix, suffix) {
        if (root.previewMode || root.readOnly) return
        var start = textArea.selectionStart
        var end = textArea.selectionEnd
        if (start !== end) {
            var sel = textArea.selectedText
            textArea.remove(start, end)
            textArea.insert(start, prefix + sel + suffix)
            textArea.select(start + prefix.length, start + prefix.length + sel.length)
        } else {
            var pos = textArea.cursorPosition
            textArea.insert(pos, prefix + suffix)
            textArea.cursorPosition = pos + prefix.length
        }
        textArea.forceActiveFocus()
    }

    function prefixCurrentLine(prefix) {
        if (root.previewMode || root.readOnly) return
        var pos = textArea.cursorPosition
        var content = textArea.text
        var lineStart = content.lastIndexOf("\n", pos - 1) + 1
        textArea.insert(lineStart, prefix)
        textArea.cursorPosition = pos + prefix.length
        textArea.forceActiveFocus()
    }

    onTextChanged: {
        if (textArea.text !== root.text) {
            _syncingExternal = true
            textArea.text = root.text
            _syncingExternal = false
        }
    }

    property string toolbarDensity: "comfortable"
    readonly property bool isCompactToolbar: toolbarDensity === "compact"

    // -------------------------------------------------------------
    // Toolbar (Supports "comfortable" vs "compact" density)
    // -------------------------------------------------------------
    Item {
        id: toolbar
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: root.showToolbar ? (root.isCompactToolbar ? 26 : 36) : 0
        visible: root.showToolbar
        z: 50

        Row {
            id: modeSwitchRow
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: root.isCompactToolbar ? 2 : 4

            EditorToolButton {
                text: "Edit"
                tooltipText: "Edit Markdown"
                selected: !root.previewMode
                compact: root.isCompactToolbar
                customWidth: root.isCompactToolbar ? 44 : 56
                customHeight: root.isCompactToolbar ? 22 : 30
                onTriggered: {
                    root.previewMode = false
                    root.forceEditorFocus()
                }
            }

            EditorToolButton {
                text: "Preview"
                tooltipText: "Preview Markdown"
                selected: root.previewMode
                compact: root.isCompactToolbar
                customWidth: root.isCompactToolbar ? 58 : 76
                customHeight: root.isCompactToolbar ? 22 : 30
                onTriggered: {
                    root.previewMode = true
                }
            }
        }

        // Quick Markdown helpers in Edit mode
        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: root.isCompactToolbar ? 3 : 5
            visible: !root.previewMode && !root.readOnly

            EditorToolButton {
                text: "B"
                tooltipText: "Bold"
                bold: true
                compact: root.isCompactToolbar
                onTriggered: root.wrapSelection("**", "**")
            }

            EditorToolButton {
                text: "I"
                tooltipText: "Italic"
                italic: true
                compact: root.isCompactToolbar
                onTriggered: root.wrapSelection("*", "*")
            }

            EditorToolButton {
                text: "`"
                tooltipText: "Inline code"
                fontFamily: "monospace"
                compact: root.isCompactToolbar
                onTriggered: root.wrapSelection("`", "`")
            }

            EditorToolButton {
                text: "•"
                tooltipText: "Bullet list"
                compact: root.isCompactToolbar
                onTriggered: root.prefixCurrentLine("- ")
            }

            EditorToolButton {
                text: "☑"
                tooltipText: "Checklist"
                compact: root.isCompactToolbar
                tooltipAlignRight: true
                onTriggered: root.prefixCurrentLine("- [ ] ")
            }
        }
    }

    // -------------------------------------------------------------
    // Editor Surface (Edit mode)
    // -------------------------------------------------------------
    ScrollView {
        id: editScroll
        anchors.top: toolbar.bottom
        anchors.topMargin: root.showToolbar ? 4 : 0
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        visible: !root.previewMode
        clip: true

        TextArea {
            id: textArea
            text: root.text
            readOnly: root.readOnly
            textFormat: TextEdit.PlainText
            wrapMode: TextEdit.Wrap
            selectByMouse: true
            ContextMenu.menu: null
            color: Theme.fg
            selectionColor: Theme.accent
            selectedTextColor: Theme.onAccentColor
            placeholderText: root.placeholderText
            placeholderTextColor: Theme.fgMuted
            font.family: Theme.fontFamily
            font.pixelSize: Math.max(12, Theme.fontSize - 1)
            padding: 4
            background: null

            onTextChanged: {
                if (root._syncingExternal) return
                if (root.text !== text) {
                    root.textEdited(text)
                    root.textChangedByUser(text)
                }
            }

            Keys.onTabPressed: event => {
                insert(cursorPosition, "\t")
                event.accepted = true
            }

            Keys.onBacktabPressed: event => {
                event.accepted = true
            }

            Keys.onEscapePressed: event => {
                root.escapeRequested()
                event.accepted = true
            }

            Keys.onPressed: event => {
                if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_S) {
                    root.saveRequested()
                    event.accepted = true
                }
            }
        }
    }

    // -------------------------------------------------------------
    // Preview Surface (Markdown rendered preview)
    // -------------------------------------------------------------
    ScrollView {
        id: previewScroll
        anchors.top: toolbar.bottom
        anchors.topMargin: root.showToolbar ? 4 : 0
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        visible: root.previewMode
        clip: true

        TextEdit {
            id: previewText
            text: (textArea.text.length > 0 ? textArea.text : root.text).length > 0
                  ? (textArea.text.length > 0 ? textArea.text : root.text)
                  : "*No content to preview*"
            textFormat: TextEdit.MarkdownText
            wrapMode: TextEdit.Wrap
            readOnly: true
            selectByMouse: true
            color: Theme.fg
            selectionColor: Theme.accent
            selectedTextColor: Theme.onAccentColor
            font.family: Theme.fontFamily
            font.pixelSize: Math.max(12, Theme.fontSize - 1)
            padding: 4
        }
    }
}
