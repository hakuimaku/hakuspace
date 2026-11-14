import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import "../../services"
import "../motion" as Motion

Item {
    id: root

    property string query: ""
    property color rowHoverColor: Theme.hoverMuted
    property color rowSelectedColor: Theme.accent
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
        if (entry.runInTerminal && entry.command && entry.command.length > 0) {
            var terminal = Quickshell.env("TERMINAL") || "kitty"
            Quickshell.execDetached([terminal, "-e"].concat(entry.command))
        } else {
            entry.execute()
        }
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

    Item {
        anchors.fill: parent
        anchors.leftMargin: -Theme.hakuMenuLeftPadding
        anchors.rightMargin: -Theme.hakuMenuRightPadding
        clip: true

        ListView {
            id: appList
            anchors.fill: parent
            anchors.leftMargin: Theme.hakuMenuLeftPadding + Theme.gap
            anchors.rightMargin: Theme.hakuMenuRightPadding + Theme.gap
            anchors.topMargin: Theme.gap
            anchors.bottomMargin: Theme.gap
            clip: false
            spacing: Theme.gap
            boundsBehavior: Flickable.StopAtBounds
            currentIndex: count > 0 ? 0 : -1
            model: appModel
            onCurrentIndexChanged: {
                root.publishCurrentLabel();
                if (currentIndex < 0) {
                    selectionPill.targetItem = null;
                }
            }

            Motion.SelectionPill {
                id: selectionPill
                parent: appList.contentItem
                z: 0
                normalColor: Theme.accent
                scale: targetItem ? targetItem.scale : 1.0
                transformOrigin: Item.Center
            }

            ScrollBar.vertical: Motion.HScrollBar {
                id: vbar
            }

            delegate: Motion.MorphButton {
                id: appRow
                z: 1
                required property var modelData
                required property int index
                readonly property string secondaryText: modelData.genericName || modelData.comment || modelData.id || ""
                width: appList.width - vbar.reservedGutter
                height: Math.max(48, Theme.fontSize * 3.5)
                radius: Theme.radius
                selected: appList.currentIndex === appRow.index
                selectedOverridesHover: true
                idleColor: "transparent"
                hoverColor: (selected || focused) ? "transparent" : root.rowHoverColor
                pressedColor: (selected || focused) ? "transparent" : root.rowHoverColor
                selectedColor: "transparent"
                foregroundColor: Theme.fg
                hoverForegroundColor: (selected || focused) ? Theme.onAccentColor : Theme.fg
                pressedForegroundColor: (selected || focused) ? Theme.onAccentColor : Theme.fg
                selectedForegroundColor: Theme.onAccentColor
                hoverScaleDelta: Theme.hakuMenuHoverScaleDelta
                pressScaleDelta: 0.012

                Component.onCompleted: {
                    if (selected) {
                        selectionPill.targetItem = this;
                    }
                }

                onSelectedChanged: {
                    if (selected) {
                        selectionPill.targetItem = this;
                    }
                }

                onHoveredChanged: {
                    if (hovered) appList.currentIndex = appRow.index
                }
                onClicked: root.activateIndex(appRow.index)

                GridLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.pad
                    anchors.rightMargin: Theme.pad
                    columns: 2
                    rowSpacing: 2
                    columnSpacing: Theme.gap * 2

                    Item {
                        Layout.row: 0
                        Layout.column: 0
                        Layout.rowSpan: 2
                        Layout.preferredWidth: appRow.height - Theme.pad
                        Layout.fillHeight: true

                        IconImage {
                            anchors.centerIn: parent
                            width: Math.min(parent.width, Theme.fontSize * 2.2)
                            height: width
                            source: root.iconSource(appRow.modelData.icon)
                            visible: source !== ""
                        }
                    }

                    Text {
                        Layout.row: 0
                        Layout.column: 1
                        Layout.rowSpan: appRow.secondaryText.length > 0 ? 1 : 2
                        Layout.fillWidth: true
                        Layout.alignment: appRow.secondaryText.length > 0 ? (Qt.AlignLeft | Qt.AlignBottom) : (Qt.AlignLeft | Qt.AlignVCenter)
                        text: appRow.modelData.name || appRow.modelData.id
                        color: appRow.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize + 1
                        font.weight: (appRow.selected || appRow.focused) ? Font.Medium : Font.Normal
                        elide: Text.ElideRight
                    }

                    Text {
                        Layout.row: 1
                        Layout.column: 1
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignLeft | Qt.AlignTop
                        text: appRow.secondaryText
                        color: (appRow.selected || appRow.focused) ? Theme.onAccentMuted : Theme.fgMuted
                        font.family: Theme.fontFamily
                        font.pixelSize: Math.max(10, Math.round((Theme.fontSize + 1) * 0.82))
                        elide: Text.ElideRight
                        visible: text.length > 0

                        Behavior on color {
                            ColorAnimation {
                                duration: HAnimation.selectionMorphDuration
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: HAnimation.selectionMorphCurve
                            }
                        }
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                text: root.query.trim().length > 0 ? "No applications found" : "No applications"
                color: Theme.fgMuted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize + 1
                visible: appList.count === 0
            }
        }
    }
}
