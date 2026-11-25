import QtQuick
import QtQuick.Controls
import Quickshell
import "../../../services"
import "TaskManagerMotion.js" as Motion

ComboBox {
    id: root
    property int padX: Theme.spaceMd
    property bool reducedMotion: Quickshell.env("HAKUSPACE_REDUCED_MOTION") === "1"
    property alias unfurlProgress: dropdownPopup.unfurlProgress
    property bool popupOpen: false
    readonly property bool popupClosing: dropdownPopup.visible && !root.popupOpen
    property double _lastAboutToHideMs: 0
    property bool _wasOpenOnPress: false

    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSize - 1
    implicitHeight: Theme.controlHeight

    // Prevent default Qt palette from injecting light rectangles in dark mode.
    palette.button: Theme.surfaceSubtle(1.35)
    palette.buttonText: Theme.fg
    palette.base: Theme.surface
    palette.text: Theme.fg
    palette.window: Theme.surface
    palette.windowText: Theme.fg
    palette.highlight: "transparent"
    palette.highlightedText: Theme.accent

    function setUnfurlProgress(value) {
        dropdownPopup.unfurlProgress = Motion.clamp01(value)
    }

    HoverHandler {
        id: hoverHandler
        cursorShape: Qt.PointingHandCursor
    }

    // Toggle explicitly to avoid reopening a popup that just closed.
    MouseArea {
        id: toggleArea
        anchors.fill: parent
        z: 10
        acceptedButtons: Qt.LeftButton
        onPressed: {
            root.forceActiveFocus()
            root._wasOpenOnPress = root.popupOpen || (Date.now() - root._lastAboutToHideMs < 80)
            if (root.popupOpen) {
                root.popup.close()
            }
        }
        onClicked: {
            if (!root._wasOpenOnPress && !root.popupOpen) {
                root.popup.open()
            }
            root._wasOpenOnPress = false
        }
    }

    background: Rectangle {
        radius: height / 2
        border.width: 0
        color: toggleArea.pressed || root.down || root.popupOpen || root.activeFocus
            ? Theme.hoverMuted
            : (hoverHandler.hovered ? Theme.hoverMuted : Theme.surfaceSubtle(1.35))

        Behavior on color {
            enabled: !root.reducedMotion
            ColorAnimation { duration: HAnimation.fast }
        }

        Rectangle {
            objectName: "dropdownFocusRail"
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            width: (root.activeFocus || root.popupOpen) ? Math.min(20, parent.width * 0.35) : 0
            height: 2
            radius: 1
            border.width: 0
            color: Theme.accent
            Behavior on width {
                enabled: !root.reducedMotion
                NumberAnimation {
                    duration: HAnimation.taskBarFillDuration
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: HAnimation.moduleCurve
                }
            }
        }
    }

    contentItem: Label {
        leftPadding: root.padX
        rightPadding: root.padX + Theme.spaceMd
        text: root.displayText
        font: root.font
        color: Theme.accent
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }

    indicator: Label {
        x: root.width - width - root.padX + 2
        y: (root.height - height) / 2
        text: root.popupOpen ? "▴" : "▾"
        font.pixelSize: Theme.fontSize - 1
        color: root.popupOpen ? Theme.accent : Theme.fgMuted
    }

    delegate: ItemDelegate {
        id: optionItem
        required property var modelData
        required property int index
        readonly property bool isCurrent: root.currentIndex === index
        readonly property bool isHighlighted: root.highlightedIndex === index
        width: ListView.view ? ListView.view.width : root.width
        height: Theme.controlHeight
        padding: 0
        highlighted: isHighlighted

        HoverHandler { id: optionHover; cursorShape: Qt.PointingHandCursor }

        contentItem: Item {
            Row {
                anchors.fill: parent
                anchors.leftMargin: Theme.spaceMd
                anchors.rightMargin: Theme.spaceMd
                spacing: Theme.spaceSm

                Rectangle {
                    objectName: "dropdownActivePill_" + optionItem.index
                    anchors.verticalCenter: parent.verticalCenter
                    width: optionItem.isCurrent ? Math.max(1, Math.round(4 * root.unfurlProgress)) : 0
                    height: optionItem.isCurrent ? Math.max(2, Math.round(12 * root.unfurlProgress)) : 0
                    radius: 2
                    border.width: 0
                    color: Theme.accent
                    visible: optionItem.isCurrent && root.unfurlProgress > 0
                }

                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - (optionItem.isCurrent ? 14 : 0)
                    text: optionItem.modelData
                    font: root.font
                    color: optionItem.isCurrent ? Theme.accent : (optionItem.isHighlighted || optionHover.hovered ? Theme.fg : Theme.fgMuted)
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                }
            }
        }

        background: Rectangle {
            radius: Theme.radius
            border.width: 0
            color: (optionItem.isCurrent || optionItem.isHighlighted || optionHover.hovered)
                ? Theme.hoverMuted
                : "transparent"
        }
    }

    popup: Popup {
        id: dropdownPopup
        objectName: "taskDropdownPopup"
        property real unfurlProgress: 0.0
        readonly property int targetFullHeight: Math.max(Theme.controlHeight + Theme.spaceMd, dropdownList.implicitHeight + Theme.spaceMd)
        y: root.height + Theme.spaceXs
        width: Math.max(root.width, 120)
        height: Math.max(0, Math.round(targetFullHeight * dropdownPopup.unfurlProgress))
        implicitHeight: targetFullHeight
        padding: 0
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        enter: Transition {
            NumberAnimation {
                property: "unfurlProgress"
                to: 1.0
                duration: Motion.reversibleDuration(HAnimation.taskDropdownOpenDuration, dropdownPopup.unfurlProgress, 1.0, root.reducedMotion)
                easing.type: Easing.BezierSpline
                easing.bezierCurve: HAnimation.taskDropdownOpenCurve
            }
        }

        exit: Transition {
            NumberAnimation {
                property: "unfurlProgress"
                to: 0.0
                duration: Motion.reversibleDuration(HAnimation.taskDropdownCloseDuration, dropdownPopup.unfurlProgress, 0.0, root.reducedMotion)
                easing.type: Easing.BezierSpline
                easing.bezierCurve: HAnimation.taskDropdownCloseCurve
            }
        }

        onAboutToShow: {
            root.popupOpen = true
            if (root.reducedMotion) {
                dropdownPopup.unfurlProgress = 1.0
            }
        }
        onAboutToHide: {
            root.popupOpen = false
            root._lastAboutToHideMs = Date.now()
            if (root.reducedMotion) {
                dropdownPopup.unfurlProgress = 0.0
            }
        }
        onClosed: {
            root.popupOpen = false
            dropdownPopup.unfurlProgress = 0.0
        }

        contentItem: Item {
            objectName: "taskDropdownUnfurlViewport"
            clip: true

            ListView {
                id: dropdownList
                x: Theme.spaceSm
                y: Theme.spaceXs
                width: dropdownPopup.width - Theme.spaceMd
                height: implicitHeight
                clip: true
                spacing: 2
                implicitHeight: Math.min(180, contentHeight)
                model: dropdownPopup.visible ? root.delegateModel : null
                currentIndex: root.highlightedIndex
            }

            Rectangle {
                objectName: "taskDropdownUnfurlEdge"
                visible: dropdownPopup.unfurlProgress > 0 && dropdownPopup.unfurlProgress < 0.999
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 2
                border.width: 0
                color: Theme.accent
            }
        }

        background: Rectangle {
            radius: Theme.radius
            border.width: 0
            color: Theme.surfaceSubtle(1.6)
            clip: true
        }
    }
}
