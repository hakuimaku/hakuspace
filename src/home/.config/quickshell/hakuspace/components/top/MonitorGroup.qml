import QtQuick
import "../"
import "../base"
import "../../services"

HDrawer {
    id: root
    leftToRight: false
    open: false
    
    onOpenChanged: {
        if (open) SysStats.acquire()
        else SysStats.release()
    }

    trigger: TopModule {
        icon: root.open ? "" : ""
        isAccent: true
        tooltip: "System Monitor"
        onClicked: root.open = !root.open
    }
    
    Row {
        spacing: Theme.gap
        TopModule { 
            text: SysStats.cpu + "%"
            icon: ""
            color: hovered ? Theme.surfaceHi : "rgba(32,32,32,0.6)"
        }
        TopModule { 
            text: SysStats.ram + "%"
            icon: ""
            color: hovered ? Theme.surfaceHi : "rgba(32,32,32,0.6)"
        }
        TopModule { 
            text: SysStats.temp + "°C"
            icon: ""
            visible: SysStats.hasTemp
            color: hovered ? Theme.surfaceHi : "rgba(32,32,32,0.6)"
        }
    }
}
