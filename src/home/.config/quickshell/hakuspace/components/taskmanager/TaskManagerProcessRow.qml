import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../services"
import "TaskManagerLogic.js" as Logic

RowLayout {
    id: root
    // Share identical column geometry between the header and virtualized rows.
    property bool header: false
    property var process: ({})
    readonly property color foreground: header ? Theme.fgMuted : Theme.fg
    TextMetrics { id: pidWidth; font: pidCell.font; text: "9999999" }
    Label {
        id: pidCell
        objectName: "taskManagerPid"
        Layout.minimumWidth: Math.ceil(pidWidth.width) + 4
        Layout.preferredWidth: Layout.minimumWidth
        Layout.maximumWidth: Layout.minimumWidth
        text: root.header ? "PID" : String(root.process.pid)
        color: root.foreground
        elide: Text.ElideNone
    }
    Label {
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        text: root.header ? "Name / user" : root.process.name + " · " + root.process.user
        color: root.foreground
        elide: Text.ElideRight
    }
    Label {
        Layout.minimumWidth: 85
        Layout.preferredWidth: 85
        Layout.maximumWidth: 85
        text: root.header ? "CPU" : Logic.metric(root.process.cpuTotalPercent, "%")
        color: root.foreground
        horizontalAlignment: Text.AlignRight
    }
    Label {
        Layout.minimumWidth: 105
        Layout.preferredWidth: 105
        Layout.maximumWidth: 105
        text: root.header ? "Memory" : Logic.bytes(root.process.rss)
        color: root.foreground
        horizontalAlignment: Text.AlignRight
    }
    Label {
        Layout.minimumWidth: 55
        Layout.preferredWidth: 55
        Layout.maximumWidth: 55
        text: root.header ? "Threads" : String(root.process.threads)
        color: root.foreground
        horizontalAlignment: Text.AlignRight
    }
}
