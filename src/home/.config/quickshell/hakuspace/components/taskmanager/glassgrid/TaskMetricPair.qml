import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../../services"

Item {
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
    property int spacing: 4
    implicitHeight: Math.max(labelText.implicitHeight, valueLabel.implicitHeight)

    Label {
        id: labelText
        text: root.label
        color: root.labelColor
        font.pixelSize: root.fontSize
        // Preserve complete values before allocating the remaining label space.
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: Math.min(implicitWidth, Math.max(0, root.width - valueLabel.implicitWidth - root.spacing))
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
        anchors.left: labelText.right
        anchors.leftMargin: root.spacing
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        maximumLineCount: 1
        elide: Text.ElideRight
    }
}
