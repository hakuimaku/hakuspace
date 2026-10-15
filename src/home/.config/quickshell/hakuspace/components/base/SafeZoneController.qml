import QtQuick
import "../../services"

Item {
    id: root
    visible: false
    property bool active: false
    property bool closing: false
    property bool closeOnPointerExit: true
    property int graceMs: Interaction.safeZoneGraceMs
    property var containsPoint: null
    property bool pointerInside: false
    property bool keyboardLease: false
    property bool animationLease: false
    property var externalTokens: []
    readonly property bool externallyLeased: externalTokens.length > 0
    readonly property bool closePending: closeTimer.running
    readonly property bool focusRestoreLease: focusRestoreTimer.running
    property real lastPointerX: -1
    property real lastPointerY: -1
    signal closeRequested(string reason)
    signal pointerModeEntered()
    signal keyboardModeEntered()

    onActiveChanged: { if (active) open(); else reset() }
    onClosingChanged: if (closing) cancelClose()
    onKeyboardLeaseChanged: { if (keyboardLease) cancelClose(); else scheduleClose() }
    Component.onDestruction: reset()

    Timer { id: closeTimer; interval: root.graceMs; onTriggered: root.commitClose() }
    Timer { id: focusRestoreTimer; interval: Interaction.focusRestoreLeaseMs; onTriggered: Qt.callLater(root.scheduleClose) }

    function open() {
        reset()
        keyboardLease = true
        keyboardModeEntered()
    }

    function reset() {
        closeTimer.stop()
        focusRestoreTimer.stop()
        pointerInside = false
        keyboardLease = false
        animationLease = false
        externalTokens = []
        lastPointerX = -1
        lastPointerY = -1
        closeTimer.stop()
    }

    function pointerEntered(x, y) { pointerMoved(x, y) }

    function pointerMoved(x, y) {
        if (!active || closing) return
        var moved = lastPointerX >= 0 && Math.hypot(x - lastPointerX, y - lastPointerY)
            >= Interaction.pointerModeThreshold
        lastPointerX = x
        lastPointerY = y
        pointerInside = containsPoint ? containsPoint(x, y) : true
        if (moved && pointerInside && keyboardLease) forcePointerMode()
        if (pointerInside) cancelClose()
        else scheduleClose()
    }

    function pointerExited() {
        if (!active || closing) return
        pointerInside = false
        scheduleClose()
    }

    function beginKeyboardLease() { forceKeyboardMode() }
    function releaseKeyboardLease() {
        keyboardLease = false
        scheduleClose()
    }
    function beginAnimationLease() { animationLease = true; cancelClose() }
    function endAnimationLease() { animationLease = false; scheduleClose() }

    function acquireExternalLease(token) {
        if (!token || externalTokens.indexOf(token) >= 0) return
        externalTokens = externalTokens.concat([token])
        cancelClose()
    }

    function releaseExternalLease(token, restoreKeyboardFocus) {
        var index = externalTokens.indexOf(token)
        if (index < 0) return
        externalTokens = externalTokens.filter(function(value) { return value !== token })
        if (restoreKeyboardFocus) {
            beginKeyboardLease()
            focusRestoreTimer.restart()
        }
        scheduleClose()
    }

    function cancelClose() { closeTimer.stop() }
    function scheduleClose() {
        if (active && !closing && closeOnPointerExit && !pointerInside && !keyboardLease
                && !externallyLeased && !animationLease && !focusRestoreLease && !closeTimer.running)
            closeTimer.start()
    }
    function commitClose() {
        if (active && !closing && closeOnPointerExit && !pointerInside && !keyboardLease
                && !externallyLeased && !animationLease && !focusRestoreLease)
            closeRequested("pointer-exit")
    }
    function forcePointerMode() {
        if (!keyboardLease) return
        keyboardLease = false
        pointerModeEntered()
        scheduleClose()
    }
    function forceKeyboardMode() {
        keyboardLease = true
        cancelClose()
        keyboardModeEntered()
    }
}
