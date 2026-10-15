import QtQuick
import Quickshell.Io
import "../../services"

FocusScope {
    id: root
    signal closeRequested(bool keyboard)
    signal actionRequested(string key)
    property int selectedIndex: 0
    property bool keyboardCursor: false
    property var toggleStates: ({})
    property string errorMessage: ""
    property string statusOutput: ""
    readonly property var actions: [
        { key: "wifi", icon: "󰤨", label: "Wi-Fi", toggle: true },
        { key: "bluetooth", icon: "󰂯", label: "Bluetooth", toggle: true },
        { key: "idleInhibit", icon: "󰈈", label: "Idle Inhibit", toggle: true },
        { key: "nightLight", icon: "󰖔", label: "Night Light", toggle: true },
        { key: "taskbar", icon: "󰧨", label: "Taskbar", toggle: true },
        { key: "desktopIcons", icon: "󰀻", label: "Desktop Icons", toggle: true },
        { key: "cava", icon: "󰝚", label: "Cava Underbar", toggle: true },
        { key: "screenshot", icon: "󰄄", label: "Screenshot", toggle: false },
        { key: "lock", icon: "󰌾", label: "Lock", toggle: false },
        { key: "wallpaper", icon: "󰸉", label: "Wallpaper", toggle: false }
    ]

    function forceFocus() { root.forceActiveFocus() }
    function stateFor(key) { return toggleStates[key] || { available: false, enabled: false } }

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

    Component.onCompleted: refresh()
    Keys.onLeftPressed: event => {
        keyboardCursor = true
        if (selectedIndex % 5 > 0) selectedIndex--
        event.accepted = true
    }
    Keys.onRightPressed: event => {
        keyboardCursor = true
        if (selectedIndex % 5 < 4 && selectedIndex < actions.length - 1) selectedIndex++
        event.accepted = true
    }
    Keys.onUpPressed: event => {
        keyboardCursor = true
        if (selectedIndex >= 5) selectedIndex -= 5
        event.accepted = true
    }
    Keys.onDownPressed: event => {
        keyboardCursor = true
        if (selectedIndex < 5) selectedIndex += 5
        event.accepted = true
    }
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
        columns: 5
        spacing: 8
        Repeater {
            model: root.actions
            delegate: SidebarMorphButton {
                required property int index
                required property var modelData
                readonly property bool checked: modelData.toggle && root.stateFor(modelData.key).enabled
                readonly property bool cursor: root.keyboardCursor && root.activeFocus && root.selectedIndex === index
                width: Math.max(1, (root.width - 32) / 5)
                height: Math.max(1, (root.height - 8) / 2)
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
                        text: modelData.label
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
