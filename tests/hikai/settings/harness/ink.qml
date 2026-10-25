import QtQuick
import QtQuick.Window
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "services"
import "components"
import "components/dashboard" as Dashboard
import "components/settings/SettingsCatalog.js" as Catalog

ShellRoot {
    id: root
    // Drive only disposable surfaces, preferences and input devices from the runner.
    property var hosts: []
    property int phase: 0
    // Exercise interrupted morphs and output transfer before editing any drafts.
    property int animationPhase: 0
    // Compare reversal frames against the last sampled progress value.
    property real animationProgress: 0
    // Wait for Wayland's initial configure before measuring window geometry.
    property bool animationMapped: false
    property int ticks: 0
    property int rounds: 0
    property int captures: 0
    property var captureRequest: null
    property int pointerPhase: 0
    property int togglePhase: 0
    property int fontPhase: 0
    property int fontListPhase: 0
    property bool originalWelcome: false
    property int sidebarHoverPhase: 0
    property bool dropdownOpeningObserved: false
    property bool dropdownClosingObserved: false
    property int dropdownClickPhase: 0
    property bool sessionChecked: false
    property int configChoicePhase: 0
    property int choicePhase: 0
    property int toolPhase: 0
    property int clipboardPhase: 0
    property int preferencePhase: 0
    property int nativePhase: 0
    property int dialogLease: 0
    property string originalAvatar: ""
    property QtObject notificationMemory: QtObject { property string recordsJson: "[]"; property int nextKey: 1 }
    property string configDraft: ""
    readonly property var host: hosts[0] || null
    readonly property var panel: host && host.loaders[1].active ? host.loaders[1].item : null
    readonly property var nav: host ? host.navigationItem : null
    readonly property var note: host && host.loaders[2].active ? host.loaders[2].item : null
    readonly property string output: host ? host.modelData.name : ""
    Process { id: keyboard; command: ["python3", Quickshell.env("INK_TEST_ROOT") + "/wayland_keyboard.py"]; stdinEnabled: true; running: true }
    Process { id: pointer; command: ["python3", Quickshell.env("INK_TEST_ROOT") + "/wayland_pointer.py"]; environment: ({HAKUSPACE_TEST_POINTER_OUTPUT: root.output}); stdinEnabled: true; running: false }
    Process { id: fontFailure }
    Process { id: notificationSender; command: ["notify-send", "-t", "0", "Hikai UX", "A comfortable notification with a readable body."] }
    Process { id: dropdownCapture; property string filename: ""; command: ["grim", "-o", root.output, Quickshell.env("INK_ARTIFACT_DIR") + "/" + filename + ".png"] }
    Process { id: notificationCapture; command: ["grim", "-o", root.output, Quickshell.env("INK_ARTIFACT_DIR") + "/notifications-popup.png"] }
    Process { id: pointerCapture; command: ["grim", "-c", "-o", root.output, Quickshell.env("INK_ARTIFACT_DIR") + "/note-pointer.png"] }
    Variants {
        model: Quickshell.screens
        EphemeralSurfaces { id: instance; Component.onCompleted: root.hosts = root.hosts.concat([instance]) }
    }
    FloatingWindow {
        id: cropWindow
        visible: false
        implicitWidth: 600; implicitHeight: 700
        Dashboard.AvatarCropper { id: cropper; parent: cropWindow.contentItem }
    }
    FloatingWindow {
        id: nativeWindow
        visible: false
        implicitWidth: 440; implicitHeight: 180
        color: Theme.surface
        TextInput { id: nativeInput; anchors.centerIn: parent; width: 360; height: 40; color: Theme.fg; font.pixelSize: 18; focus: true }
    }
    // Fail loudly so a QML assertion can never be mistaken for a passing probe.
    function check(ok, message) {
        if (ok) return
        console.error("Ink Settings failed at " + phase + ": " + message)
        Qt.exit(1)
        throw new Error(message)
    }
    // Find production controls without depending on private child indices.
    function find(item, predicate) {
        if (!item) return null
        if (predicate(item)) return item
        var children = Array.from(item.children || [])
        for (var object of item.data || []) if (object.contentItem && !children.includes(object.contentItem)) children.push(object.contentItem)
        for (var child of children) {
            var match = find(child, predicate)
            if (match) return match
        }
        return null
    }
    // Capture only the test surface, keeping the user's desktop outside artifacts.
    function capture(name, nextAction) {
        ++captures
        captureRequest = {name: name, nextAction: nextAction}
        captureDelay.restart()
    }
    // Settle page transitions before recording a reviewable frame.
    Timer {
        id: captureDelay
        interval: 240
        onTriggered: {
            var body = root.find(root.panel.contentItem, item => item.radius !== undefined && item.children.some(child => child.currentPage !== undefined))
            root.check(body, "Settings body exists")
            var footer = root.find(root.panel.contentItem, item => item.actionWidth !== undefined && item.page !== undefined)
            var action = root.find(footer, item => item.settingsNavRole === "footer")
            root.check(footer && action, "shared footer has actions")
            root.check(Math.abs(footer.parent.y + footer.parent.height - body.height) < 0.5, "footer reaches the panel bottom without an extra outer margin")
            if (!footer.compact) root.check(Math.abs(action.mapToItem(footer, 0, action.height / 2).y - footer.height / 2) < 0.5, "footer buttons are vertically centered")
            else root.check(Math.abs(footer.height - action.mapToItem(footer, 0, action.height).y - Theme.spaceLg) < 0.5, "compact footer keeps balanced bottom padding")
            body.grabToImage(result => {
                root.check(result.saveToFile(Quickshell.env("INK_ARTIFACT_DIR") + "/" + root.captureRequest.name + ".png"), "save screenshot")
                var action = root.captureRequest.nextAction
                root.captureRequest = null
                --root.captures
                if (action) action()
            })
        }
    }
    // Check live geometry and loader ownership throughout opening and closing.
    Timer {
        interval: 16; repeat: true
        running: root.phase === 1 && root.animationPhase < 6
        onTriggered: {
            // Inspect the first output without retaining a released surface.
            var panel = root.panel
            if (!panel) root.animationMapped = false
            if (panel && !root.animationMapped) {
                if (panel.width !== root.host.modelData.width || panel.height !== root.host.modelData.height) return
                root.animationMapped = true
            }
            if (panel) {
                // Locate the chassis independently of its private child index.
                var body = root.find(panel.contentItem, item => item.radius !== undefined && item.children.some(child => child.currentPage !== undefined))
                root.check(body, "animated Settings body exists")
                // Inspect the stable page layout inside the moving chassis.
                var interior = body.children.find(child => child.currentPage !== undefined)
                root.check(Math.abs(interior.width + 2 * interior.x - panel.targetBodyWidth) < 0.5
                    && Math.abs(interior.height + interior.y - panel.targetBodyHeight) < 0.5, "content keeps its final layout size during morph")
                root.check(interior.enabled === panel.interactionReady, "controls wait for settled geometry")
                if (panel.revealProgress > 0.01 && panel.revealProgress < 0.99) {
                    root.check(panel.width === root.host.modelData.width && panel.height === root.host.modelData.height,
                        "Wayland geometry stays fixed: " + panel.width + "x" + panel.height)
                    root.check(!panel.releaseReady && !panel.interactionReady && panel.visible, "intermediate frame stays loaded and noninteractive")
                    root.check(Math.abs(body.x + body.width / 2 - panel.width / 2) < 0.001
                        && Math.abs(body.y + body.height / 2 - panel.height / 2) < 0.001,
                        "chassis expands in place without sliding from the corner")
                    root.check(panel.revealGeometry.path.length > 0,
                        "full-length diagonal remains connected throughout the morph")
                    root.check(Math.abs(panel.revealGeometry.center.x - panel.width / 2) < 0.001
                        && Math.abs(panel.revealGeometry.center.y - panel.height / 2) < 0.001,
                        "diagonal ends at the fixed screen center")
                }
            }
            if (root.animationPhase === 0) {
                if (!panel || panel.revealProgress < 0.2) return
                root.animationProgress = panel.morphProgress
                UiState.closeSettings()
                root.check(Math.abs(panel.morphProgress - root.animationProgress) < 0.001, "close preserves the current opening frame")
                ++root.animationPhase
            } else if (root.animationPhase === 1) {
                root.check(panel && !panel.panelOpen, "close keeps the original surface alive")
                if (panel.morphProgress > root.animationProgress * 0.7) return
                root.animationProgress = panel.morphProgress
                UiState.openSettings(root.output)
                root.check(root.panel === panel && Math.abs(panel.morphProgress - root.animationProgress) < 0.001, "reopen reverses without recreating or snapping")
                ++root.animationPhase
            } else if (root.animationPhase === 2) {
                if (!panel || !panel.interactionReady) return
                root.check(body.width === panel.targetBodyWidth && body.height === panel.targetBodyHeight, "open chassis reaches its final size")
                root.check(Math.abs(body.x + body.width / 2 - panel.width / 2) < 0.5
                    && Math.abs(body.y + body.height / 2 - panel.height / 2) < 0.5, "open chassis is centered")
                root.check(root.hosts.length > 1, "animation probe has two outputs")
                UiState.openSettings(root.hosts[1].modelData.name)
                ++root.animationPhase
            } else if (root.animationPhase === 3) {
                // Wait for the destination output's own Settings surface.
                var loader = root.hosts[1].loaders[1]
                if (panel || !loader.active || !loader.item.interactionReady) return
                root.check(UiState.ownsInteraction("settings", root.hosts[1].modelData.name), "output transfer preserves keyboard ownership")
                UiState.closeSettings()
                ++root.animationPhase
            } else if (root.animationPhase === 4) {
                if (root.hosts.some(host => host.loaders[1].active)) return
                AppState.taskbarManualState = true
                UiState.openSettings(root.output)
                ++root.animationPhase
            } else if (panel && panel.interactionReady) {
                root.check(panel.revealPosition === 7 && panel.revealGeometry.anchor.y > panel.height / 2,
                    "bottom layout uses the bottom-left attachment")
                AppState.taskbarManualState = false
                console.info("Settings animation checks passed")
                ++root.animationPhase
            }
        }
    }
    // Observe actual dropdown transition frames during physical clicks.
    Timer {
        interval: 16; repeat: true
        running: !!root.panel && root.panel.interactionReady
        onTriggered: {
            if (!root.panel) return
            if (root.phase === 5 && root.panel.configPage) {
                var choice = root.find(root.panel.configPage, item => typeof item.choose === "function" && item.options !== undefined)
                if (!choice) return
                var popup = choice.data.find(object => object.objectName === "settings-choice-popup")
                if (popup.visible && popup.opacity > 0 && popup.opacity < 1) {
                    if (root.dropdownClickPhase === 2 || root.dropdownClickPhase === 3) root.dropdownOpeningObserved = true
                    if (root.dropdownClickPhase === 4) root.dropdownClosingObserved = true
                }
            }
        }
    }
    // Every visible exclusive surface must agree with the shared output owner.
    function ownership() {
        var exclusive = 0
        for (var owner of hosts) for (var loader of owner.loaders) {
            if (!loader.active || !loader.item) continue
            var window = loader.item
            if (window.WlrLayershell && window.WlrLayershell.keyboardFocus === WlrKeyboardFocus.Exclusive) ++exclusive
        }
        check(exclusive <= 1, "at most one exclusive keyboard owner")
        if (UiState.interactionOwner === "tempNote") check(UiState.tempNoteOpen, "no invisible note owner")
    }
    Timer {
        interval: 90; repeat: true; running: true
        onTriggered: {
            root.check(++root.ticks < 450, "runtime timeout (animation phase " + root.animationPhase + ")")
            if (!root.host || root.captures || fontFailure.running || Avatar.busy || SettingsStore.loading || SettingsStore.saving || ShellSettingsStore.loading || ShellSettingsStore.saving || ConfigEditorStore.busy || WallpaperSettingsStore.loading || WallpaperSettingsStore.saving) return
            root.ownership()
            if (phase === 0) {
                WM.backendName = "niri"
                Theme.apply(JSON.stringify({accent: "#88c0d0", font: "monospace", fgDim: "#b39ab8"}))
                UiState.openSettings(root.output)
            } else if (phase === 1) {
                if (root.animationPhase < 6 || !root.panel || !root.panel.interactionReady || !SettingsStore.ready) return
                root.check(!ShellSettingsStore.error, "fixture shell settings loaded")
                root.check(root.panel.selectedCategory === "General", "starts at General")
                root.check(!root.find(root.panel.contentItem, item => item.objectName === "settings-domain-strip"), "single primary hierarchy")
                var form = root.find(root.panel.contentItem, item => item.descriptors !== undefined)
                root.check(form.descriptors.some(item => item.key === "NIGHT_LIGHT_TEMPERATURE"), "night light visible")
                root.check(form.descriptors.some(item => item.key === "SCREENSHOT_DIR"), "screenshot folder is available on every desktop")
                // Typography uses the real controller, including failed saves and reloads.
                if (root.fontPhase < 7) {
                    root.check(SettingsStore.fontsReady, "canonical font settings loaded")
                    var fontRow = root.find(form, item => item.descriptor && item.descriptor.id === "font-family")
                    var sizeRow = root.find(form, item => item.descriptor && item.descriptor.id === "font-size")
                    var screenshot = root.find(form, item => item.descriptor && item.descriptor.key === "SCREENSHOT_DIR")
                    var niriNote = root.find(screenshot, item => typeof item.text === "string" && item.text.startsWith("Niri"))
                    root.check(fontRow && sizeRow, "General has family and size controls")
                    if (root.fontPhase === 0) {
                        root.check(!SettingsStore.error && niriNote && niriNote.visible, "Niri sees its screenshot note")
                        root.check(!root.find(form, item => item.text === "WELCOME_MSG" || item.text === "SCREENSHOT_DIR" || (typeof item.text === "string" && item.text.startsWith("SETTING_VERSION"))), "raw variable names and metadata are hidden")
                        WM.backendName = "hyprland"
                    } else if (root.fontPhase === 1) {
                        if (WM.backendName !== "niri") {
                            root.check(!niriNote, "other desktops have no screenshot description")
                            WM.backendName = "niri"
                        }
                        var family = root.find(fontRow, item => typeof item.choose === "function")
                        var size = root.find(sizeRow, item => typeof item.edited === "function")
                        if (family.loading) return
                        if (root.fontListPhase < 15) {
                            var fontSearch = root.find(family, item => item.objectName === "settings-choice-search")
                            var fontPopup = family.data.find(object => object.objectName === "settings-choice-popup")
                            if (root.fontListPhase === 0) {
                                root.check(family.options.length === 2 && family.options.every(option => option.value.startsWith("Fixture Mono")), "General uses the same monospace Fontconfig source as Change Theme")
                                root.check(family.currentLabel === "monospace", "current family remains readable without adding a synthetic option")
                                family.clicked()
                            } else if (root.fontListPhase === 1) {
                                if (!fontPopup.opened) return
                                root.check(fontSearch.inputFocused, "opening font choices focuses search")
                                keyboard.write("text fixture mono b\n")
                            } else if (root.fontListPhase === 2) {
                                if (fontSearch.text !== "fixture mono b") return
                                root.check(family.visibleOptions.length === 1 && family.visibleOptions[0].value === "Fixture Mono B", "font search is case-insensitive")
                                keyboard.write("key 108\n")
                            } else if (root.fontListPhase === 3) {
                                keyboard.write("key 28\n")
                            } else if (root.fontListPhase === 4) {
                                if (family.popupOpen) return
                                root.check(SettingsStore.fontValues.family === "Fixture Mono B", "filtered keyboard selection commits the matching family")
                                SettingsStore.discard()
                                fontFailure.command = ["cp", Quickshell.env("INK_TEST_ROOT") + "/new-font-families.txt", Quickshell.env("INK_TEST_ROOT") + "/font-families.txt"]
                                fontFailure.running = true
                            } else if (root.fontListPhase === 5) {
                                family.clicked()
                            } else if (root.fontListPhase === 6) {
                                if (!fontPopup.opened) return
                                root.check(family.options.some(option => option.value === "Fixture Mono C") && !family.options.some(option => option.value === "Fixture Mono A"), "reopening discovers added fonts and drops removed fonts without restarting QML")
                                fontSearch.text = "missing font"
                                root.check(!family.visibleOptions.length, "font search has an empty state")
                                keyboard.write("key 1\n")
                            } else if (root.fontListPhase === 7) {
                                if (fontSearch.text) return
                                root.check(family.popupOpen && family.visibleOptions.length === 2, "Escape clears a query before closing")
                                keyboard.write("key 1\n")
                            } else if (root.fontListPhase === 8) {
                                if (family.popupOpen) return
                                fontFailure.command = ["touch", Quickshell.env("INK_TEST_ROOT") + "/font-list-failure"]
                                fontFailure.running = true
                            } else if (root.fontListPhase === 9) {
                                family.clicked()
                            } else if (root.fontListPhase === 10) {
                                if (!fontPopup.opened) return
                                root.check(family.statusMessage.includes("font list fixture failure") && !family.options.length, "failed refresh reports its error without stale choices")
                                root.check(SettingsStore.fontValues.family === "monospace" && !SettingsStore.dirty, "font listing never changes the preference draft")
                                fontFailure.command = ["rm", Quickshell.env("INK_TEST_ROOT") + "/font-list-failure"]
                                fontFailure.running = true
                                family.clicked()
                            } else if (root.fontListPhase === 11) {
                                if (family.popupOpen) return
                                family.clicked()
                            } else if (root.fontListPhase === 12) {
                                if (!fontPopup.opened) return
                                root.check(!family.statusMessage && family.options.length === 2, "reopening retries a failed font refresh")
                                dropdownCapture.filename = "settings-font-search"
                                fontSearch.text = "fixture mono c"
                                dropdownCapture.running = true
                            } else if (root.fontListPhase === 13) {
                                if (dropdownCapture.running) return
                                fontSearch.text = ""
                                family.clicked()
                            } else if (root.fontListPhase === 14) {
                                if (family.popupOpen) return
                            }
                            ++root.fontListPhase
                            return
                        }
                        family.choose(family.options.findIndex(option => option.value === "Fixture Mono B"))
                        size.edited(16)
                        root.check(SettingsStore.fontsDirty && Theme.fontSize === 14, "font controls edit a draft until Apply")
                        fontFailure.command = ["touch", Quickshell.env("INK_TEST_ROOT") + "/font-save-failure"]
                        fontFailure.running = true
                    } else if (root.fontPhase === 2 || root.fontPhase === 4) {
                        root.panel.generalPage.activateAction("Apply")
                    } else if (root.fontPhase === 3) {
                        root.check(SettingsStore.error.includes("font fixture save failure") && SettingsStore.fontsDirty, "failed font save preserves the draft")
                        root.check(SettingsStore.savedFontValues.family === "monospace" && SettingsStore.savedFontValues.size === 14, "failed save does not confirm unsaved fonts")
                        fontFailure.command = ["rm", Quickshell.env("INK_TEST_ROOT") + "/font-save-failure"]
                        fontFailure.running = true
                    } else if (root.fontPhase === 5) {
                        root.check(!SettingsStore.error && !SettingsStore.fontsDirty && SettingsStore.savedFontValues.family === "Fixture Mono B" && SettingsStore.savedFontValues.size === 16, "retry saves both font values")
                        if (Theme.fontSize !== 16 || Theme.fontFamily !== "Fixture Mono B") return
                        SettingsStore.setFontValue("size", 18)
                        SettingsStore.discard()
                        root.check(SettingsStore.fontValues.size === 16 && !SettingsStore.dirty, "Discard restores saved typography")
                        SettingsStore.setFontValue("family", "serif")
                        SettingsStore.reload()
                    } else if (root.fontPhase === 6) {
                        root.check(SettingsStore.fontValues.family === "Fixture Mono B" && SettingsStore.fontValues.size === 16 && !SettingsStore.dirty, "Reload reads canonical typography")
                        SettingsStore.setFontValue("family", "monospace")
                    }
                    ++root.fontPhase
                    return
                }
                root.check(!SettingsStore.error, "fixture preferences loaded")
                root.check(!root.panel.shellPage && !root.panel.wallpaperPage, "hidden page trees are not loaded")
                root.check(!root.find(root.panel.contentItem, item => item.objectName === "settings-advanced-toggle"), "Settings has no Advanced disclosure")
                var rail = root.find(root.panel.contentItem, item => item.categories !== undefined)
                root.check(rail.categories.includes("Session"), "Session is always available")
                var welcome = root.find(form, item => item.descriptor && item.descriptor.key === "WELCOME_MSG")
                var toggle = root.find(welcome, item => item.labels !== undefined && item.checked !== undefined)
                var indicator = root.find(toggle, item => item.objectName === "settings-toggle-selection")
                root.check(indicator && indicator.indexedMode, "general On/Off uses the shared indexed pill")
                if (root.togglePhase === 0) {
                    root.originalWelcome = toggle.checked
                    toggle.forceActiveFocus()
                    keyboard.write("key 57\n")
                    ++root.togglePhase
                    return
                }
                if (root.togglePhase === 1) {
                    if (toggle.checked === root.originalWelcome) return
                    root.check(Math.abs(indicator.animatedStartIndex - indicator.targetIndex) > 0.001 || Math.abs(indicator.animatedEndIndex - indicator.targetIndex - 1) > 0.001, "On/Off animates instead of jumping")
                    keyboard.write("key 57\n")
                    ++root.togglePhase
                    return
                }
                if (root.togglePhase === 2) {
                    if (toggle.checked !== root.originalWelcome || Math.abs(indicator.animatedStartIndex - indicator.targetIndex) > 0.001 || Math.abs(indicator.animatedEndIndex - indicator.targetIndex - 1) > 0.001) return
                    root.check(Math.abs(indicator.width - indicator.laneSlotWidth) < 0.5, "interrupted toggle returns to one settled pill")
                    ++root.togglePhase
                }
                var general = root.find(root.panel.contentItem, item => item.objectName === "settings-category-General")
                var appearance = root.find(root.panel.contentItem, item => item.objectName === "settings-category-Appearance")
                var pill = root.find(root.panel.contentItem, item => item.objectName === "settings-sidebar-selection")
                root.check(pill && pill.targetItem === general && pill.width > 0, "shared pill starts on the selected category")
                if (root.sidebarHoverPhase === 0) { pointer.running = true; ++root.sidebarHoverPhase; return }
                if (root.sidebarHoverPhase === 1 || root.sidebarHoverPhase === 3) {
                    var target = root.sidebarHoverPhase === 1 ? appearance : general
                    var point = target.mapToItem(root.panel.contentItem, target.width / 2, target.height / 2)
                    pointer.write(Math.round(point.x) + " " + Math.round(point.y) + " " + root.host.modelData.width + " " + root.host.modelData.height + " 0\n")
                    ++root.sidebarHoverPhase
                    return
                }
                if (root.sidebarHoverPhase === 2) {
                    if (!appearance.hovered) return
                    root.check(appearance.targetBackground.a === 0 && pill.targetItem === general, "hover keeps an unselected row transparent and preserves selection")
                    ++root.sidebarHoverPhase
                    return
                }
                if (!general.hovered) return
                root.check(general.targetBackground.a === 0 && general.targetForeground === Theme.onAccentColor, "selected hover leaves the shared pill and readable text intact")
                root.panel.generalPage.scrollToSection("General")
                root.capture("settings-general", function() {
                    SettingsStore.setValue("NIGHT_LIGHT_TEMPERATURE", 4400)
                    root.panel.selectCategory("Appearance")
                })
            } else if (phase === 2) {
                root.check(SettingsStore.value("NIGHT_LIGHT_TEMPERATURE") === 4400, "draft survives page unload")
                root.check(SettingsStore.fontValues.family === "monospace" && SettingsStore.fontsDirty, "font draft survives page unload")
                var pill = root.find(root.panel.contentItem, item => item.objectName === "settings-sidebar-selection")
                root.check(pill.targetItem.objectName === "settings-category-Appearance", "shared pill follows category selection")
                root.check(root.panel.shellPage.sectionCards.every(card => ["Layout", "Appearance", "Rounded Screen", "Surface"].includes(card.title)), "Appearance sections only")
                if (root.choicePhase === 0) { SettingsStore.setValue("ACCENT_COLOR_BASED_ON_WALLPAPER", true); ++root.choicePhase; return }
                var choice = root.find(root.panel.shellPage, item => typeof item.choose === "function" && item.options !== undefined)
                if (!choice) return
                if (root.choicePhase === 1) { choice.clicked(); ++root.choicePhase; return }
                if (root.choicePhase === 2) {
                    root.check(choice.popupOpen, "Hikai choice popover opens")
                    var list = root.find(choice, item => item.objectName === "settings-choice-list")
                    var selection = root.find(list, item => item.objectName === "settings-choice-selection")
                    root.check(selection && selection.parent === list.contentItem && selection.z < list.currentItem.z, "dropdown pill stays below its scrolling labels")
                    keyboard.write("key 108\n")
                    ++root.choicePhase
                    return
                }
                if (root.choicePhase === 3) {
                    var list = root.find(choice, item => item.objectName === "settings-choice-list")
                    root.check(list.currentIndex === 1 && SettingsStore.value("ACCENT_COLOR_MODE") === "vivid", "keyboard moves the pill before committing a value")
                    var selection = root.find(list, item => item.objectName === "settings-choice-selection")
                    if (Math.abs(selection.y - selection.targetY) > 0.5 || Math.abs(selection.height - selection.targetHeight) > 0.5) return
                    dropdownCapture.filename = "settings-accent-dropdown"
                    dropdownCapture.running = true
                    ++root.choicePhase
                    return
                }
                if (root.choicePhase === 4) {
                    if (dropdownCapture.running) return
                    keyboard.write("key 28\n")
                    ++root.choicePhase
                    return
                }
                if (choice.popupOpen) return
                root.check(SettingsStore.value("ACCENT_COLOR_MODE") === "dominant" && !choice.popupOpen, "choice menu works with native keyboard events")
                root.capture("settings-appearance", function() { root.panel.selectCategory("Desktop") })
            } else if (phase === 3) {
                root.check(root.panel.shellPage.sectionCards.some(card => card.title === "Top Bar"), "Desktop controls available")
                var cava = root.panel.shellPage.sectionCards.find(card => card.title === "Cava Underbar")
                root.check(root.find(cava, item => item.objectName === "settings-toggle-selection"), "Cava On/Off uses the same morph primitive")
                root.check(!root.panel.shellPage.sectionCards.some(card => card.title === "Rounded Screen"), "no Appearance controls in Desktop")
                var heading = root.find(root.panel.shellPage, item => item.text === "Cava Underbar")
                root.check(heading && heading.font.pixelSize > Theme.fontSize, "section titles stand above control labels")
                var desktopScroll = root.find(root.panel.shellPage, item => item.contentHeight !== undefined && item.contentY !== undefined)
                root.check(desktopScroll && desktopScroll.contentY === 0, "switching to Desktop starts with its section heading visible")
                root.capture("settings-desktop", function() { root.panel.selectCategory("Wallpaper") })
            } else if (phase === 4) {
                var wallpaper = root.panel.wallpaperPage
                root.check(wallpaper && wallpaper.sidebarSections.includes("Video cache") && wallpaper.sidebarSections.includes("Browser"), "cache and browser preferences are always available")
                root.check(root.find(wallpaper, item => item.objectName === "settings-toggle-selection"), "wallpaper On/Off uses the same morph primitive")
                root.check(!root.find(root.panel.contentItem, item => item.text === "Build proxies"), "user-facing video copy")
                var profiles = ["low-memory", "screen", "original"].map(value => root.find(wallpaper, item => item.objectName === "wallpaper-setting-profile-" + value))
                root.check(profiles.every(button => button && Math.abs(button.width - profiles[0].width) < 0.01 && button.height === profiles[0].height), "quality tabs have identical dimensions")
                for (var button of profiles) {
                    var label = root.find(button, item => item.text && item.font !== undefined)
                    root.check(label.x >= Theme.spaceLg && button.width - label.x - label.width >= Theme.spaceLg - 0.1, "quality tabs retain horizontal padding")
                }
                wallpaper.scrollToSection("Video playback")
                root.capture("settings-wallpaper", function() {
                    root.panel.selectCategory("Configuration")
                })
            } else if (phase === 5) {
                if (!ConfigEditorStore.hasFile) return
                root.check(root.panel.configPage.visibleFiles[0].id === "wm/niri-custom.kdl", "active WM first")
                root.check(root.panel.configPage.visibleFiles.length === ConfigEditorStore.files.length, "every WM configuration file is available")
                root.check(!root.find(root.panel.configPage, item => item.descriptors !== undefined), "Configuration contains only the file editor")
                var choice = root.find(root.panel.configPage, item => typeof item.choose === "function" && item.options !== undefined)
                var point = choice.mapToItem(root.panel.contentItem, choice.width / 2, choice.height / 2)
                if ([0, 2, 5].includes(root.dropdownClickPhase)) {
                    pointer.write(Math.round(point.x) + " " + Math.round(point.y) + " " + root.host.modelData.width + " " + root.host.modelData.height + " 272 1\n")
                    ++root.dropdownClickPhase
                    return
                }
                if ([1, 3, 6].includes(root.dropdownClickPhase)) {
                    pointer.write(Math.round(point.x) + " " + Math.round(point.y) + " " + root.host.modelData.width + " " + root.host.modelData.height + " 272 0\n")
                    ++root.dropdownClickPhase
                    return
                }
                if (root.dropdownClickPhase === 4) {
                    if (choice.popupOpen) return
                    root.check(ConfigEditorStore.selectedFileId === "wm/niri-custom.kdl", "clicking the trigger again closes without selecting")
                    root.check(root.dropdownOpeningObserved && root.dropdownClosingObserved, "dropdown renders intermediate frames while opening and closing")
                    ++root.dropdownClickPhase
                    return
                }
                if (root.configChoicePhase === 0) {
                    var list = root.find(choice, item => item.objectName === "settings-choice-list")
                    var popup = choice.data.find(object => object.objectName === "settings-choice-popup")
                    if (!popup.opened) return
                    var origin = list.mapToItem(root.panel.contentItem, 0, 0)
                    var anchor = choice.mapToItem(root.panel.contentItem, 0, choice.height)
                    root.check(Math.abs(origin.x - popup.leftPadding - anchor.x) < 1 && Math.abs(origin.y - popup.topPadding - anchor.y - Theme.spaceSm) < 1, "dropdown aligns with its trigger after a physical click")
                    root.check(!root.find(root.panel.configPage, item => item.text === "Configuration" || item.text === "Open in VS Code"), "Configuration contains only its selector and editor")
                    ++root.configChoicePhase
                    return
                }
                var list = root.find(choice, item => item.objectName === "settings-choice-list")
                var selection = root.find(list, item => item.objectName === "settings-choice-selection")
                if (root.configChoicePhase === 1) {
                    root.check(list.contentHeight > list.height, "long configuration list scrolls inside the popup")
                    root.check(selection.parent === list.contentItem && selection.z < list.currentItem.z, "configuration labels render above the pill")
                    var label = root.find(list.currentItem, item => item.objectName === "settings-choice-option-label")
                    root.check(label.text === ConfigEditorStore.selectedFileId && label.x > 0 && label.x + label.width < list.currentItem.width, "selected filename has padding on both sides")
                    var longLabel = root.find(list, item => item.objectName === "settings-choice-option-label" && item.text.startsWith("config/example-configuration"))
                    root.check(longLabel && longLabel.truncated, "long filenames elide inside their padded row")
                    dropdownCapture.filename = "settings-config-dropdown"
                    dropdownCapture.running = true
                    ++root.configChoicePhase
                    return
                }
                if (root.configChoicePhase === 2) {
                    if (dropdownCapture.running) return
                    keyboard.write("key 108\n".repeat(list.count - 1))
                    ++root.configChoicePhase
                    return
                }
                if (root.configChoicePhase === 3) {
                    if (list.currentIndex !== list.count - 1) return
                    var label = root.find(list.currentItem, item => item.objectName === "settings-choice-option-label")
                    root.check(list.contentY > 0 && selection.targetItem === list.currentItem, "pill follows the scrolled current item")
                    var target = list.itemAtIndex(list.count - 2)
                    var point = target.mapToItem(root.panel.contentItem, target.width / 2, target.height / 2)
                    pointer.write(Math.round(point.x) + " " + Math.round(point.y) + " " + root.host.modelData.width + " " + root.host.modelData.height + " 0\n")
                    ++root.configChoicePhase
                    return
                }
                if (root.configChoicePhase === 4) {
                    if (list.currentIndex !== list.count - 2) return
                    root.check(selection.targetItem === list.currentItem && ConfigEditorStore.selectedFileId === "wm/niri-custom.kdl", "pointer hover moves the pill without committing a file")
                    keyboard.write("key 1\n")
                    pointer.write("0 0 " + root.host.modelData.width + " " + root.host.modelData.height + " 0\n")
                    ++root.configChoicePhase
                    return
                }
                if (root.configChoicePhase === 5) {
                    if (choice.popupOpen) return
                    root.check(!choice.popupOpen && ConfigEditorStore.selectedFileId === "wm/niri-custom.kdl", "Escape cancels without selecting a file")
                    choice.clicked()
                    ++root.configChoicePhase
                    return
                }
                if (root.configChoicePhase === 6) {
                    var popup = choice.data.find(object => object.objectName === "settings-choice-popup")
                    if (!popup.opened) return
                    root.check(list.currentIndex === choice.selectedIndex && list.contentY <= 0, "reopening restores the selected filename and scroll position")
                    keyboard.write("key 1\n")
                    ++root.configChoicePhase
                    return
                }
                if (choice.popupOpen) return
                root.capture("settings-configuration", function() {
                ConfigEditorStore.setText("draft survives category switch\n")
                root.configDraft = ConfigEditorStore.text
                root.panel.configPage.requestSelect("config/cava-layer")
                root.check(root.panel.configPage.confirmation === "switch", "dirty file switch requires a choice")
                root.panel.selectCategory("General")
                })
            } else if (phase === 6) {
                root.check(ConfigEditorStore.text === root.configDraft && SettingsStore.dirty, "all draft domains survive navigation")
                root.panel.selectCategory("Configuration")
                root.check(root.panel.configPage.confirmation === "switch", "file confirmation survives hidden page")
                root.panel.configPage.cancelConfirmation()
                ConfigEditorStore.discard()
                root.panel.selectCategory("Session")
            } else if (phase === 7) {
                if (!root.sessionChecked) {
                    var session = root.find(root.panel.generalPage, item => item.descriptors !== undefined)
                    root.check(session.descriptors.length === 2 && session.descriptors.some(item => item.key === "EXIT_APP_LIST_USER"), "Session options render without a disclosure")
                    root.sessionChecked = true
                    root.panel.selectCategory("Recording")
                    return
                }
                var form = root.find(root.panel.generalPage, item => item.descriptors !== undefined)
                root.check(form.descriptors.length === 3 && form.descriptors.some(item => item.key === "REC_OPTS"), "recording options are always available")
                var command = root.find(form, item => item.settingsNavRole === "input" && item.text === SettingsStore.value("REC_COMMAND"))
                root.check(command && command.font.pixelSize === Theme.fontSize - 1, "recorder input uses the Settings control font")
                root.capture("settings-recording", function() {
                    SettingsStore.setValue("REC_OPTS", "--max-fps 30")
                    root.panel.generalPage.activateAction("Apply")
                    root.panel.selectCategory("Appearance")
                })
            } else if (phase === 8) {
                if (root.preferencePhase === 0) {
                    root.check(SettingsStore.savedValues.REC_OPTS === "--max-fps 30", "Recording Apply saves recorder options")
                    root.check(SettingsStore.savedFontValues.family === "monospace" && SettingsStore.savedFontValues.size === 16 && !SettingsStore.fontsDirty, "shared Apply saves pending typography")
                    var form = root.find(root.panel.shellPage, item => item.descriptors !== undefined)
                    root.check(form.descriptors.some(item => item.key === "HAKU_CLOCK_FONT_SIZE"), "Classic fonts are always available")
                    var themes = root.find(root.panel.shellPage, item => item.descriptor && item.descriptor.key === "WAYBAR_MODE_USER")
                    var entry = root.find(themes, item => item.placeholderText === "Theme folder name")
                    root.check(entry && entry.enabled, "Waybar has an editable list")
                    entry.text = "custom theme"
                    entry.add()
                    root.panel.shellPage.activateAction("Apply")
                    ++root.preferencePhase
                    return
                }
                if (root.preferencePhase === 1) {
                    root.check(SettingsStore.savedValues.WAYBAR_MODE_USER[0] === "custom theme", "Appearance Apply saves Waybar arrays")
                    root.panel.selectCategory("Wallpaper")
                    ++root.preferencePhase
                    return
                }
                if (root.preferencePhase === 2) {
                    var form = root.find(root.panel.wallpaperPage, item => item.descriptors !== undefined)
                    root.check(form.descriptors.some(item => item.key === "AWWW_OPTS") && form.descriptors.some(item => item.key === "WALL_INTERVAL"), "Wallpaper owns transition and rotation preferences")
                    SettingsStore.setValue("AWWW_OPTS", "--transition-type fade")
                    root.panel.wallpaperPage.activateAction("Apply")
                    ++root.preferencePhase
                    return
                }
                if (root.preferencePhase === 3) {
                    root.check(SettingsStore.savedValues.AWWW_OPTS === "--transition-type fade", "Wallpaper Apply saves transition options")
                    root.capture("settings-wallpaper-options", function() { root.panel.selectCategory("About") })
                    ++root.preferencePhase
                    return
                }
                if (root.preferencePhase === 4) {
                    if (!InfoStore.ready) return
                    root.check(root.find(root.panel.infoPage, item => item.title && item.settingsNavSection !== undefined), "About renders shared section cards")
                    root.capture("settings-about", function() { root.panel.selectCategory("General") })
                    ++root.preferencePhase
                    return
                }
                if (root.preferencePhase === 5) ++root.preferencePhase
                var search = root.find(root.panel.contentItem, item => item.inputFocused !== undefined && typeof item.focusSearch === "function")
                if (root.preferencePhase === 6) {
                    var rail = root.find(root.panel.contentItem, item => item.categories !== undefined)
                    root.check(!rail.categories.includes("Advanced") && !rail.categories.includes("Shortcuts") && rail.categories.includes("Session"), "rail exposes every category without an Advanced entry")
                    SettingsStore.setValue("NIGHT_LIGHT_TEMPERATURE", 4300)
                    search.focusSearch()
                    keyboard.write("text wal\n")
                    ++root.preferencePhase
                    return
                }
                if (root.preferencePhase === 7) {
                    var results = root.find(root.panel.contentItem, item => item.objectName === "settings-search-results")
                    if (!results || !results.count || !results.currentItem || results.parent.opacity < 0.999) return
                    var label = root.find(results.currentItem, item => item.objectName === "settings-search-result-label")
                    root.check(label && !label.truncated && label.font.pixelSize === Theme.fontSize - 1, "search uses the available row width and a consistent font")
                    dropdownCapture.filename = "settings-search"
                    dropdownCapture.running = true
                    ++root.preferencePhase
                    return
                }
                if (dropdownCapture.running) return
                search.focusSearch()
                keyboard.write("text blue light\nkey 28\n")
            } else if (phase === 9) {
                if (root.panel.selectedCategory !== "General") return
                root.check(root.panel.selectedCategory === "General" && root.panel.highlightedId === "NIGHT_LIGHT_TEMPERATURE", "search jumps and highlights")
                if (root.nativePhase === 0) {
                    root.dialogLease = UiState.beginNativeDialog("settings")
                    root.check(root.dialogLease > 0, "native chooser acquires a focus lease")
                    root.check(root.panel.WlrLayershell.keyboardFocus === WlrKeyboardFocus.None && SettingsStore.dirty, "native chooser preserves drafts and releases keyboard")
                    nativeWindow.visible = true
                    nativeWindow.contentItem.Window.window.requestActivate()
                    nativeInput.forceActiveFocus()
                    ++root.nativePhase
                    return
                }
                if (root.nativePhase === 1) {
                    root.check(root.panel.WlrLayershell.layer === WlrLayer.Bottom, "native chooser lowers the layer")
                    keyboard.write("text native chooser\n"); ++root.nativePhase; return
                }
                if (root.nativePhase === 2) {
                    if (nativeInput.text !== "native chooser") return
                    nativeWindow.visible = false
                    UiState.endNativeDialog(root.dialogLease)
                    root.check(UiState.ownsInteraction("settings", root.output) && root.panel.WlrLayershell.layer === ShellTransitionState.chromeOverlayLayer, "native chooser returns the layer and keyboard")
                    ++root.nativePhase
                }
                root.panel.requestClose()
                root.check(root.panel.confirmation === "close", "unsaved close is guarded")
                root.panel.confirmDiscard()
            } else if (phase === 10) {
                if (root.panel) return
                root.check(!SettingsStore.dirty && !ShellSettingsStore.dirty, "Discard restores every draft")
                if (Quickshell.env("INK_SETTINGS_ONLY") === "1") {
                    console.info("Ink Settings checks passed (Settings only)")
                    Qt.quit()
                    return
                }
                UiState.openNavigation(root.output, {x: 12, y: 0, width: 40, height: 32})
            } else if (phase === 11) {
                if (!root.nav) return
                UiState.beginNavigationHandoff("sidebar")
                root.nav.focusSidebarRail(true)
                keyboard.write("key 106\n")
            } else if (phase === 12) {
                var layer = root.find(root.nav, item => item.focusContent !== undefined && item.toolContent !== undefined)
                if (root.toolPhase === 0) {
                    if (!root.nav.sidebarToolOpen || !layer || layer.activeProgress < 0.99) return
                    root.check(root.nav.sidebarToolOpen, "Right opens the selected Sidebar tool")
                    keyboard.write("key 1\n")
                    ++root.toolPhase
                    return
                }
                if (root.toolPhase === 1) {
                    if (root.nav.sidebarToolOpen) return
                    root.check(root.nav.panelOpen && root.nav.sidebarKeyboardMode, "Escape returns from tool to rail")
                    keyboard.write("key 106\n")
                    ++root.toolPhase
                    return
                }
                if (!root.nav.sidebarToolOpen || !layer || layer.activeProgress < 0.99) return
                root.nav.toggleSidebarTool("tempNote", true)
            } else if (phase === 13) {
                if (!root.note || !root.note.interactionReady) return
                root.check(UiState.navigationMode === "closed" && (!root.nav || !root.nav.panelOpen), "note handoff dismisses Navigation")
                root.check(UiState.ownsInteraction("tempNote", root.output), "note owns keyboard after opening")
                keyboard.write("text ownership test\n")
            } else if (phase === 14) {
                if (!TextStore.scratchDraft.includes("ownership test")) return
                UiState.openSettings(root.output)
            } else if (phase === 15) {
                if (!root.panel || !root.panel.interactionReady) return
                if (root.pointerPhase === 0) root.check(root.note.panelOpen && !root.note.keyboardRequested, "pinned note releases its exclusive lease")
                var x = UiState.tempNoteRect.x + 60, y = UiState.tempNoteRect.y + 90
                if (root.pointerPhase === 0) { pointer.running = true; ++root.pointerPhase; return }
                if (root.pointerPhase === 1) { pointer.write(x + " " + y + " " + root.host.modelData.width + " " + root.host.modelData.height + " 272 1\n"); ++root.pointerPhase; return }
                if (root.pointerPhase === 2) { pointer.write(x + " " + y + " " + root.host.modelData.width + " " + root.host.modelData.height + " 272 0\n"); ++root.pointerPhase; return }
                if (root.pointerPhase === 3) { pointerCapture.running = true; ++root.pointerPhase; return }
                if (pointerCapture.running) return
                var search = root.find(root.panel.contentItem, item => item.inputFocused !== undefined && typeof item.focusSearch === "function")
                var point = search.mapToItem(root.panel.contentItem, search.width / 2, search.height / 2)
                if (root.pointerPhase === 4) {
                    root.check(UiState.ownsInteraction("tempNote", root.output), "real click returns focus to visible passive note")
                    pointer.write(Math.round(point.x) + " " + Math.round(point.y) + " " + root.host.modelData.width + " " + root.host.modelData.height + " 272 1\n")
                    ++root.pointerPhase
                    return
                }
                if (root.pointerPhase === 5) {
                    pointer.write(Math.round(point.x) + " " + Math.round(point.y) + " " + root.host.modelData.width + " " + root.host.modelData.height + " 272 0\n")
                    ++root.pointerPhase
                    return
                }
                root.check(UiState.ownsInteraction("settings", root.output) && search.inputFocused, "real click returns keyboard to Settings input")
                UiState.closeSettings()
                UiState.closeTempNote()
            } else if (phase === 16) {
                if (root.note) return
                UiState.openNavigation(root.output, {x: 12, y: 0, width: 40, height: 32})
            } else if (phase === 17) {
                if (!root.nav) return
                UiState.beginNavigationHandoff("sidebar")
                root.nav.openSidebarTool("clipboard", true)
                root.nav.toggleSidebarTool("tempNote", true)
            } else if (phase === 18) {
                if (!root.note || !root.note.interactionReady) return
                UiState.closeTempNote()
                UiState.openNavigation(root.output, {x: 12, y: 0, width: 40, height: 32})
            } else if (phase === 19) {
                if (!root.nav) return
                UiState.beginNavigationHandoff("sidebar")
                if (root.clipboardPhase === 0) {
                    root.nav.openSidebarTool("clipboard", true)
                    ++root.clipboardPhase
                    return
                }
                if (root.clipboardPhase === 1) {
                    var layer = root.find(root.nav, item => item.focusContent !== undefined && item.toolContent !== undefined)
                    if (!layer || layer.activeProgress < 0.99) return
                    root.check(root.nav.sidebarToolOpen, "Clipboard reopens after note handoff")
                    keyboard.write("key 105\n")
                    ++root.clipboardPhase
                    return
                }
                if (root.nav.sidebarToolOpen) return
                root.check(root.nav.panelOpen && root.nav.sidebarKeyboardMode, "Left returns Clipboard to rail")
                UiState.closeNavigation()
            } else if (phase === 20) {
                UiState.openTempNote(root.output)
            } else if (phase === 21) {
                if (!root.note) return
                keyboard.write("key 1\n")
            } else if (phase === 22) {
                if (UiState.tempNoteOpen) return
                root.check(UiState.interactionOwner === "", "early Escape releases note ownership")
                if (++root.rounds < 20) { root.phase = 20; return }
                UiState.openTempNote(root.hosts[1].modelData.name)
            } else if (phase === 23) {
                if (UiState.interactionOwner !== "tempNote") return
                root.check(UiState.tempNoteScreenName === root.hosts[1].modelData.name, "note transfers to second output")
                UiState.closeTempNoteIfScreen(root.output)
                root.check(UiState.tempNoteOpen, "stale output cannot close the new owner")
                UiState.closeTempNote()
                root.originalAvatar = Avatar.path
                cropWindow.visible = true
                cropper.source = "file://" + Quickshell.env("INK_TEST_ROOT") + "/avatar-wide.png"
                cropper.open()
            } else if (phase === 24) {
                if (!cropper.imageReady) return
                cropper.zoom = 2
                cropper.pan = Qt.point(10000, -10000)
                cropper.clampPan()
                Avatar.saveCrop(cropper.cropCanvas)
            } else if (phase === 25) {
                root.check(Avatar.path && Avatar.path !== root.originalAvatar && Avatar.revision > 0, "crop committed through the avatar controller")
                root.check(!Avatar.lastError && !cropper.visible && !Avatar.temporaryPath, "capture cleanup and close")
                root.originalAvatar = Avatar.path
                cropper.source = "file://" + Quickshell.env("INK_TEST_ROOT") + "/avatar-wide.png"
                cropper.open()
                cropper.close()
                root.check(Avatar.path === root.originalAvatar, "Cancel preserves existing avatar")
                cropWindow.visible = false
                UiState.openSettings(root.hosts[1].modelData.name)
            } else if (phase === 26) {
                if (!root.hosts[1].loaders[1].active || !root.hosts[1].loaders[1].item.interactionReady) return
                var second = root.hosts[1].loaders[1].item
                root.check(second.panelOpen && (!root.panel || !root.panel.panelOpen), "Settings transfers to second output")
                root.captureSecond(second)
                UiState.closeSettings()
            } else if (phase === 27) {
                NotificationStore.start(root.notificationMemory)
            } else if (phase === 28) {
                if (!NotificationStore.server.objectAt(0)) return
                notificationSender.running = true
            } else if (phase === 29) {
                var popup = root.host.loaders[7].item
                if (NotificationStore.count !== 1 || !popup || popup.revealTarget <= 0 || Math.abs(popup.revealHeight - popup.revealTarget) > 0.5) return
                notificationCapture.running = true
                UiState.openTempNote(root.output)
            } else if (phase === 30) {
                if (notificationCapture.running || !root.note || !root.note.interactionReady) return
                UiState.toggleNotifications(root.output, {x: root.host.modelData.width - 80, y: 0, width: 40, height: 36})
            } else if (phase === 31) {
                var center = root.host.loaders[4].item
                var flare = root.find(center, item => item.naturalContentHeight !== undefined && item.horizontalPadding !== undefined)
                if (!flare || flare.currentHeight < flare.naturalContentHeight + flare.verticalPadding * 2 - 1) return
                root.check(root.note.panelOpen && !root.note.keyboardRequested && UiState.ownsInteraction("notifications", root.output), "Notification Center takes the note keyboard lease")
                notificationCapture.command = ["grim", "-o", root.output, Quickshell.env("INK_ARTIFACT_DIR") + "/notifications-center.png"]
                notificationCapture.running = true
            } else if (phase === 32) {
                if (notificationCapture.running) return
                NotificationStore.toggleDnd()
                root.check(NotificationStore.dnd, "DND remains functional")
                NotificationStore.toggleDnd()
                UiState.closeNotifications()
                root.check(UiState.interactionOwner === "" && UiState.tempNoteOpen, "closing notifications never revives a stale note lease")
                UiState.closeTempNote()
                NotificationStore.clearAll()
            } else {
                if (root.hosts.some(owner => owner.loaders.slice(0, 8).some(loader => loader.active))) return
                root.check(!SettingsStore.dirty && !ConfigEditorStore.dirty, "all drafts settled")
                console.info("Ink Settings checks passed")
                Qt.quit()
                return
            }
            ++root.phase
        }
    }
    // Capture the final output independently of the first host's released Settings tree.
    function captureSecond(second) {
        check(UiState.ownsInteraction("settings", second.modelData.name), "second output owns Settings input")
    }
}
