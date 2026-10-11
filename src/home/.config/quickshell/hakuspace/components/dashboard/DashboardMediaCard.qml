import QtQuick
import QtQuick.Effects
import "../../services"

Rectangle {
    id: root

    radius: Theme.radius
    color: Theme.surface
    border.width: 0
    border.color: Qt.lighter(Theme.hoverMuted, 1.25)
    clip: true

    readonly property real outerPadding: Math.max(10, Math.min(14, Math.round(Theme.pad * 1.1)))
    readonly property real artSize: Math.max(74, Math.min(88, root.height - outerPadding * 2))
    readonly property bool hasValidArt: Media.artUrl.length > 0 && artImage.status === Image.Ready

    property bool active: false
    property bool _cavaSubscribed: false

    function _updateCavaSubscription() {
        if (active && !_cavaSubscribed) {
            _cavaSubscribed = true
            Cava.acquireDashboard()
        } else if (!active && _cavaSubscribed) {
            _cavaSubscribed = false
            Cava.releaseDashboard()
        }
    }

    onActiveChanged: _updateCavaSubscription()
    Component.onCompleted: _updateCavaSubscription()
    Component.onDestruction: {
        if (_cavaSubscribed) {
            _cavaSubscribed = false
            Cava.releaseDashboard()
        }
    }

    // Subtle Cava audio waveform rendered behind media content
    DashboardCavaWave {
        anchors.fill: parent
        z: 1
    }

    // Left: Fixed Artwork Slot
    Item {
        id: artBox
        x: root.outerPadding
        width: root.artSize
        height: root.artSize
        anchors.verticalCenter: parent.verticalCenter
        z: 5

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

    // Right: Content area spanning the remaining width and card height
    Item {
        id: contentArea
        anchors.left: artBox.right
        anchors.leftMargin: Math.max(12, Math.round(Theme.pad * 1.2))
        anchors.right: parent.right
        anchors.rightMargin: root.outerPadding
        anchors.top: parent.top
        anchors.topMargin: root.outerPadding
        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.outerPadding
        z: 5

        // Upper metadata column
        Column {
            id: metaCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: Media.available ? parent.top : undefined
            anchors.verticalCenter: Media.available ? undefined : parent.verticalCenter
            spacing: 2

            Text {
                id: titleText
                width: parent.width
                text: Media.available ? Media.title : "No media"
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize + 1
                font.weight: Font.Bold
                color: Theme.fg
                elide: Text.ElideRight

                HoverHandler {
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    onHoveredChanged: {
                        if (hovered && Media.available) {
                            DashboardTooltip.show(titleText, Media.title + (Media.artist ? ("\n" + Media.artist) : ""))
                        } else {
                            DashboardTooltip.hide(titleText)
                        }
                    }
                }
            }

            Text {
                id: artistText
                width: parent.width
                text: Media.available ? (Media.artist ? Media.artist : (Media.album ? Media.album : "Unknown artist")) : "Idle"
                font.family: Theme.fontFamily
                font.pixelSize: Math.max(10, Theme.fontSize - 1)
                font.weight: Font.Normal
                color: Theme.fgDim
                elide: Text.ElideRight
            }
        }

        // Lower control row: centered in right content area
        Row {
            id: controlsRow
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 10
            visible: Media.available

            // Previous Button: 32x32
            Rectangle {
                id: prevBtn
                width: 32
                height: 32
                radius: 16
                anchors.verticalCenter: parent.verticalCenter
                color: prevArea.containsMouse ? Theme.hoverMuted : "transparent"
                opacity: (Media.available && Media.canGoPrevious) ? 1.0 : 0.35
                enabled: Media.available && Media.canGoPrevious
                Behavior on color { ColorAnimation { duration: HAnimation.fast } }

                Text {
                    anchors.centerIn: parent
                    text: "󰒮"
                    font.family: Theme.fontFamily
                    font.pixelSize: 17
                    color: parent.enabled ? Theme.fg : Theme.fgDim
                }

                MouseArea {
                    id: prevArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: parent.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    acceptedButtons: Qt.LeftButton
                    onEntered: if (parent.enabled) DashboardTooltip.show(prevBtn, "Previous track")
                    onExited: DashboardTooltip.hide(prevBtn)
                    onClicked: { DashboardTooltip.dismiss(); Media.previous() }
                }
            }

            // Play/Pause Button: 38x38 dominant control
            Rectangle {
                id: playBtn
                width: 38
                height: 38
                radius: 19
                anchors.verticalCenter: parent.verticalCenter
                color: playArea.containsMouse ? Qt.lighter(Theme.hoverMuted, 1.35) : Theme.hoverMuted
                opacity: (Media.available && Media.canTogglePlaying) ? 1.0 : 0.35
                enabled: Media.available && Media.canTogglePlaying
                Behavior on color { ColorAnimation { duration: HAnimation.fast } }

                Text {
                    anchors.centerIn: parent
                    text: Media.playing ? "󰏤" : "󰐊"
                    font.family: Theme.fontFamily
                    font.pixelSize: 19
                    color: parent.enabled ? Theme.fg : Theme.fgDim
                }

                MouseArea {
                    id: playArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: parent.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    acceptedButtons: Qt.LeftButton
                    onEntered: if (parent.enabled) DashboardTooltip.show(playBtn, Media.playing ? "Pause" : "Play")
                    onExited: DashboardTooltip.hide(playBtn)
                    onClicked: { DashboardTooltip.dismiss(); Media.togglePlaying() }
                }
            }

            // Next Button: 32x32
            Rectangle {
                id: nextBtn
                width: 32
                height: 32
                radius: 16
                anchors.verticalCenter: parent.verticalCenter
                color: nextArea.containsMouse ? Theme.hoverMuted : "transparent"
                opacity: (Media.available && Media.canGoNext) ? 1.0 : 0.35
                enabled: Media.available && Media.canGoNext
                Behavior on color { ColorAnimation { duration: HAnimation.fast } }

                Text {
                    anchors.centerIn: parent
                    text: "󰒭"
                    font.family: Theme.fontFamily
                    font.pixelSize: 17
                    color: parent.enabled ? Theme.fg : Theme.fgDim
                }

                MouseArea {
                    id: nextArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: parent.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    acceptedButtons: Qt.LeftButton
                    onEntered: if (parent.enabled) DashboardTooltip.show(nextBtn, "Next track")
                    onExited: DashboardTooltip.hide(nextBtn)
                    onClicked: { DashboardTooltip.dismiss(); Media.next() }
                }
            }
        }
    }
}
