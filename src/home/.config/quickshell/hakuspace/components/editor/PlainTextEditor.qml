import QtQuick
import QtQuick.Controls
import "../../services"

// Reusable multiline editor that keeps input as plain text.
Item {
    id: root

    property string text: ""
    property bool readOnly: false
    property string placeholderText: ""
    property bool _syncingExternal: false

    signal textEdited(string newText)
    signal escapeRequested()
    signal saveRequested()

    // Focus the input after its parent panel opens.
    function forceEditorFocus() {
        textArea.forceActiveFocus()
    }

    // Apply external updates without reporting them as user edits.
    onTextChanged: {
        if (textArea.text !== root.text) {
            _syncingExternal = true
            var cursor = textArea.cursorPosition
            textArea.text = root.text
            textArea.cursorPosition = Math.min(cursor, textArea.text.length)
            _syncingExternal = false
        }
    }

    // Let long notes scroll within the available space.
    ScrollView {
        anchors.fill: parent
        clip: true

        // Display Markdown characters literally.
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

            // Forward only text entered by the user.
            onTextChanged: {
                if (!root._syncingExternal && root.text !== text) {
                    root.textEdited(text)
                }
            }

            // Insert a tab instead of moving focus.
            Keys.onTabPressed: event => {
                insert(cursorPosition, "\t")
                event.accepted = true
            }

            // Keep reverse Tab from moving focus.
            Keys.onBacktabPressed: event => {
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
                }
            }
        }
    }
}
