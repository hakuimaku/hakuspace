import QtQuick
import QtQuick.Controls
import Quickshell
import "../../services"
import "../motion" as Motion

Item {
    id: root

    property bool active: false
    property string audioTab: "apps" // "apps" | "output" | "input"
    property bool _subscribed: false
    readonly property bool reducedMotion: Quickshell.env("HAKUSPACE_REDUCED_MOTION") === "1"
    // Dynamic horizontal margin so width * 1.05 never clips on either edge.
    readonly property real hoverInsetX: Math.ceil(width * 0.03) + 4

    property int _lastTabIndex: 0
    property real _tabSlideX: 0
    property real _tabOpacity: 1.0

    ListModel { id: streamsModel }
    ListModel { id: sinksModel }
    ListModel { id: sourcesModel }

    function _normalizeStreams(list) {
        var arr = Array.isArray(list) ? list : []
        var out = []
        for (var i = 0; i < arr.length; ++i) {
            var item = arr[i] || ({})
            var sid = String(item.id !== undefined && item.id !== null ? item.id : "")
            if (!sid) continue
            out.push({
                streamId: sid,
                appName: String(item.appName || "Audio Stream"),
                mediaName: String(item.mediaName || ""),
                sinkId: String(item.sinkId !== undefined && item.sinkId !== null ? item.sinkId : ""),
                sinkName: String(item.sinkName || "Output"),
                muted: !!item.muted,
                volumePercent: Math.max(0, Math.min(150, Math.round(Number(item.volumePercent || 0)))),
                corked: !!item.corked
            })
        }
        return out
    }

    function _normalizeDevices(list) {
        var arr = Array.isArray(list) ? list : []
        var out = []
        for (var i = 0; i < arr.length; ++i) {
            var item = arr[i] || ({})
            var devName = String(item.name || item.id || "")
            if (!devName) continue
            out.push({
                deviceId: String(item.id !== undefined && item.id !== null ? item.id : devName),
                deviceName: devName,
                description: String(item.description || devName || "Unknown device"),
                isDefault: !!item.isDefault,
                muted: !!item.muted,
                volumePercent: Math.max(0, Math.min(150, Math.round(Number(item.volumePercent || 0))))
            })
        }
        return out
    }

    // Mutates ListModel in place without clear() so active delegates keep identity and hover/slider state.
    function syncListModel(listModel, nextArray, keyField, fields) {
        var keySet = ({})
        for (var k = 0; k < nextArray.length; ++k) {
            keySet[String(nextArray[k][keyField])] = true
        }

        for (var i = listModel.count - 1; i >= 0; --i) {
            var curKey = String(listModel.get(i)[keyField])
            if (!keySet[curKey]) {
                listModel.remove(i, 1)
            }
        }

        for (var targetIdx = 0; targetIdx < nextArray.length; ++targetIdx) {
            var rec = nextArray[targetIdx]
            var recKey = String(rec[keyField])
            var foundIdx = -1
            for (var j = 0; j < listModel.count; ++j) {
                if (String(listModel.get(j)[keyField]) === recKey) {
                    foundIdx = j
                    break
                }
            }

            if (foundIdx < 0) {
                if (targetIdx < listModel.count) listModel.insert(targetIdx, rec)
                else listModel.append(rec)
            } else {
                if (foundIdx !== targetIdx) {
                    listModel.move(foundIdx, targetIdx, 1)
                }
                var existing = listModel.get(targetIdx)
                for (var f = 0; f < fields.length; ++f) {
                    var field = fields[f]
                    if (existing[field] !== rec[field]) {
                        listModel.setProperty(targetIdx, field, rec[field])
                    }
                }
            }
        }
    }

    function _syncStreams() {
        syncListModel(streamsModel, _normalizeStreams(DeviceHubService.streams), "streamId",
            ["appName", "mediaName", "sinkId", "sinkName", "muted", "volumePercent", "corked"])
    }

    function _syncSinks() {
        syncListModel(sinksModel, _normalizeDevices(DeviceHubService.sinks), "deviceName",
            ["deviceId", "description", "isDefault", "muted", "volumePercent"])
    }

    function _syncSources() {
        syncListModel(sourcesModel, _normalizeDevices(DeviceHubService.sources), "deviceName",
            ["deviceId", "description", "isDefault", "muted", "volumePercent"])
    }

    Connections {
        target: DeviceHubService
        function onStreamsChanged() { root._syncStreams() }
        function onSinksChanged() { root._syncSinks() }
        function onSourcesChanged() { root._syncSources() }
    }

    function _tabIndexFor(tab) {
        return tab === "apps" ? 0 : (tab === "output" ? 1 : 2)
    }

    onAudioTabChanged: {
        var nextIdx = _tabIndexFor(audioTab)
        var dir = nextIdx > _lastTabIndex ? 1 : (nextIdx < _lastTabIndex ? -1 : 0)
        _lastTabIndex = nextIdx
        if (dir !== 0 && !root.reducedMotion) {
            tabSwitchAnim.stop()
            tabSlideAnim.from = dir * 12
            tabSwitchAnim.start()
        }
    }

    ParallelAnimation {
        id: tabSwitchAnim
        NumberAnimation {
            id: tabSlideAnim
            target: root
            property: "_tabSlideX"
            from: 12
            to: 0
            duration: HAnimation.normal
            easing.type: Easing.BezierSpline
            easing.bezierCurve: HAnimation.moduleCurve
        }
        NumberAnimation {
            target: root
            property: "_tabOpacity"
            from: 0.3
            to: 1.0
            duration: HAnimation.normal
            easing.type: Easing.BezierSpline
            easing.bezierCurve: HAnimation.moduleCurve
        }
    }

    function _updateSubscription() {
        if (active && !_subscribed) {
            _subscribed = true
            DeviceHubService.acquire()
        } else if (!active && _subscribed) {
            _subscribed = false
            DeviceHubService.release()
        }
    }

    function nextSinkForStream(currentSinkId) {
        var list = DeviceHubService.sinks
        if (!list || list.length <= 1) return null
        var idx = -1
        for (var i = 0; i < list.length; ++i) {
            if (String(list[i].id) === String(currentSinkId)) {
                idx = i
                break
            }
        }
        return list[(idx + 1 + list.length) % list.length]
    }

    onActiveChanged: _updateSubscription()
    Component.onCompleted: {
        _lastTabIndex = _tabIndexFor(audioTab)
        _syncStreams()
        _syncSinks()
        _syncSources()
        _updateSubscription()
    }
    Component.onDestruction: {
        if (_subscribed) {
            _subscribed = false
            DeviceHubService.release()
        }
    }

    // Conditional ShellHealth inline banner (hidden when system is healthy)
    Rectangle {
        id: healthBanner
        visible: ShellHealth.hasIssues
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.leftMargin: root.hoverInsetX
        anchors.right: parent.right
        anchors.rightMargin: root.hoverInsetX
        height: visible ? 30 : 0
        radius: Theme.radius
        color: Theme.surface

        Row {
            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.right: healthRetryBtn.left
            anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: ""
                font.family: Theme.iconFontFamily
                font.pixelSize: Math.max(12, Theme.fontSize - 1)
                color: ShellHealth.degraded ? Theme.danger : Theme.warning
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(0, parent.width - 24)
                text: ShellHealth.issueCount + " shell issue(s)"
                font.family: Theme.fontFamily
                font.pixelSize: Math.max(11, Theme.fontSize - 1)
                font.weight: Font.Medium
                color: Theme.fg
                elide: Text.ElideRight
            }
        }

        Rectangle {
            id: healthRetryBtn
            anchors.right: parent.right
            anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            width: healthRetryLabel.implicitWidth + 14
            height: 22
            radius: Theme.radius
            color: "transparent"
            scale: (healthRetryMouse.containsMouse && !root.reducedMotion) ? 1.05 : 1.0

            Behavior on scale {
                enabled: !root.reducedMotion
                NumberAnimation {
                    duration: healthRetryMouse.containsMouse ? HAnimation.buttonHoverDuration : HAnimation.buttonReleaseDuration
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: healthRetryMouse.containsMouse ? HAnimation.buttonHoverCurve : HAnimation.buttonReleaseCurve
                }
            }

            Text {
                id: healthRetryLabel
                anchors.centerIn: parent
                text: "Retry"
                font.family: Theme.fontFamily
                font.pixelSize: Math.max(10, Theme.fontSize - 2)
                font.weight: Font.DemiBold
                color: Theme.accent
            }

            MouseArea {
                id: healthRetryMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton
                onClicked: {
                    DashboardTooltip.dismiss()
                    ShellHealth.retryFailingServices()
                }
            }
        }
    }

    // Audio Mixer top bar: Apps | Output | Input switcher + Refresh button
    // Shares the exact same left/right hoverInsetX axis as every list delegate.
    Item {
        id: audioToolbar
        anchors.top: healthBanner.visible ? healthBanner.bottom : parent.top
        anchors.topMargin: healthBanner.visible ? 6 : 0
        anchors.left: parent.left
        anchors.leftMargin: root.hoverInsetX
        anchors.right: parent.right
        anchors.rightMargin: root.hoverInsetX
        height: 34

        Rectangle {
            id: segmentedControl
            anchors.left: parent.left
            anchors.right: refreshBtn.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            height: 32
            radius: Theme.radius
            color: Theme.surface

            Item {
                id: segmentedLane
                anchors.fill: parent
                anchors.margins: 2

                Motion.SelectionPill {
                    id: tabPill
                    z: 0
                    coordinateSpace: segmentedLane
                    targetIndex: root.audioTab === "apps" ? 0 : (root.audioTab === "output" ? 1 : 2)
                    slotCount: 3
                    slotSpacing: 2
                    normalColor: Theme.accent
                    duration: root.reducedMotion ? 0 : HAnimation.spatial
                    fadeEnabled: false
                }

                Row {
                    anchors.fill: parent
                    spacing: 2
                    z: 1

                    Repeater {
                        model: [
                            { key: "apps", label: "Apps" },
                            { key: "output", label: "Output" },
                            { key: "input", label: "Input" }
                        ]

                        delegate: Item {
                            required property var modelData
                            required property int index
                            readonly property bool selected: root.audioTab === modelData.key
                            readonly property int streamCount: modelData.key === "apps" ? streamsModel.count : 0

                            width: Math.max(0, (segmentedLane.width - 4) / 3)
                            height: segmentedLane.height

                            Row {
                                anchors.centerIn: parent
                                spacing: 5
                                scale: (tabMouse.containsMouse && !root.reducedMotion) ? 1.05 : 1.0

                                Behavior on scale {
                                    enabled: !root.reducedMotion
                                    NumberAnimation {
                                        duration: tabMouse.containsMouse ? HAnimation.buttonHoverDuration : HAnimation.buttonReleaseDuration
                                        easing.type: Easing.BezierSpline
                                        easing.bezierCurve: tabMouse.containsMouse ? HAnimation.buttonHoverCurve : HAnimation.buttonReleaseCurve
                                    }
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: modelData.label
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Math.max(11, Theme.fontSize - 1)
                                    font.weight: selected ? Font.DemiBold : Font.Normal
                                    color: selected ? Theme.onAccentColor : Theme.fgDim

                                    Behavior on color {
                                        enabled: !root.reducedMotion
                                        ColorAnimation {
                                            duration: HAnimation.selectionMorphDuration
                                            easing.type: Easing.BezierSpline
                                            easing.bezierCurve: HAnimation.selectionMorphCurve
                                        }
                                    }
                                }

                                Rectangle {
                                    visible: streamCount > 0
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: Math.max(16, badgeText.implicitWidth + 8)
                                    height: 16
                                    radius: 8
                                    color: selected ? Qt.alpha(Theme.onAccentColor, 0.22) : Theme.surfaceSubtle(1.25)

                                    Text {
                                        id: badgeText
                                        anchors.centerIn: parent
                                        text: String(streamCount)
                                        font.family: Theme.iconFontFamily
                                        font.pixelSize: Math.max(9, Theme.fontSize - 3)
                                        font.weight: Font.Bold
                                        color: selected ? Theme.onAccentColor : Theme.accent
                                    }
                                }
                            }

                            MouseArea {
                                id: tabMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                acceptedButtons: Qt.LeftButton
                                onClicked: {
                                    DashboardTooltip.dismiss()
                                    root.audioTab = modelData.key
                                }
                            }
                        }
                    }
                }
            }
        }

        Rectangle {
            id: refreshBtn
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 32
            height: 32
            radius: 16
            color: Theme.surfaceSubtle(1.25)
            scale: (refreshMouse.containsMouse && !root.reducedMotion) ? 1.05 : 1.0

            Behavior on scale {
                enabled: !root.reducedMotion
                NumberAnimation {
                    duration: refreshMouse.containsMouse ? HAnimation.buttonHoverDuration : HAnimation.buttonReleaseDuration
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: refreshMouse.containsMouse ? HAnimation.buttonHoverCurve : HAnimation.buttonReleaseCurve
                }
            }

            Text {
                anchors.centerIn: parent
                text: "󰑐"
                font.family: Theme.iconFontFamily
                font.pixelSize: 18
                color: DeviceHubService.loading ? Theme.accent : Theme.fgDim
            }

            MouseArea {
                id: refreshMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton
                onEntered: DashboardTooltip.show(refreshBtn, "Refresh audio mixer")
                onExited: DashboardTooltip.hide(refreshBtn)
                onClicked: {
                    DashboardTooltip.dismiss()
                    DeviceHubService.refresh()
                }
            }
        }
    }

    // Main Mixer Viewport (100% height below toolbar)
    Item {
        id: mixerViewport
        anchors.top: audioToolbar.bottom
        anchors.topMargin: 8
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        clip: true
        opacity: root._tabOpacity
        transform: Translate { x: root._tabSlideX }

        // Tab 1: Apps (Playback sink-inputs)
        ListView {
            id: streamList
            visible: root.audioTab === "apps"
            anchors.fill: parent
            topMargin: 6
            bottomMargin: 6
            model: streamsModel
            spacing: 8
            clip: true
            interactive: true
            flickableDirection: Flickable.VerticalFlick
            boundsBehavior: Flickable.StopAtBounds
            onMovementStarted: DashboardTooltip.dismiss()
            onContentYChanged: DashboardTooltip.dismiss()

            ScrollBar.vertical: Motion.HScrollBar {
                id: streamScrollBar
                policy: ScrollBar.AsNeeded
            }

            delegate: Item {
                id: streamDelegate
                required property string streamId
                required property string appName
                required property string mediaName
                required property string sinkId
                required property string sinkName
                required property bool muted
                required property int volumePercent
                required property bool corked

                width: ListView.view ? ListView.view.width : 0
                height: 84
                z: streamCard.cardHovered ? 2 : 0

                Rectangle {
                    id: streamCard
                    readonly property bool isMuted: streamDelegate.muted
                    readonly property bool canSwitchSink: sinksModel.count > 1
                    readonly property bool cardHovered: streamHover.hovered || streamSlider.hovered || streamSlider.pressed || streamMuteMouse.containsMouse || sinkPillMouse.containsMouse || streamPctMouse.containsMouse

                    anchors.centerIn: parent
                    width: Math.max(0, parent.width - root.hoverInsetX * 2)
                    height: parent.height
                    radius: Theme.radius
                    color: Theme.surfaceSubtle(1.25)
                    border.width: 0
                    transformOrigin: Item.Center
                    scale: (cardHovered && !root.reducedMotion) ? 1.05 : 1.0

                    Behavior on scale {
                        enabled: !root.reducedMotion
                        NumberAnimation {
                            duration: streamCard.cardHovered ? HAnimation.buttonHoverDuration : HAnimation.buttonReleaseDuration
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: streamCard.cardHovered ? HAnimation.buttonHoverCurve : HAnimation.buttonReleaseCurve
                        }
                    }

                    HoverHandler {
                        id: streamHover
                        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    }

                    // Top row: App name + media subtitle + solid Accent output sink pill
                    Item {
                        id: streamTopRow
                        anchors.top: parent.top
                        anchors.topMargin: 8
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        height: 26

                        Item {
                            id: streamMeta
                            anchors.left: parent.left
                            anchors.right: sinkPill.left
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            height: parent.height

                            Text {
                                id: appNameText
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                width: Math.min(implicitWidth, parent.width * (mediaNameText.visible ? 0.55 : 1.0))
                                text: streamDelegate.appName || "Audio Stream"
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize
                                font.weight: Font.Bold
                                color: Theme.fg
                                elide: Text.ElideRight
                            }

                            Text {
                                id: mediaNameText
                                visible: streamDelegate.mediaName.length > 0 && streamDelegate.mediaName !== streamDelegate.appName
                                anchors.left: appNameText.right
                                anchors.leftMargin: 6
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                text: streamDelegate.mediaName
                                font.family: Theme.fontFamily
                                font.pixelSize: Math.max(11, Theme.fontSize - 1)
                                color: Theme.fgDim
                                elide: Text.ElideRight
                            }
                        }

                        Rectangle {
                            id: sinkPill
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.min(126, Math.max(48, sinkPillText.implicitWidth + 18))
                            height: 24
                            radius: Theme.radius
                            color: Theme.accent
                            border.width: 0
                            scale: (sinkPillMouse.containsMouse && streamCard.canSwitchSink && !root.reducedMotion) ? 1.05 : 1.0

                            Behavior on scale {
                                enabled: !root.reducedMotion
                                NumberAnimation {
                                    duration: sinkPillMouse.containsMouse ? HAnimation.buttonHoverDuration : HAnimation.buttonReleaseDuration
                                    easing.type: Easing.BezierSpline
                                    easing.bezierCurve: sinkPillMouse.containsMouse ? HAnimation.buttonHoverCurve : HAnimation.buttonReleaseCurve
                                }
                            }

                            Text {
                                id: sinkPillText
                                anchors.centerIn: parent
                                width: Math.max(0, parent.width - 12)
                                horizontalAlignment: Text.AlignHCenter
                                text: streamDelegate.sinkName || "Output"
                                font.family: Theme.fontFamily
                                font.pixelSize: Math.max(10, Theme.fontSize - 2)
                                font.weight: Font.DemiBold
                                color: Theme.onAccentColor
                                elide: Text.ElideRight
                            }

                            MouseArea {
                                id: sinkPillMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                enabled: streamCard.canSwitchSink && !DeviceHubService.actionBusy
                                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                acceptedButtons: Qt.LeftButton
                                onEntered: DashboardTooltip.show(sinkPill, streamCard.canSwitchSink
                                    ? ("Output: " + streamDelegate.sinkName + " (click to switch)")
                                    : (streamDelegate.sinkName || "Output"))
                                onExited: DashboardTooltip.hide(sinkPill)
                                onClicked: {
                                    DashboardTooltip.dismiss()
                                    var nextSink = root.nextSinkForStream(streamDelegate.sinkId)
                                    if (nextSink && nextSink.name) {
                                        DeviceHubService.moveStreamToSink(streamDelegate.streamId, nextSink.name)
                                    }
                                }
                            }
                        }
                    }

                    // Bottom row: Mute button + Shell-standard Pill Slider + Click-to-100% readout
                    Item {
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 8
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        height: 34

                        Rectangle {
                            id: streamMuteBtn
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            width: 34
                            height: 34
                            radius: 17
                            color: Theme.surface
                            scale: (streamMuteMouse.containsMouse && !root.reducedMotion) ? 1.05 : 1.0

                            Behavior on scale {
                                enabled: !root.reducedMotion
                                NumberAnimation {
                                    duration: streamMuteMouse.containsMouse ? HAnimation.buttonHoverDuration : HAnimation.buttonReleaseDuration
                                    easing.type: Easing.BezierSpline
                                    easing.bezierCurve: streamMuteMouse.containsMouse ? HAnimation.buttonHoverCurve : HAnimation.buttonReleaseCurve
                                }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: streamCard.isMuted ? "󰝟" : "󰕾"
                                font.family: Theme.iconFontFamily
                                font.pixelSize: 19
                                color: streamCard.isMuted ? Theme.danger : Theme.fg
                            }

                            MouseArea {
                                id: streamMuteMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                acceptedButtons: Qt.LeftButton
                                onEntered: DashboardTooltip.show(streamMuteBtn, streamCard.isMuted ? "Unmute stream" : "Mute stream")
                                onExited: DashboardTooltip.hide(streamMuteBtn)
                                onClicked: {
                                    DashboardTooltip.dismiss()
                                    DeviceHubService.toggleStreamMute(streamDelegate.streamId)
                                }
                            }
                        }

                        Slider {
                            id: streamSlider
                            anchors.left: streamMuteBtn.right
                            anchors.leftMargin: 8
                            anchors.right: streamPctBtn.left
                            anchors.rightMargin: 4
                            anchors.verticalCenter: parent.verticalCenter
                            height: 28
                            padding: 4
                            from: 0
                            to: 150
                            stepSize: 1
                            snapMode: Slider.SnapAlways
                            live: true
                            wheelEnabled: false
                            focusPolicy: Qt.NoFocus
                            activeFocusOnTab: false

                            readonly property int backendValue: Math.max(0, Math.min(150, streamDelegate.volumePercent))
                            property bool _dragging: false
                            property bool _wheelHolding: false
                            property int _lastEmitted: -1

                            Component.onCompleted: value = backendValue
                            onBackendValueChanged: {
                                if (!pressed && !_wheelHolding) {
                                    value = backendValue
                                }
                            }
                            onPressedChanged: {
                                if (pressed) {
                                    DashboardTooltip.dismiss()
                                    _wheelHolding = false
                                    streamWheelHold.stop()
                                    _lastEmitted = -1
                                    if (!_dragging) {
                                        _dragging = true
                                        DeviceHubService.beginDrag()
                                    }
                                } else if (_dragging) {
                                    _dragging = false
                                    DeviceHubService.endDrag()
                                }
                            }
                            Component.onDestruction: {
                                if (_dragging) {
                                    _dragging = false
                                    DeviceHubService.endDrag()
                                }
                            }
                            onMoved: {
                                var pct = Math.max(0, Math.min(150, Math.round(value)))
                                if (pressed && Math.abs(pct - 100) <= 4) {
                                    pct = 100
                                    if (Math.round(value) !== 100) value = 100
                                }
                                if (pct !== _lastEmitted) {
                                    _lastEmitted = pct
                                    DeviceHubService.setStreamVolume(streamDelegate.streamId, pct)
                                }
                            }

                            WheelHandler {
                                target: null
                                enabled: streamSlider.enabled
                                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                                onWheel: event => {
                                    DashboardTooltip.dismiss()
                                    var step = event.angleDelta.y > 0 ? 5 : (event.angleDelta.y < 0 ? -5 : 0)
                                    if (step === 0) return
                                    var cur = Math.round(streamSlider.value)
                                    var next = Math.max(0, Math.min(150, cur + step))
                                    // Stop cleanly at 100% before crossing into or out of boost range.
                                    if ((cur < 100 && next > 100) || (cur > 100 && next < 100)) {
                                        next = 100
                                    }
                                    streamSlider.value = next
                                    streamSlider._wheelHolding = true
                                    streamWheelHold.restart()
                                    if (next !== streamSlider._lastEmitted) {
                                        streamSlider._lastEmitted = next
                                        DeviceHubService.setStreamVolume(streamDelegate.streamId, next)
                                    }
                                    event.accepted = true
                                }
                            }

                            Timer {
                                id: streamWheelHold
                                interval: 700
                                repeat: false
                                onTriggered: {
                                    streamSlider._wheelHolding = false
                                    if (!streamSlider.pressed) streamSlider.value = streamSlider.backendValue
                                }
                            }

                            background: Rectangle {
                                x: streamSlider.leftPadding
                                y: streamSlider.topPadding + streamSlider.availableHeight / 2 - height / 2
                                width: streamSlider.availableWidth
                                height: 18
                                radius: height / 2
                                color: Theme.surface

                                Rectangle {
                                    id: streamFill
                                    width: streamSlider.handle
                                        ? Math.max(0, Math.min(parent.width, streamSlider.handle.x - parent.x + streamSlider.handle.width))
                                        : 0
                                    height: parent.height
                                    radius: parent.radius
                                    color: streamCard.isMuted ? Theme.fgMuted : Theme.accent
                                }

                                // 100% unity reference notch
                                Rectangle {
                                    readonly property real markX: Math.round(parent.width * (100 / 150)) - 1
                                    readonly property bool covered: streamFill.width >= markX + 1
                                    x: markX
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 2
                                    height: Math.round(parent.height * 0.55)
                                    radius: 1
                                    color: covered ? Theme.onAccentColor : Theme.fgMuted
                                    opacity: covered ? 0.45 : 0.5
                                }
                            }

                            handle: Item {
                                x: streamSlider.leftPadding + streamSlider.visualPosition * (streamSlider.availableWidth - width)
                                y: streamSlider.topPadding + streamSlider.availableHeight / 2 - height / 2
                                width: 20
                                height: 20

                                Rectangle {
                                    anchors.centerIn: parent
                                    width: streamSlider.pressed ? 14 : 12
                                    height: width
                                    radius: width / 2
                                    color: Theme.onAccentColor
                                    opacity: streamSlider.pressed ? 1.0 : 0.85
                                }
                            }
                        }

                        Item {
                            id: streamPctBtn
                            readonly property int shownPct: Math.round(streamSlider.value)
                            readonly property bool isUnity: shownPct === 100
                            readonly property bool isBoosted: shownPct > 100
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            width: 46
                            height: 26
                            scale: (streamPctMouse.containsMouse && !isUnity && !root.reducedMotion) ? 1.05 : 1.0

                            Behavior on scale {
                                enabled: !root.reducedMotion
                                NumberAnimation {
                                    duration: streamPctMouse.containsMouse ? HAnimation.buttonHoverDuration : HAnimation.buttonReleaseDuration
                                    easing.type: Easing.BezierSpline
                                    easing.bezierCurve: streamPctMouse.containsMouse ? HAnimation.buttonHoverCurve : HAnimation.buttonReleaseCurve
                                }
                            }

                            Text {
                                id: streamPctText
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                text: streamPctBtn.shownPct + "%"
                                font.family: Theme.iconFontFamily
                                font.pixelSize: Math.max(11, Theme.fontSize - 1)
                                font.weight: (streamPctBtn.isUnity || streamPctBtn.isBoosted) ? Font.DemiBold : Font.Medium
                                color: streamCard.isMuted ? Theme.fgMuted
                                    : (streamPctBtn.isBoosted ? Theme.accent
                                        : (streamPctBtn.isUnity ? Theme.fg : Theme.fgDim))
                            }

                            MouseArea {
                                id: streamPctMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: !streamPctBtn.isUnity ? Qt.PointingHandCursor : Qt.ArrowCursor
                                acceptedButtons: Qt.LeftButton
                                onEntered: if (!streamPctBtn.isUnity) DashboardTooltip.show(streamPctBtn, "Click to set 100%")
                                onExited: DashboardTooltip.hide(streamPctBtn)
                                onClicked: {
                                    if (streamPctBtn.isUnity) return
                                    DashboardTooltip.dismiss()
                                    streamSlider.value = 100
                                    streamSlider._wheelHolding = true
                                    streamWheelHold.restart()
                                    streamSlider._lastEmitted = 100
                                    DeviceHubService.setStreamVolume(streamDelegate.streamId, 100)
                                }
                            }
                        }
                    }
                }
            }
        }

        // Tab 2 & 3: Output Sinks & Input Sources
        ListView {
            id: deviceList
            visible: root.audioTab !== "apps"
            anchors.fill: parent
            topMargin: 6
            bottomMargin: 6
            model: root.audioTab === "output" ? sinksModel : sourcesModel
            spacing: 8
            clip: true
            interactive: true
            flickableDirection: Flickable.VerticalFlick
            boundsBehavior: Flickable.StopAtBounds
            onMovementStarted: DashboardTooltip.dismiss()
            onContentYChanged: DashboardTooltip.dismiss()

            ScrollBar.vertical: Motion.HScrollBar {
                id: deviceScrollBar
                policy: ScrollBar.AsNeeded
            }

            delegate: Item {
                id: deviceDelegate
                required property string deviceId
                required property string deviceName
                required property string description
                required property bool isDefault
                required property bool muted
                required property int volumePercent

                width: ListView.view ? ListView.view.width : 0
                height: 84
                z: deviceCard.cardHovered ? 2 : 0

                Rectangle {
                    id: deviceCard
                    readonly property bool isDefault: deviceDelegate.isDefault
                    readonly property bool isMuted: deviceDelegate.muted
                    readonly property string targetKey: deviceDelegate.deviceName || deviceDelegate.deviceId
                    readonly property bool cardHovered: deviceHover.hovered || deviceSlider.hovered || deviceSlider.pressed || defaultClickMouse.containsMouse || deviceMuteMouse.containsMouse || devicePctMouse.containsMouse

                    anchors.centerIn: parent
                    width: Math.max(0, parent.width - root.hoverInsetX * 2)
                    height: parent.height
                    radius: Theme.radius
                    color: Theme.surfaceSubtle(1.25)
                    border.width: 0
                    transformOrigin: Item.Center
                    scale: (cardHovered && !root.reducedMotion) ? 1.05 : 1.0

                    Behavior on scale {
                        enabled: !root.reducedMotion
                        NumberAnimation {
                            duration: deviceCard.cardHovered ? HAnimation.buttonHoverDuration : HAnimation.buttonReleaseDuration
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: deviceCard.cardHovered ? HAnimation.buttonHoverCurve : HAnimation.buttonReleaseCurve
                        }
                    }

                    HoverHandler {
                        id: deviceHover
                        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    }

                    // Top row: Solid Accent default badge (no outline border) + device name
                    Item {
                        id: deviceTopRow
                        anchors.top: parent.top
                        anchors.topMargin: 8
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        height: 26

                        Rectangle {
                            id: defaultBadge
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            width: 22
                            height: 22
                            radius: 11
                            border.width: 0
                            color: deviceCard.isDefault ? Theme.accent : Theme.surface
                            scale: (defaultClickMouse.containsMouse && !root.reducedMotion) ? 1.05 : 1.0

                            Behavior on color {
                                enabled: !root.reducedMotion
                                ColorAnimation { duration: HAnimation.fast }
                            }
                            Behavior on scale {
                                enabled: !root.reducedMotion
                                NumberAnimation {
                                    duration: defaultClickMouse.containsMouse ? HAnimation.buttonHoverDuration : HAnimation.buttonReleaseDuration
                                    easing.type: Easing.BezierSpline
                                    easing.bezierCurve: defaultClickMouse.containsMouse ? HAnimation.buttonHoverCurve : HAnimation.buttonReleaseCurve
                                }
                            }

                            Text {
                                visible: deviceCard.isDefault
                                anchors.centerIn: parent
                                text: "󰄬"
                                font.family: Theme.iconFontFamily
                                font.pixelSize: 14
                                color: Theme.onAccentColor
                            }
                        }

                        Text {
                            id: deviceNameText
                            anchors.left: defaultBadge.right
                            anchors.leftMargin: 10
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: deviceDelegate.description || deviceCard.targetKey || "Unknown device"
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize
                            font.weight: deviceCard.isDefault ? Font.Bold : Font.Medium
                            color: deviceCard.isDefault ? Theme.fg : Theme.fgDim
                            elide: Text.ElideRight
                        }

                        MouseArea {
                            id: defaultClickMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: deviceCard.targetKey.length > 0 && !DeviceHubService.actionBusy
                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                            acceptedButtons: Qt.LeftButton
                            onEntered: DashboardTooltip.show(deviceTopRow, deviceCard.isDefault
                                ? (deviceNameText.text + " (Default)")
                                : ("Set default: " + deviceNameText.text))
                            onExited: DashboardTooltip.hide(deviceTopRow)
                            onClicked: {
                                DashboardTooltip.dismiss()
                                if (root.audioTab === "output") {
                                    DeviceHubService.setDefaultSink(deviceCard.targetKey)
                                } else {
                                    DeviceHubService.setDefaultSource(deviceCard.targetKey)
                                }
                            }
                        }
                    }

                    // Bottom row: Mute button + Shell-standard Pill Slider + Click-to-100% readout
                    Item {
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 8
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        height: 34

                        Rectangle {
                            id: deviceMuteBtn
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            width: 34
                            height: 34
                            radius: 17
                            color: Theme.surface
                            scale: (deviceMuteMouse.containsMouse && !root.reducedMotion) ? 1.05 : 1.0

                            Behavior on scale {
                                enabled: !root.reducedMotion
                                NumberAnimation {
                                    duration: deviceMuteMouse.containsMouse ? HAnimation.buttonHoverDuration : HAnimation.buttonReleaseDuration
                                    easing.type: Easing.BezierSpline
                                    easing.bezierCurve: deviceMuteMouse.containsMouse ? HAnimation.buttonHoverCurve : HAnimation.buttonReleaseCurve
                                }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: root.audioTab === "output"
                                    ? (deviceCard.isMuted ? "󰝟" : "󰕾")
                                    : (deviceCard.isMuted ? "󰍭" : "󰍬")
                                font.family: Theme.iconFontFamily
                                font.pixelSize: 19
                                color: deviceCard.isMuted ? Theme.danger : Theme.fg
                            }

                            MouseArea {
                                id: deviceMuteMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                enabled: deviceCard.targetKey.length > 0
                                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                acceptedButtons: Qt.LeftButton
                                onEntered: DashboardTooltip.show(deviceMuteBtn, deviceCard.isMuted ? "Unmute" : "Mute")
                                onExited: DashboardTooltip.hide(deviceMuteBtn)
                                onClicked: {
                                    DashboardTooltip.dismiss()
                                    if (root.audioTab === "output") {
                                        DeviceHubService.toggleSinkMute(deviceCard.targetKey)
                                    } else {
                                        DeviceHubService.toggleSourceMute(deviceCard.targetKey)
                                    }
                                }
                            }
                        }

                        Slider {
                            id: deviceSlider
                            anchors.left: deviceMuteBtn.right
                            anchors.leftMargin: 8
                            anchors.right: devicePctBtn.left
                            anchors.rightMargin: 4
                            anchors.verticalCenter: parent.verticalCenter
                            height: 28
                            padding: 4
                            from: 0
                            to: 150
                            stepSize: 1
                            snapMode: Slider.SnapAlways
                            live: true
                            wheelEnabled: false
                            enabled: deviceCard.targetKey.length > 0
                            focusPolicy: Qt.NoFocus
                            activeFocusOnTab: false

                            readonly property int backendValue: Math.max(0, Math.min(150, deviceDelegate.volumePercent))
                            property bool _dragging: false
                            property bool _wheelHolding: false
                            property int _lastEmitted: -1

                            function applyVolume(pct) {
                                if (root.audioTab === "output") {
                                    DeviceHubService.setSinkVolume(deviceCard.targetKey, pct)
                                } else {
                                    DeviceHubService.setSourceVolume(deviceCard.targetKey, pct)
                                }
                            }

                            Component.onCompleted: value = backendValue
                            onBackendValueChanged: {
                                if (!pressed && !_wheelHolding) {
                                    value = backendValue
                                }
                            }
                            onPressedChanged: {
                                if (pressed) {
                                    DashboardTooltip.dismiss()
                                    _wheelHolding = false
                                    deviceWheelHold.stop()
                                    _lastEmitted = -1
                                    if (!_dragging) {
                                        _dragging = true
                                        DeviceHubService.beginDrag()
                                    }
                                } else if (_dragging) {
                                    _dragging = false
                                    DeviceHubService.endDrag()
                                }
                            }
                            Component.onDestruction: {
                                if (_dragging) {
                                    _dragging = false
                                    DeviceHubService.endDrag()
                                }
                            }
                            onMoved: {
                                var pct = Math.max(0, Math.min(150, Math.round(value)))
                                if (pressed && Math.abs(pct - 100) <= 4) {
                                    pct = 100
                                    if (Math.round(value) !== 100) value = 100
                                }
                                if (pct !== _lastEmitted) {
                                    _lastEmitted = pct
                                    applyVolume(pct)
                                }
                            }

                            WheelHandler {
                                target: null
                                enabled: deviceSlider.enabled
                                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                                onWheel: event => {
                                    DashboardTooltip.dismiss()
                                    var step = event.angleDelta.y > 0 ? 5 : (event.angleDelta.y < 0 ? -5 : 0)
                                    if (step === 0) return
                                    var cur = Math.round(deviceSlider.value)
                                    var next = Math.max(0, Math.min(150, cur + step))
                                    // Stop cleanly at 100% before crossing into or out of boost range.
                                    if ((cur < 100 && next > 100) || (cur > 100 && next < 100)) {
                                        next = 100
                                    }
                                    deviceSlider.value = next
                                    deviceSlider._wheelHolding = true
                                    deviceWheelHold.restart()
                                    if (next !== deviceSlider._lastEmitted) {
                                        deviceSlider._lastEmitted = next
                                        deviceSlider.applyVolume(next)
                                    }
                                    event.accepted = true
                                }
                            }

                            Timer {
                                id: deviceWheelHold
                                interval: 700
                                repeat: false
                                onTriggered: {
                                    deviceSlider._wheelHolding = false
                                    if (!deviceSlider.pressed) deviceSlider.value = deviceSlider.backendValue
                                }
                            }

                            background: Rectangle {
                                x: deviceSlider.leftPadding
                                y: deviceSlider.topPadding + deviceSlider.availableHeight / 2 - height / 2
                                width: deviceSlider.availableWidth
                                height: 18
                                radius: height / 2
                                color: Theme.surface

                                Rectangle {
                                    id: deviceFill
                                    width: deviceSlider.handle
                                        ? Math.max(0, Math.min(parent.width, deviceSlider.handle.x - parent.x + deviceSlider.handle.width))
                                        : 0
                                    height: parent.height
                                    radius: parent.radius
                                    color: deviceCard.isMuted ? Theme.fgMuted : Theme.accent
                                }

                                // 100% unity reference notch
                                Rectangle {
                                    readonly property real markX: Math.round(parent.width * (100 / 150)) - 1
                                    readonly property bool covered: deviceFill.width >= markX + 1
                                    x: markX
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 2
                                    height: Math.round(parent.height * 0.55)
                                    radius: 1
                                    color: covered ? Theme.onAccentColor : Theme.fgMuted
                                    opacity: covered ? 0.45 : 0.5
                                }
                            }

                            handle: Item {
                                x: deviceSlider.leftPadding + deviceSlider.visualPosition * (deviceSlider.availableWidth - width)
                                y: deviceSlider.topPadding + deviceSlider.availableHeight / 2 - height / 2
                                width: 20
                                height: 20

                                Rectangle {
                                    anchors.centerIn: parent
                                    width: deviceSlider.pressed ? 14 : 12
                                    height: width
                                    radius: width / 2
                                    color: Theme.onAccentColor
                                    opacity: deviceSlider.pressed ? 1.0 : 0.85
                                }
                            }
                        }

                        Item {
                            id: devicePctBtn
                            readonly property int shownPct: Math.round(deviceSlider.value)
                            readonly property bool isUnity: shownPct === 100
                            readonly property bool isBoosted: shownPct > 100
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            width: 46
                            height: 26
                            scale: (devicePctMouse.containsMouse && !isUnity && !root.reducedMotion) ? 1.05 : 1.0

                            Behavior on scale {
                                enabled: !root.reducedMotion
                                NumberAnimation {
                                    duration: devicePctMouse.containsMouse ? HAnimation.buttonHoverDuration : HAnimation.buttonReleaseDuration
                                    easing.type: Easing.BezierSpline
                                    easing.bezierCurve: devicePctMouse.containsMouse ? HAnimation.buttonHoverCurve : HAnimation.buttonReleaseCurve
                                }
                            }

                            Text {
                                id: devicePctText
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                text: devicePctBtn.shownPct + "%"
                                font.family: Theme.iconFontFamily
                                font.pixelSize: Math.max(11, Theme.fontSize - 1)
                                font.weight: (devicePctBtn.isUnity || devicePctBtn.isBoosted) ? Font.DemiBold : Font.Medium
                                color: deviceCard.isMuted ? Theme.fgMuted
                                    : (devicePctBtn.isBoosted ? Theme.accent
                                        : (devicePctBtn.isUnity ? Theme.fg : Theme.fgDim))
                            }

                            MouseArea {
                                id: devicePctMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                enabled: deviceSlider.enabled
                                cursorShape: (!devicePctBtn.isUnity && enabled) ? Qt.PointingHandCursor : Qt.ArrowCursor
                                acceptedButtons: Qt.LeftButton
                                onEntered: if (!devicePctBtn.isUnity && enabled) DashboardTooltip.show(devicePctBtn, "Click to set 100%")
                                onExited: DashboardTooltip.hide(devicePctBtn)
                                onClicked: {
                                    if (devicePctBtn.isUnity) return
                                    DashboardTooltip.dismiss()
                                    deviceSlider.value = 100
                                    deviceSlider._wheelHolding = true
                                    deviceWheelHold.restart()
                                    deviceSlider._lastEmitted = 100
                                    deviceSlider.applyVolume(100)
                                }
                            }
                        }
                    }
                }
            }
        }

        // Empty state message
        Text {
            anchors.centerIn: parent
            visible: DeviceHubService.initialized
                && ((root.audioTab === "apps" && streamList.count === 0)
                    || (root.audioTab !== "apps" && deviceList.count === 0))
            width: Math.max(0, parent.width - root.hoverInsetX * 2)
            horizontalAlignment: Text.AlignHCenter
            text: {
                if (DeviceHubService.error.length > 0) return DeviceHubService.error
                if (root.audioTab === "apps") return "No active audio playback"
                if (root.audioTab === "output") return "No output devices found"
                return "No input devices found"
            }
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            color: DeviceHubService.error.length > 0 ? Theme.danger : Theme.fgMuted
            wrapMode: Text.WordWrap
        }
    }
}
