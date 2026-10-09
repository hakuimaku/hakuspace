import QtQuick
import "../../services"

Rectangle {
    id: root

    property string text: ""
    property bool selected: false
    property bool focused: false
    property bool interactive: true
    property bool externalHovered: false
    property bool externalPressed: false
    property bool selectedOverridesHover: false

    property color idleColor: Theme.surface
    property color hoverColor: Theme.surfaceHi
    property color pressedColor: Theme.surfaceHi
    property color selectedColor: Theme.accent
    property color focusColor: hoverColor
    property color disabledColor: idleColor

    property color foregroundColor: Theme.fg
    property color hoverForegroundColor: Theme.onAccentColor
    property color pressedForegroundColor: hoverForegroundColor
    property color selectedForegroundColor: Theme.onAccentColor
    property color focusForegroundColor: foregroundColor
    property color disabledForegroundColor: Theme.fgMuted

    property real hoverScaleDelta: 0.008
    property real pressScaleDelta: 0.030
    property real selectedScaleDelta: 0.0
    // Optional horizontal-only expansion.  The default path keeps the legacy
    // transform behavior.  `expandedVisual` draws a dedicated centered
    // background shell so the expansion is unmistakable without changing the
    // control's allocated layout width or hitbox.
    property real hoverXScaleDelta: 0.0
    property real pressXScaleDelta: 0.0
    property bool expandedVisual: false
    property real hoverFadeAmount: 0.0
    readonly property real horizontalScale: 1
        + motion.hoverProgress * hoverXScaleDelta
        - motion.pressProgress * pressXScaleDelta
    property real disabledOpacity: 0.45

    readonly property bool hovered: interactive ? hitArea.containsMouse : externalHovered
    readonly property bool pressed: interactive ? hitArea.pressed : externalPressed
    readonly property bool selectedWins: selected && selectedOverridesHover
    readonly property color targetBackground: !enabled ? disabledColor
        : pressed ? pressedColor
        : selectedWins ? selectedColor
        : hovered ? hoverColor
        : focused ? focusColor
        : selected ? selectedColor
        : idleColor
    readonly property color targetForeground: !enabled ? disabledForegroundColor
        : pressed ? pressedForegroundColor
        : selectedWins ? selectedForegroundColor
        : hovered ? hoverForegroundColor
        : focused ? focusForegroundColor
        : selected ? selectedForegroundColor
        : foregroundColor
    readonly property int transitionDuration: pressed ? HAnimation.buttonPressDuration
        : (selectedWins || selected) ? HAnimation.buttonSelectDuration
        : focused ? HAnimation.buttonFocusDuration
        : hovered ? HAnimation.buttonHoverDuration
        : HAnimation.buttonReleaseDuration
    readonly property var transitionCurve: pressed ? HAnimation.buttonPressCurve
        : (selectedWins || selected) ? HAnimation.buttonSelectCurve
        : focused ? HAnimation.buttonFocusCurve
        : hovered ? HAnimation.buttonHoverCurve
        : HAnimation.buttonReleaseCurve

    property color animatedForeground: targetForeground
    readonly property color foreground: animatedForeground

    signal clicked()

    color: expandedVisual ? "transparent" : targetBackground
    opacity: enabled ? 1 : disabledOpacity
    scale: motion.scale
    transformOrigin: Item.Center
    transform: Scale {
        origin.x: root.width / 2
        origin.y: root.height / 2
        xScale: root.expandedVisual ? 1 : root.horizontalScale
        yScale: 1
    }

    Rectangle {
        id: expandedBackground
        visible: root.expandedVisual
        z: 0
        anchors.centerIn: parent
        width: root.width * root.horizontalScale
        height: root.height
        radius: root.radius
        color: root.targetBackground
        opacity: Math.max(0, Math.min(1,
            1 - root.hoverFadeAmount + motion.hoverProgress * root.hoverFadeAmount))

        Behavior on color {
            ColorAnimation {
                duration: root.transitionDuration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: root.transitionCurve
            }
        }
    }

    Behavior on color {
        ColorAnimation {
            duration: root.transitionDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: root.transitionCurve
        }
    }

    Behavior on animatedForeground {
        ColorAnimation {
            duration: root.transitionDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: root.transitionCurve
        }
    }

    Behavior on opacity {
        NumberAnimation {
            duration: HAnimation.buttonReleaseDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: HAnimation.buttonReleaseCurve
        }
    }

    ButtonMotion {
        id: motion
        hovered: root.hovered
        pressed: root.pressed
        selected: root.selected
        focused: root.focused
        available: root.enabled
        hoverScaleDelta: root.hoverScaleDelta
        pressScaleDelta: root.pressScaleDelta
        selectedScaleDelta: root.selectedScaleDelta
    }

    Text {
        id: label
        z: 1
        anchors.centerIn: parent
        visible: root.text.length > 0
        text: root.text
        color: root.foreground
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
    }

    MouseArea {
        id: hitArea
        z: 1000
        anchors.fill: parent
        enabled: root.interactive && root.enabled
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
