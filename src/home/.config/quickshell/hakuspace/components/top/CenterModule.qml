import QtQuick
import "../../services"
import "../base"

Item {
    id: root
    property real maximumWidth: 0
    property string screenName: ""
    property bool hovered: false
    property bool initialized: false
    readonly property string mode: CenterState.centerMode
    readonly property bool hakuMenuActive: UiState.activePanel === "hakumenu"
                                                && UiState.hakuMenuScreenName === screenName
    readonly property string breadcrumb: hakuMenuActive ? UiState.hakuMenuBreadcrumb : ""
    property string displayedMode: "idle"
    readonly property bool active: (hakuMenuActive || mode !== "idle") && maximumWidth >= Theme.fontSize * 3
    readonly property bool mediaMode: !hakuMenuActive && displayedMode === "media"
    readonly property string icon: displayedMode === "recording" ? "●" : (Media.playing ? "󰐊" : "󰏤")
    readonly property string caption: displayedMode === "recording" ? "REC"
                                      : (Media.artist ? Media.title + " · " + Media.artist : Media.title)
    property string displayedBreadcrumb: ""
    property real breadcrumbOffset: 0
    readonly property string shownCaption: hakuMenuActive ? displayedBreadcrumb : caption

    implicitHeight: Theme.fontSize * 1.8
    implicitWidth: Math.min(Theme.fontSize * 26,
                            (hakuMenuActive ? 0 : iconBox.width + content.spacing)
                            + label.implicitWidth + Theme.pad * 2)
                   + (hovered ? Theme.pad * 2 : 0)
    Behavior on implicitWidth {
        NumberAnimation { duration: HAnimation.normal; easing.bezierCurve: HAnimation.moduleCurve }
    }
    width: active ? Math.min(implicitWidth, maximumWidth) : 0
    height: implicitHeight
    visible: active
    clip: true

    Component.onCompleted: {
        displayedMode = mode
        displayedBreadcrumb = breadcrumb
        initialized = true
    }
    onModeChanged: {
        if (!initialized) return
        if (!active || displayedMode === "idle") {
            stateTransition.stop()
            displayedMode = mode
            content.opacity = 1
        } else {
            stateTransition.restart()
        }
    }
    onBreadcrumbChanged: {
        if (!initialized || !hakuMenuActive) {
            displayedBreadcrumb = breadcrumb
            return
        }
        breadcrumbTransition.restart()
    }
    onHakuMenuActiveChanged: {
        breadcrumbTransition.stop()
        displayedBreadcrumb = breadcrumb
        content.opacity = 1
        breadcrumbOffset = 0
    }

    onActiveChanged: {
        if (!active) {
            stateTransition.stop()
            displayedMode = mode
            content.opacity = 1
            hovered = false
            hoverTooltip.active = false
        }
    }

    SequentialAnimation {
        id: stateTransition
        NumberAnimation { target: content; property: "opacity"; to: 0; duration: HAnimation.fast }
        ScriptAction { script: root.displayedMode = root.mode }
        NumberAnimation { target: content; property: "opacity"; to: 1; duration: HAnimation.fast }
    }

    SequentialAnimation {
        id: breadcrumbTransition
        ParallelAnimation {
            NumberAnimation {
                target: content
                property: "opacity"
                to: 0
                duration: HAnimation.fast
                easing.bezierCurve: HAnimation.moduleCurve
            }
            NumberAnimation {
                target: root
                property: "breadcrumbOffset"
                to: -4
                duration: HAnimation.fast
                easing.bezierCurve: HAnimation.moduleCurve
            }
        }
        ScriptAction {
            script: {
                root.displayedBreadcrumb = root.breadcrumb
                root.breadcrumbOffset = 4
            }
        }
        ParallelAnimation {
            NumberAnimation {
                target: content
                property: "opacity"
                to: 1
                duration: HAnimation.fast
                easing.bezierCurve: HAnimation.moduleCurve
            }
            NumberAnimation {
                target: root
                property: "breadcrumbOffset"
                to: 0
                duration: HAnimation.fast
                easing.bezierCurve: HAnimation.moduleCurve
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusSm
        color: root.hovered ? Theme.surfaceHi : Theme.surface
        Behavior on color { ColorAnimation { duration: HAnimation.normal; easing.bezierCurve: HAnimation.moduleCurve } }
    }

    Row {
        id: content
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        height: parent.height
        transform: Translate { y: root.hakuMenuActive ? root.breadcrumbOffset : 0 }
        anchors.leftMargin: Theme.pad
        anchors.rightMargin: Theme.pad
        spacing: root.hakuMenuActive ? 0 : (root.mediaMode ? Theme.pad * 1.5 : Theme.gap)

        Item {
            id: iconBox
            anchors.verticalCenter: parent.verticalCenter
            width: root.hakuMenuActive ? 0 : (root.mediaMode ? Theme.fontSize * 1.55 : iconLabel.implicitWidth)
            height: root.mediaMode ? width : iconLabel.implicitHeight

            Rectangle {
                anchors.fill: parent
                visible: root.mediaMode && !root.hakuMenuActive
                radius: width / 2
                color: Theme.accent
                scale: root.hovered ? 1.06 : 1
                Behavior on scale { NumberAnimation { duration: HAnimation.normal; easing.bezierCurve: HAnimation.moduleCurve } }
            }
            Text {
                id: iconLabel
                anchors.centerIn: parent
                text: root.hakuMenuActive ? "" : root.icon
                color: root.mediaMode ? Theme.onAccentColor : Theme.accent
                font.family: Theme.fontFamily
                font.pixelSize: root.mediaMode ? Theme.fontSize + 3 : Theme.fontSize
                font.weight: Font.Bold
                Behavior on color { ColorAnimation { duration: HAnimation.normal } }
            }
        }
        Text {
            id: label
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(0, content.width - iconBox.width - content.spacing)
            text: root.shownCaption
            color: root.hovered ? Theme.onAccentColor : Theme.fg
            font.family: Theme.fontFamily
            font.pixelSize: root.mediaMode ? Theme.fontSize - 1 : Theme.fontSize
            font.weight: Font.Bold
            elide: Text.ElideRight
            verticalAlignment: Text.AlignVCenter
            Behavior on color { ColorAnimation { duration: HAnimation.normal } }
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.active && !root.hakuMenuActive
        hoverEnabled: true
        onEntered: {
            root.hovered = true
            hoverTooltip.active = true
        }
        onExited: {
            root.hovered = false
            hoverTooltip.active = false
        }
        onClicked: {
            if (root.mode === "media") Media.togglePlaying()
        }
    }

    HTooltip {
        id: hoverTooltip
        target: root
        text: root.mode === "media" ? (Media.artist ? Media.title + "\n" + Media.artist : Media.title) : root.caption
    }
}
