import QtQuick
import Quickshell
import Quickshell.Io
import "services"
import "components/settings" as Settings
import "components/motion" as Motion
import "components/hakumenu" as HakuMenu

ShellRoot {
    id: root
    // Await asynchronous settings IO before testing the next persistence boundary.
    property int phase: 0
    property int ticks: 0
    property bool capturing: false
    // Observe actual stretching frames, not only the final selected state.
    property bool segmentMotionObserved: false
    property bool segmentStretchObserved: false
    property string captureName: ""
    property var tones: ["ink", "dark", "soft"]
    DesktopColorScheme { id: desktopScheme }
    // Exercise the Theme tab against the real settings writer and mode owner.
    HakuMenu.ThemeList {
        id: themeList
        width: 600
        height: 600
        leftColumnWidth: 440
        stateColumnWidth: 144
        query: "~ light"
        onLaunched: closeMenu => root.check(!closeMenu, "mode toggle keeps HakuMenu open")
    }
    FileView { id: schemeFile; path: Quickshell.env("HOME") + "/color-scheme"; printErrors: false }
    FileView { id: gtkThemeFile; path: Quickshell.env("HOME") + "/gtk-theme"; printErrors: false }
    FileView { id: iconThemeFile; path: Quickshell.env("HOME") + "/icon-theme"; printErrors: false }
    FileView { id: kittyFile; path: Quickshell.env("HOME") + "/.local/state/hakuspace/theme/kitty-mode.conf"; printErrors: false }
    // Read the stub's completed write rather than assuming process launch means success.
    function checkScheme(expected) {
        schemeFile.reload()
        schemeFile.waitForJob()
        root.check(schemeFile.text().trim() === expected, "desktop scheme " + expected)
        var suffix = expected === "prefer-light" ? "-Light" : ""
        gtkThemeFile.reload(); gtkThemeFile.waitForJob()
        iconThemeFile.reload(); iconThemeFile.waitForJob()
        root.check(gtkThemeFile.text().trim() === "Hikaide" + suffix, "GTK follows effective mode")
        root.check(iconThemeFile.text().trim() === "Hikaide-Symbols" + suffix, "icons follow effective mode")
        kittyFile.reload()
        kittyFile.waitForJob()
        if (expected === "prefer-light") {
            root.check(kittyFile.text().includes("background " + String(Theme.surface) + "\n"), "Kitty follows the surface draft")
            root.check(kittyFile.text().includes("foreground " + String(Theme.accent) + "\n"), "Kitty follows the active accent")
        } else root.check(kittyFile.text().trim() === "", "Dark clears Kitty's Light override")
    }
    FloatingWindow {
        id: window
        implicitWidth: 1000
        implicitHeight: 900
        color: Theme.surface
        Rectangle {
            id: canvas
            anchors.fill: parent
            color: Theme.surface
            Settings.LookSettingsPage { id: page; anchors.fill: parent }
        }
        Motion.MorphButton { id: selectedButton; visible: false; selected: true }
    }
    // Fail both QML execution and the test runner on a violated contract.
    function check(condition, message) {
        if (condition) return
        console.error("Light theme failed: " + message)
        Qt.exit(1)
        throw new Error(message)
    }
    // Locate production controls through their public labels.
    function find(item, label) {
        if (item.text === label && typeof item.clicked === "function") return item
        for (var child of item.children || []) {
            var result = find(child, label)
            if (result) return result
        }
        return null
    }
    // Segmented controls use one moving surface beneath transparent input targets.
    function modePill() {
        var button = find(page, "Light")
        return button ? Array.from(button.parent.parent.children).find(item => item.objectName === "settings-segment-selection") : null
    }
    Timer {
        interval: 16; repeat: true
        running: root.phase >= 2 && root.phase <= 4
        onTriggered: {
            var pill = root.modePill()
            if (!pill) return
            if (pill.animatedStartIndex > 0 && pill.animatedStartIndex < 1) root.segmentMotionObserved = true
            if (Math.abs(pill.animatedEndIndex - pill.animatedStartIndex - 1) > 0.001) root.segmentStretchObserved = true
        }
    }
    // Save rendered frames for reviewing all light surface levels.
    function capture(name) {
        capturing = true
        captureName = name
        captureDelay.restart()
    }
    // Settle color animations before recording the requested surface tone.
    Timer {
        id: captureDelay
        interval: HAnimation.selectionMorphDuration + 40
        onTriggered: canvas.grabToImage(result => {
            root.check(result.saveToFile(Quickshell.env("HAKUSPACE_THEME_ARTIFACT_DIR") + "/" + root.captureName + ".png"), "save " + root.captureName)
            root.capturing = false
        })
    }
    Component.onCompleted: { WM.backendName = "niri"; SettingsStore.reload() }
    Timer {
        interval: 100
        running: true
        repeat: true
        onTriggered: {
            root.check(++root.ticks < 150, "timeout: " + ShellSettingsStore.error)
            if (!ShellSettingsStore.ready || ShellSettingsStore.loading || ShellSettingsStore.saving || root.capturing || desktopScheme.writer.running || desktopScheme.kittyWriter.running) return
            root.check(!ShellSettingsStore.error, ShellSettingsStore.error)
            if (root.phase === 0) {
                root.checkScheme("prefer-dark")
                root.check(!Theme.isLight && ShellSettingsStore.values.version === 10, "default dark schema v10")
                root.check(String(Theme.accent) === "#a2cb8b", "generated dark accent")
                for (var tone of root.tones) {
                    ShellSettingsStore.setValue("appearance", "surfaceTone", tone)
                    root.check(String(Theme.surface) === ({ink: "#000000", dark: "#0b0b0b", soft: "#171717"})[tone], "dark " + tone)
                }
                ShellSettingsStore.discard()
                page.scrollToSection("Theme")
                root.capture("dark")
            } else if (root.phase === 1) {
                var light = root.find(page, "Light")
                root.check(light && light.enabled, "Light control available")
                var pill = root.modePill()
                root.check(pill && pill.animatedStartIndex === 0 && pill.animatedEndIndex === 1, "initial selection snaps into its segment")
                light.clicked()
                root.check(light.color.a === 0 && pill.animatedStartIndex === 0, "mode changes move one pill without a second button fill or an initial jump")
                root.check(Theme.isLight && String(Theme.accent) === "#2e4820", "live mode selects generated light accent")
                root.check(String(selectedButton.selectedForegroundColor) === "#ffffff", "selected foreground follows onAccent")
                root.check(String(CavaService.surfaceColor) === String(Theme.surface)
                    && String(CavaService.accentColor) === String(Theme.accent), "Cava receives live colors")
            } else if (root.phase >= 2 && root.phase <= 4) {
                root.checkScheme("prefer-light")
                var tone = root.tones[root.phase - 2]
                var label = ({ink: "Pure White", dark: "White", soft: "Gray White"})[tone]
                var button = root.find(page, label)
                root.check(button, "light surface label " + label)
                button.clicked()
                page.scrollToSection("Theme")
                root.check(String(Theme.surface) === ({ink: "#ffffff", dark: "#eeeeee", soft: "#d6d6d6"})[tone], "light " + tone)
                root.check(String(Theme.hoverMuted) === ({ink: "#e9e9e9", dark: "#d7d7d7", soft: "#c0c0c0"})[tone], "light hover " + tone)
                root.capture("light-" + tone)
            } else if (root.phase === 5) {
                var pill = root.modePill()
                var light = root.find(page, "Light")
                root.check(root.segmentMotionObserved && root.segmentStretchObserved, "selection slides with asymmetric pill morph frames")
                root.check(Math.abs(pill.x - light.x) < 0.01 && Math.abs(pill.width - light.width) < 0.01, "pill settles exactly behind the selected segment")
                ShellSettingsStore.discard()
                root.check(Theme.isLight, "Autosaved mode survives Discard")
                ShellSettingsStore.setValue("appearance", "colorMode", "light")
                ShellSettingsStore.apply()
            } else if (root.phase === 6) {
                root.checkScheme("prefer-light")
                root.check(!ShellSettingsStore.dirty && ShellSettingsStore.savedValues.appearance.colorMode === "light", "Apply saves light")
                ShellSettingsStore.reload()
            } else if (root.phase === 7) {
                root.check(Theme.isLight, "Reload restores light")
                ShellSettingsStore.reset()
                root.check(!Theme.isLight, "Reset previews dark")
                ShellSettingsStore.discard()
                root.check(Theme.isLight, "Discard restores saved light")
                var pill = root.modePill()
                root.check(pill.targetIndex === 1 && pill.animatedStartIndex === 1 && pill.animatedEndIndex === 2, "rapid return preserves the settled selection without a stale animation")
                root.check(Theme.surfaceSubtle(1.18).hslLightness > Theme.hoverMuted.hslLightness, "light subtle surfaces stay lighter")
            } else if (root.phase === 8) {
                root.checkScheme("prefer-light")
                ShellTransitionState.chromeEnabled = false
            } else if (root.phase === 9) {
                root.checkScheme("prefer-dark")
                root.check(ShellSettingsStore.colorMode === "light", "Classic context preserves Hikai preference")
                ShellTransitionState.chromeEnabled = true
            } else if (root.phase === 10) {
                root.checkScheme("prefer-light")
                root.check(themeList.visibleItems.length === 1 && themeList.visibleItems[0].stateKind === "colorMode", "Theme tab searches Light")
                ShellSettingsStore.setValue("appearance", "baseRadius", 20)
                themeList.activateCurrent()
            } else if (root.phase === 11) {
                root.checkScheme("prefer-dark")
                root.check(!Theme.isLight && ShellSettingsStore.savedValues.appearance.colorMode === "dark", "Theme tab saves Dark")
                root.check(ShellSettingsStore.baseRadius === 20 && ShellSettingsStore.savedValues.appearance.baseRadius === 12, "mode toggle retains unrelated unsaved draft")
                ShellSettingsStore.discard()
                root.check(!Theme.isLight && ShellSettingsStore.baseRadius === 12, "Discard preserves applied mode only")
                themeList.query = "~ dark"
            } else if (root.phase === 12) {
                root.check(themeList.visibleItems.length === 1, "Theme tab searches Dark")
                themeList.activateCurrent()
            } else if (root.phase === 13) {
                root.checkScheme("prefer-light")
                root.check(Theme.isLight && !ShellSettingsStore.dirty, "Theme tab saves Light without a draft")
                ShellSettingsStore.reload()
            } else if (root.phase === 14) {
                root.check(Theme.isLight, "Theme tab mode survives Reload")
                console.info("Hikai Light theme checks passed")
                Qt.quit()
            }
            ++root.phase
        }
    }
}
