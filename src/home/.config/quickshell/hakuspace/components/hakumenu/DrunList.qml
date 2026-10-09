import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Widgets
import "../../services"
import "../motion" as Motion

Item {
    id: root

    property string query: ""
    property color rowHoverColor: "#202020"
    property color rowSelectedColor: "#262626"
    signal launched()
    signal highlightedLabelChanged(string label)

    function iconSource(icon) {
        if (!icon) return ""
        if (icon.startsWith("image://") || icon.startsWith("file://")) return icon
        return icon.startsWith("/") ? "file://" + icon : "image://icon/" + icon
    }

    function normalizedQuery() {
        return query.trim().toLowerCase()
    }

    function matches(entry) {
        var q = normalizedQuery()
        if (q.length === 0) return true

        var fields = [
            entry.name || "",
            entry.genericName || "",
            entry.comment || "",
            entry.id || "",
            entry.keywords ? entry.keywords.join(" ") : ""
        ].join(" ").toLowerCase()

        var terms = q.split(/\s+/)
        for (var i = 0; i < terms.length; ++i) {
            if (terms[i].length > 0 && fields.indexOf(terms[i]) < 0) return false
        }
        return true
    }

    function sortedApplications() {
        var entries = [...DesktopEntries.applications.values]
            .filter(function(entry) { return root.matches(entry) })

        entries.sort(function(a, b) {
            return (a.name || a.id || "").localeCompare(b.name || b.id || "")
        })
        return entries
    }


    function currentLabel() {
        var index = appList.currentIndex
        if (index < 0 || index >= appModel.values.length) return ""
        var entry = appModel.values[index]
        if (!entry) return ""
        return entry.name || entry.id || ""
    }

    function publishCurrentLabel() {
        root.highlightedLabelChanged(root.currentLabel())
    }

    function resetSelection() {
        appList.currentIndex = appModel.values.length > 0 ? 0 : -1
        if (appList.currentIndex >= 0) appList.positionViewAtIndex(0, ListView.Beginning)
        root.publishCurrentLabel()
    }

    function moveSelection(delta) {
        var count = appModel.values.length
        if (count === 0) return
        var next = appList.currentIndex
        if (next < 0) next = 0
        else next = Math.max(0, Math.min(count - 1, next + delta))
        appList.currentIndex = next
        appList.positionViewAtIndex(next, ListView.Contain)
    }

    function activateIndex(index) {
        if (index < 0 || index >= appModel.values.length) return
        var entry = appModel.values[index]
        if (!entry) return
        entry.execute()
        root.launched()
    }

    function activateCurrent() {
        activateIndex(appList.currentIndex)
    }

    onQueryChanged: Qt.callLater(resetSelection)
    onVisibleChanged: {
        if (visible) Qt.callLater(publishCurrentLabel)
    }

    ScriptModel {
        id: appModel
        values: root.sortedApplications()
        onValuesChanged: Qt.callLater(root.resetSelection)
    }

    ListView {
        id: appList
        anchors.fill: parent
        anchors.margins: Theme.gap
        clip: true
        spacing: Theme.gap
        boundsBehavior: Flickable.StopAtBounds
        currentIndex: count > 0 ? 0 : -1
        model: appModel
        onCurrentIndexChanged: root.publishCurrentLabel()

        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded
        }

        delegate: Motion.MorphButton {
            id: appRow
            required property var modelData
            required property int index
            width: appList.width
            height: Math.max(48, Theme.fontSize * 3.5)
            radius: Theme.radiusSm
            selected: ListView.isCurrentItem
            selectedOverridesHover: true
            idleColor: "transparent"
            hoverColor: root.rowHoverColor
            pressedColor: root.rowSelectedColor
            selectedColor: root.rowSelectedColor
            foregroundColor: Theme.fg
            hoverForegroundColor: Theme.accent
            pressedForegroundColor: Theme.accent
            selectedForegroundColor: Theme.accent
            hoverScaleDelta: 0.003
            pressScaleDelta: 0.012
            onHoveredChanged: {
                if (hovered) appList.currentIndex = appRow.index
            }
            onClicked: root.activateIndex(appRow.index)

            Row {
                anchors.fill: parent
                anchors.leftMargin: Theme.pad
                anchors.rightMargin: Theme.pad
                spacing: Theme.gap * 2

                Item {
                    width: appRow.height - Theme.pad
                    height: appRow.height

                    IconImage {
                        anchors.centerIn: parent
                        width: Math.min(parent.width, Theme.fontSize * 2.2)
                        height: width
                        source: root.iconSource(appRow.modelData.icon)
                        visible: source !== ""
                    }
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.max(0, parent.width - (appRow.height - Theme.pad) - Theme.gap * 2)
                    spacing: 2

                    Text {
                        width: parent.width
                        text: appRow.modelData.name || appRow.modelData.id
                        color: appRow.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                        elide: Text.ElideRight
                    }

                    Text {
                        width: parent.width
                        text: appRow.modelData.genericName || appRow.modelData.comment || appRow.modelData.id
                        color: Theme.fgMuted
                        font.family: Theme.fontFamily
                        font.pixelSize: Math.max(10, Theme.fontSize * 0.82)
                        elide: Text.ElideRight
                        visible: text.length > 0
                    }
                }
            }
        }

        Text {
            anchors.centerIn: parent
            text: root.query.trim().length > 0 ? "No applications found" : "No applications"
            color: Theme.fgMuted
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            visible: appList.count === 0
        }
    }
}
