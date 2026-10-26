import QtQuick
import "../../services"

Rectangle {
    id: root

    radius: Theme.largeRadius
    color: Theme.surface
    border.width: 0
    border.color: Theme.surfaceHighlight(1.25)
    clip: true

    property var widgets: [
        {
            key: "calendar",
            title: "Calendar",
            component: calendarWidgetComponent
        },
        {
            key: "bio",
            title: "Bio",
            component: bioWidgetComponent
        }
    ]
    property int currentIndex: 0
    // Calendar navigation survives unloading its visual widget.
    property int calendarMonthOffset: 0

    readonly property int widgetCount: widgets ? widgets.length : 0
    readonly property var currentWidget: (widgets && widgetCount > 0 && currentIndex >= 0 && currentIndex < widgetCount)
                                         ? widgets[currentIndex] : null
    readonly property string currentKey: currentWidget ? currentWidget.key : ""
    readonly property string currentTitle: currentWidget ? currentWidget.title : ""

    // Staged transition state
    property int committedIndex: currentIndex
    property int pendingIndex: -1
    property int transitionDirection: 0 // -1: prev, +1: next
    property bool transitioning: false
    property real transitionProgress: 0.0

    readonly property real slideDistance: 64

    // Switches to the previous dynamic widget with slide-fade transition.
    function previousWidget() {
        if (transitioning || widgetCount <= 1) return
        startTransition(-1)
    }

    // Switches to the next dynamic widget with slide-fade transition.
    function nextWidget() {
        if (transitioning || widgetCount <= 1) return
        startTransition(1)
    }

    // Begins directional slide-fade transition to the target widget index.
    function startTransition(direction) {
        var targetIndex = (committedIndex + direction + widgetCount) % widgetCount
        if (targetIndex === committedIndex) return

        transitionDirection = direction
        pendingIndex = targetIndex
        transitioning = true
        transitionAnim.start()
    }

    // Drives cross-fade and horizontal slide progress between active widgets.
    NumberAnimation {
        id: transitionAnim
        target: root
        property: "transitionProgress"
        from: 0.0
        to: 1.0
        duration: HAnimation.dashboardWidgetSwitchDuration
        easing.bezierCurve: HAnimation.dashboardWidgetSwitchCurve

        onFinished: {
            root.committedIndex = root.pendingIndex
            root.currentIndex = root.committedIndex
            root.transitioning = false
            root.transitionDirection = 0
            root.pendingIndex = -1
            root.transitionProgress = 0.0
        }
    }

    Item {
        id: headerArea
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 36
        anchors.topMargin: Math.max(8, Math.round(Theme.pad * 0.8))
        anchors.leftMargin: Math.max(12, Math.round(Theme.pad * 1.2))
        anchors.rightMargin: Math.max(12, Math.round(Theme.pad * 1.2))

        // Animated title container
        Item {
            id: titleContainer
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: 140
            height: parent.height
            clip: true

            Text {
                id: activeTitleLabel
                anchors.verticalCenter: parent.verticalCenter
                text: root.transitioning ? root.widgets[root.committedIndex].title : root.currentTitle
                font.family: Theme.fontFamily
                font.pixelSize: Math.max(12, Theme.fontSize - 1)
                font.weight: Font.Bold
                color: Theme.fg
                opacity: root.transitioning ? (1.0 - root.transitionProgress) : 1.0
                x: root.transitioning ? (-root.transitionDirection * 20 * root.transitionProgress) : 0
            }

            Text {
                id: incomingTitleLabel
                anchors.verticalCenter: parent.verticalCenter
                text: (root.transitioning && root.pendingIndex >= 0) ? root.widgets[root.pendingIndex].title : ""
                font.family: Theme.fontFamily
                font.pixelSize: Math.max(12, Theme.fontSize - 1)
                font.weight: Font.Bold
                color: Theme.fg
                visible: root.transitioning
                opacity: root.transitioning ? root.transitionProgress : 0.0
                x: root.transitioning ? (root.transitionDirection * 20 * (1.0 - root.transitionProgress)) : 0
            }
        }

        // Directional switcher buttons
        Row {
            id: switchControls
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6
            visible: root.widgetCount > 1

            Rectangle {
                width: 26
                height: 26
                radius: 13
                color: prevArea.containsMouse ? Theme.hoverMuted : "transparent"
                opacity: root.transitioning ? 0.5 : 1.0
                scale: prevArea.pressed && !root.transitioning ? 0.92 : 1.0

                Behavior on color { ColorAnimation { duration: HAnimation.fast } }
                Behavior on scale {
                    NumberAnimation {
                        duration: HAnimation.buttonHoverDuration
                        easing.bezierCurve: HAnimation.buttonHoverCurve
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: "‹"
                    font.family: Theme.fontFamily
                    font.pixelSize: 17
                    font.weight: Font.Bold
                    color: Theme.fg
                }

                MouseArea {
                    id: prevArea
                    anchors.fill: parent
                    enabled: !root.transitioning
                    hoverEnabled: true
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    acceptedButtons: Qt.LeftButton
                    onClicked: root.previousWidget()
                }
            }

            Rectangle {
                width: 26
                height: 26
                radius: 13
                color: nextArea.containsMouse ? Theme.hoverMuted : "transparent"
                opacity: root.transitioning ? 0.5 : 1.0
                scale: nextArea.pressed && !root.transitioning ? 0.92 : 1.0

                Behavior on color { ColorAnimation { duration: HAnimation.fast } }
                Behavior on scale {
                    NumberAnimation {
                        duration: HAnimation.buttonHoverDuration
                        easing.bezierCurve: HAnimation.buttonHoverCurve
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: "›"
                    font.family: Theme.fontFamily
                    font.pixelSize: 17
                    font.weight: Font.Bold
                    color: Theme.fg
                }

                MouseArea {
                    id: nextArea
                    anchors.fill: parent
                    enabled: !root.transitioning
                    hoverEnabled: true
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    acceptedButtons: Qt.LeftButton
                    onClicked: root.nextWidget()
                }
            }
        }
    }

    // Viewport with slide-fade transition slots
    Item {
        id: contentViewport
        anchors.top: headerArea.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: Math.max(8, Math.round(Theme.pad * 0.8))
        clip: true

        Repeater {
            model: root.widgets

            delegate: Item {
                id: slotItem
                required property int index
                required property var modelData

                width: contentViewport.width
                height: contentViewport.height
                y: 0

                readonly property bool isCurrent: root.committedIndex === index
                readonly property bool isOutgoing: root.transitioning && root.committedIndex === index
                readonly property bool isIncoming: root.transitioning && root.pendingIndex === index

                visible: isCurrent || isOutgoing || isIncoming

                // Slide animation:
                // Outgoing slides in direction opposite of travel (-direction * slideDistance)
                // Incoming enters from (+direction * slideDistance) to 0
                x: isOutgoing
                   ? (-root.transitionDirection * root.slideDistance * root.transitionProgress)
                   : (isIncoming
                      ? (root.transitionDirection * root.slideDistance * (1.0 - root.transitionProgress))
                      : 0)

                // Fade animation:
                // Outgoing fades from 1.0 down to 0.0
                // Incoming fades from 0.0 up to 1.0
                opacity: isOutgoing
                         ? (1.0 - root.transitionProgress)
                         : (isIncoming
                            ? root.transitionProgress
                            : (isCurrent ? 1.0 : 0.0))

                Loader {
                    anchors.fill: parent
                    sourceComponent: modelData.component
                    active: slotItem.isCurrent || slotItem.isOutgoing || slotItem.isIncoming
                }
            }
        }
    }

    Component {
        id: calendarWidgetComponent

        DashboardCalendarWidget {
            monthOffset: root.calendarMonthOffset
            onMonthOffsetChanged: root.calendarMonthOffset = monthOffset
            anchors.fill: parent
        }
    }

    Component {
        id: bioWidgetComponent

        DashboardBioWidget {
            anchors.fill: parent
        }
    }
}
