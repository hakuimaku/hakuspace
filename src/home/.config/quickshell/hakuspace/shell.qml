//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "services"
import "components"
import "components/wallpaper" as Wallpaper

import "ipc" as Ipc

ShellRoot {
    id: root
    // Stop wallpaper workers before Quickshell interrupts the departing configuration.
    Component.onDestruction: WallpaperService.shutdown()
    // Keep idle and logind hooks resident even before the first diagnostic IPC call.
    readonly property bool nativeIdleEnabled: IdleService.enabled

    DesktopColorScheme {}

    // Bootstrap keeps all ordinary surfaces absent until the cover barrier.
    readonly property var hikaiScreenModel: ShellTransitionState.chromeEnabled ? Quickshell.screens : []

    // Consume the bootstrap guard once, including across in-process reloads.
    PersistentProperties {
        id: transitionMemory
        reloadableId: "hakuspace-shell-transition-bootstrap"
        property bool bootstrapComplete: false
        onLoaded: {
            if (bootstrapComplete) ShellTransitionState.chromeEnabled = true
        }
    }

    Connections {
        target: ShellTransitionState
        function onFinishedAndQuit() { Qt.quit() }
        function onChromeEnabledChanged() {
            if (ShellTransitionState.chromeEnabled) transitionMemory.bootstrapComplete = true
        }
    }

    PersistentProperties {
        id: notificationMemory
        reloadableId: "hakuspace-notification-records"
        property string recordsJson: "[]"
        property int nextKey: 1
        // Restore history before the native server activates.
        onLoaded: NotificationStore.start(notificationMemory)
    }

    Ipc.SystemIpc {
        id: systemIpc
    }

    Ipc.MediaIpc {}
    Ipc.NavigationIpc {}
    Ipc.UtilityIpc {}

    PersistentProperties {
        id: lockMemory
        reloadableId: "hakuspace-lock-state"
        property bool locked: false
        onLoaded: {
            if (locked && !LockState.locked) LockState.requestLock()
        }
    }

    Connections {
        target: LockState
        function onLockedChanged() {
            lockMemory.locked = LockState.locked
        }
    }



    LockSession { id: lockSession }

    // Classic instantiates neither the telemetry service nor its timers/processes.
    LazyLoader {
        active: AppState.shellBackend === "hikai"
        MemoryMaintenanceHost {
            hosts: ephemeralHosts.instances
            externalBusy: systemIpc.maintenanceBusy || lockSession.releaseActive
        }
    }

    Variants {
        model: root.hikaiScreenModel
        TopBar {}
    }

    Variants {
        model: ChromeLayout.leftBarMode ? root.hikaiScreenModel : []
        LeftBar {}
    }

    // Separate hosts reuse the same app content without sharing enable policy.
    Variants {
        model: root.hikaiScreenModel
        Taskbar {}
    }
    Variants {
        model: root.hikaiScreenModel
        DockBar {}
    }


    // Cava owns its audio processing and animated surfaces in a separate process.
    CavaRendererHost { service: CavaService; screens: root.hikaiScreenModel }

    // Enumerate screens cheaply and create heavy surfaces only while needed.
    Variants {
        id: ephemeralHosts
        model: root.hikaiScreenModel
        EphemeralSurfaces {}
    }

    // Persistent wallpaper renderers are independent from browser visibility.
    Variants {
        model: root.hikaiScreenModel
        Wallpaper.WallpaperSurface {}
    }

    Variants {
        model: root.hikaiScreenModel
        RoundedScreen {}
    }

    // Map last so an active wipe sits above existing Hikai overlay panels.
    Variants {
        model: Quickshell.screens
        ShellTransitionOverlay {}
    }
}
