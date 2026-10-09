import QtQuick
import Quickshell
import "../../services"
import ".."

TopModule {
    id: root
    
    SystemClock {
        id: sysClock
    }
    
    property int monthOffset: 0
    
    text: ""
    icon: ""
    
    implicitWidth: Math.max(implicitHeight, contentRow.implicitWidth + Theme.pad * 2 + (hovered ? 20 : 0))
    
    Row {
        id: contentRow
        anchors.centerIn: parent
        spacing: 16
        
        Text {
            text: sysClock.date ? sysClock.date.toLocaleString(Qt.locale(), "HH:mm") : "" 
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            font.weight: Font.Bold
            color: root.hovered ? Theme.onAccentColor : Theme.fg
            anchors.verticalCenter: parent.verticalCenter
            Behavior on color { ColorAnimation { duration: HAnimation.normal } }
        }

        Column {
            id: customCol
            anchors.verticalCenter: parent.verticalCenter
            spacing: -2
            
            Text {
                text: sysClock.date ? sysClock.date.toLocaleString(Qt.locale(), "dddd") : ""
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize - 2
                font.weight: Font.Bold
                color: root.hovered ? Theme.onAccentColor : Theme.fg
                anchors.left: parent.left
                anchors.leftMargin: - 2
                Behavior on color { ColorAnimation { duration: HAnimation.normal } }
            }
            
            Text {
                text: sysClock.date ? sysClock.date.toLocaleString(Qt.locale(), "dd/MM/yyyy") : ""
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize - 4
                font.weight: Font.Normal
                color: root.hovered ? Theme.onAccentColor : Theme.fg
                anchors.right: parent.right
                anchors.rightMargin: - 4
                Behavior on color { ColorAnimation { duration: HAnimation.normal } }
            }
        }
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
            currentDate: sysClock.date
            monthOffset: root.monthOffset
        }
    }

    tooltipComponent: calendarComponent
}
