import QtQuick
import "../../services"

Item {
    id: root

    property string target: "/"
    property string source: ""
    property string fstype: ""
    property string usedStr: ""
    property string sizeStr: ""
    property int percent: 0
    property bool available: true
    property bool showUsed: false

    width: parent ? parent.width : 200
    height: 28

    Row {
        anchors.fill: parent
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8

        // Mount point label
        Text {
            id: label
            width: Math.min(68, Math.max(48, root.width * 0.26))
            anchors.verticalCenter: parent.verticalCenter
            text: root.target === "/" ? "Root /" : (root.target.lastIndexOf("/") > 0 ? root.target.substring(root.target.lastIndexOf("/") + 1) : root.target)
            font.family: Theme.fontFamily
            font.pixelSize: Math.max(10, Theme.fontSize - 2)
            font.weight: Font.DemiBold
            color: root.available ? Theme.fg : Theme.fgDim
            elide: Text.ElideRight
        }

        // Progress bar track
        Rectangle {
            id: track
            width: parent.width - label.width - valueText.width - (parent.spacing * 2)
            height: 5
            radius: 2.5
            color: Theme.hoverMuted
            anchors.verticalCenter: parent.verticalCenter

            Rectangle {
                id: fill
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: root.available ? Math.round(parent.width * (Math.max(0, Math.min(100, root.percent)) / 100)) : 0
                radius: 2.5
                color: Theme.accent
                visible: root.available

                Behavior on width {
                    NumberAnimation {
                        duration: HAnimation.normal
                        easing.type: Easing.OutCubic
                    }
                }
            }
        }

        // Value text (% or used)
        Text {
            id: valueText
            width: Math.max(38, implicitWidth)
            horizontalAlignment: Text.AlignRight
            anchors.verticalCenter: parent.verticalCenter
            text: {
                if (!root.available) return "N/A"
                if (root.showUsed && root.usedStr.length > 0) return root.usedStr
                return root.percent + "%"
            }
            font.family: Theme.fontFamily
            font.pixelSize: Math.max(10, Theme.fontSize - 2)
            font.weight: Font.Bold
            color: root.available ? Theme.fg : Theme.fgDim
        }
    }

    MouseArea {
        id: rowArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.available ? Qt.PointingHandCursor : Qt.ArrowCursor
        acceptedButtons: Qt.LeftButton

        function updateTooltip() {
            if (!root.available) return
            var title = root.target === "/" ? "Root (/)" : root.target
            var text = title
            if (root.fstype) text += " • " + root.fstype
            if (root.usedStr && root.sizeStr) {
                text += "\n" + root.usedStr + " used of " + root.sizeStr + " (" + root.percent + "%)"
            } else {
                text += "\n" + root.percent + "% used"
            }
            text += "\nClick to toggle % / used"
            DashboardTooltip.show(root, text)
        }

        onEntered: updateTooltip()
        onExited: DashboardTooltip.hide(root)
        onClicked: {
            if (root.available) {
                root.showUsed = !root.showUsed
                updateTooltip()
            }
        }
    }
}
