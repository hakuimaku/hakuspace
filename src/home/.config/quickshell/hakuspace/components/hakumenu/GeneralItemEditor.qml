import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import "../../services"
import "../settings" as Settings

FocusScope {
    id: root
    objectName: "general-editor"
    // Retain draft and pending save until visual closure and backend completion.
    property bool requested: false
    // Start newly loaded editors at zero opacity so their first opening also fades.
    property bool initialized: false
    readonly property bool reducedMotion: Quickshell.env("HAKUSPACE_REDUCED_MOTION") === "1"
    property var entry: null
    property bool saving: false
    property string error: ""
    readonly property bool editing: !!entry
    readonly property bool releaseReady: !requested && opacity <= 0.01 && !saving
    property alias iconText: iconField.text
    property alias labelText: nameField.text
    property alias commandText: commandField.text
    signal closeRequested()
    implicitHeight: form.implicitHeight + footer.height + Theme.spaceLg + Theme.pad * 2
    opacity: requested && initialized ? 1 : 0
    visible: opacity > 0
    enabled: requested
    z: 20
    focus: requested

    // Restore the existing draft only when starting a new add/edit session.
    function initialize() {
        iconText = entry ? entry.icon : ""
        labelText = entry ? entry.label : ""
        commandText = entry ? entry.commandText : ""
        error = ""
        Qt.callLater(focusName)
    }
    // Defer focus until the editor has joined its drawing window.
    function focusName() { if (requested) nameField.forceActiveFocus() }
    // Preserve supplementary glyph pairs without relying on QML string iteration.
    function firstIcon(value) {
        var match = value.trim().match(/^(?:[\uD800-\uDBFF][\uDC00-\uDFFF]|[^\uD800-\uDFFF])/)
        return match ? match[0] : ""
    }
    // Keep authoritative argument parsing in the backend while checking simple field limits.
    function save() {
        if (saving || GeneralMenuService.busy) return
        if (!labelText.trim() || Array.from(labelText).length > 96 || iconText !== firstIcon(iconText) || !commandText.trim()
                || /[\x00-\x1f\x7f-\x9f]/.test(labelText + iconText) || commandText.indexOf("\u0000") >= 0) {
            error = "Enter a name (up to 96 characters), a single icon character, and command."
            return
        }
        var payload = {label: labelText, icon: iconText, commandText: commandText}
        error = ""
        saving = editing ? GeneralMenuService.update(entry.id, payload) : GeneralMenuService.add(payload)
        if (!saving) error = GeneralMenuService.error || "General menu is busy. Try again."
    }
    // Open the icon reference without replacing the current editor draft.
    function openIconCatalog() {
        Qt.openUrlExternally("https://www.nerdfonts.com/cheat-sheet")
    }
    // Cancel never interrupts an accepted save.
    function cancel() { if (!saving) closeRequested() }
    onRequestedChanged: if (requested) initialize()
    Component.onCompleted: {
        initialized = true
        if (requested) initialize()
    }
    Keys.onEscapePressed: event => { cancel(); event.accepted = true }

    Connections {
        target: GeneralMenuService
        function onMutationFinished(operation, success) {
            if (!root.saving) return
            root.saving = false
            if (success) root.closeRequested()
            else root.error = GeneralMenuService.error === "conflict"
                ? "Actions changed elsewhere. Review your changes and save again." : GeneralMenuService.error
        }
    }
    Behavior on opacity {
        NumberAnimation {
            duration: root.reducedMotion ? 0 : HAnimation.slow
            easing.type: Easing.InOutCubic
        }
    }
    Rectangle { anchors.fill: parent; color: Theme.surface; radius: Theme.largeRadius }
    MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons; onClicked: mouse => mouse.accepted = true }

    Flickable {
        anchors { top: parent.top; left: parent.left; right: parent.right; bottom: footer.top; margins: Theme.pad; bottomMargin: Theme.spaceLg }
        contentHeight: form.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ColumnLayout {
            id: form
            width: parent.width
            spacing: Theme.spaceSm
            Text {
                text: root.editing ? "Edit General action" : "Add General action"
                color: Theme.fg
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize + 2
                Layout.fillWidth: true
            }
            Text { text: "Icon"; color: Theme.fgMuted; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize - 1 }
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spaceSm
                EditorField {
                    id: iconField
                    objectName: "general-icon"
                    Layout.fillWidth: false
                    Layout.preferredWidth: Theme.controlHeight * 2
                    horizontalAlignment: TextInput.AlignHCenter
                    font.family: Theme.iconFontFamily
                    placeholderText: ""
                    Accessible.name: "Icon"
                    KeyNavigation.tab: iconCatalog
                    KeyNavigation.backtab: saveButton
                    onAccepted: nameField.forceActiveFocus()
                    // Preserve supplementary Nerd Font glyphs when limiting pasted text.
                    onTextEdited: {
                        var glyph = root.firstIcon(text)
                        if (text !== glyph) text = glyph
                    }
                }
                Settings.SettingsActionButton {
                    id: iconCatalog
                    objectName: "general-icon-catalog"
                    Layout.preferredWidth: Math.max(136, Theme.fontSize * 9)
                    Layout.preferredHeight: Theme.controlHeight
                    text: "Nerd Fonts 󰏌"
                    enabled: !root.saving
                    activeFocusOnTab: true; focused: activeFocus
                    Accessible.name: "Browse Nerd Fonts icons"
                    KeyNavigation.tab: nameField
                    KeyNavigation.backtab: iconField
                    onClicked: root.openIconCatalog()
                    Keys.onReturnPressed: clicked()
                    Keys.onSpacePressed: clicked()
                    Settings.SettingsTooltip { target: iconCatalog; active: iconCatalog.hovered || iconCatalog.activeFocus; text: "Browse Nerd Fonts icons" }
                }
                Item { Layout.fillWidth: true }
            }
            Text { text: "Name"; color: Theme.fgMuted; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize - 1 }
            EditorField {
                id: nameField;
                objectName: "general-name";
                placeholderText: "e.g. Terminal";
                Accessible.name: "Name";
                KeyNavigation.tab: commandField;
                KeyNavigation.backtab: iconCatalog;
                onAccepted: commandField.forceActiveFocus();
            }
            Text { text: "Command"; color: Theme.fgMuted; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize - 1 }
            EditorField {
                id: commandField;
                objectName: "general-command";
                placeholderText: "e.g. kitty -e htop";
                Accessible.name: "Command";
                KeyNavigation.tab: cancelButton;
                KeyNavigation.backtab: nameField;
                onAccepted: root.save();
            }
            Text {
                Layout.fillWidth: true
                visible: text.length > 0
                text: root.error
                color: Theme.danger
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize - 1
                wrapMode: Text.Wrap
                Accessible.role: Accessible.AlertMessage
            }
        }
    }

    RowLayout {
        id: footer
        // Save and Cancel stay visible even on a height-constrained output.
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: Theme.pad }
        height: Theme.controlHeight
        spacing: Theme.spaceSm
        Item { Layout.fillWidth: true }
        Settings.SettingsActionButton {
            id: cancelButton
            KeyNavigation.tab: saveButton
            KeyNavigation.backtab: commandField
            objectName: "general-cancel"
            width: 80; height: Theme.controlHeight
            text: "Cancel"
            enabled: !root.saving
            activeFocusOnTab: true; focused: activeFocus
            onClicked: root.cancel()
            Keys.onReturnPressed: clicked()
            Keys.onSpacePressed: clicked()
        }
        Settings.SettingsActionButton {
            id: saveButton
            KeyNavigation.tab: iconField
            KeyNavigation.backtab: cancelButton
            objectName: "general-save"
            width: 80; height: Theme.controlHeight
            text: root.saving ? "Saving…" : "Save"
            enabled: !root.saving && !GeneralMenuService.busy
            activeFocusOnTab: true; focused: activeFocus
            onClicked: root.save()
            Keys.onReturnPressed: clicked()
            Keys.onSpacePressed: clicked()
        }
    }

    // Share the existing Hikai field styling across the three draft values.
    component EditorField: TextField {
        id: field
        Layout.fillWidth: true
        Layout.preferredHeight: Theme.controlHeight
        color: Theme.fg
        placeholderTextColor: Qt.alpha(Theme.fgMuted, 0.3)
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        selectByMouse: true
        readOnly: root.saving
        leftPadding: Theme.spaceLg
        rightPadding: Theme.spaceLg
        background: Rectangle {
            radius: Theme.radius
            color: Theme.hoverMuted
            border.width: field.activeFocus ? 1 : 0
            border.color: Theme.accent
        }
    }
}
