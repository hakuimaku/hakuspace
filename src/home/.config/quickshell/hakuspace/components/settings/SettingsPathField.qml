import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import Quickshell
import "../../services"
import "SettingsCatalog.js" as Catalog

Row {
    id: root
    property string value: ""
    property string label: "Folder"
    property Item shortcutTarget: null
    signal edited(string value)
    spacing: Theme.spaceSm
    TextField {
        id: field
        property bool settingsNavItem: true
        property string settingsNavRole: "input"
        verticalAlignment: TextInput.AlignVCenter
        leftPadding: Theme.spaceLg; rightPadding: Theme.spaceLg
        topPadding: Theme.spaceSm; bottomPadding: Theme.spaceSm
        width: Math.max(0, root.width - browse.width - root.spacing); height: Theme.comfortableControlHeight
        text: root.value.replace(/^\$HOME(?=\/|$)|^\$\{HOME\}(?=\/|$)/, "~")
        color: Theme.fg; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize - 1; selectByMouse: true
        Accessible.name: root.label
        Keys.forwardTo: root.shortcutTarget ? [root.shortcutTarget] : []
        background: Rectangle { radius: Theme.radius; color: Theme.hoverMuted; border.width: field.activeFocus ? 1 : 0; border.color: Theme.accent }
        onEditingFinished: if (text.length && text !== root.value && text !== root.value.replace(/^\$HOME|^\$\{HOME\}/, "~")) root.edited(text)
    }
    SettingsActionButton {
        id: browse
        width: 100; height: Theme.comfortableControlHeight; text: "󰉋 Browse"
        activeFocusOnTab: true; focused: activeFocus
        Accessible.name: "Browse " + root.label
        onClicked: { folder.lease = UiState.beginNativeDialog("settings"); folder.open() }
        Keys.onReturnPressed: clicked()
        Keys.onSpacePressed: clicked()
    }
    FolderDialog {
        id: folder
        property int lease: 0
        title: root.label
        currentFolder: WallpaperService.fileUrl(Catalog.folderPath(root.value, Quickshell.env("HOME")))
        onAccepted: { root.edited(decodeURIComponent(String(selectedFolder).substring(7))); UiState.endNativeDialog(lease) }
        onRejected: UiState.endNativeDialog(lease)
        Component.onDestruction: UiState.endNativeDialog(lease)
    }
}
