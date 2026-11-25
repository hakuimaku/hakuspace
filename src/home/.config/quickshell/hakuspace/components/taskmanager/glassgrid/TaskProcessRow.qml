import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../../services"
import "../TaskManagerLogic.js" as Logic
import "../../../config/UiCatalog.js" as Catalog

RowLayout {
    id: root
    property bool header: false
    property var process: ({})
    property bool selected: false
    property bool isPinned: false
    property string sortKey: "cpu"
    property bool descending: true

    signal sortRequested(string key)

    readonly property bool compactColumns: width > 0 && width < 440
    readonly property int rowFontSize: root.header ? (Theme.fontSize - 1) : Theme.fontSize
    readonly property int cpuColumnWidth: compactColumns ? 74 : 92
    readonly property int memColumnWidth: compactColumns ? 88 : 108

    spacing: compactColumns ? Theme.spaceSm : Theme.spaceMd

    function headerSuffix(colKey) {
        if (!root.header || root.sortKey !== colKey) return ""
        return root.descending ? " ↓" : " ↑"
    }

    Item {
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        Layout.fillHeight: true

        RowLayout {
            anchors.fill: parent
            spacing: Theme.spaceXs

            Label {
                objectName: "taskManagerProcessPin"
                visible: !root.header && root.isPinned
                text: Catalog.taskManagerIcons.pin
                color: root.selected ? Theme.onAccentColor : Theme.accent
                font.family: Theme.iconFontFamily
                font.pixelSize: root.rowFontSize
            }

            Label {
                objectName: "taskManagerProcessName"
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                font.family: Theme.fontFamily
                font.pixelSize: root.rowFontSize
                font.bold: (root.header && root.sortKey === "name") || (!root.header && (root.selected || root.isPinned))
                text: root.header ? ("Process" + root.headerSuffix("name")) : String(root.process.name || "—")
                color: root.header
                    ? (root.sortKey === "name" ? Theme.accent : Theme.fgMuted)
                    : (root.selected ? Theme.onAccentColor : Theme.fg)
                elide: Text.ElideRight
            }
        }

        MouseArea {
            enabled: root.header
            anchors.fill: parent
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: root.sortRequested("name")
        }
    }

    Item {
        Layout.minimumWidth: root.cpuColumnWidth
        Layout.preferredWidth: root.cpuColumnWidth
        Layout.maximumWidth: root.cpuColumnWidth
        Layout.fillHeight: true

        Label {
            objectName: "taskManagerProcessCpu"
            anchors.fill: parent
            verticalAlignment: Text.AlignVCenter
            horizontalAlignment: Text.AlignRight
            font.family: Theme.fontFamily
            font.pixelSize: root.rowFontSize
            font.bold: (root.header && root.sortKey === "cpu") || (!root.header && root.selected)
            text: root.header ? ("CPU" + root.headerSuffix("cpu")) : Logic.metric(root.process.cpuTotalPercent, "%")
            color: root.header
                ? (root.sortKey === "cpu" ? Theme.accent : Theme.fgMuted)
                : (root.selected ? Theme.onAccentColor : Theme.accent)
            elide: Text.ElideRight
        }

        MouseArea {
            enabled: root.header
            anchors.fill: parent
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: root.sortRequested("cpu")
        }
    }

    Item {
        Layout.minimumWidth: root.memColumnWidth
        Layout.preferredWidth: root.memColumnWidth
        Layout.maximumWidth: root.memColumnWidth
        Layout.fillHeight: true

        Label {
            objectName: "taskManagerProcessMemory"
            anchors.fill: parent
            verticalAlignment: Text.AlignVCenter
            horizontalAlignment: Text.AlignRight
            font.family: Theme.fontFamily
            font.pixelSize: root.rowFontSize
            font.bold: root.header && root.sortKey === "memory"
            text: root.header ? ("RAM" + root.headerSuffix("memory")) : Logic.bytes(root.process.rss)
            color: root.header
                ? (root.sortKey === "memory" ? Theme.accent : Theme.fgMuted)
                : (root.selected ? Theme.onAccentColor : Theme.fg)
            elide: Text.ElideRight
        }

        MouseArea {
            enabled: root.header
            anchors.fill: parent
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: root.sortRequested("memory")
        }
    }
}
