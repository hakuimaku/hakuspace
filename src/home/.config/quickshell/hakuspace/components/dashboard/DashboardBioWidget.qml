import QtQuick
import "../../services"
import "../editor"

Item {
    id: root

    MarkdownEditor {
        id: editor
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: bottomBar.top
        anchors.bottomMargin: 8
        toolbarDensity: "comfortable"
        text: TextStore.bioDraft
        placeholderText: "Write your bio or notes in Markdown..."

        onTextEdited: newText => {
            TextStore.setBioDraft(newText)
        }

        onTextChangedByUser: newText => {
            TextStore.setBioDraft(newText)
        }

        onSaveRequested: {
            TextStore.saveBio()
        }
    }

    Item {
        id: bottomBar
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 32

        // Left: Save status indicator
        Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            Rectangle {
                width: 7
                height: 7
                radius: 3.5
                anchors.verticalCenter: parent.verticalCenter
                color: TextStore.bioSaving ? Theme.accent
                                           : (TextStore.bioError.length > 0 ? "#ff5555"
                                           : (TextStore.bioDirty ? "#e5c07b" : "#98c379"))
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: TextStore.bioSaving ? "Saving…"
                                          : (TextStore.bioError.length > 0 ? "Save failed"
                                          : (TextStore.bioDirty ? "Unsaved changes" : "Saved"))
                font.family: Theme.fontFamily
                font.pixelSize: Math.max(11, Theme.fontSize - 2)
                color: Theme.fgDim
            }
        }

        // Right: Polished Save button (~72x30px)
        Item {
            id: saveButtonHost
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 72
            height: 30

            property bool tooltipShown: false

            Timer {
                id: saveTooltipTimer
                interval: 350
                onTriggered: {
                    if (saveMouseArea.containsMouse) {
                        saveButtonHost.tooltipShown = true
                    }
                }
            }

            Rectangle {
                id: saveButton
                anchors.fill: parent
                radius: 6
                readonly property bool canSave: TextStore.bioDirty && !TextStore.bioSaving
                color: canSave ? (saveMouseArea.pressed
                                  ? Qt.darker(Theme.accent, 1.10)
                                  : (saveMouseArea.containsMouse ? Qt.lighter(Theme.accent, 1.15) : Theme.accent))
                               : Theme.hoverMuted
                opacity: canSave ? 1.0 : 0.45
                scale: saveMouseArea.pressed && canSave ? 0.95 : 1.0

                Behavior on color { ColorAnimation { duration: HAnimation.buttonHoverDuration } }
                Behavior on scale {
                    NumberAnimation {
                        duration: saveMouseArea.pressed ? HAnimation.buttonPressDuration : HAnimation.buttonReleaseDuration
                        easing.bezierCurve: saveMouseArea.pressed ? HAnimation.buttonPressCurve : HAnimation.buttonReleaseCurve
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: TextStore.bioSaving ? "Saving…"
                                              : (TextStore.bioDirty ? "Save" : "Saved")
                    font.family: Theme.fontFamily
                    font.pixelSize: Math.max(12, Theme.fontSize - 1)
                    font.weight: Font.Bold
                    color: saveButton.canSave ? Theme.onAccentColor : Theme.fgDim
                }

                MouseArea {
                    id: saveMouseArea
                    anchors.fill: parent
                    enabled: saveButton.canSave
                    hoverEnabled: true
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    acceptedButtons: Qt.LeftButton
                    onEntered: saveTooltipTimer.restart()
                    onExited: {
                        saveTooltipTimer.stop()
                        saveButtonHost.tooltipShown = false
                    }
                    onClicked: TextStore.saveBio()
                }
            }

            // Save Tooltip bubble
            Rectangle {
                id: saveTooltip
                visible: saveButtonHost.tooltipShown && opacity > 0.01
                opacity: saveButtonHost.tooltipShown ? 1.0 : 0.0
                anchors.bottom: parent.top
                anchors.bottomMargin: 6
                anchors.right: parent.right
                width: saveTooltipText.implicitWidth + 14
                height: saveTooltipText.implicitHeight + 8
                radius: Theme.radiusSm
                color: Theme.surface
                border.width: 1
                border.color: Qt.lighter(Theme.hoverMuted, 1.45)
                z: 200

                Behavior on opacity {
                    NumberAnimation {
                        duration: 160
                        easing.bezierCurve: HAnimation.tooltipCurve
                    }
                }

                Text {
                    id: saveTooltipText
                    anchors.centerIn: parent
                    text: "Save bio (Ctrl+S)"
                    font.family: Theme.fontFamily
                    font.pixelSize: Math.max(10, Theme.fontSize - 3)
                    font.weight: Font.Medium
                    color: Theme.fg
                }
            }
        }
    }
}
