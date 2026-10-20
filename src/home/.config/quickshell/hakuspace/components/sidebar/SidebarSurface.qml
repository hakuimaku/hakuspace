import QtQuick
import "../../services"

Item {
    id: root

    required property real controlDiameter
    required property real bodyWidth
    property bool bottomAttached: false
    property real bodyHeight: 500
    property Item tooltipHost: null
    property real rf: ScreenGeometry.edgeHugRadius
    property real sideInset: ScreenGeometry.leftInset
    property real topFlareY: 16
    property real earWidth: Math.max(32, Math.round(rf * 1.5))
    property real earRadius: Math.max(32, Math.round(rf * 1.5))
    property real cornerRadius: Theme.largeRadius + 8
    property color surfaceColor: Theme.surface
    property bool expanded: false
    property string activeToolKey: ""
    property int selectedToolIndex: 0
    property bool keyboardSelected: false

    readonly property real itemDiameter: root.controlDiameter
    readonly property real itemSpacing: 10
    // Keep equal insets around the utility stack.
    readonly property real listTopPadding: 30
    readonly property real listBottomPadding: 30
    readonly property real joinOverlap: 20

    readonly property var tools: [
        { key: "quickActions", icon: "󰀻", label: "Quick Actions" },
        { key: "clipboard", icon: "󰅌", label: "Clipboard" },
        { key: "tempNote", icon: "󰏫", label: "Temp Note" }
    ]
    readonly property real preferredBodyHeight: listTopPadding + tools.length * itemDiameter
        + (tools.length - 1) * itemSpacing + listBottomPadding

    signal pointerMoved(real x, real y)
    signal toolRequested(string key)

    // Morph animation:
    property real morphProgress: 0.0

    onExpandedChanged: {
        morphAnim.stop()
        if (expanded) {
            morphAnim.to = 1.0
            morphAnim.duration = HAnimation.sidebarOpenDuration
            morphAnim.easing.bezierCurve = HAnimation.sidebarOpenCurve
            morphAnim.start()
        } else {
            morphAnim.to = 0.0
            morphAnim.duration = HAnimation.sidebarCloseDuration
            morphAnim.easing.bezierCurve = HAnimation.sidebarCloseCurve
            morphAnim.start()
        }
    }

    NumberAnimation {
        id: morphAnim
        target: root
        property: "morphProgress"
    }

    // Height of the lobe grows dynamically with morphProgress:
    readonly property real currentHeight: bodyHeight * morphProgress

    visible: morphProgress > 0.001 || expanded

    // The Overlay owns only the rounded rail and its controls.
    Rectangle {
        x: 0
        y: root.bottomAttached ? root.bodyHeight - root.currentHeight : -root.joinOverlap
        width: root.bodyWidth
        height: root.currentHeight + root.joinOverlap
        color: root.surfaceColor
        topRightRadius: root.cornerRadius
        bottomRightRadius: root.cornerRadius
    }

    // Place the three utility controls inside the attached rail.
    Item {
        id: controlsGroup
        z: 1
        x: 0
        // Center the stack across the painted rail, including its attachment overlap.
        y: (root.bottomAttached ? 1 : -1) * root.joinOverlap / 2
        width: root.bodyWidth
        height: root.bodyHeight
        opacity: Math.max(0, Math.min(1, (root.morphProgress - 0.15) / 0.70))
        transform: Translate {
            y: (root.bottomAttached ? 24 : -24) * (1.0 - root.morphProgress)
        }
        visible: opacity > 0.001

        readonly property real controlX: Math.round((root.bodyWidth - root.controlDiameter) / 2)

        Repeater {
            model: root.tools

            delegate: Item {
                id: toolDelegate
                required property int index
                required property var modelData

                x: controlsGroup.controlX
                y: root.listTopPadding + index * (root.itemDiameter + root.itemSpacing)
                width: root.itemDiameter
                height: root.itemDiameter
                z: 20

                SidebarRailButton {
                    anchors.fill: parent
                    text: modelData.icon
                    tooltip: modelData.label
                    tooltipHost: root.tooltipHost
                    selected: root.keyboardSelected && root.selectedToolIndex === index
                    focused: root.keyboardSelected && root.selectedToolIndex === index
                    onClicked: root.toolRequested(modelData.key)
                }
            }
        }

    }

    // Keep background pointer tracking below buttons so their hover handlers receive motion.
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        onEntered: root.pointerMoved(mouseX, mouseY)
        onPositionChanged: mouse => root.pointerMoved(mouse.x, mouse.y)
    }
}
