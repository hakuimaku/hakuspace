import QtQuick
import QtQuick.Shapes
import "../../services"
import "../editor"

Item {
    id: root

    property bool open: false
    property real targetWidth: 350
    property real targetHeight: 250
    property real bridgeWidth: 8
    property real bridgeHeight: 36
    property real cornerRadius: Theme.radiusSm + 4
    property color surfaceColor: Theme.barColor

    signal closeRequested()
    signal closed()
    signal pointerMoved(real x, real y)

    function forceFocus() {
        if (editor) {
            editor.forceEditorFocus()
        }
    }

    onMorphProgressChanged: {
        if (morphProgress >= 0.96 && open) {
            forceFocus()
        }
    }

    // Morph animation progress (0.0 -> 1.0)
    property real morphProgress: 0.0
    readonly property real activeProgress: morphProgress

    onOpenChanged: {
        morphAnim.stop()
        if (open) {
            morphAnim.to = 1.0
            morphAnim.duration = HAnimation.sidebarToolOpenDuration
            morphAnim.easing.bezierCurve = HAnimation.sidebarToolOpenCurve
            morphAnim.start()
        } else {
            morphAnim.to = 0.0
            morphAnim.duration = HAnimation.sidebarToolCloseDuration
            morphAnim.easing.bezierCurve = HAnimation.sidebarToolCloseCurve
            morphAnim.start()
        }
    }

    NumberAnimation {
        id: morphAnim
        target: root
        property: "morphProgress"
        onFinished: {
            if (!root.open && root.morphProgress <= 0.001) {
                root.closed()
            }
        }
    }

    visible: open || morphProgress > 0.001

    // Staged progress drivers:
    // 0.00–0.25 establish attachment / ear / bridge
    // 0.15–0.75 expand width
    // 0.25–0.90 expand height / settle radius
    // 0.65–1.00 reveal content
    readonly property real bridgeFactor: Math.max(0, Math.min(1, morphProgress / 0.25))
    readonly property real widthFactor: Math.max(0, Math.min(1, (morphProgress - 0.15) / 0.60))
    readonly property real heightFactor: Math.max(0, Math.min(1, (morphProgress - 0.25) / 0.65))
    readonly property real contentFactor: Math.max(0, Math.min(1, (morphProgress - 0.65) / 0.35))

    // Envelope geometry:
    readonly property real currentWidth: Math.round(targetWidth * widthFactor)
    readonly property real currentHeight: Math.max(Math.round(bridgeHeight * bridgeFactor), Math.round(targetHeight * heightFactor))
    readonly property real currentBridgeWidth: Math.round(bridgeWidth * bridgeFactor)

    width: currentBridgeWidth + currentWidth
    height: Math.max(bridgeHeight, currentHeight)

    // 1. Flare bridge connecting rail to panel shell
    Rectangle {
        id: bridgeBody
        x: 0
        y: 12
        width: root.currentBridgeWidth + 2
        height: root.bridgeHeight
        color: root.surfaceColor
        visible: root.bridgeFactor > 0.01
        opacity: root.bridgeFactor
        z: 1
    }

    // Top flare ear connecting rail and bridge
    Shape {
        id: topBridgeEar
        x: 0
        y: bridgeBody.y - 12
        width: root.currentBridgeWidth + 1
        height: 12
        preferredRendererType: Shape.CurveRenderer
        visible: root.bridgeFactor > 0.10
        opacity: Math.max(0, Math.min(1, (root.bridgeFactor - 0.10) / 0.90))
        z: 1

        ShapePath {
            fillColor: root.surfaceColor
            strokeColor: "transparent"
            PathSvg {
                path: "M 0 " + topBridgeEar.height + " L " + topBridgeEar.width + " " + topBridgeEar.height + " A " + topBridgeEar.width + " " + topBridgeEar.height + " 0 0 1 0 0 Z"
            }
        }
    }

    // Bottom flare ear connecting rail and bridge
    Shape {
        id: bottomBridgeEar
        x: 0
        y: bridgeBody.y + bridgeBody.height
        width: root.currentBridgeWidth + 1
        height: 12
        preferredRendererType: Shape.CurveRenderer
        visible: root.bridgeFactor > 0.10
        opacity: Math.max(0, Math.min(1, (root.bridgeFactor - 0.10) / 0.90))
        z: 1

        ShapePath {
            fillColor: root.surfaceColor
            strokeColor: "transparent"
            PathSvg {
                path: "M 0 0 L " + bottomBridgeEar.width + " 0 A " + bottomBridgeEar.width + " " + bottomBridgeEar.height + " 0 0 0 0 " + bottomBridgeEar.height + " Z"
            }
        }
    }

    // 2. Main panel shell body
    Rectangle {
        id: shellBody
        x: root.currentBridgeWidth
        y: 0
        width: root.currentWidth
        height: root.currentHeight
        radius: root.cornerRadius
        color: root.surfaceColor
        border.width: 2
        border.color: Theme.accent
        clip: true
        z: 2

        // Staged content container (delayed reveal with 4px inner padding)
        Item {
            id: contentContainer
            anchors.fill: parent
            anchors.margins: 4
            opacity: root.contentFactor
            visible: opacity > 0.001
            transform: Translate {
                x: 8 * (1.0 - root.contentFactor)
            }

            // Header
            Item {
                id: header
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: 32
                anchors.topMargin: 4
                anchors.leftMargin: 10
                anchors.rightMargin: 10

                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    Text {
                        text: "󰏫"
                        font.family: Theme.fontFamily
                        font.pixelSize: Math.max(13, Theme.fontSize)
                        color: Theme.accent
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: "Temp Note"
                        font.family: Theme.fontFamily
                        font.pixelSize: Math.max(12, Theme.fontSize - 1)
                        font.weight: Font.Bold
                        color: Theme.fg
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Rectangle {
                        width: 5
                        height: 5
                        radius: 2.5
                        anchors.verticalCenter: parent.verticalCenter
                        color: TextStore.scratchSaving ? Theme.accent
                                                       : (TextStore.scratchError.length > 0 ? "#ff5555"
                                                       : (TextStore.scratchDirty ? "#e5c07b" : "#98c379"))
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: TextStore.scratchSaving ? "Saving…"
                                                      : (TextStore.scratchError.length > 0 ? "Error"
                                                      : (TextStore.scratchDirty ? "Unsaved" : "Saved"))
                        font.family: Theme.fontFamily
                        font.pixelSize: Math.max(9, Theme.fontSize - 4)
                        color: Theme.fgDim
                    }
                }

                // Close button (×)
                Rectangle {
                    id: closeBtn
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: 22
                    height: 22
                    radius: 11
                    color: closeMouseArea.containsMouse ? Theme.hoverMuted : "transparent"

                    Behavior on color { ColorAnimation { duration: HAnimation.buttonHoverDuration } }

                    Text {
                        anchors.centerIn: parent
                        text: "×"
                        font.family: Theme.fontFamily
                        font.pixelSize: 15
                        font.weight: Font.Bold
                        color: closeMouseArea.containsMouse ? Theme.fg : Theme.fgDim
                    }

                    MouseArea {
                        id: closeMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton
                        onClicked: root.closeRequested()
                    }
                }
            }

            Rectangle {
                id: headerDivider
                anchors.top: header.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                height: 1
                color: Qt.lighter(Theme.hoverMuted, 1.25)
            }

            // Real editor body (compact toolbar)
            MarkdownEditor {
                id: editor
                anchors.top: headerDivider.bottom
                anchors.topMargin: 4
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: 6
                toolbarDensity: "compact"
                text: TextStore.scratchDraft
                placeholderText: "Quick temporary note (autosaved)..."

                onTextEdited: newText => {
                    TextStore.setScratchDraft(newText)
                }

                onTextChangedByUser: newText => {
                    TextStore.setScratchDraft(newText)
                }

                onEscapeRequested: {
                    root.closeRequested()
                }

                onSaveRequested: {
                    TextStore.flushScratch()
                }
            }
        }
    }

    // Pointer ownership tracking across the bridge and shell
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        onEntered: root.pointerMoved(mouseX, mouseY)
        onPositionChanged: mouse => root.pointerMoved(mouse.x, mouse.y)
    }
}
