import QtQuick
import Quickshell
import "../../services"
import "../../config/UiCatalog.js" as UiCatalog

Rectangle {
    id: root

    radius: Theme.largeRadius
    color: Theme.surfaceSubtle(1.6)
    border.width: 0
    clip: true

    readonly property bool reducedMotion: Quickshell.env("HAKUSPACE_REDUCED_MOTION") === "1"

    // Resolve presentation metadata to the existing local widget implementations.
    property var widgets: UiCatalog.dashboardWidgets.map(function(widget) {
        return Object.assign({}, widget, {component: ({calendar: calendarWidgetComponent,
            devices: deviceHubWidgetComponent,
            bio: bioWidgetComponent})[widget.key]})
    })
    property bool active: false
    property int currentIndex: 0
    // Calendar navigation survives unloading its visual widget.
    property int calendarMonthOffset: 0

    readonly property int widgetCount: widgets ? widgets.length : 0
    readonly property int safeCurrentIndex: widgetCount > 0 ? Math.max(0, Math.min(widgetCount - 1, currentIndex)) : 0
    readonly property var currentWidget: (widgets && widgetCount > 0)
                                         ? widgets[safeCurrentIndex] : null
    readonly property string currentKey: currentWidget ? currentWidget.key : ""
    readonly property string currentTitle: currentWidget ? currentWidget.title : ""

    // Staged transition state
    property int committedIndex: safeCurrentIndex
    property int pendingIndex: -1
    property int transitionDirection: 0 // -1: prev, +1: next
    property bool transitioning: false
    property real transitionProgress: 0.0

    Component.onCompleted: {
        if (widgetCount > 0 && currentIndex !== safeCurrentIndex) {
            currentIndex = safeCurrentIndex
        }
        committedIndex = safeCurrentIndex
    }
    onCurrentIndexChanged: {
        if (!transitioning && widgetCount > 0) {
            committedIndex = safeCurrentIndex
        }
    }

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
        height: 38
        anchors.topMargin: Math.max(10, Math.round(Theme.pad * 0.9))
        anchors.leftMargin: Math.max(14, Math.round(Theme.pad * 1.25))
        anchors.rightMargin: Math.max(14, Math.round(Theme.pad * 1.25))

        // Animated title container
        Item {
            id: titleContainer
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(140, headerArea.width - switchControls.width - 16)
            height: parent.height
            clip: true

            Text {
                id: activeTitleLabel
                anchors.verticalCenter: parent.verticalCenter
                text: root.transitioning ? root.widgets[root.committedIndex].title : root.currentTitle
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize + 1
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
                font.pixelSize: Theme.fontSize + 1
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
                width: 32
                height: 32
                radius: 16
                color: "transparent"
                opacity: root.transitioning ? 0.5 : 1.0
                scale: (prevArea.pressed && !root.transitioning && !root.reducedMotion) ? 0.92
                    : ((prevArea.containsMouse && !root.transitioning && !root.reducedMotion) ? 1.05 : 1.0)

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
                    text: "󰅁"
                    font.family: Theme.iconFontFamily
                    font.pixelSize: 19
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
                width: 32
                height: 32
                radius: 16
                color: "transparent"
                opacity: root.transitioning ? 0.5 : 1.0
                scale: (nextArea.pressed && !root.transitioning && !root.reducedMotion) ? 0.92
                    : ((nextArea.containsMouse && !root.transitioning && !root.reducedMotion) ? 1.05 : 1.0)

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
                    text: "󰅂"
                    font.family: Theme.iconFontFamily
                    font.pixelSize: 19
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
        id: deviceHubWidgetComponent

        DashboardDeviceHubWidget {
            active: root.active && !root.transitioning && root.currentKey === "devices"
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
