import QtQuick
import "../../services"

Item {
    id: root

    property bool open: false
    property real targetWidth: 350
    property real targetHeight: 250
    property real cornerRadius: Theme.largeRadius
    property color surfaceColor: Theme.surface
    property real contentPadding: 24
    property bool showHeader: true
    property string title: ""
    property string icon: ""
    property Component toolContent

    signal closeRequested()
    signal closed()
    signal pointerMoved(real x, real y)

    property real morphProgress: 0
    property real retainedWidth: 0
    property real retainedHeight: 0
    readonly property real activeProgress: morphProgress
    readonly property real widthFactor: Math.max(0, Math.min(1, (morphProgress - 0.15) / 0.60))
    readonly property real heightFactor: Math.max(0, Math.min(1, (morphProgress - 0.25) / 0.65))
    readonly property real contentFactor: Math.max(0, Math.min(1, (morphProgress - 0.55) / 0.45))
    readonly property real slideFactor: Math.max(0, Math.min(1, (morphProgress - 0.08) / 0.70))
    property real currentWidth: Math.round(targetWidth * widthFactor)
    property real currentHeight: Math.round(targetHeight * heightFactor)
    // Keep the target envelope until closing finishes, even while the shell shrinks.
    readonly property real interactionWidth: Math.max(targetWidth, retainedWidth, currentWidth)
    readonly property real interactionHeight: Math.max(targetHeight, retainedHeight, currentHeight)

    width: currentWidth
    height: currentHeight
    visible: open || morphProgress > 0.001

    Behavior on currentWidth {
        enabled: root.open && root.morphProgress > 0.99
        NumberAnimation { duration: HAnimation.sidebarToolOpenDuration; easing.bezierCurve: HAnimation.sidebarToolOpenCurve }
    }
    Behavior on currentHeight {
        enabled: root.open && root.morphProgress > 0.99
        NumberAnimation { duration: HAnimation.sidebarToolOpenDuration; easing.bezierCurve: HAnimation.sidebarToolOpenCurve }
    }

    // Forward focus to the loaded tool.
    function forceFocus() {
        if (contentLoader.item && typeof contentLoader.item.forceFocus === "function")
            contentLoader.item.forceFocus()
    }

    onTargetWidthChanged: { if (open) retainedWidth = Math.max(retainedWidth, targetWidth) }
    onTargetHeightChanged: { if (open) retainedHeight = Math.max(retainedHeight, targetHeight) }
    onOpenChanged: {
        morphAnim.stop()
        if (open) {
            retainedWidth = Math.max(retainedWidth, targetWidth)
            retainedHeight = Math.max(retainedHeight, targetHeight)
        }
        morphAnim.to = open ? 1 : 0
        morphAnim.duration = open ? HAnimation.sidebarToolOpenDuration : HAnimation.sidebarToolCloseDuration
        morphAnim.easing.bezierCurve = open ? HAnimation.sidebarToolOpenCurve : HAnimation.sidebarToolCloseCurve
        morphAnim.start()
    }
    onMorphProgressChanged: {
        if (open && morphProgress >= 0.96) forceFocus()
    }

    NumberAnimation {
        id: morphAnim
        target: root
        property: "morphProgress"
        onFinished: {
            if (!root.open && root.morphProgress <= 0.001) {
                root.retainedWidth = 0
                root.retainedHeight = 0
                root.closed()
            }
        }
    }

    Rectangle {
        x: -34 * (1 - root.slideFactor)
        width: root.currentWidth
        height: root.currentHeight
        radius: 6 + (root.cornerRadius - 6) * Math.max(0, Math.min(1, (root.morphProgress - 0.18) / 0.67))
        color: root.surfaceColor
        border.width: 3
        border.color: Theme.accent
        clip: true
        z: 2

        Item {
            anchors.fill: parent
            anchors.margins: root.contentPadding
            opacity: root.contentFactor
            visible: opacity > 0.001
            transform: Translate { x: 8 * (1 - root.contentFactor) }

            Item {
                id: header
                anchors { top: parent.top; left: parent.left; right: parent.right }
                height: 32
                visible: root.showHeader

                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6
                    Text {
                        text: root.icon
                        font.family: Theme.fontFamily
                        font.pixelSize: Math.max(13, Theme.fontSize)
                        color: Theme.accent
                    }
                    Text {
                        text: root.title
                        font.family: Theme.fontFamily
                        font.pixelSize: Math.max(12, Theme.fontSize - 1)
                        font.weight: Font.Bold
                        color: Theme.accent
                    }
                }

                SidebarMorphButton {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: 26
                    height: 26
                    radius: width / 2
                    text: "×"
                    fontSize: 16
                    onClicked: root.closeRequested()
                }
            }

            Loader {
                id: contentLoader
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                anchors.top: root.showHeader ? header.bottom : parent.top
                anchors.topMargin: root.showHeader ? 14 : 0
                sourceComponent: root.toolContent
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        onEntered: root.pointerMoved(mouseX, mouseY)
        onPositionChanged: mouse => root.pointerMoved(mouse.x, mouse.y)
    }
}
