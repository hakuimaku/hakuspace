import QtQuick
import QtQuick.Controls
import Quickshell.Io
import "../../services"

Item {
    id: root

    property string query: ""
    property color rowHoverColor: "#202020"
    property color rowSelectedColor: "#262626"
    readonly property real itemGap: Math.max(3, Math.round(Theme.gap * 0.35) + 1)
    readonly property real rowHeight: Math.max(34, Theme.fontSize * 2.35)
    readonly property real sectionGap: Math.max(10, Math.round(Theme.gap * 1.5))
    property var parsedItems: []
    property var pendingItems: []
    property var visibleItems: []
    signal launched()
    signal highlightedLabelChanged(string label)

    readonly property var fixedItems: [
        { label: "Wifi", icon: "󰖩", command: ["nm-connection-editor"] },
        { label: "Bluetooth", icon: "󰂯", command: ["blueman-manager"] },
        { label: "Disk Manager", icon: "󰋊", command: ["gparted"] },
        { label: "Storage Manager", icon: "󰃢", command: ["kitty", "--class", "ncdu", "-e", "sudo", "ncdu", "/"] },
        { label: "Audio Control", icon: "", command: ["pavucontrol"] }
    ]

    function cleanLabel(line) {
        var text = (line || "").trim()
        var parts = text.split(/\s{2,}/)
        return parts.length > 1 ? parts.slice(1).join("  ").trim() : text
    }

    function normalizedQuery() {
        var text = query.trim()
        if (text.startsWith(">")) text = text.slice(1)
        return text.trim().toLowerCase()
    }

    function matches(item) {
        var q = normalizedQuery()
        if (q.length === 0) return true
        return ((item.label || "") + " " + (item.raw || "")).toLowerCase().indexOf(q) >= 0
    }

    function filteredItems() {
        var dynamicRows = parsedItems.filter(function(item) { return root.matches(item) })
        var fixedRows = []
        for (var i = 0; i < fixedItems.length; ++i) {
            var fixed = fixedItems[i]
            var row = {
                label: fixed.label,
                raw: fixed.icon + "  " + fixed.label,
                command: fixed.command,
                fixed: true,
                sectionStart: false
            }
            if (root.matches(row)) fixedRows.push(row)
        }

        if (fixedRows.length > 0 && dynamicRows.length > 0)
            fixedRows[0].sectionStart = true

        return dynamicRows.concat(fixedRows)
    }

    function refresh() {
        pendingItems = []
        listProcess.running = false
        listProcess.command = [Env.binDir + "/hm_general.sh"]
        listProcess.running = true
    }

    function receiveLine(data) {
        var raw = (data || "").trim()
        if (raw.length === 0) return
        var label = cleanLabel(raw)
        if (label.toLowerCase() === "app menu") return
        pendingItems.push({ label: label, raw: raw, fixed: false, sectionStart: false })
    }

    function rebuildModel() {
        visibleItems = filteredItems()
        Qt.callLater(resetSelection)
    }

    function resetSelection() {
        generalList.currentIndex = visibleItems.length > 0 ? 0 : -1
        if (generalList.currentIndex >= 0)
            generalList.positionViewAtIndex(generalList.currentIndex, ListView.Beginning)
        syncSelectionLabel()
    }

    function syncSelectionLabel() {
        if (!visible) return
        var index = generalList.currentIndex
        if (index < 0 || index >= visibleItems.length) {
            root.highlightedLabelChanged("")
            return
        }
        root.highlightedLabelChanged(visibleItems[index].label || "")
    }

    function moveSelection(delta) {
        var count = visibleItems.length
        if (count === 0) return
        var next = generalList.currentIndex
        if (next < 0) next = 0
        else next = Math.max(0, Math.min(count - 1, next + delta))
        generalList.currentIndex = next
        generalList.positionViewAtIndex(next, ListView.Contain)
        syncSelectionLabel()
    }

    function activateIndex(index) {
        if (index < 0 || index >= visibleItems.length) return
        var item = visibleItems[index]
        if (!item) return

        actionProcess.running = false
        actionProcess.command = item.fixed
            ? item.command
            : [Env.binDir + "/hm_general.sh", item.raw]
        actionProcess.running = true
        root.launched()
    }

    function activateCurrent() {
        activateIndex(generalList.currentIndex)
    }

    onQueryChanged: rebuildModel()
    onVisibleChanged: {
        if (visible) {
            refresh()
            rebuildModel()
        } else {
            root.highlightedLabelChanged("")
        }
    }


    Process {
        id: listProcess
        stdout: SplitParser {
            onRead: data => root.receiveLine(data)
        }
        onExited: exitCode => {
            if (exitCode === 0) root.parsedItems = root.pendingItems.slice()
            else root.parsedItems = []
            root.rebuildModel()
        }
    }

    Process {
        id: actionProcess
    }


    ListView {
        id: generalList
        anchors.fill: parent
        anchors.margins: Theme.gap
        clip: true
        spacing: root.itemGap
        boundsBehavior: Flickable.StopAtBounds
        currentIndex: count > 0 ? 0 : -1
        model: root.visibleItems
        onCurrentIndexChanged: root.syncSelectionLabel()

        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded
        }

        delegate: Item {
            id: rowWrap
            required property var modelData
            required property int index
            width: generalList.width
            height: row.height + (modelData.sectionStart ? root.sectionGap : 0)

            Rectangle {
                visible: rowWrap.modelData.sectionStart
                x: Theme.pad
                y: Math.max(0, (root.sectionGap - height) / 2)
                width: Math.max(0, parent.width - Theme.pad * 2)
                height: 1
                color: Qt.darker(Theme.fgMuted, 1.75)
                opacity: 0.55
            }

            Rectangle {
                id: row
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: root.rowHeight
                radius: Theme.radiusSm
                readonly property bool selected: generalList.currentIndex === rowWrap.index
                color: selected ? root.rowSelectedColor
                                : (rowMouse.containsMouse ? root.rowHoverColor : "transparent")

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.pad * 1.5
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.pad * 1.5
                    anchors.verticalCenter: parent.verticalCenter
                    text: rowWrap.modelData.raw
                    color: row.selected ? Theme.accent : Theme.fg
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize + 1
                    font.bold: row.selected
                    elide: Text.ElideRight
                }

                MouseArea {
                    id: rowMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: {
                        generalList.currentIndex = rowWrap.index
                        root.syncSelectionLabel()
                    }
                    onClicked: root.activateIndex(rowWrap.index)
                }
            }
        }

        Text {
            anchors.centerIn: parent
            text: root.normalizedQuery().length > 0 ? "No General actions found" : "No General actions"
            color: Theme.fgMuted
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize + 1
            visible: generalList.count === 0 && !listProcess.running
        }
    }
}
