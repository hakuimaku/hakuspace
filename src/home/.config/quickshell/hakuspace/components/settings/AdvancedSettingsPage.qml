import QtQuick
import "../../services"

Item {
    id: root
    property Item shortcutTarget: null
    property string highlightedId: ""
    property string tab: "editor"
    readonly property bool popupOpen: editor.popupOpen
    property alias confirmation: editor.confirmation
    readonly property var actionLabels: []
    readonly property string footerStatus: ""
    readonly property bool footerDirty: false
    readonly property bool footerError: false
    function canActivate(label) { return false }
    function activateAction(label) { }
    function saveFromKeyboard() { if (tab === "editor") editor.saveFromKeyboard() }
    function requestReload() { if (tab === "editor") editor.requestReload() }
    function focusConfirmation() { editor.focusConfirmation() }
    function cancelConfirmation() { editor.cancelConfirmation() }
    function reveal(id, section) { tab = "options"; options.reveal(id, section) }
    signal closeRequested()
    Column {
        anchors.fill: parent; spacing: Theme.spaceMd
        Text { text: "Advanced"; color: Theme.fg; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize + 5; font.weight: Font.DemiBold }
        SettingsSegmentedControl { width: parent.width; value: root.tab; options: [{value: "editor", label: "WM config"}, {value: "options", label: "Advanced options"}]; onChosen: value => root.tab = value }
        Item {
            width: parent.width; height: Math.max(0, parent.height - y)
            ConfigEditorPage { id: editor; anchors.fill: parent; visible: root.tab === "editor"; shortcutTarget: root.shortcutTarget; onCloseRequested: root.closeRequested() }
            SettingsCategoryPage { id: options; anchors.fill: parent; visible: root.tab === "options"; category: "Advanced"; shortcutTarget: root.shortcutTarget; highlightedId: root.highlightedId; trailingContent: Component { SettingsSectionCard { width: parent.width; title: "Wallpaper transitions"; SettingsArgumentsForm { width: parent.width; preference: "AWWW_OPTS"; shortcutTarget: root.shortcutTarget } } } }
        }
    }
}
