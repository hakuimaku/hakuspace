import QtQuick
import "components/base" as Base

Item {
    id: root
    property int closes: 0
    property int phase: 0

    function check(ok, message) {
        if (ok) return
        console.error("SafeZoneController failed: " + message)
        Qt.exit(1)
        throw new Error(message)
    }

    Base.SafeZoneController {
        id: zone
        graceMs: 30
        containsPoint: function(x, y) { return x >= 0 && x <= 100 && y >= 0 && y <= 100 }
        onCloseRequested: root.closes++
    }
    Component { id: zoneFactory; Base.SafeZoneController { graceMs: 30 } }
    property var doomedZone: null

    Timer {
        id: step
        interval: 45
        onTriggered: {
            if (root.phase === 0) {
                root.check(root.closes === 0, "reentry canceled close")
                zone.pointerExited()
                zone.acquireExternalLease("file")
                zone.acquireExternalLease("folder")
                root.check(!zone.closePending, "external lease blocks close")
                zone.releaseExternalLease("file", false)
                root.check(!zone.closePending, "second external lease survives")
                zone.releaseExternalLease("folder", false)
                root.check(zone.closePending, "last lease release schedules close")
                zone.beginAnimationLease()
                root.check(!zone.closePending, "animation lease blocks close")
                zone.endAnimationLease()
                zone.beginKeyboardLease()
                root.check(!zone.closePending, "keyboard lease blocks close")
                zone.releaseKeyboardLease()
                root.check(zone.closePending, "keyboard lease release schedules close")
            } else if (root.phase === 1) {
                root.check(root.closes === 1, "timer commits close once")
                zone.pointerExited()
                zone.active = false
            } else if (root.phase === 2) {
                root.check(root.closes === 1, "reset cancels delayed close")
                root.doomedZone = zoneFactory.createObject(root)
                root.doomedZone.closeRequested.connect(function() { root.closes++ })
                root.doomedZone.active = true
                root.doomedZone.forcePointerMode()
                root.doomedZone.pointerExited()
                root.check(root.doomedZone.closePending, "destroy test has pending close")
                root.doomedZone.destroy()
                root.doomedZone = null
            } else if (root.phase === 3) {
                root.check(root.closes === 1, "destroy cancels delayed close")
                zone.active = true
                zone.pointerEntered(10, 10)
                zone.pointerMoved(13, 10)
                zone.pointerExited()
                zone.acquireExternalLease("chooser")
                zone.releaseExternalLease("chooser", true)
                zone.forcePointerMode()
                root.check(zone.focusRestoreLease && !zone.closePending,
                    "focus restoration blocks pointer close")
                step.interval = 190
            } else {
                root.check(zone.closePending, "focus lease expiry resumes close timer")
                zone.pointerEntered(15, 10)
                root.check(!zone.closePending && root.closes === 1,
                    "reentry after focus restoration wins")
                console.info("SafeZoneController passed")
                Qt.quit()
                return
            }
            root.phase++
            step.start()
        }
    }

    Component.onCompleted: {
        zone.active = true
        root.check(zone.keyboardLease, "open starts with keyboard lease")
        zone.pointerEntered(10, 10)
        zone.pointerMoved(13, 10)
        root.check(!zone.keyboardLease, "pointer motion transfers ownership")
        zone.closeOnPointerExit = false
        zone.pointerExited()
        root.check(!zone.closePending, "modal policy disables pointer close")
        zone.closeOnPointerExit = true
        zone.pointerEntered(13, 10)
        zone.pointerExited()
        root.check(zone.closePending, "exit schedules close")
        zone.pointerEntered(14, 10)
        root.check(!zone.closePending, "reentry cancels close")
        zone.commitClose()
        root.check(root.closes === 0, "commit rechecks reentry")
        step.start()
    }
}
