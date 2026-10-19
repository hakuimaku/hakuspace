import QtQuick
import "../../services"

Row {
    id: root
    // Keep exact counts through five windows, then use dots plus an overflow count.
    property int count: 0
    spacing: 3
    Repeater {
        model: Math.min(5, root.count)
        Rectangle { width: 4; height: 4; radius: 2; color: Theme.accent }
    }
    Text {
        visible: root.count > 5
        text: "+" + (root.count - 5)
        color: Theme.accent
        font.pixelSize: 9
        y: 4 - height
    }
}
