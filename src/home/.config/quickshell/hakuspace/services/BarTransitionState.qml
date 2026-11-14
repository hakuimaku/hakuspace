pragma Singleton
import QtQuick

QtObject {
    id: root

    // Enabled by shell.qml so standalone test harnesses keep synchronous bar visibility.
    property bool hostActive: false
    property bool armed: false

    property string phase: "idle" // "idle" | "hiding" | "moving" | "showing"
    property string fromEdge: ChromeLayout.statusEdge
    property string toEdge: ChromeLayout.statusEdge
    property string settledEdge: ChromeLayout.statusEdge
    property bool overlayVisible: false

    readonly property bool active: phase !== "idle"
    readonly property bool moving: phase === "moving"
    readonly property string visualEdge: !hostActive || !armed ? ChromeLayout.statusEdge
        : phase === "hiding" ? fromEdge
        : phase === "moving" ? ""
        : phase === "showing" ? toEdge
        : settledEdge

    // Keep LeftBar instantiated while active on left or transitioning to/from left.
    readonly property bool keepLeftBarMounted: !hostActive || !armed ? ChromeLayout.leftBarMode
        : (settledEdge === "left" || fromEdge === "left" || toEdge === "left")

    // Map target Wayland surfaces at transition start so handoffs only toggle scene-graph visibility.
    readonly property bool topWindowMapped: !hostActive || !armed ? ChromeLayout.topStatusBarVisible
        : (visualEdge === "top" || (active && (fromEdge === "top" || toEdge === "top")))
    readonly property bool leftWindowMapped: !hostActive || !armed ? ChromeLayout.leftBarMode
        : (visualEdge === "left" || (active && (fromEdge === "left" || toEdge === "left")))
    readonly property bool bottomWindowMapped: !hostActive || !armed ? ChromeLayout.taskbarMode
        : (visualEdge === "bottom" || (active && (fromEdge === "bottom" || toEdge === "bottom")))

    property real modulesOpacity: 1
    property real moveProgress: 0

    readonly property int moduleFadeDuration: 500
    readonly property int moveDuration: 700
    readonly property int handoffOverlapDuration: 32

    readonly property bool shouldArm: hostActive && ShellSettingsStore.ready && ShellTransitionState.chromeEnabled
    onShouldArmChanged: {
        if (shouldArm && !armed) armTimer.restart()
        else if (!shouldArm) {
            armTimer.stop()
            armed = false
        }
    }

    property Timer armTimer: Timer {
        interval: 150
        repeat: false
        onTriggered: {
            root.settledEdge = ChromeLayout.statusEdge
            root.fromEdge = root.settledEdge
            root.toEdge = root.settledEdge
            root.armed = true
        }
    }

    property Connections layoutConn: Connections {
        target: ChromeLayout
        function onStatusEdgeChanged() {
            var nextEdge = ChromeLayout.statusEdge
            if (!root.armed) {
                root.settledEdge = nextEdge
                root.fromEdge = nextEdge
                root.toEdge = nextEdge
                return
            }
            root.startTransition(nextEdge)
        }
    }

    function finishTransition() {
        overlayVisible = false
        fromEdge = settledEdge
        toEdge = settledEdge
        phase = "idle"
    }

    function startTransition(nextEdge) {
        if (phase === "idle" && nextEdge === settledEdge) return
        TooltipManager.dismiss()

        if (phase === "hiding") {
            // Coalesce multi-file updates or quick reversals before the bar layer moves.
            if (nextEdge === fromEdge) {
                transitionSeq.stop()
                overlayVisible = false
                toEdge = fromEdge
                settledEdge = fromEdge
                phase = "showing"
                showOnlyAnim.from = modulesOpacity
                resumeShow.restart()
                return
            }
            toEdge = nextEdge
            settledEdge = nextEdge
            return
        }

        if (phase === "moving" || phase === "showing") {
            transitionSeq.stop()
            resumeMove.stop()
            resumeShow.stop()
            fromEdge = toEdge
            toEdge = nextEdge
            settledEdge = nextEdge
            moveProgress = 0
            if (modulesOpacity <= 0.01) {
                modulesOpacity = 0
                overlayVisible = true
                phase = "moving"
                resumeMove.restart()
            } else {
                overlayVisible = false
                phase = "hiding"
                hideAnim.from = modulesOpacity
                transitionSeq.restart()
            }
            return
        }

        fromEdge = settledEdge
        toEdge = nextEdge
        settledEdge = nextEdge
        moveProgress = 0
        modulesOpacity = 1
        overlayVisible = false
        hideAnim.from = 1
        phase = "hiding"
        transitionSeq.restart()
    }

    property SequentialAnimation transitionSeq: SequentialAnimation {
        NumberAnimation {
            id: hideAnim
            target: root
            property: "modulesOpacity"
            from: 1
            to: 0
            duration: root.moduleFadeDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: HAnimation.tooltipCurve
        }
        // Present the overlay at p=0 before hiding the outgoing bar to prevent a 1-frame Wayland commit gap.
        PropertyAction { target: root; property: "overlayVisible"; value: true }
        PauseAnimation { duration: root.handoffOverlapDuration }
        PropertyAction { target: root; property: "phase"; value: "moving" }
        NumberAnimation {
            target: root
            property: "moveProgress"
            from: 0
            to: 1
            duration: root.moveDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: HAnimation.barTransitionCurve
        }
        // Present the incoming bar at opacity=0 before hiding the overlay at p=1.
        PropertyAction { target: root; property: "phase"; value: "showing" }
        PauseAnimation { duration: root.handoffOverlapDuration }
        PropertyAction { target: root; property: "overlayVisible"; value: false }
        NumberAnimation {
            target: root
            property: "modulesOpacity"
            from: 0
            to: 1
            duration: root.moduleFadeDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: HAnimation.moduleCurve
        }
        ScriptAction { script: root.finishTransition() }
    }

    property SequentialAnimation resumeMove: SequentialAnimation {
        NumberAnimation {
            target: root
            property: "moveProgress"
            from: 0
            to: 1
            duration: root.moveDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: HAnimation.barTransitionCurve
        }
        PropertyAction { target: root; property: "phase"; value: "showing" }
        PauseAnimation { duration: root.handoffOverlapDuration }
        PropertyAction { target: root; property: "overlayVisible"; value: false }
        NumberAnimation {
            target: root
            property: "modulesOpacity"
            from: 0
            to: 1
            duration: root.moduleFadeDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: HAnimation.moduleCurve
        }
        ScriptAction { script: root.finishTransition() }
    }

    property SequentialAnimation resumeShow: SequentialAnimation {
        NumberAnimation {
            id: showOnlyAnim
            target: root
            property: "modulesOpacity"
            from: 0
            to: 1
            duration: root.moduleFadeDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: HAnimation.moduleCurve
        }
        ScriptAction { script: root.finishTransition() }
    }
}
