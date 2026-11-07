import QtQuick
import Quickshell
import "../../services"
import ".."

TopModule {
    id: root

    // Stack hours above minutes; calendar interaction stays separate.
    property bool vertical: false
    hoverAxis: vertical ? "vertical" : "horizontal"
    property bool compact: false
    property int monthOffset: 0
    
    text: ""
    icon: compact && !vertical ? "" : ""
    
    implicitHeight: vertical ? Math.max(ScreenGeometry.leftModuleTouchSize, verticalClock.implicitHeight + ScreenGeometry.leftModuleInset * 2) : Theme.fontSize * 1.8
    implicitWidth: vertical ? ScreenGeometry.leftTouchSize : compact ? implicitHeight : Math.max(implicitHeight, contentRow.implicitWidth + Theme.pad * 2 + (hovered ? 20 : 0))
    
    Row {
        id: contentRow
        visible: !root.compact && !root.vertical
        anchors.centerIn: parent
        spacing: 16
        
        Text {
            text: Clock.date ? Clock.date.toLocaleString(Qt.locale(), "HH:mm") : ""
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            font.weight: Font.Bold
            color: root.hovered ? Theme.onAccentColor : Theme.fg
            anchors.verticalCenter: parent.verticalCenter
            Behavior on color { ColorAnimation { duration: HAnimation.slow } }
        }

        Column {
            id: customCol
            anchors.verticalCenter: parent.verticalCenter
            spacing: -2
            
            Text {
                text: Clock.date ? Clock.date.toLocaleString(Qt.locale(), "dddd") : ""
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize - 2
                font.weight: Font.Bold
                color: root.hovered ? Theme.onAccentColor : Theme.fg
                anchors.left: parent.left
                anchors.leftMargin: - 2
                Behavior on color { ColorAnimation { duration: HAnimation.slow } }
            }
            
            Text {
                text: Clock.date ? Clock.date.toLocaleString(Qt.locale(), "dd/MM/yyyy") : ""
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize - 4
                font.weight: Font.Normal
                color: root.hovered ? Theme.onAccentColor : Theme.fg
                anchors.right: parent.right
                anchors.rightMargin: - 4
                Behavior on color { ColorAnimation { duration: HAnimation.slow } }
            }
        }
    }
    
    Text {
        id: verticalClock
        objectName: "leftbar-clock-time"
        anchors.centerIn: parent
        visible: root.vertical
        text: Clock.date ? Clock.date.toLocaleString(Qt.locale(), "HH\nmm") : "00\n00"
        width: Math.max(0, root.visualItem.width - 2)
        horizontalAlignment: Text.AlignHCenter
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        minimumPixelSize: Math.min(10, font.pixelSize)
        fontSizeMode: Text.HorizontalFit
        font.bold: true
        color: root.hovered ? Theme.onAccentColor : Theme.fg
    }

    onClicked: requestTooltip()
    onRightClicked: monthOffset = 0
    onScrolled: (delta) => {
        if (delta > 0) monthOffset++;
        else monthOffset--;
    }
    
    Component {
        id: calendarComponent
        CalendarGrid {
            currentDate: Clock.date
            monthOffset: root.monthOffset
            maxHeight: 180
            preferredCellHeight: 22
        }
    }

    tooltipComponent: calendarComponent
}
