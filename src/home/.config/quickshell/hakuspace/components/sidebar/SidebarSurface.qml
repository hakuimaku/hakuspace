import QtQuick
import QtQuick.Shapes
import Quickshell.Widgets
import "../../services"

Item {
    id: root

    required property real controlDiameter
    required property real bodyWidth
    property real bodyHeight: 500
    property var pinsModel
    property Item tooltipHost: null
    property real rf: Math.max(Theme.hugRadius, AppState.roundedScreenRadius)
    property real frameThickness: FlareEdges.thickness
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
    readonly property real listTopPadding: 20
    // Leave room below Add for the control offset and hover scale.
    readonly property real listBottomPadding: 40

    readonly property var tools: [
        { key: "quickActions", icon: "󰀻", label: "Quick Actions" },
        { key: "clipboard", icon: "󰅌", label: "Clipboard" },
        { key: "tempNote", icon: "󰏫", label: "Temp Note" }
    ]
    readonly property int pinCount: pinsModel ? pinsModel.pins.length : 0
    readonly property int navigationCount: tools.length + pinCount + 1
    readonly property real primaryBottom: listTopPadding + tools.length * itemDiameter + (tools.length - 1) * itemSpacing
    readonly property real dividerY: primaryBottom + 24
    readonly property real addY: bodyHeight - listBottomPadding - itemDiameter
    readonly property real pinsTop: dividerY + 24
    readonly property real pinRowsHeight: pinCount > 0
        ? pinCount * (itemDiameter + 8) + (pinCount - 1) * 8 : 0
    readonly property real preferredBodyHeight: pinsTop + pinRowsHeight + 12
        + itemDiameter + listBottomPadding

    signal pointerMoved(real x, real y)
    signal toolRequested(string key)
    signal pinRequested(int index)
    signal unpinRequested(int index)

    function entryKind(index) { return index < tools.length ? "tool" : index < tools.length + pinCount ? "pin" : "add" }
    function entryKey(index) { return entryKind(index) === "tool" ? tools[index].key : entryKind(index) === "pin" ? String(index - tools.length) : "shortcutManager" }
    function activateIndex(index) {
        if (index < 0 || index >= navigationCount) return
        if (entryKind(index) === "pin") pinRequested(index - tools.length)
        else toolRequested(entryKey(index))
    }
    function revealIndex(index) {
        if (index >= tools.length && index < tools.length + pinCount)
            pinList.positionViewAtIndex(index - tools.length, ListView.Contain)
    }
    function pinTooltip(pin) {
        if (typeof pin.target === "string" && pin.target.length) return pin.target
        var command = pin.command || []
        for (var i = command.length - 1; i >= 0; i--) {
            var arg = command[i]
            if (typeof arg === "string" && (arg.indexOf("/") >= 0 || arg.startsWith("$") || arg.startsWith("~")))
                return arg
        }
        return pin.cwd || pin.label
    }

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

    // Clip wrapper so background body smoothly expands with morph progress
    Item {
        id: bodyClipper
        x: 0
        y: -20
        width: root.bodyWidth + root.earWidth + 4
        height: root.currentHeight + root.rf + 20
        clip: true

        // Top extension behind circular shell to guarantee zero hairline gap
        Rectangle {
            id: topExtension
            x: 0
            y: 0
            width: root.bodyWidth
            height: 22
            color: root.surfaceColor
        }

        // 1. Vertical lobe body attached flush to the left edge
        Rectangle {
            id: body
            x: 0
            y: 20
            width: root.bodyWidth
            height: root.currentHeight
            color: root.surfaceColor
            bottomRightRadius: root.cornerRadius
            bottomLeftRadius: 0
            topRightRadius: 0
            topLeftRadius: 0
        }

        // 2. Flare foot at bottom connecting smoothly into RoundedScreen border (indented by frameThickness)
        Rectangle {
            id: flareFootBacking
            x: 0
            y: flareFoot.y
            width: root.frameThickness
            height: root.rf
            color: root.surfaceColor
            visible: flareFoot.visible
            opacity: flareFoot.opacity
        }

        Shape {
            id: flareFoot
            x: root.frameThickness
            y: Math.max(20, 20 + root.currentHeight - 1)
            width: root.rf
            height: root.rf
            preferredRendererType: Shape.CurveRenderer
            visible: root.rf > 0 && root.morphProgress > 0.10
            opacity: Math.max(0, Math.min(1, (root.morphProgress - 0.10) / 0.90))

            ShapePath {
                fillColor: root.surfaceColor
                strokeColor: "transparent"
                PathSvg {
                    path: "M 0 0 L " + root.rf + " 0 A " + root.rf + " " + root.rf + " 0 0 0 0 " + root.rf + " Z"
                }
            }
        }

        // 3. Flare ear at top right wrapping smoothly into navigation layer
        Shape {
            id: topRightEar
            x: root.bodyWidth - 1
            y: 20 + root.topFlareY - 1
            width: root.earWidth + 1
            height: root.earRadius + 1
            preferredRendererType: Shape.CurveRenderer
            visible: root.morphProgress > 0.05
            opacity: Math.max(0, Math.min(1, (root.morphProgress - 0.05) / 0.65))

            ShapePath {
                fillColor: root.surfaceColor
                strokeColor: "transparent"
                PathSvg {
                    path: "M 0 0 L " + (root.earWidth + 1) + " 0 A " + (root.earWidth + 1) + " " + (root.earRadius + 1) + " 0 0 0 0 " + (root.earRadius + 1) + " Z"
                }
            }
        }
    }

    // Keep the controls fixed while the pin list takes the remaining height.
    Item {
        id: controlsGroup
        z: 1
        x: 0
        y: 20
        width: root.bodyWidth
        height: root.bodyHeight
        opacity: Math.max(0, Math.min(1, (root.morphProgress - 0.15) / 0.70))
        transform: Translate {
            y: -24 * (1.0 - root.morphProgress)
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

        Rectangle {
            x: Math.round(root.bodyWidth * 0.2)
            y: root.dividerY
            width: Math.round(root.bodyWidth * 0.6)
            height: 2
            radius: 1
            color: Theme.hoverMuted
        }

        ListView {
            id: pinList
            x: 0
            y: root.pinsTop
            width: root.bodyWidth
            height: Math.max(0, root.addY - root.pinsTop - 12)
            clip: true
            spacing: 8
            model: root.pinsModel ? root.pinsModel.pins : []
            delegate: Item {
                required property int index
                required property var modelData
                width: pinList.width
                height: root.itemDiameter + 8
                SidebarRailButton {
                    id: pinButton
                    anchors.centerIn: parent
                    width: root.itemDiameter
                    height: width
                    text: modelData.kind === "app" ? "" : (modelData.icon || "󰐃")
                    radius: Theme.largeRadius
                    tooltip: root.pinTooltip(modelData)
                    tooltipHost: root.tooltipHost
                    focused: root.keyboardSelected && root.selectedToolIndex === root.tools.length + index
                    onClicked: root.pinRequested(index)
                    TapHandler {
                        acceptedButtons: Qt.MiddleButton
                        onTapped: root.unpinRequested(index)
                    }
                    IconImage {
                        anchors.centerIn: parent
                        width: Math.round(pinButton.width * 0.55)
                        height: width
                        visible: modelData.kind === "app"
                        source: visible ? (modelData.icon.startsWith("/")
                            ? "file://" + modelData.icon : "image://icon/" + modelData.icon) : ""
                    }
                }
            }
        }

        SidebarRailButton {
            x: controlsGroup.controlX
            y: root.addY
            width: root.itemDiameter
            height: width
            text: "󰐕"
            tooltip: "Add Shortcut"
            tooltipHost: root.tooltipHost
            idleColor: "transparent"
            selected: root.keyboardSelected && root.selectedToolIndex === root.navigationCount - 1
            focused: root.keyboardSelected && root.selectedToolIndex === root.navigationCount - 1
            onClicked: root.toolRequested("shortcutManager")
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
