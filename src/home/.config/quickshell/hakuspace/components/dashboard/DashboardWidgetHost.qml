import QtQuick
import "../../services"

Rectangle {
    id: root

    radius: Theme.radius
    color: Theme.surface
    border.width: 1
    border.color: Qt.lighter(Theme.hoverMuted, 1.25)
    clip: true

    property var widgets: [
        {
            key: "calendar",
            title: "Calendar",
            component: calendarPlaceholderComponent
        }
    ]
    property int currentIndex: 0

    readonly property int widgetCount: widgets ? widgets.length : 0
    readonly property var currentWidget: (widgets && widgetCount > 0 && currentIndex >= 0 && currentIndex < widgetCount)
                                         ? widgets[currentIndex] : null
    readonly property string currentKey: currentWidget ? currentWidget.key : ""
    readonly property string currentTitle: currentWidget ? currentWidget.title : ""

    function previousWidget() {
        if (widgetCount > 1) {
            currentIndex = (currentIndex - 1 + widgetCount) % widgetCount
        }
    }

    function nextWidget() {
        if (widgetCount > 1) {
            currentIndex = (currentIndex + 1) % widgetCount
        }
    }

    function setCurrentIndex(index) {
        if (index >= 0 && index < widgetCount) {
            currentIndex = index
        }
    }

    Item {
        id: headerArea
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 36
        anchors.topMargin: Math.max(8, Math.round(Theme.pad * 0.8))
        anchors.leftMargin: Math.max(12, Math.round(Theme.pad * 1.2))
        anchors.rightMargin: Math.max(12, Math.round(Theme.pad * 1.2))

        Text {
            id: titleLabel
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: root.currentTitle
            font.family: Theme.fontFamily
            font.pixelSize: Math.max(12, Theme.fontSize - 1)
            font.weight: Font.Bold
            color: Theme.fg
        }

        Row {
            id: switchControls
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4
            visible: root.widgetCount > 1

            Rectangle {
                width: 24
                height: 24
                radius: 12
                color: prevArea.containsMouse ? Theme.hoverMuted : "transparent"
                Behavior on color { ColorAnimation { duration: HAnimation.fast } }

                Text {
                    anchors.centerIn: parent
                    text: "‹"
                    font.family: Theme.fontFamily
                    font.pixelSize: 16
                    color: Theme.fg
                }

                MouseArea {
                    id: prevArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton
                    onClicked: root.previousWidget()
                }
            }

            Rectangle {
                width: 24
                height: 24
                radius: 12
                color: nextArea.containsMouse ? Theme.hoverMuted : "transparent"
                Behavior on color { ColorAnimation { duration: HAnimation.fast } }

                Text {
                    anchors.centerIn: parent
                    text: "›"
                    font.family: Theme.fontFamily
                    font.pixelSize: 16
                    color: Theme.fg
                }

                MouseArea {
                    id: nextArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton
                    onClicked: root.nextWidget()
                }
            }
        }
    }

    Loader {
        id: contentLoader
        anchors.top: headerArea.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: Math.max(8, Math.round(Theme.pad * 0.8))
        sourceComponent: root.currentWidget ? root.currentWidget.component : null
    }

    Component {
        id: calendarPlaceholderComponent

        Item {
            anchors.fill: parent

            Column {
                anchors.centerIn: parent
                spacing: 6

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: ""
                    font.family: Theme.fontFamily
                    font.pixelSize: 28
                    color: Theme.fgDim
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Calendar"
                    color: Theme.fg
                    font.family: Theme.fontFamily
                    font.pixelSize: Math.max(14, Theme.fontSize)
                    font.weight: Font.Bold
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "placeholder"
                    color: Theme.fgDim
                    font.family: Theme.fontFamily
                    font.pixelSize: Math.max(10, Theme.fontSize - 3)
                }
            }
        }
    }
}
