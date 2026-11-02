import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../../services"

RowLayout {
    id: root
    property string label: ""
    property string value: ""
    property bool accentValue: false
    property color labelColor: Theme.fgMuted
    property var visuals
    property color valueColor: accentValue ? Theme.accent : (visuals ? visuals.primaryFg : Theme.fg)
    property int fontSize: visuals ? visuals.metaFontSize : 11
    property string valueObjectName: ""
    property bool compact: false
    property bool ultraCompact: false

    Layout.fillWidth: true
    Layout.minimumWidth: 0
    spacing: 4

    Label {
        id: labelText
        text: root.label
        color: root.labelColor
        font.pixelSize: root.fontSize
        Layout.minimumWidth: 0
        Layout.preferredWidth: root.ultraCompact ? 48 : (root.compact ? 54 : 62)
        Layout.maximumWidth: root.ultraCompact ? 54 : (root.compact ? 60 : 70)
        maximumLineCount: 1
        elide: Text.ElideRight
    }

    Label {
        id: valueLabel
        objectName: root.valueObjectName
        text: root.value
        color: root.valueColor
        font.bold: root.accentValue
        font.pixelSize: root.fontSize
        horizontalAlignment: Text.AlignRight
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        maximumLineCount: 1
        elide: Text.ElideRight
    }
}
