import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import "../../services"
import "../sidebar" as Sidebar
import "TaskManagerLogic.js" as Logic

FocusScope {
    id: root
    // Recompute process rows only for source-table or control changes.
    property string query: ""
    property string sortKey: "cpu"
    property bool descending: true
    readonly property var rows: Logic.processRows(TaskManagerService.processes, query, sortKey, descending)
    // Selection and confirmation belong to process identities across refresh/reorder.
    property string selectedKey: ""
    readonly property var selectedProcess: TaskManagerService.processes.find(row => row.key === selectedKey) || null
    property bool detailsOpen: false
    property string killKey: ""
    readonly property int selectedIndex: rows.findIndex(row => row.key === selectedKey)
    // Only the floating surface holding the shared lease may handle keyboard actions.
    property bool interactionOwned: false
    signal closeRequested()

    // Discard stale selection and confirmation as soon as a process disappears.
    Connections {
        target: TaskManagerService
        function onProcessesChanged() {
            if (root.selectedKey && !root.selectedProcess) {
                root.selectedKey = ""; root.killKey = ""; root.detailsOpen = false
            }
        }
    }

    // Restore table navigation after pointer handoff without stealing search focus.
    function forceFocus() { if (!search.activeFocus) table.forceActiveFocus() }
    // Move by identity, even when the CPU sort reorders the visible rows.
    function moveSelection(delta) {
        if (!rows.length) return
        var index = Math.max(0, Math.min(rows.length - 1, selectedIndex < 0 ? 0 : selectedIndex + delta))
        selectedKey = rows[index].key
        killKey = ""
        table.positionViewAtIndex(index, ListView.Contain)
    }
    // Escape dismisses the current child state before closing the utility.
    function handleEscape() {
        if (killKey) killKey = ""
        else if (search.activeFocus || query) { search.text = ""; table.forceActiveFocus() }
        else if (detailsOpen) detailsOpen = false
        else closeRequested()
    }
    // Route navigation before ListView consumes its built-in key handling.
    function handleKey(event) {
        if (!interactionOwned) return
        if (event.key === Qt.Key_Escape) handleEscape()
        else if ((event.key === Qt.Key_F && (event.modifiers & Qt.ControlModifier))
                 || (event.key === Qt.Key_Slash && !search.activeFocus)) search.forceActiveFocus()
        else if (event.key === Qt.Key_Down && !search.activeFocus) moveSelection(1)
        else if (event.key === Qt.Key_Up && !search.activeFocus) moveSelection(-1)
        else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && selectedProcess && !search.activeFocus) detailsOpen = true
        else return
        event.accepted = true
    }

    Keys.onPressed: event => handleKey(event)

    ColumnLayout {
        anchors.fill: parent
        spacing: 6
        Label {
            Layout.fillWidth: true
            color: TaskManagerService.error ? Theme.accent : Theme.fgMuted
            elide: Text.ElideRight
            text: TaskManagerService.error || (TaskManagerService.warmingUp ? "Warming up…" : "Live · " + TaskManagerService.processes.length + " processes · Process CPU% of total capacity")
        }
        TaskManagerSummary { Layout.fillWidth: true; Layout.preferredHeight: Math.min(190, root.height * 0.34) }
        RowLayout {
            Layout.fillWidth: true
            TextField {
                id: search
                objectName: "taskManagerSearch"
                Layout.fillWidth: true
                placeholderText: "Search process, PID, user… (Ctrl+F)"
                Accessible.name: "Search processes"
                onTextChanged: root.query = text
            }
            ComboBox {
                model: ["CPU", "Memory", "PID", "Name"]
                Accessible.name: "Sort processes"
                onActivated: root.sortKey = ["cpu", "memory", "pid", "name"][currentIndex]
            }
            Sidebar.SidebarMorphButton {
                Layout.preferredWidth: 42
                Layout.preferredHeight: 32
                text: root.descending ? "↓" : "↑"
                activeFocusOnTab: true
                focused: activeFocus
                Accessible.role: Accessible.Button
                Accessible.name: "Reverse sort order"
                onClicked: root.descending = !root.descending
                Keys.onReturnPressed: clicked()
                Keys.onSpacePressed: clicked()
            }
        }
        TaskManagerProcessRow {
            Layout.fillWidth: true
            Layout.leftMargin: 4
            Layout.rightMargin: 4
            header: true
        }
        ScriptModel {
            id: processModel
            values: root.rows
            objectProp: "key"
            comparisonMode: ObjectComparison.Structure
        }
        ListView {
            id: table
            objectName: "taskManagerProcesses"
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 40
            model: processModel
            clip: true
            focus: true
            keyNavigationEnabled: false
            Keys.priority: Keys.BeforeItem
            Keys.onPressed: event => root.handleKey(event)
            currentIndex: root.selectedIndex
            ScrollBar.vertical: ScrollBar {}
            delegate: Rectangle {
                id: row
                required property var modelData
                width: table.width
                height: 34
                radius: 4
                color: root.selectedKey === modelData.key ? Theme.hoverMuted : "transparent"
                Accessible.role: Accessible.ListItem
                Accessible.name: modelData.pid + " " + modelData.name + " " + Logic.metric(modelData.cpuTotalPercent, "%")
                TaskManagerProcessRow {
                    anchors.fill: parent
                    anchors.margins: 4
                    process: row.modelData
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        root.selectedKey = row.modelData.key
                        root.killKey = ""
                        table.forceActiveFocus()
                    }
                    onDoubleClicked: root.detailsOpen = true
                }
            }
        }
        Label {
            visible: root.detailsOpen && !!root.selectedProcess
            Layout.fillWidth: true
            Layout.maximumHeight: 70
            color: Theme.fgMuted
            wrapMode: Text.WrapAnywhere
            maximumLineCount: 3
            elide: Text.ElideRight
            text: root.selectedProcess ? root.selectedProcess.cmdline + "\nPPID " + root.selectedProcess.ppid
                + " · State " + root.selectedProcess.state + " · " + root.selectedProcess.user
                + " · Memory " + Logic.metric(root.selectedProcess.memoryPercent, "%")
                + " · Runtime " + Logic.metric(root.selectedProcess.runtimeSeconds, " s", 0) : ""
        }
        RowLayout {
            Layout.fillWidth: true
            Label {
                Layout.fillWidth: true
                color: Theme.fgMuted
                elide: Text.ElideRight
                text: root.killKey ? "Force kill PID " + (root.selectedProcess || {}).pid + "? Unsaved work may be lost."
                    : TaskManagerService.actionError || TaskManagerService.actionStatus
                      || (root.selectedProcess ? root.selectedProcess.pid + " · " + root.selectedProcess.name : "Select a process")
            }
            Repeater {
                model: root.killKey ? ["Cancel", "Confirm kill"] : ["Details", "Terminate", "Force kill"]
                Sidebar.SidebarMorphButton {
                    required property string modelData
                    Layout.preferredWidth: modelData === "Confirm kill" ? 110 : 90
                    Layout.preferredHeight: 32
                    text: modelData
                    enabled: !!root.selectedProcess && !TaskManagerService.actionBusy
                    activeFocusOnTab: true
                    focused: activeFocus
                    Accessible.role: Accessible.Button
                    Accessible.name: modelData
                    onClicked: {
                        if (modelData === "Details") root.detailsOpen = !root.detailsOpen
                        else if (modelData === "Terminate") TaskManagerService.sendSignal(root.selectedProcess, "TERM")
                        else if (modelData === "Force kill") root.killKey = root.selectedKey
                        else if (modelData === "Confirm kill") {
                            if (root.killKey === root.selectedKey) TaskManagerService.sendSignal(root.selectedProcess, "KILL")
                            root.killKey = ""
                        } else root.killKey = ""
                    }
                    Keys.onReturnPressed: clicked()
                    Keys.onSpacePressed: clicked()
                }
            }
        }
    }
}
