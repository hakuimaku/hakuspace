import QtQuick
import Quickshell
import Quickshell.Wayland
import "../services"
import "lock"

Scope {
    id: root

    // Prepare an ordinary overlay while locked, then reveal the desktop after PAM unlock.
    property bool releaseActive: false
    property real releaseProgress: 0

    Connections {
        target: LockState
        function onAuthStateChanged() {
            if (LockState.authState === "Success" && !LockState.reducedMotion) {
                root.releaseProgress = 0
                root.releaseActive = true
            }
        }
        function onLockedChanged() {
            if (LockState.locked) {
                releaseAnim.stop()
                root.releaseActive = false
                root.releaseProgress = 0
            } else if (root.releaseActive) {
                releaseAnim.restart()
            }
        }
    }

    NumberAnimation {
        id: releaseAnim
        target: root
        property: "releaseProgress"
        from: 0
        to: 1
        duration: 1600
        easing.type: Easing.Linear
        onFinished: root.releaseActive = false
    }

    Variants {
        model: Quickshell.screens
        LockReleaseOverlay {
            visible: root.releaseActive
            progress: root.releaseProgress
        }
    }

    // Single Wayland session-lock owner across the entire Hikai runtime.
    WlSessionLock {
        id: sessionLock
        reloadableId: "hakuspace-session-lock"
        locked: LockState.locked

        onSecureStateChanged: {
            LockState.secure = sessionLock.secure
        }

        onLockStateChanged: {
            LockState.secure = sessionLock.secure
        }

        WlSessionLockSurface {
            id: surf
            color: Theme.surface

            property var boundScreen: null
            readonly property bool screenValid: boundScreen !== null
                                                && screen === boundScreen
                                                && width > 1
                                                && height > 1

            onScreenChanged: {
                if (boundScreen === null && screen !== null) {
                    boundScreen = screen
                }
            }

            LockSurface {
                id: surfaceItem
                width: surf.boundScreen ? surf.boundScreen.width : 1920
                height: surf.boundScreen ? surf.boundScreen.height : 1080
                interactive: true
                animationsEnabled: surf.screenValid
            }
        }
    }
}
