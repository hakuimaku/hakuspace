import QtQuick
import "../../services"

Column {
    id: root
    property Item shortcutTarget: null
    spacing: Theme.spaceSm
    StatusEdgeControl { width: parent.width; shortcutTarget: root.shortcutTarget }
}
