import QtQuick
import Quickshell
import Quickshell.Wayland
import "../services"
import "base"

Item {
    id: root
    // Preserve the Rectangle API while painting independently of the pointer wrapper.
    property alias color: chassis.color
    property alias radius: chassis.radius
    property alias border: chassis.border
    // Shared modules opt into Y hover explicitly; horizontal bars keep their original sizing.
    property string hoverAxis: "horizontal"
    readonly property bool verticalPresentation: hoverAxis === "vertical"
    property bool compactVisual: verticalPresentation
    property real hoverExpansion: compactVisual && hovered ? ScreenGeometry.leftModuleHoverExtent : 0
    readonly property real normalVisualHeight: compactVisual ? Math.max(ScreenGeometry.leftVisualSize, height - (ScreenGeometry.leftControlSlotHeight - ScreenGeometry.leftVisualSize)) : height
    readonly property real visualHeight: Math.min(height, normalVisualHeight + hoverExpansion * 2)
    readonly property Item visualItem: chassis
    readonly property Item interactionItem: hitRegion
    property string text: ""
    property string icon: ""
    property bool isAccent: false
    property bool hovered: false
    property bool muted: false
    property bool urgent: false
    property bool blink: false
    property string tooltip: ""
    property Component tooltipComponent: null
    property real iconFontSize: compactVisual ? ScreenGeometry.leftIconSize : Theme.fontSize
    property color foregroundColor: hovered ? Theme.onAccentColor
                                            : (urgent ? "#ff3333" : (isAccent ? Theme.accent : Theme.fg))
    property int borderWidth: 0
    property string borderColor: "transparent"
    property int blinkDuration: HAnimation.normal

    signal clicked()
    signal rightClicked()
    signal scrolled(int delta)

    // Activates tooltip display anchored to this top bar module.
    function requestTooltip() {
        if (root.tooltip === "" && !root.tooltipComponent) return;
        if (!tooltipObj.active) tooltipObj.active = true;
        else TooltipManager.show(hitRegion, root.tooltip, root.tooltipComponent);
    }

    color: hovered ? Theme.surfaceHi : Theme.surface
    
    radius: Theme.radius
    border.width: borderWidth
    border.color: borderColor
    
    implicitHeight: verticalPresentation ? ScreenGeometry.leftControlSlotHeight : Theme.fontSize * 1.8
    implicitWidth: verticalPresentation ? ScreenGeometry.leftModuleTouchSize : Math.max(implicitHeight, row.implicitWidth + Theme.pad * 2 + (hovered ? 20 : 0))
    readonly property real hoverSafeWidth: Math.max(implicitHeight, row.implicitWidth + Theme.pad * 2 + 20)
    onVisibleChanged: {
        if (!visible) {
            hovered = false
            tooltipObj.active = false
        }
    }

    // Hover fills the reserved slot instead of overpainting a clipped Flickable.
    Rectangle {
        id: chassis
        z: -1
        anchors.centerIn: parent
        width: root.compactVisual ? ScreenGeometry.leftVisualSize : root.width
        height: root.visualHeight
    }
    Behavior on hoverExpansion {
        NumberAnimation { duration: HAnimation.slow; easing.bezierCurve: HAnimation.moduleCurve }
    }
    // Repeatedly pulses module opacity when urgent alert blinking is enabled.
    SequentialAnimation on opacity {
        running: root.blink
        loops: Animation.Infinite
        NumberAnimation { to: 0.5; duration: root.blinkDuration; easing.type: Easing.InOutQuad }
        NumberAnimation { to: 1.0; duration: root.blinkDuration; easing.type: Easing.InOutQuad }
    }
    
    onBlinkChanged: {
        if (!blink) opacity = muted ? 0.5 : 1.0
    }
    onMutedChanged: {
        if (!blink) opacity = muted ? 0.5 : 1.0
    }
    Component.onCompleted: opacity = muted ? 0.5 : 1.0
    
    // Animates width expansion when label content or hover padding changes.
    Behavior on implicitWidth {
        NumberAnimation { duration: HAnimation.slow; easing.bezierCurve: HAnimation.moduleCurve }
    }
    // Animates module background color on hover enter and exit.
    Behavior on color {
        ColorAnimation { duration: HAnimation.slow; easing.bezierCurve: HAnimation.moduleCurve }
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: Theme.gap
        
        Text {
            id: iconLabel
            visible: root.icon !== ""
            text: root.icon
            font.family: Theme.fontFamily
            font.pixelSize: root.iconFontSize
            font.weight: Font.Bold
            color: root.foregroundColor
            Behavior on color { ColorAnimation { duration: HAnimation.slow } }
        }
        
        Text {
            id: textLabel
            visible: root.text !== ""
            text: root.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            font.weight: Font.Bold
            color: root.foregroundColor
            Behavior on color { ColorAnimation { duration: HAnimation.slow } }
        }
    }

    MouseArea {
        id: hitRegion
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onEntered: {
            root.hovered = true
            root.requestTooltip()
        }
        onExited: {
            root.hovered = false
            tooltipObj.active = false
        }
        onClicked: (mouse) => {
            if (mouse.button === Qt.LeftButton) root.clicked();
            else if (mouse.button === Qt.RightButton) root.rightClicked();
        }
        onWheel: (wheel) => {
            root.scrolled(wheel.angleDelta.y);
        }
    }
    
    HTooltip {
        id: tooltipObj
        target: hitRegion
        text: root.tooltip
        component: root.tooltipComponent
    }
}
