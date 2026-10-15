import QtQuick
import Quickshell
import Quickshell.Io
import "../../../services"
import "../../shortcut" as Shortcut
import ".." as ActionMenu

ActionMenu.ActionMenuPage {
    id: root
    readonly property bool pinToSidebar: UiState.actionMenuFlow === "sidebarPin"
    title: pinToSidebar ? "Pin App" : "Add Desktop Shortcut"
    subtitle: "Choose an installed app"
    icon: "󰀻"
    geometryProfile: "option"
    property string errorMessage: ""

    Component.onCompleted: Qt.callLater(function() { picker.forceFocus() })
    function activateCurrent() { picker.activateCurrent() }

    Process {
        id: addProc
        onExited: (code, status) => {
            if (code === 0) root.requestClose()
            else root.errorMessage = "Could not create shortcut"
        }
    }
    Shortcut.ShortcutPickerView {
        id: picker
        anchors.fill: parent
        onShortcutChosen: path => {
            root.errorMessage = ""
            if (root.pinToSidebar) {
                root.requestClose()
                Qt.callLater(function() {
                    Quickshell.execDetached([Env.binDir + "/sidebar_pins_ctl.py", "add-app", path])
                })
                return
            }
            addProc.command = [Env.binDir + "/gen_shortcut.sh", "--add", path]
            addProc.running = true
        }
        onBackRequested: root.requestClose()
    }
    Text {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        visible: root.errorMessage.length > 0
        text: root.errorMessage
        color: Theme.accent
        font.family: Theme.fontFamily
    }
}
