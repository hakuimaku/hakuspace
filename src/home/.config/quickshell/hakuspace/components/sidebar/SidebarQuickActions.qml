import QtQuick
import Quickshell.Io
import "../../services"
import "../../config/UiCatalog.js" as UiCatalog

FocusScope {
    id: root
    signal closeRequested(bool keyboard)
    signal railFocusRequested()
    signal actionRequested(string key)
    property int selectedIndex: 0
    property bool keyboardCursor: false
    property var toggleStates: ({})
    property string errorMessage: ""
    property string statusOutput: ""
    readonly property var actions: UiCatalog.sidebarQuickActions

    readonly property int columnCount: 4
    readonly property int rowCount: Math.ceil(actions.length / columnCount)
    readonly property real cellSpacing: 8

    function forceFocus() { root.forceActiveFocus() }
    function stateFor(key) {
        if (key === "dockbar" && ChromeLayout.taskbarMode)
            return {available: false, enabled: AppState.dockbarManualState}
        return toggleStates[key] || { available: false, enabled: false }
    }

    // Refresh from system owners after each completed toggle.
    function refresh() {
        statusOutput = ""
        statusProc.running = true
    }

    // Keep toggle commands serialized and leave action close policy to Navigation.
    function activate(index) {
        if (index < 0 || index >= actions.length) return
        var action = actions[index]
        if (!action.toggle) { actionRequested(action.key); return }
        if (!stateFor(action.key).available || toggleProc.running || statusProc.running) return
        errorMessage = ""
        toggleProc.command = [Env.binDir + "/quick_actions_ctl.py", "toggle", action.key]
        toggleProc.running = true
    }

    // Preserve rows horizontally and clamp downward movement into the incomplete last row.
    function moveSelection(dx, dy) {
        keyboardCursor = true
        var column = selectedIndex % columnCount
        if (dx < 0 && column === 0) { railFocusRequested(); return }
        if (dx !== 0) {
            var next = selectedIndex + dx
            if (next >= 0 && next < actions.length && column + dx < columnCount) selectedIndex = next
        } else if (dy < 0 && selectedIndex >= columnCount) selectedIndex -= columnCount
        else if (dy > 0 && Math.floor(selectedIndex / columnCount) < rowCount - 1)
            selectedIndex = Math.min(actions.length - 1, selectedIndex + columnCount)
    }

    Component.onCompleted: refresh()
    Keys.onLeftPressed: event => { moveSelection(-1, 0); event.accepted = true }
    Keys.onRightPressed: event => { moveSelection(1, 0); event.accepted = true }
    Keys.onUpPressed: event => { moveSelection(0, -1); event.accepted = true }
    Keys.onDownPressed: event => { moveSelection(0, 1); event.accepted = true }
    Keys.onReturnPressed: event => { keyboardCursor = true; activate(selectedIndex); event.accepted = true }
    Keys.onEnterPressed: event => { keyboardCursor = true; activate(selectedIndex); event.accepted = true }
    Keys.onSpacePressed: event => { keyboardCursor = true; activate(selectedIndex); event.accepted = true }
    Keys.onEscapePressed: event => { closeRequested(true); event.accepted = true }

    Process {
        id: statusProc
        command: [Env.binDir + "/quick_actions_ctl.py", "status"]
        stdout: SplitParser { onRead: data => root.statusOutput += data }
        onExited: (code, status) => {
            if (code !== 0) { root.errorMessage = "Could not read action states"; return }
            try { root.toggleStates = JSON.parse(root.statusOutput.trim()) }
            catch (error) { root.errorMessage = "Invalid action states" }
        }
    }
    Process {
        id: toggleProc
        onExited: (code, status) => {
            if (code !== 0) root.errorMessage = "Could not change action"
            root.refresh()
        }
    }

    Grid {
        anchors.fill: parent
        columns: root.columnCount
        spacing: root.cellSpacing
        Repeater {
            model: root.actions
            delegate: SidebarMorphButton {
                required property int index
                required property var modelData
                readonly property bool checked: modelData.toggle && root.stateFor(modelData.key).enabled
                readonly property bool cursor: root.keyboardCursor && root.activeFocus && root.selectedIndex === index
                width: Math.max(1, (root.width - (root.columnCount - 1) * root.cellSpacing) / root.columnCount)
                height: Math.max(1, (root.height - (root.rowCount - 1) * root.cellSpacing) / root.rowCount)
                radius: Theme.radius
                enabled: !modelData.toggle || root.stateFor(modelData.key).available
                selected: checked || cursor
                focused: cursor
                focusColor: Theme.accent
                focusForegroundColor: Theme.onAccentColor
                border.width: 0
                hoverScaleDelta: 0.04
                onClicked: { root.selectedIndex = index; root.activate(index) }

                Column {
                    anchors.centerIn: parent
                    width: parent.width - 8
                    spacing: 5
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: modelData.icon
                        font.family: Theme.fontFamily
                        font.pixelSize: Math.max(21, Theme.fontSize * 1.5)
                        color: parent.parent.foreground
                    }
                    Text {
                        width: parent.width
                        text: modelData.key === "dockbar" && ChromeLayout.taskbarMode ? "Dockbar\nTopBar only" : modelData.label
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        font.family: Theme.fontFamily
                        font.pixelSize: Math.max(9, Theme.fontSize - 3)
                        color: parent.parent.foreground
                    }
                }
            }
        }
    }
    Text {
        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom }
        visible: root.errorMessage.length > 0
        text: root.errorMessage
        color: Theme.accent
        font.family: Theme.fontFamily
        font.pixelSize: Math.max(9, Theme.fontSize - 3)
    }
}
