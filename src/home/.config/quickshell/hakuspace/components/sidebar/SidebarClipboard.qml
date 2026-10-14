import QtQuick
import Quickshell.Io
import "../../services"
import "../motion" as Motion

FocusScope {
    id: root
    signal closeRequested(bool keyboard)
    signal openFullRequested()
    property var entries: []
    property var pendingEntries: []
    property int selectedIndex: 0
    property bool fullMenuSelected: false
    property bool loading: true
    property string errorMessage: ""

    // Own list keys while open.
    function forceFocus() { root.forceActiveFocus() }

    // Match ClipboardPage's raw-row parsing and binary preview detection.
    function appendRow(line) {
        if (!line || pendingEntries.length >= 8) return
        var tab = line.indexOf("\t")
        var preview = tab === -1 ? line : line.substring(tab + 1).trim()
        pendingEntries.push({
            raw: line,
            preview: preview,
            isImage: preview.indexOf("[[ binary data") !== -1 || /\.(png|jpe?g|webp|gif|svg)$/i.test(preview)
        })
    }

    // Refresh only when the mini tool opens.
    function reload() {
        loading = true
        errorMessage = ""
        pendingEntries = []
        ensureProc.running = false
        ensureProc.running = true
    }

    // Pass the untouched backend row to clipboard_ctl.sh.
    function copy(index) {
        if (index < 0 || index >= entries.length) return
        errorMessage = ""
        copyProc.command = [Env.binDir + "/clipboard_ctl.sh", "copy", entries[index].raw]
        copyProc.running = true
    }

    Component.onCompleted: reload()
    Keys.onUpPressed: event => {
        if (fullMenuSelected) fullMenuSelected = false
        else selectedIndex = Math.max(0, selectedIndex - 1)
        if (entries.length > 0) clipList.positionViewAtIndex(selectedIndex, ListView.Contain)
        event.accepted = true
    }
    Keys.onDownPressed: event => {
        if (entries.length === 0 || selectedIndex >= entries.length - 1) fullMenuSelected = true
        else {
            selectedIndex++
            clipList.positionViewAtIndex(selectedIndex, ListView.Contain)
        }
        event.accepted = true
    }
    Keys.onTabPressed: event => { fullMenuSelected = true; event.accepted = true }
    Keys.onBacktabPressed: event => { fullMenuSelected = false; event.accepted = true }
    Keys.onReturnPressed: event => {
        if (fullMenuSelected) openFullRequested()
        else copy(selectedIndex)
        event.accepted = true
    }
    Keys.onEnterPressed: event => {
        if (fullMenuSelected) openFullRequested()
        else copy(selectedIndex)
        event.accepted = true
    }
    Keys.onSpacePressed: event => {
        if (fullMenuSelected) openFullRequested()
        else copy(selectedIndex)
        event.accepted = true
    }
    Keys.onEscapePressed: event => { closeRequested(true); event.accepted = true }

    Process {
        id: ensureProc
        command: [Env.binDir + "/clipboard_ctl.sh", "ensure-watchers"]
        onExited: (code, status) => {
            if (code !== 0) {
                root.loading = false
                root.errorMessage = "Clipboard watcher unavailable"
                return
            }
            listProc.running = true
        }
    }
    Process {
        id: listProc
        command: [Env.binDir + "/clipboard_ctl.sh", "list"]
        stdout: SplitParser { onRead: data => root.appendRow(data) }
        onExited: (code, status) => {
            root.loading = false
            if (code !== 0) {
                root.errorMessage = "Could not load clipboard"
                return
            }
            root.entries = root.pendingEntries.slice()
            root.selectedIndex = 0
        }
    }
    Process {
        id: copyProc
        onExited: (code, status) => {
            if (code === 0) root.closeRequested(false)
            else root.errorMessage = "Could not copy entry"
        }
    }

    Text {
        anchors.centerIn: parent
        visible: root.loading || root.errorMessage.length > 0 || root.entries.length === 0
        text: root.loading ? "Loading…" : root.errorMessage.length > 0
              ? root.errorMessage : "Clipboard history is empty"
        color: Theme.fgDim
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
    }

    ListView {
        id: clipList
        anchors { top: parent.top; left: parent.left; right: parent.right; bottom: fullMenuButton.top }
        anchors.bottomMargin: 10
        visible: !root.loading && root.entries.length > 0
        clip: true
        model: root.entries
        spacing: 6
        Motion.SelectionPill {
            id: selectionPill
            parent: clipList.contentItem
            z: 0
            normalColor: Theme.accent
            visible: !root.fullMenuSelected
        }
        delegate: SidebarMorphButton {
            required property int index
            required property var modelData
            z: 1
            width: clipList.width
            height: 43
            radius: height / 2
            focused: root.activeFocus && !root.fullMenuSelected && root.selectedIndex === index
            selected: !root.fullMenuSelected && root.selectedIndex === index
            selectedOverridesHover: true
            idleColor: "transparent"
            hoverColor: "transparent"
            selectedColor: "transparent"
            focusColor: "transparent"
            pressedColor: "transparent"
            foregroundColor: Theme.accent
            selectedForegroundColor: Theme.onAccentColor
            focusForegroundColor: Theme.onAccentColor
            hoverForegroundColor: selected ? Theme.onAccentColor : Theme.accent
            border.width: 0
            hoverScaleDelta: 0.003
            Component.onCompleted: if (selected) selectionPill.targetItem = this
            onSelectedChanged: if (selected) selectionPill.targetItem = this
            onHoveredChanged: if (hovered) { root.fullMenuSelected = false; root.selectedIndex = index }
            onClicked: { root.fullMenuSelected = false; root.selectedIndex = index; root.copy(index) }
            Row {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.margins: 8
                spacing: 8
                Text {
                    text: modelData.isImage ? "󰋩" : "󰉿"
                    color: parent.parent.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize + 2
                }
                Text {
                    width: parent.width - 34
                    text: modelData.isImage ? "[Image] " + modelData.preview : modelData.preview
                    color: parent.parent.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: Math.max(10, Theme.fontSize - 2)
                    elide: Text.ElideRight
                    maximumLineCount: 2
                    wrapMode: Text.Wrap
                }
            }
        }
    }

    SidebarMorphButton {
        id: fullMenuButton
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: 36
        radius: Theme.radius
        text: "󰅌  View all clipboard"
        fontSize: Math.max(10, Theme.fontSize - 1)
        selected: root.fullMenuSelected
        focused: root.fullMenuSelected && root.activeFocus
        focusColor: Theme.accent
        focusForegroundColor: Theme.onAccentColor
        border.width: 0
        hoverScaleDelta: 0.02
        onClicked: root.openFullRequested()
    }
}
