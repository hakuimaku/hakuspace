import QtQuick
import "services"
import "components/settings" as Settings
import "components/flare" as Flare

Item {
    id: root
    width: 600
    height: 600
    // Advance only after each asynchronous backend operation finishes.
    property int phase: 0
    property int ticks: 0

    // Fail the process as well as the QML assertion so CI cannot accept a warning.
    function check(ok, message) {
        if (ok) return
        console.error("Hikai settings failed: " + message)
        Qt.exit(1)
        throw new Error(message)
    }
    // Exercise the actual page and slider types while using an isolated backend.
    Settings.ShellSettingsPage { width: 580; height: 580 }
    Settings.SettingsSlider { id: slider; from: 4; to: 24; visible: false; value: ShellSettingsStore.baseRadius }
    Item { id: liveAnchor; x: 33; y: 8; width: 24; height: 20 }
    Flare.FlareMorph {
        id: anchorMorph
        anchorRect: ({x: 1180, y: 8, width: 32, height: 24})
        hostRect: ({x: 1000, y: 0, width: 280, height: 720})
    }
    Flare.FlareMorph {
        id: boundsMorph
        anchorRect: ({x: 0, y: 8, width: 24, height: 20})
        hostRect: ({x: 0, y: 0, width: 320, height: 720})
        bounds: ({start: 0, end: 320})
        contentW: 100
        contentH: 40
        shown: true
        openDuration: 0
        retargetDuration: 0
    }
    Flare.FlareSurface {
        id: flare
        start: 0
        end: 320
        currentHeight: 180
        bounds: ({start: 0, end: 320})
    }

    Timer {
        interval: 30
        repeat: true
        running: true
        onTriggered: {
            root.check(++root.ticks < 200, "backend timeout: " + ShellSettingsStore.error)
            if (ShellSettingsStore.loading || ShellSettingsStore.saving) return
            root.check(!ShellSettingsStore.error, ShellSettingsStore.error)
            if (root.phase === 0) {
                if (!ShellSettingsStore.ready) return
                if (ShellSettingsStore.migrationPending) {
                    root.check(!ShellSettingsStore.dirty, "migration alone is not an unsaved user edit")
                    ShellSettingsStore.apply()
                    return
                }
                root.check(!ShellSettingsStore.dirty && ShellSettingsStore.valid, "initial defaults")
                root.check(anchorMorph.anchorSpan().start === 180 && anchorMorph.anchorSpan().end === 212, "captured anchor localization")
                anchorMorph.anchorItem = liveAnchor
                root.check(anchorMorph.anchorSpan().start === 33 && anchorMorph.anchorSpan().end === 57, "live anchor keeps priority")
                for (var radius of [4, 12, 24]) {
                    ShellSettingsStore.setValue("appearance", "baseRadius", radius)
                    root.check(Theme.radius === radius && Theme.largeRadius === radius + 4
                        && ScreenGeometry.roundedRadius === 20 && Theme.hugRadius === radius + 16
                        && Theme.giantRadius === radius + 36, "radius family " + radius)
                    root.check(slider.value === radius && flare.r === radius + 12, "live bindings")
                    root.check(flare.p.footStart.scale >= 0 && flare.p.footEnd.scale >= 0, "flare bounds")
                }
                // Physical screen settings never change card radius or the TopBar attachment.
                var attachment = ScreenGeometry.flareTopY
                root.check(attachment === Theme.topBarHeight && attachment === Theme.topBarContentHeight + 4, "TopBar owns the complete upper chassis")
                for (var screenRadius of [0, 4, 20, 24]) {
                    ShellSettingsStore.setValue("roundedScreen", "radius", screenRadius)
                    root.check(ScreenGeometry.roundedRadius === screenRadius && Theme.radius === 24, "independent screen radius")
                    for (var border of [0, 1, 4, 6]) {
                        ShellSettingsStore.setValue("roundedScreen", "borderThickness", border)
                        var bounds = ScreenGeometry.horizontalBounds(320)
                        root.check(bounds.start === border && bounds.end === 320 - border, "live side bounds")
                        root.check(ScreenGeometry.flareTopY === attachment, "border never moves Flare Y")
                    }
                }
                ShellSettingsStore.setValue("appearance", "baseRadius", 4)
                root.check(ScreenGeometry.roundedRadius === 24, "component radius leaves screen radius alone")
                for (var tone of ["ink", "dark", "soft"]) {
                    ShellSettingsStore.setValue("appearance", "surfaceTone", tone)
                    root.check(String(Theme.surface) === ({ink: "#000000", dark: "#0b0b0b", soft: "#171717"})[tone], "surface " + tone)
                    root.check(Theme.hoverMuted === ({ink: "#202020", dark: "#2b2b2b", soft: "#333333"})[tone], "hover " + tone)
                }
                ShellSettingsStore.discard()
                root.check(Theme.radius === 12 && String(Theme.surface) === "#0b0b0b" && !ShellSettingsStore.dirty, "discard live preview")
                ShellSettingsStore.setValue("appearance", "baseRadius", 20)
                ShellSettingsStore.setValue("appearance", "surfaceTone", "soft")
                ShellSettingsStore.setValue("topbar", "tray", false)
                ShellSettingsStore.setValue("roundedScreen", "radius", 24)
                ShellSettingsStore.setValue("roundedScreen", "borderThickness", 6)
                // Old generated files must not reclaim shell-owned properties.
                Theme.apply(JSON.stringify({accent: "#aabbcc", font: "monospace", fontSize: 17,
                    surface: "#ff0000", hoverMuted: "#ff0000", radius: 99, largeRadius: 99, hugRadius: 99, giantRadius: 99}))
                root.check(Theme.radius === 20 && String(Theme.surface) === "#171717" && !ShellSettingsStore.showTray, "theme isolation")
                root.check(ScreenGeometry.roundedRadius === 24 && ScreenGeometry.borderThickness === 6, "theme leaves screen preferences intact")
                root.check(Theme.accent === "#aabbcc" && Theme.font === "monospace" && Theme.fontSize === 17, "dynamic theme still applies")
                ShellSettingsStore.setValue("topbar", "tray", "false")
                ShellSettingsStore.setValue("appearance", "baseRadius", 99)
                root.check(!ShellSettingsStore.showTray && Theme.radius === 20, "invalid edits rejected")
                ShellSettingsStore.apply()
            } else if (root.phase === 1) {
                root.check(!ShellSettingsStore.dirty && ShellSettingsStore.savedValues.appearance.baseRadius === 20, "apply snapshot")
                root.check(ShellSettingsStore.savedValues.roundedScreen.radius === 24
                    && ShellSettingsStore.savedValues.roundedScreen.borderThickness === 6, "Apply saves both screen preferences")
                boundsMorph._lastAnimTime = Date.now()
                boundsMorph.bounds = {start: 1, end: 319}
                ShellSettingsStore.reload()
            } else if (root.phase === 2) {
                root.check(boundsMorph.mStart === 1, "one-pixel border change retargets an open Flare")
                root.check(Theme.radius === 20 && !ShellSettingsStore.showTray, "persistence after reload")
                root.check(ScreenGeometry.roundedRadius === 24 && ScreenGeometry.borderThickness === 6, "reload preserves both screen preferences")
                ShellSettingsStore.reset()
                root.check(Theme.radius === 12 && ShellSettingsStore.showTray && ShellSettingsStore.dirty, "reset previews defaults")
                root.check(ScreenGeometry.roundedRadius === 20 && ScreenGeometry.borderThickness === 4, "Reset previews screen defaults")
                ShellSettingsStore.discard()
                root.check(Theme.radius === 20 && !ShellSettingsStore.showTray && !ShellSettingsStore.dirty, "reset then discard")
                root.check(ScreenGeometry.roundedRadius === 24 && ScreenGeometry.borderThickness === 6, "Discard restores both screen preferences")
                ShellSettingsStore.reset()
                ShellSettingsStore.apply()
            } else if (root.phase === 3) {
                root.check(Theme.radius === 12 && ShellSettingsStore.showTray && !ShellSettingsStore.dirty, "reset then apply")
                ShellSettingsStore.reload()
            } else {
                root.check(Theme.radius === 12 && !ShellSettingsStore.dirty, "persisted reset")
                console.info("Hikai settings checks passed")
                Qt.quit()
            }
            root.phase++
        }
    }
}
