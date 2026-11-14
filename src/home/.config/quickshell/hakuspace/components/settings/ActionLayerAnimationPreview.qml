import QtQuick
import QtQuick.Effects
import QtQuick.Window
import "../../services"

Rectangle {
    id: root
    objectName: "settings-action-layer-preview"

    property string style: "scale"
    property string phase: "closed"
    property real openProgress: 0.0
    property real openOpacity: 0.0
    property real openScale: 0.86
    property real openTranslateY: 0.0
    property real closeProgress: 0.0
    property real closeOpacity: 1.0
    property real closeScale: 1.0
    property real closeTranslateY: 0.0

    readonly property bool activeOnScreen: visible && Window.visibility !== Window.Hidden
    readonly property real transitionProgress: Math.max(0.0, Math.min(1.0, openProgress * (1.0 - closeProgress)))
    readonly property bool effectActive: (phase === "opening" || phase === "closing")
        && (style === "unfold" || style === "blur")
    readonly property real startScale: style === "scale" ? 0.84
        : (style === "unfold" || style === "blur") ? 0.94 : 1.0
    readonly property real startTranslateY: style === "scale" ? 12.0
        : style === "slide" ? -28.0 : 0.0
    readonly property string styleLabel: ({
        scale: "Scale",
        fade: "Fade",
        unfold: "Unfold",
        blur: "Blur",
        slide: "Slide"
    })[style] || "Scale"

    radius: Theme.radius
    color: Qt.tint(Theme.surface, Qt.alpha(Theme.overlayInk, 0.04))
    border.width: 1
    border.color: Theme.hoverMuted
    clip: true

    function resetAndStart() {
        loopAnim.stop()
        if (!activeOnScreen) {
            phase = "ready"
            openProgress = 1.0
            openOpacity = 1.0
            openScale = 1.0
            openTranslateY = 0.0
            closeProgress = 0.0
            closeOpacity = 1.0
            closeScale = 1.0
            closeTranslateY = 0.0
            return
        }
        loopAnim.start()
    }

    onStyleChanged: resetAndStart()
    onActiveOnScreenChanged: resetAndStart()
    Component.onCompleted: resetAndStart()

    // Subtle desktop background grid inside the miniature monitor.
    Item {
        anchors.fill: parent
        opacity: 0.04
        Repeater {
            model: 5
            Rectangle {
                required property int index
                y: (index + 1) * Math.round(root.height / 6)
                width: root.width
                height: 1
                color: Theme.fg
            }
        }
        Repeater {
            model: 7
            Rectangle {
                required property int index
                x: (index + 1) * Math.round(root.width / 8)
                width: 1
                height: root.height
                color: Theme.fg
            }
        }
    }

    // Miniature top status bar cue.
    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 6
        height: 8
        radius: 4
        color: Qt.alpha(Theme.fg, 0.08)

        Row {
            anchors.left: parent.left
            anchors.leftMargin: 5
            anchors.verticalCenter: parent.verticalCenter
            spacing: 3
            Repeater {
                model: 3
                Rectangle {
                    required property int index
                    width: index === 0 ? 8 : 4
                    height: 3
                    radius: 1.5
                    color: index === 0 ? Theme.accent : Qt.alpha(Theme.fg, 0.35)
                }
            }
        }
    }

    // Scrim backdrop synced to the miniature layer opacity.
    Rectangle {
        anchors.fill: parent
        color: Theme.surface
        opacity: 0.22 * root.openOpacity * root.closeOpacity
    }

    // Animated miniature Action Layer container.
    Item {
        id: miniLayerHost
        width: Math.round(root.width * 0.66)
        height: Math.round(root.height * 0.64)
        anchors.centerIn: parent
        anchors.verticalCenterOffset: 4
        scale: root.openScale * root.closeScale
        opacity: root.openOpacity * root.closeOpacity
        transform: Translate { y: root.openTranslateY + root.closeTranslateY }

        Rectangle {
            id: miniSurfaceRect
            anchors.fill: parent
            radius: Math.max(6, Math.round(Theme.largeRadius * 0.55))
            color: Theme.surface
            border.width: 1
            border.color: Qt.alpha(Theme.fg, 0.16)
            clip: true

            Column {
                anchors.fill: parent
                anchors.margins: 9
                spacing: 5

                Row {
                    spacing: 5
                    Rectangle {
                        width: 7
                        height: 7
                        radius: 3.5
                        anchors.verticalCenter: parent.verticalCenter
                        color: Theme.accent
                    }
                    Rectangle {
                        width: 44
                        height: 5
                        radius: 2.5
                        anchors.verticalCenter: parent.verticalCenter
                        color: Qt.alpha(Theme.fg, 0.75)
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 14
                    radius: Math.max(4, Math.round(Theme.radius * 0.45))
                    color: Qt.alpha(Theme.overlayInk, 0.07)
                }

                Rectangle {
                    width: parent.width
                    height: 14
                    radius: Math.max(4, Math.round(Theme.radius * 0.45))
                    color: Theme.accent

                    Rectangle {
                        anchors.left: parent.left
                        anchors.leftMargin: 6
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.round(parent.width * 0.52)
                        height: 4
                        radius: 2
                        color: Theme.onAccentColor
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 12
                    radius: Math.max(4, Math.round(Theme.radius * 0.45))
                    color: "transparent"

                    Rectangle {
                        anchors.left: parent.left
                        anchors.leftMargin: 6
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.round(parent.width * 0.42)
                        height: 4
                        radius: 2
                        color: Qt.alpha(Theme.fg, 0.4)
                    }
                }
            }
        }

        Item {
            id: previewMaskItem
            anchors.fill: parent
            visible: false
            layer.enabled: true

            Rectangle {
                id: previewMaskRect
                anchors.centerIn: parent
                readonly property real minW: Math.max(16, miniLayerHost.width * 0.24)
                readonly property real minH: Math.max(14, miniLayerHost.height * 0.16)
                width: Math.max(1, minW + (miniLayerHost.width - minW) * root.transitionProgress)
                height: Math.max(1, minH + (miniLayerHost.height - minH) * root.transitionProgress)
                radius: Math.min(width / 2, height / 2, miniSurfaceRect.radius)
                color: "white"
            }
        }

        ShaderEffectSource {
            id: previewCaptureSource
            anchors.fill: parent
            sourceItem: miniSurfaceRect
            hideSource: root.effectActive
            live: true
            visible: false
        }

        MultiEffect {
            anchors.fill: parent
            source: previewCaptureSource
            visible: root.effectActive
            maskEnabled: root.style === "unfold"
            maskSource: root.style === "unfold" ? previewMaskItem : null
            maskThresholdMin: 0.5
            maskSpreadAtMin: 0.03
            maskThresholdMax: 1.0
            maskSpreadAtMax: 0.0
            blurEnabled: root.style === "blur"
            blurMax: 24
            blur: root.style === "blur" ? Math.max(0.0, Math.min(1.0, 1.0 - root.transitionProgress)) : 0.0
            autoPaddingEnabled: root.style === "blur"
        }

        Rectangle {
            anchors.centerIn: parent
            width: previewMaskRect.width
            height: previewMaskRect.height
            radius: previewMaskRect.radius
            color: "transparent"
            border.width: 1
            border.color: Qt.alpha(Theme.fg, 0.16)
            visible: root.effectActive && root.style === "unfold"
        }
    }

    // Style badge in bottom-right corner.
    Rectangle {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 6
        height: 18
        width: badgeText.implicitWidth + 12
        radius: 9
        color: Qt.alpha(Theme.surface, 0.82)
        border.width: 1
        border.color: Qt.alpha(Theme.fg, 0.12)

        Text {
            id: badgeText
            anchors.centerIn: parent
            text: root.styleLabel
            color: Theme.fgDim
            font.family: Theme.fontFamily
            font.pixelSize: Math.max(9, Theme.fontSize - 4)
        }
    }

    SequentialAnimation {
        id: loopAnim
        loops: Animation.Infinite
        running: false

        ScriptAction {
            script: {
                root.phase = "opening"
                root.openProgress = 0.0
                root.openOpacity = 0.0
                root.openScale = root.startScale
                root.openTranslateY = root.startTranslateY
                root.closeProgress = 0.0
                root.closeOpacity = 1.0
                root.closeScale = 1.0
                root.closeTranslateY = 0.0
            }
        }

        ParallelAnimation {
            NumberAnimation {
                target: root
                property: "openProgress"
                from: 0.0
                to: 1.0
                duration: HAnimation.actionLayerEntranceDuration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: root.style === "unfold"
                    ? [0.22, 0.68, 0.22, 1.0, 1, 1]
                    : HAnimation.actionLayerOpenCurve
            }
            NumberAnimation {
                target: root
                property: "openOpacity"
                from: 0.0
                to: 1.0
                duration: root.style === "fade" || root.style === "blur"
                    ? HAnimation.actionLayerEntranceDuration
                    : root.style === "unfold"
                        ? Math.round(HAnimation.actionLayerEntranceDuration * 0.35)
                        : Math.round(HAnimation.actionLayerEntranceDuration * 0.72)
                easing.type: Easing.BezierSpline
                easing.bezierCurve: HAnimation.actionLayerContentCurve
            }
            NumberAnimation {
                target: root
                property: "openScale"
                from: root.startScale
                to: 1.0
                duration: HAnimation.actionLayerEntranceDuration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: root.style === "unfold"
                    ? [0.22, 0.68, 0.22, 1.0, 1, 1]
                    : HAnimation.actionLayerOpenCurve
            }
            NumberAnimation {
                target: root
                property: "openTranslateY"
                from: root.startTranslateY
                to: 0.0
                duration: HAnimation.actionLayerEntranceDuration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: HAnimation.actionLayerOpenCurve
            }
        }

        ScriptAction {
            script: {
                root.phase = "ready"
            }
        }

        PauseAnimation { duration: 760 }

        ScriptAction {
            script: {
                root.phase = "closing"
            }
        }

        ParallelAnimation {
            NumberAnimation {
                target: root
                property: "closeProgress"
                from: 0.0
                to: 1.0
                duration: root.style === "unfold" ? HAnimation.actionLayerEntranceDuration : HAnimation.actionLayerCloseDuration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: root.style === "unfold"
                    ? [0.35, 0.0, 0.25, 1.0, 1, 1]
                    : HAnimation.actionLayerCloseCurve
            }
            NumberAnimation {
                target: root
                property: "closeOpacity"
                from: 1.0
                to: 0.0
                duration: root.style === "unfold" ? HAnimation.actionLayerEntranceDuration : HAnimation.actionLayerCloseDuration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: root.style === "unfold"
                    ? [0.55, 0.0, 0.85, 0.35, 1, 1]
                    : HAnimation.actionLayerCloseCurve
            }
            NumberAnimation {
                target: root
                property: "closeScale"
                from: 1.0
                to: root.startScale
                duration: root.style === "unfold" ? HAnimation.actionLayerEntranceDuration : HAnimation.actionLayerCloseDuration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: root.style === "unfold"
                    ? [0.35, 0.0, 0.25, 1.0, 1, 1]
                    : HAnimation.actionLayerCloseCurve
            }
            NumberAnimation {
                target: root
                property: "closeTranslateY"
                from: 0.0
                to: root.startTranslateY
                duration: HAnimation.actionLayerCloseDuration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: HAnimation.actionLayerCloseCurve
            }
        }

        ScriptAction {
            script: {
                root.phase = "closed"
            }
        }

        PauseAnimation { duration: 240 }
    }
}
