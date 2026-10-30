import QtQuick
import Quickshell
import Quickshell.Io
import "services"
import "components"

ShellRoot {
    // Only the disposable compositor receives this native session lock.
    LockSession {}
    Component.onCompleted: {
        Quickshell.watchFiles = false
        if (Quickshell.env("HAKUSPACE_LOCK_PROFILE_DEFER") !== "1") LockState.requestLock()
    }
    IpcHandler {
        target: "memoryProbe"
        function status(): string {
            return JSON.stringify({lock: JSON.parse(LockState.status()), idle: JSON.parse(IdleService.status()),
                displayOff: LockMemoryProbe.displayOff, surfaces: LockMemoryProbe.snapshot()})
        }
        function displayOff(value: bool) {
            LockMemoryProbe.displayOff = value
            if (typeof IdleService.displayOff === "boolean") IdleService.displayOff = value
        }
        function wake() {
            for (var surface of LockMemoryProbe.surfaces) {
                var motion = surface.motionController
                if (typeof motion.wakeAmbient === "function") motion.wakeAmbient()
            }
        }
        function lock() { LockState.requestLock() }
        function unlock(): bool {
            LockState.pam.configDirectory = Quickshell.env("HAKUSPACE_LOCK_PROFILE_PAM")
            LockState.pam.config = "lock-profile-permit"
            return LockState.submit("private-fixture")
        }
    }
}
