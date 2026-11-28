import QtQuick
import QtQuick.Effects
import Quickshell
import "../../services"

Rectangle {
    id: root

    radius: Theme.largeRadius
    color: Theme.surfaceSubtle(1.6)
    border.width: 0
    clip: true

    readonly property bool reducedMotion: Quickshell.env("HAKUSPACE_REDUCED_MOTION") === "1"
    readonly property real outerPadding: Math.max(12, Math.min(16, Math.round(Theme.pad * 1.1)))
    readonly property real artSize: Math.max(84, Math.min(116, root.height - outerPadding * 2))
    readonly property bool hasValidArt: Media.artUrl.length > 0 && artImage.status === Image.Ready

    property bool active: false
    property bool _cavaSubscribed: false
    property bool _positionSubscribed: false
    property bool _seeking: false
    property real _seekPreviewSeconds: 0

    function formatTime(sec) {
        var s = Math.max(0, Math.floor(Number.isFinite(sec) ? sec : 0))
        var m = Math.floor(s / 60)
        var rem = s % 60
        return (m < 10 ? "0" + m : String(m)) + ":" + (rem < 10 ? "0" + rem : String(rem))
    }

    // Synchronizes Cava audio visualizer and position polling with active card visibility.
    function _updateSubscriptions() {
        if (active && !_cavaSubscribed) {
            _cavaSubscribed = true
            Cava.acquireDashboard()
        } else if (!active && _cavaSubscribed) {
            _cavaSubscribed = false
            Cava.releaseDashboard()
        }

        if (active && !_positionSubscribed) {
            _positionSubscribed = true
            Media.acquirePosition()
        } else if (!active && _positionSubscribed) {
            _positionSubscribed = false
            Media.releasePosition()
        }
    }

    onActiveChanged: _updateSubscriptions()
    Component.onCompleted: _updateSubscriptions()
    Component.onDestruction: {
        if (_cavaSubscribed) {
            _cavaSubscribed = false
            Cava.releaseDashboard()
        }
        if (_positionSubscribed) {
            _positionSubscribed = false
            Media.releasePosition()
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
            radius: Theme.radius
            color: Theme.surfaceSubtle(1.25)
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
            cache: false
        }

        Item {
            id: artMask
            anchors.fill: parent
            visible: false
            layer.enabled: true

            Rectangle {
                anchors.fill: parent
                radius: Theme.radius
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
        anchors.leftMargin: Math.max(14, Math.round(Theme.pad * 1.2))
        anchors.right: parent.right
        anchors.rightMargin: root.outerPadding
        anchors.top: parent.top
        anchors.topMargin: root.outerPadding
        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.outerPadding
        z: 5

        // Upper metadata + optional player switcher pill
        Item {
            id: metaHeader
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: Media.available ? parent.top : undefined
            anchors.verticalCenter: Media.available ? undefined : parent.verticalCenter
            height: titleRow.height + 2 + artistText.implicitHeight

            Item {
                id: titleRow
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                height: Math.max(titleText.implicitHeight, playerPill.visible ? playerPill.height : 0)

                Text {
                    id: titleText
                    anchors.left: parent.left
                    anchors.right: playerPill.visible ? playerPill.left : parent.right
                    anchors.rightMargin: playerPill.visible ? 8 : 0
                    anchors.verticalCenter: parent.verticalCenter
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

                Rectangle {
                    id: playerPill
                    visible: Media.available && Media.availablePlayers.length > 1
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(104, playerPillText.implicitWidth + 14)
                    height: 24
                    radius: Theme.radius
                    color: Theme.surfaceSubtle(1.25)
                    scale: (playerPillMouse.containsMouse && !root.reducedMotion) ? 1.05 : 1.0

                    Behavior on scale {
                        enabled: !root.reducedMotion
                        NumberAnimation {
                            duration: playerPillMouse.containsMouse ? HAnimation.buttonHoverDuration : HAnimation.buttonReleaseDuration
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: playerPillMouse.containsMouse ? HAnimation.buttonHoverCurve : HAnimation.buttonReleaseCurve
                        }
                    }

                    Text {
                        id: playerPillText
                        anchors.centerIn: parent
                        width: Math.max(0, parent.width - 10)
                        horizontalAlignment: Text.AlignHCenter
                        text: (Media.selected && Media.selected.identity) ? Media.selected.identity : "Player"
                        font.family: Theme.fontFamily
                        font.pixelSize: Math.max(10, Theme.fontSize - 2)
                        font.weight: Font.Medium
                        color: Theme.fgDim
                        elide: Text.ElideRight
                    }

                    MouseArea {
                        id: playerPillMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton
                        onEntered: DashboardTooltip.show(playerPill, "Switch player (" + Media.availablePlayers.length + ")")
                        onExited: DashboardTooltip.hide(playerPill)
                        onClicked: {
                            DashboardTooltip.dismiss()
                            Media.cyclePlayer(1)
                        }
                    }
                }
            }

            Text {
                id: artistText
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: titleRow.bottom
                anchors.topMargin: 2
                text: Media.available ? (Media.artist ? Media.artist : (Media.album ? Media.album : "Unknown artist")) : "Idle"
                font.family: Theme.fontFamily
                font.pixelSize: Math.max(11, Theme.fontSize - 1)
                font.weight: Font.Normal
                color: Theme.fgDim
                elide: Text.ElideRight
            }
        }

        // Seek bar + compact MM:SS / MM:SS timestamp
        Item {
            id: seekRow
            visible: Media.available && Media.length > 0
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: controlsRow.top
            anchors.bottomMargin: 6
            height: 18

            readonly property real shownPosition: root._seeking ? root._seekPreviewSeconds : Media.position
            readonly property real ratio: Media.length > 0 ? Math.max(0, Math.min(1, shownPosition / Media.length)) : 0

            Item {
                id: seekHit
                anchors.left: parent.left
                anchors.right: timeLabel.left
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                height: 14

                Rectangle {
                    id: seekTrack
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    height: (seekMouse.containsMouse || root._seeking) && Media.canSeek ? 5 : 3
                    radius: height / 2
                    color: Theme.surfaceSubtle(1.25)

                    Behavior on height {
                        enabled: !root.reducedMotion
                        NumberAnimation { duration: HAnimation.fast }
                    }

                    Rectangle {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: Math.round(parent.width * seekRow.ratio)
                        radius: parent.radius
                        color: Theme.accent
                    }
                }

                MouseArea {
                    id: seekMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: Media.canSeek
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    acceptedButtons: Qt.LeftButton

                    function targetSec(mx) {
                        var t = Math.max(0, Math.min(1, mx / Math.max(1, width)))
                        return t * Media.length
                    }

                    onPressed: mouse => {
                        root._seeking = true
                        root._seekPreviewSeconds = targetSec(mouse.x)
                    }
                    onPositionChanged: mouse => {
                        if (root._seeking) {
                            root._seekPreviewSeconds = targetSec(mouse.x)
                        }
                    }
                    onReleased: mouse => {
                        var sec = targetSec(mouse.x)
                        root._seeking = false
                        Media.seekTo(sec)
                    }
                    onCanceled: root._seeking = false
                }
            }

            Text {
                id: timeLabel
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: root.formatTime(seekRow.shownPosition) + " / " + root.formatTime(Media.length)
                font.family: Theme.fontFamily
                font.pixelSize: Math.max(10, Theme.fontSize - 2)
                color: Theme.fgDim
            }
        }

        // Lower control row: centered in right content area
        Row {
            id: controlsRow
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 2
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 12
            visible: Media.available

            // Previous Button: 36x36
            Rectangle {
                id: prevBtn
                width: 36
                height: 36
                radius: 18
                anchors.verticalCenter: parent.verticalCenter
                color: "transparent"
                opacity: (Media.available && Media.canGoPrevious) ? 1.0 : 0.35
                enabled: Media.available && Media.canGoPrevious
                scale: (prevArea.containsMouse && enabled && !root.reducedMotion) ? 1.05 : 1.0

                Behavior on scale {
                    enabled: !root.reducedMotion
                    NumberAnimation {
                        duration: prevArea.containsMouse ? HAnimation.buttonHoverDuration : HAnimation.buttonReleaseDuration
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: prevArea.containsMouse ? HAnimation.buttonHoverCurve : HAnimation.buttonReleaseCurve
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: "󰒮"
                    font.family: Theme.iconFontFamily
                    font.pixelSize: 20
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

            // Play/Pause Button: 44x44 dominant control
            Rectangle {
                id: playBtn
                width: 44
                height: 44
                radius: 22
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.surfaceSubtle(1.25)
                opacity: (Media.available && Media.canTogglePlaying) ? 1.0 : 0.35
                enabled: Media.available && Media.canTogglePlaying
                scale: (playArea.containsMouse && enabled && !root.reducedMotion) ? 1.05 : 1.0

                Behavior on scale {
                    enabled: !root.reducedMotion
                    NumberAnimation {
                        duration: playArea.containsMouse ? HAnimation.buttonHoverDuration : HAnimation.buttonReleaseDuration
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: playArea.containsMouse ? HAnimation.buttonHoverCurve : HAnimation.buttonReleaseCurve
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: Media.playing ? "󰏤" : "󰐊"
                    font.family: Theme.iconFontFamily
                    font.pixelSize: 22
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

            // Next Button: 36x36
            Rectangle {
                id: nextBtn
                width: 36
                height: 36
                radius: 18
                anchors.verticalCenter: parent.verticalCenter
                color: "transparent"
                opacity: (Media.available && Media.canGoNext) ? 1.0 : 0.35
                enabled: Media.available && Media.canGoNext
                scale: (nextArea.containsMouse && enabled && !root.reducedMotion) ? 1.05 : 1.0

                Behavior on scale {
                    enabled: !root.reducedMotion
                    NumberAnimation {
                        duration: nextArea.containsMouse ? HAnimation.buttonHoverDuration : HAnimation.buttonReleaseDuration
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: nextArea.containsMouse ? HAnimation.buttonHoverCurve : HAnimation.buttonReleaseCurve
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: "󰒭"
                    font.family: Theme.iconFontFamily
                    font.pixelSize: 20
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
