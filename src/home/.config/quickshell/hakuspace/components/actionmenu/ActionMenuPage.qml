import QtQuick
import QtQuick.Layouts
import "../../services"
import "../motion" as Motion

Item {
    id: root

    property string title: ""
    property string subtitle: ""
    property string icon: ""
    property string geometryProfile: "option"
    property bool showHeader: true
    property bool canGoBack: false

    default property alias contentData: contentContainer.data

    signal requestBack()
    signal requestClose()
    signal scrollPrevious()
    signal scrollNext()

    property real _wheelAccumulator: 0
    property real _touchAccumulator: 0

    Timer {
        id: wheelDecayTimer
        interval: 180
        onTriggered: {
            root._wheelAccumulator = 0;
            root._touchAccumulator = 0;
        }
    }

    // Handles touchpad and mouse wheel scrolls with stepped accumulators.
    WheelHandler {
        id: pageWheelHandler
        target: root
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => {
            wheelDecayTimer.restart();

            var isTouchPad = event.device && (event.device.pointerType === PointerDevice.TouchPad
                             || (event.pixelDelta && (event.pixelDelta.x !== 0 || event.pixelDelta.y !== 0)));

            if (isTouchPad && event.pixelDelta && (event.pixelDelta.x !== 0 || event.pixelDelta.y !== 0)) {
                var pDelta = Math.abs(event.pixelDelta.y) >= Math.abs(event.pixelDelta.x)
                             ? event.pixelDelta.y
                             : event.pixelDelta.x;
                root._touchAccumulator += pDelta;
                var threshold = 40;
                if (Math.abs(root._touchAccumulator) >= threshold) {
                    var tSteps = Math.trunc(root._touchAccumulator / threshold);
                    root._touchAccumulator -= tSteps * threshold;
                    if (tSteps > 0) root.scrollPrevious();
                    else if (tSteps < 0) root.scrollNext();
                }
            } else {
                var aDelta = Math.abs(event.angleDelta.y) >= Math.abs(event.angleDelta.x)
                             ? event.angleDelta.y
                             : event.angleDelta.x;
                if (aDelta !== 0) {
                    root._wheelAccumulator += aDelta;
                    var notch = 120;
                    if (Math.abs(root._wheelAccumulator) >= notch) {
                        var wSteps = Math.trunc(root._wheelAccumulator / notch);
                        root._wheelAccumulator -= wSteps * notch;
                        if (wSteps > 0) root.scrollPrevious();
                        else if (wSteps < 0) root.scrollNext();
                    }
                }
            }
            event.accepted = true;
        }
    }

    // Default action handler executed on Return, Enter, or middle click (overridden by sub-pages).
    function activateCurrent() {}

    TapHandler {
        acceptedButtons: Qt.MiddleButton
        onTapped: root.activateCurrent()
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.panelPadding
        spacing: Theme.spaceLg

        // Optional standard header
        RowLayout {
            id: headerRow
            visible: root.showHeader
            Layout.fillWidth: true
            Layout.preferredHeight: Math.max(36, Theme.fontSize * 2.2)
            spacing: Theme.spaceMd

            // Back button if canGoBack
            Motion.MorphButton {
                id: backBtn
                visible: root.canGoBack
                Layout.preferredWidth: Math.max(34, Theme.fontSize * 2.2)
                Layout.preferredHeight: Layout.preferredWidth
                radius: Theme.radius
                text: ""
                idleColor: "transparent"
                hoverColor: "transparent"
                pressedColor: Theme.hoverMuted
                selectedColor: Theme.accent
                onClicked: root.requestBack()

                Text {
                    anchors.centerIn: parent
                    text: "󰁍"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize + 2
                    color: parent.hovered ? Theme.fg : Theme.fgMuted
                }
            }

            // Page icon
            Text {
                visible: !root.canGoBack && root.icon.length > 0
                text: root.icon
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize + 3
                color: Theme.accent
                verticalAlignment: Text.AlignVCenter
            }

            // Title & Subtitle
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    Layout.fillWidth: true
                    text: root.title
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize + 2
                    font.weight: Font.DemiBold
                    color: Theme.fg
                    elide: Text.ElideRight
                }

                Text {
                    Layout.fillWidth: true
                    visible: root.subtitle.length > 0
                    text: root.subtitle
                    font.family: Theme.fontFamily
                    font.pixelSize: Math.max(9, Theme.fontSize - 1)
                    color: Theme.fgDescription
                    elide: Text.ElideRight
                }
            }

            // Escape shortcut badge / hint
            Rectangle {
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: escText.implicitWidth + Theme.spaceLg
                implicitHeight: Math.max(24, Theme.fontSize * 1.6)
                radius: Theme.radius
                color: Theme.hoverMuted

                Text {
                    id: escText
                    anchors.centerIn: parent
                    text: root.canGoBack ? "Esc: Back" : "Esc: Close"
                    font.family: Theme.fontFamily
                    font.pixelSize: Math.max(9, Theme.fontSize - 3)
                    color: Theme.fgMuted
                }
            }
        }

        // Main content area
        Item {
            id: contentContainer
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
        }
    }
}
