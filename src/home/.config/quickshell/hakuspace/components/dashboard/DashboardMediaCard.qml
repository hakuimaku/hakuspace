import QtQuick
import QtQuick.Effects
import "../../services"

Rectangle {
    id: root

    radius: Theme.radius
    color: Theme.surface
    border.width: 1
    border.color: Qt.lighter(Theme.hoverMuted, 1.25)
    clip: true

    readonly property real artSize: Math.max(56, Math.min(76, root.height - 24))
    readonly property bool hasValidArt: Media.artUrl.length > 0 && artImage.status === Image.Ready

    Row {
        id: cardRow
        anchors.fill: parent
        anchors.margins: Math.max(10, Math.round(Theme.pad * 1.1))
        spacing: Math.max(10, Math.round(Theme.pad * 1.1))

        // Left: Fixed Artwork Slot
        Item {
            id: artBox
            width: root.artSize
            height: root.artSize
            anchors.verticalCenter: parent.verticalCenter

            Rectangle {
                id: artPlaceholder
                anchors.fill: parent
                radius: Theme.radiusSm
                color: Theme.hoverMuted
                visible: !root.hasValidArt

                Text {
                    anchors.centerIn: parent
                    text: ""
                    font.family: Theme.fontFamily
                    font.pixelSize: Math.round(artBox.width * 0.38)
                    color: Theme.fgDim
                }
            }

            Image {
                id: artImage
                anchors.fill: parent
                fillMode: Image.PreserveAspectCrop
                source: Media.artUrl
                sourceSize.width: Math.max(1, Math.round(artBox.width * 2))
                sourceSize.height: Math.max(1, Math.round(artBox.height * 2))
                visible: false
                layer.enabled: true
                asynchronous: true
            }

            Item {
                id: artMask
                anchors.fill: parent
                visible: false
                layer.enabled: true

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.radiusSm
                    color: "white"
                }
            }

            MultiEffect {
                id: artEffect
                anchors.fill: parent
                source: artImage
                visible: root.hasValidArt
                maskEnabled: true
                maskSource: artMask
                maskThresholdMin: 0.5
                maskSpreadAtMin: 0.025
            }
        }

        // Right: Metadata Column + Controls Row
        Column {
            id: contentCol
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - artBox.width - parent.spacing
            spacing: 2

            Text {
                id: titleText
                width: parent.width
                text: Media.available ? Media.title : "No media"
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                font.weight: Font.Bold
                color: Theme.fg
                elide: Text.ElideRight
            }

            Text {
                id: artistText
                width: parent.width
                text: Media.available ? (Media.artist ? Media.artist : (Media.album ? Media.album : "Unknown artist")) : "Idle"
                font.family: Theme.fontFamily
                font.pixelSize: Math.max(10, Theme.fontSize - 2)
                font.weight: Font.Normal
                color: Theme.fgDim
                elide: Text.ElideRight
            }

            Item {
                width: 1
                height: 2
                visible: Media.available
            }

            Row {
                id: controlsRow
                visible: Media.available
                spacing: 8
                anchors.left: parent.left

                Rectangle {
                    id: prevBtn
                    width: 28
                    height: 28
                    radius: 14
                    color: prevArea.containsMouse ? Theme.hoverMuted : "transparent"
                    opacity: (Media.available && Media.canGoPrevious) ? 1.0 : 0.0
                    enabled: Media.available && Media.canGoPrevious
                    Behavior on color { ColorAnimation { duration: HAnimation.fast } }

                    Text {
                        anchors.centerIn: parent
                        text: "󰒮"
                        font.family: Theme.fontFamily
                        font.pixelSize: 15
                        color: Theme.fg
                    }

                    MouseArea {
                        id: prevArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: parent.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        acceptedButtons: Qt.LeftButton
                        onClicked: Media.previous()
                    }
                }

                Rectangle {
                    id: playBtn
                    width: 32
                    height: 28
                    radius: 14
                    color: playArea.containsMouse ? Qt.lighter(Theme.hoverMuted, 1.25) : Theme.hoverMuted
                    opacity: (Media.available && Media.canTogglePlaying) ? 1.0 : 0.0
                    enabled: Media.available && Media.canTogglePlaying
                    Behavior on color { ColorAnimation { duration: HAnimation.fast } }

                    Text {
                        anchors.centerIn: parent
                        text: Media.playing ? "󰏤" : "󰐊"
                        font.family: Theme.fontFamily
                        font.pixelSize: 15
                        color: Theme.fg
                    }

                    MouseArea {
                        id: playArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: parent.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        acceptedButtons: Qt.LeftButton
                        onClicked: Media.togglePlaying()
                    }
                }

                Rectangle {
                    id: nextBtn
                    width: 28
                    height: 28
                    radius: 14
                    color: nextArea.containsMouse ? Theme.hoverMuted : "transparent"
                    opacity: (Media.available && Media.canGoNext) ? 1.0 : 0.0
                    enabled: Media.available && Media.canGoNext
                    Behavior on color { ColorAnimation { duration: HAnimation.fast } }

                    Text {
                        anchors.centerIn: parent
                        text: "󰒭"
                        font.family: Theme.fontFamily
                        font.pixelSize: 15
                        color: Theme.fg
                    }

                    MouseArea {
                        id: nextArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: parent.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        acceptedButtons: Qt.LeftButton
                        onClicked: Media.next()
                    }
                }
            }
        }
    }
}
