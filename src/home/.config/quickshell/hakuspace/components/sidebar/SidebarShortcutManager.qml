import QtQuick
import QtQuick.Dialogs
import "../../services"

FocusScope {
    id: root
    property Item tooltipHost: null
    signal closeRequested(bool keyboard)
    signal railFocusRequested()
    signal dialogLeaseRequested(string token, bool active)
    signal appRequested()
    signal pinRequested(string kind, string path)

    function forceFocus() { root.forceActiveFocus() }
    function localPath(url) {
        var value = String(url)
        return decodeURIComponent(value.startsWith("file://") ? value.substring(7) : value)
    }

    Keys.onEscapePressed: event => {
        if (fileDialog.visible || folderDialog.visible) { event.accepted = true; return }
        closeRequested(true)
        event.accepted = true
    }
    Keys.onLeftPressed: event => {
        if (event.modifiers !== Qt.NoModifier || fileDialog.visible || folderDialog.visible) {
            event.accepted = false
            return
        }
        railFocusRequested()
        event.accepted = true
    }
    Keys.onUpPressed: event => { modeIndex = Math.max(0, modeIndex - 1); event.accepted = true }
    Keys.onDownPressed: event => { modeIndex = Math.min(2, modeIndex + 1); event.accepted = true }
    Keys.onReturnPressed: event => { activateMode(modeIndex); event.accepted = true }
    Keys.onEnterPressed: event => { activateMode(modeIndex); event.accepted = true }
    property int modeIndex: 0
    readonly property var modes: [
        { label: "App", icon: "󰀻" },
        { label: "File", icon: "󰈙" },
        { label: "Folder", icon: "󰉋" }
    ]

    function activateMode(index) {
        modeIndex = index
        if (index === 0) appRequested()
        else if (index === 1) { dialogLeaseRequested("shortcut-file-dialog", true); fileDialog.open() }
        else { dialogLeaseRequested("shortcut-folder-dialog", true); folderDialog.open() }
    }

    FileDialog {
        id: fileDialog
        title: "Choose a file to pin"
        onAccepted: if (selectedFile) root.pinRequested("file", root.localPath(selectedFile))
        onVisibleChanged: if (!visible) {
            root.dialogLeaseRequested("shortcut-file-dialog", false)
            Qt.callLater(function() { if (UiState.activePanel === "navigation") root.forceFocus() })
        }
    }
    FolderDialog {
        id: folderDialog
        title: "Choose a folder to pin"
        onAccepted: if (selectedFolder) root.pinRequested("folder", root.localPath(selectedFolder))
        onVisibleChanged: if (!visible) {
            root.dialogLeaseRequested("shortcut-folder-dialog", false)
            Qt.callLater(function() { if (UiState.activePanel === "navigation") root.forceFocus() })
        }
    }

    Column {
        anchors.fill: parent
        spacing: 8
        Repeater {
            model: root.modes
            delegate: SidebarRailButton {
                id: modeButton
                required property int index
                required property var modelData
                width: root.width
                height: (root.height - 16) / 3
                radius: Theme.radius
                border.width: 0
                idleColor: Theme.surface
                hoverColor: root.modeIndex === index ? Theme.accent : Theme.surface
                pressedColor: Theme.accent
                selectedColor: Theme.accent
                focusColor: Theme.accent
                hoverForegroundColor: root.modeIndex === index ? Theme.onAccentColor : Theme.fg
                pressedForegroundColor: Theme.onAccentColor
                selectedForegroundColor: Theme.onAccentColor
                focusForegroundColor: Theme.onAccentColor
                hoverScaleDelta: 0.04
                tooltip: modelData.label
                tooltipHost: root.tooltipHost
                Accessible.role: Accessible.Button
                Accessible.name: modelData.label
                selected: root.activeFocus && root.modeIndex === index
                focused: root.activeFocus && root.modeIndex === index
                onHoveredChanged: if (hovered) root.modeIndex = index
                onClicked: root.activateMode(index)
                Column {
                    anchors.centerIn: parent
                    spacing: 6
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: modelData.icon
                        color: modeButton.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: 24
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: modelData.label
                        color: modeButton.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                    }
                }
            }
        }
    }
}
