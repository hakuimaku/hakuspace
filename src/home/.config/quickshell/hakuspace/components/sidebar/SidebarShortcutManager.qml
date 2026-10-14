import QtQuick
import QtQuick.Dialogs
import Quickshell.Widgets
import "../../services"
import "../shortcut" as Shortcut

FocusScope {
    id: root
    property var pinsModel
    property bool showingApps: false
    signal closeRequested(bool keyboard)
    signal dialogLeaseRequested(bool active)

    function forceFocus() {
        if (showingApps) appPicker.forceFocus()
        else root.forceActiveFocus()
    }
    function localPath(url) {
        var value = String(url)
        return decodeURIComponent(value.startsWith("file://") ? value.substring(7) : value)
    }

    Keys.onEscapePressed: event => {
        if (fileDialog.visible || folderDialog.visible) { event.accepted = true; return }
        if (showingApps) { showingApps = false; root.forceActiveFocus() }
        else closeRequested(true)
        event.accepted = true
    }
    Keys.onLeftPressed: event => { if (!showingApps) { modeIndex = Math.max(0, modeIndex - 1); event.accepted = true } }
    Keys.onRightPressed: event => { if (!showingApps) { modeIndex = Math.min(2, modeIndex + 1); event.accepted = true } }
    Keys.onReturnPressed: event => { if (!showingApps) { activateMode(modeIndex); event.accepted = true } }
    Keys.onEnterPressed: event => { if (!showingApps) { activateMode(modeIndex); event.accepted = true } }
    property int modeIndex: 0
    readonly property var modes: [
        { label: "App", icon: "application-x-executable" },
        { label: "File", icon: "󰈙" },
        { label: "Folder", icon: "󰉋" }
    ]

    function activateMode(index) {
        modeIndex = index
        if (pinsModel) pinsModel.errorMessage = ""
        if (index === 0) { showingApps = true; Qt.callLater(function() { appPicker.forceFocus() }) }
        else if (index === 1) { dialogLeaseRequested(true); fileDialog.open() }
        else { dialogLeaseRequested(true); folderDialog.open() }
    }

    FileDialog {
        id: fileDialog
        title: "Choose a file to pin"
        onAccepted: if (selectedFile) root.pinsModel.addFile(root.localPath(selectedFile))
        onRejected: root.pinsModel.errorMessage = ""
        onVisibleChanged: if (!visible) { root.dialogLeaseRequested(false); Qt.callLater(root.forceFocus) }
    }
    FolderDialog {
        id: folderDialog
        title: "Choose a folder to pin"
        onAccepted: if (selectedFolder) root.pinsModel.addFolder(root.localPath(selectedFolder))
        onRejected: root.pinsModel.errorMessage = ""
        onVisibleChanged: if (!visible) { root.dialogLeaseRequested(false); Qt.callLater(root.forceFocus) }
    }

    Row {
        id: modeRow
        anchors { top: parent.top; left: parent.left; right: parent.right }
        spacing: 10
        Repeater {
            model: root.modes
            delegate: SidebarMorphButton {
                required property int index
                required property var modelData
                width: Math.max(1, (root.width - 20) / 3)
                height: 72
                radius: Theme.radius
                hoverScaleDelta: 0.04
                selected: root.showingApps && index === 0
                    || root.activeFocus && root.modeIndex === index
                focused: root.activeFocus && !root.showingApps && root.modeIndex === index
                onClicked: root.activateMode(index)
                Column {
                    anchors.centerIn: parent
                    spacing: 4
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        visible: index !== 0
                        text: index === 0 ? "" : modelData.icon
                        color: parent.parent.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize + 8
                    }
                    IconImage {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: Theme.fontSize + 8
                        height: width
                        visible: index === 0
                        source: visible ? "image://icon/" + modelData.icon : ""
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: modelData.label
                        color: parent.parent.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                    }
                }
            }
        }
    }
    Text {
        anchors.centerIn: parent
        visible: !root.showingApps
        text: root.pinsModel && root.pinsModel.errorMessage ? root.pinsModel.errorMessage : "Choose App, File or Folder"
        color: Theme.fgDim
        font.family: Theme.fontFamily
    }
    Shortcut.ShortcutPickerView {
        id: appPicker
        anchors { top: modeRow.bottom; left: parent.left; right: parent.right; bottom: parent.bottom; topMargin: 12 }
        visible: root.showingApps
        onShortcutChosen: path => root.pinsModel.addApp(path)
        onBackRequested: root.closeRequested(true)
    }
}
