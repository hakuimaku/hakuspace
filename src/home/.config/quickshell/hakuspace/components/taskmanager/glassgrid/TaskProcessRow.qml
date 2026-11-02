import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../../services"
import "../TaskManagerLogic.js" as Logic

RowLayout {
    id: root
    // Share identical column geometry and column-based color mapping between header and virtualized rows.
    property bool header: false
    property var process: ({})
    property bool selected: false
    property bool isPinned: false
    property var visuals

    readonly property bool compactColumns: width > 0 && width < 480
    readonly property int dataFontSize: (visuals ? visuals.tableFontSize : 12) - (compactColumns ? 1 : 0)
    readonly property int labelFontSize: root.header
        ? ((visuals ? visuals.metaFontSize : 11) - (compactColumns ? 1 : 0))
        : dataFontSize
    readonly property int userColumnWidth: compactColumns ? 50 : 88
    readonly property int cpuColumnWidth: compactColumns ? 58 : 72
    readonly property int memColumnWidth: compactColumns ? 70 : 96
    readonly property int thrColumnWidth: compactColumns ? 36 : 44

    readonly property color fgCol: visuals ? visuals.primaryFg : Theme.fg
    readonly property color headerAccentCol: visuals ? visuals.headerAccentFg : Qt.alpha(Theme.accent, 0.68)

    spacing: compactColumns ? 6 : 10

    TextMetrics {
        id: pidWidth
        font.family: Theme.fontFamily
        font.pixelSize: root.dataFontSize
        text: "9999999"
    }

    Label {
        id: pidCell
        objectName: "taskManagerPid"
        Layout.minimumWidth: Math.ceil(pidWidth.width) + (root.compactColumns ? 6 : 10)
        Layout.preferredWidth: Layout.minimumWidth
        Layout.maximumWidth: Layout.minimumWidth
        font.family: Theme.fontFamily
        font.pixelSize: root.labelFontSize
        text: root.header ? "PID" : String(root.process.pid)
        color: root.header ? Theme.fgMuted : root.fgCol
        elide: Text.ElideNone
    }

    Label {
        objectName: "taskManagerProcessName"
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        font.family: Theme.fontFamily
        font.pixelSize: root.labelFontSize
        font.bold: !root.header && (root.selected || root.isPinned)
        text: root.header ? "PROCESS" : ((root.isPinned ? "󰐃 " : "") + String(root.process.name || "—"))
        color: root.header ? root.headerAccentCol : Theme.accent
        elide: Text.ElideRight
    }

    Label {
        objectName: "taskManagerProcessUser"
        Layout.minimumWidth: root.userColumnWidth
        Layout.preferredWidth: root.userColumnWidth
        Layout.maximumWidth: root.userColumnWidth
        font.family: Theme.fontFamily
        font.pixelSize: root.labelFontSize
        text: root.header ? "USER" : String(root.process.user || "—")
        color: root.header ? Theme.fgMuted : root.fgCol
        elide: Text.ElideRight
    }

    Label {
        objectName: "taskManagerProcessCpu"
        Layout.minimumWidth: root.cpuColumnWidth
        Layout.preferredWidth: root.cpuColumnWidth
        Layout.maximumWidth: root.cpuColumnWidth
        font.family: Theme.fontFamily
        font.pixelSize: root.labelFontSize
        text: root.header ? "CPU" : Logic.metric(root.process.cpuTotalPercent, "%")
        color: root.header ? root.headerAccentCol : Theme.accent
        horizontalAlignment: Text.AlignRight
        elide: Text.ElideRight
    }

    Label {
        objectName: "taskManagerProcessMemory"
        Layout.minimumWidth: root.memColumnWidth
        Layout.preferredWidth: root.memColumnWidth
        Layout.maximumWidth: root.memColumnWidth
        font.family: Theme.fontFamily
        font.pixelSize: root.labelFontSize
        text: root.header ? "MEM" : Logic.bytes(root.process.rss)
        color: root.header ? Theme.fgMuted : root.fgCol
        horizontalAlignment: Text.AlignRight
        elide: Text.ElideRight
    }

    Label {
        objectName: "taskManagerProcessThreads"
        Layout.minimumWidth: root.thrColumnWidth
        Layout.preferredWidth: root.thrColumnWidth
        Layout.maximumWidth: root.thrColumnWidth
        font.family: Theme.fontFamily
        font.pixelSize: root.labelFontSize
        text: root.header ? "THR" : String(root.process.threads !== undefined ? root.process.threads : "—")
        color: root.header ? root.headerAccentCol : Theme.accent
        horizontalAlignment: Text.AlignRight
        elide: Text.ElideNone
    }
}
