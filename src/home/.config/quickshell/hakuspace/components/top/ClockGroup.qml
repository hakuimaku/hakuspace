import QtQuick
import Quickshell
import "../../services"
import "../"

TopModule {
    id: root
    
    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: updateTime()
    }
    
    property string timeText: ""
    property string dateText: ""
    
    function updateTime() {
        var d = new Date();
        timeText = d.getHours().toString().padStart(2, '0') + ":" + d.getMinutes().toString().padStart(2, '0');
        dateText = d.getDate().toString().padStart(2, '0') + "/" + (d.getMonth() + 1).toString().padStart(2, '0') + "/" + d.getFullYear();
    }
    
    Component.onCompleted: updateTime()
    
    text: " " + timeText + "   " + dateText
    
    MouseArea {
        anchors.fill: parent
        onClicked: console.log("Clock clicked!")
        cursorShape: Qt.PointingHandCursor
    }
}
