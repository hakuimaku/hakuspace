import QtQuick
import "../../services"

QtObject {
    id: root

    property bool hovered: false
    property bool pressed: false
    property bool selected: false
    property bool focused: false
    property bool available: true

    // Visual geometry stays inside the control's existing layout bounds.
    property real hoverScaleDelta: 0.008
    property real pressScaleDelta: 0.030
    property real selectedScaleDelta: 0.0

    property real hoverProgress: root.hovered && root.available ? 1 : 0
    property real pressProgress: root.pressed && root.available ? 1 : 0
    property real selectProgress: root.selected ? 1 : 0
    property real focusProgress: root.focused && root.available ? 1 : 0

    readonly property real scale: 1
        + hoverProgress * hoverScaleDelta
        + selectProgress * selectedScaleDelta
        - pressProgress * pressScaleDelta

    Behavior on hoverProgress {
        NumberAnimation {
            duration: root.hovered ? HAnimation.buttonHoverDuration : HAnimation.buttonReleaseDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: root.hovered ? HAnimation.buttonHoverCurve : HAnimation.buttonReleaseCurve
        }
    }

    Behavior on pressProgress {
        NumberAnimation {
            duration: root.pressed ? HAnimation.buttonPressDuration : HAnimation.buttonReleaseDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: root.pressed ? HAnimation.buttonPressCurve : HAnimation.buttonReleaseCurve
        }
    }

    Behavior on selectProgress {
        NumberAnimation {
            duration: HAnimation.buttonSelectDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: HAnimation.buttonSelectCurve
        }
    }

    Behavior on focusProgress {
        NumberAnimation {
            duration: HAnimation.buttonFocusDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: HAnimation.buttonFocusCurve
        }
    }
}
