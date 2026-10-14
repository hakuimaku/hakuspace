import QtQuick
import QtQuick.Controls
import Quickshell.Io
import Quickshell.Widgets
import "../../services"
import "../sidebar" as Sidebar

FocusScope {
    id: root
    signal shortcutChosen(string desktopPath)
    signal backRequested()
    property var entries: []
    property var filtered: []
    property int selectedIndex: 0
    property bool loading: true
    property string errorMessage: ""
    property string rawOutput: ""

    // Keep search and selection local to the shared picker.
    function filterEntries() {
        var query = search.text.toLocaleLowerCase()
        filtered = entries.filter(function(entry) {
            return entry.name.toLocaleLowerCase().indexOf(query) !== -1
                || entry.path.toLocaleLowerCase().indexOf(query) !== -1
        })
        selectedIndex = 0
        if (filtered.length) appList.positionViewAtIndex(0, ListView.Beginning)
    }
    function activateCurrent() {
        if (selectedIndex >= 0 && selectedIndex < filtered.length)
            shortcutChosen(filtered[selectedIndex].path)
    }
    function forceFocus() { search.forceActiveFocus() }

    Component.onCompleted: listProc.running = true
    Keys.onUpPressed: event => {
        selectedIndex = Math.max(0, selectedIndex - 1)
        if (filtered.length) appList.positionViewAtIndex(selectedIndex, ListView.Contain)
        event.accepted = true
    }
    Keys.onDownPressed: event => {
        selectedIndex = Math.min(filtered.length - 1, selectedIndex + 1)
        if (filtered.length) appList.positionViewAtIndex(selectedIndex, ListView.Contain)
        event.accepted = true
    }
    Keys.onReturnPressed: event => { activateCurrent(); event.accepted = true }
    Keys.onEnterPressed: event => { activateCurrent(); event.accepted = true }
    Keys.onEscapePressed: event => { backRequested(); event.accepted = true }

    Process {
        id: listProc
        command: [Env.binDir + "/gen_shortcut.sh", "--list-json"]
        stdout: SplitParser { onRead: data => root.rawOutput += data }
        onExited: (code, status) => {
            root.loading = false
            if (code !== 0) { root.errorMessage = "Could not list apps"; return }
            try {
                root.entries = JSON.parse(root.rawOutput.trim())
                root.filterEntries()
            } catch (error) { root.errorMessage = "Invalid app list" }
        }
    }

    TextField {
        id: search
        anchors { top: parent.top; left: parent.left; right: parent.right }
        placeholderText: "Search apps"
        color: Theme.fg
        font.family: Theme.fontFamily
        onTextChanged: root.filterEntries()
        Keys.priority: Keys.BeforeItem
        Keys.onEscapePressed: event => { root.backRequested(); event.accepted = true }
    }
    Text {
        anchors.centerIn: parent
        visible: root.loading || root.errorMessage.length > 0 || root.filtered.length === 0
        text: root.loading ? "Loading…" : root.errorMessage || "No apps found"
        color: Theme.fgDim
        font.family: Theme.fontFamily
    }
    ListView {
        id: appList
        anchors { top: search.bottom; left: parent.left; right: parent.right; bottom: parent.bottom; topMargin: 8 }
        clip: true
        spacing: 6
        model: root.filtered
        delegate: Sidebar.SidebarMorphButton {
            required property int index
            required property var modelData
            width: appList.width
            height: 52
            radius: Theme.radius
            hoverScaleDelta: 0.025
            focused: root.selectedIndex === index && (root.activeFocus || search.activeFocus)
            selected: root.selectedIndex === index && (root.activeFocus || search.activeFocus)
            onClicked: { root.selectedIndex = index; root.shortcutChosen(modelData.path) }
            Row {
                anchors { fill: parent; margins: 10 }
                spacing: 10
                IconImage {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Theme.fontSize + 8
                    height: width
                    source: modelData.icon.startsWith("/")
                        ? "file://" + modelData.icon : "image://icon/" + modelData.icon
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 45
                    Text {
                        width: parent.width
                        text: modelData.name
                        color: parent.parent.parent.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                        elide: Text.ElideRight
                    }
                    Text {
                        width: parent.width
                        text: modelData.path
                        color: parent.parent.parent.foreground
                        opacity: 0.65
                        font.family: Theme.fontFamily
                        font.pixelSize: Math.max(10, Theme.fontSize - 3)
                        elide: Text.ElideMiddle
                    }
                }
            }
        }
    }
}
