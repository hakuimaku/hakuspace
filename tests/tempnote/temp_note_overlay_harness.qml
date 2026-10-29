import QtQuick
import QtQuick.Window
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtTest
import "components"
import "services"

ShellRoot {
    id: root
    // Advance only after Qt has delivered focus and pointer events.
    property int phase: 0
    // Refer to the card through the production pointer mask.
    readonly property var card: overlay.mask.item
    // Count close notifications while ownership is still valid.
    property int closes: 0
    // Remember completed saves before removing an owning output instance.
    property int flushesBeforeRemoval: 0
    // Compare saves against each action because pointer focus can also flush drafts.
    property int flushesBeforeClose: 0
    // Require intermediate frames in both animation directions.
    property bool sawOpening: false
    property bool sawClosing: false
    // Use the compositor's primary output to instantiate a production PanelWindow.
    readonly property string screenName: Quickshell.screens[0].name

    // Send real seat events through the private compositor.
    Process {
        id: pointer
        command: ["python3", Quickshell.env("TEMP_NOTE_TEST_INPUT_DIR") + "/wayland_pointer.py"]
        environment: ({HAKUSPACE_TEST_POINTER_OUTPUT: root.screenName})
        stdinEnabled: true
        running: true
    }
    Process {
        id: keyboard
        command: ["python3", Quickshell.env("TEMP_NOTE_TEST_INPUT_DIR") + "/wayland_keyboard.py"]
        stdinEnabled: true
        running: true
    }

    // Keep a normal application surface available beneath the pinned note.
    Window {
        id: application
        visibility: root.phase >= 11 ? Window.Maximized : Window.Hidden
        TextInput { id: applicationEditor; anchors.fill: parent; focus: true }
    }

    // Click output coordinates through Wayland rather than injecting Qt-local events.
    function clickOutput(x, y) {
        pointer.write(Math.round(x) + " " + Math.round(y) + " "
                      + overlay.width + " " + overlay.height + " 272\n")
    }

    // Drag the lower-right grip with coordinates fixed to the drawing window.
    function resizeNote(dx, dy) {
        var startX = root.card.x + root.card.width - 16 // Start inside the rounded input mask.
        var startY = root.card.y + root.card.height - 16
        root.check(input.mousePress(overlay.contentItem, startX, startY, Qt.LeftButton, Qt.NoModifier, 0),
                   "resize press")
        input.mouseMove(overlay.contentItem, startX + (dx > 0 ? 20 : -20),
                        startY + (dy > 0 ? 20 : -20), 0, Qt.LeftButton, Qt.NoModifier)
        input.mouseMove(overlay.contentItem, startX + dx, startY + dy, 0, Qt.LeftButton, Qt.NoModifier)
        input.mouseRelease(overlay.contentItem, startX + dx, startY + dy, Qt.LeftButton, Qt.NoModifier, 0)
    }

    // Count editable surfaces across actual outputs.
    function visibleNotes() {
        var count = overlay.visible ? 1 : 0 // Include the primary test output.
        for (var note of otherNotes.instances) if (note.visible) count++
        return count
    }

    // Stop immediately when a production behavior violates its contract.
    function check(condition, message) {
        if (condition) return
        console.error("Temp Note overlay failed: " + message)
        Qt.exit(1)
        throw new Error(message)
    }

    TempNoteOverlay {
        id: overlay
        modelData: Quickshell.screens[0]
        TestEvent { id: input }
    }
    Variants {
        id: otherNotes
        model: Quickshell.screens.slice(1)
        TempNoteOverlay {}
    }
    Connections {
        target: UiState
        // Verify close observers run before visibility or ownership changes.
        function onTempNoteClosing(screenName) {
            root.check(UiState.tempNoteOpen && UiState.tempNoteScreenName === screenName,
                       "close notification preceded by state reset")
            root.closes++
        }
    }

    // Report the stalled phase before the runner's process timeout.
    Timer {
        interval: 8000
        running: true
        onTriggered: root.check(false, "timed out in phase " + root.phase
                                + "; focusPending=" + overlay.focusPending
                                + "; active=" + overlay.contentItem.Window.active)
    }

    Timer {
        interval: 60
        repeat: true
        running: true
        onTriggered: {
            if (root.phase === 0) {
                UiState.activePanel = "settings"
                UiState.openTempNote("A")
                root.check(UiState.tempNoteOpen && UiState.tempNoteScreenName === "A"
                           && UiState.activePanel === "settings", "independent state")
                UiState.openTempNote("A")
                root.check(root.closes === 0, "idempotent open")
                UiState.toggleTempNote("B")
                root.check(root.closes === 1 && UiState.tempNoteScreenName === "B", "ownership transfer")
                UiState.closeTempNoteIfScreen("A")
                root.check(UiState.tempNoteOpen, "unrelated output closed note")
                UiState.toggleTempNote("B")
                root.check(root.closes === 2 && !UiState.tempNoteOpen
                           && UiState.tempNoteScreenName === "", "same-output toggle")
                UiState.openTempNote(root.screenName)
                // Check the decorative window independently of the editor's Overlay.
                var flareLayer = overlay.data.find(function(child) { return child.objectName === "tempNoteFlareLayer" })
                root.check(flareLayer && flareLayer.WlrLayershell.layer === WlrLayer.Top,
                           "connecting flare is not below the Sidebar Overlay")
                root.check(flareLayer.WlrLayershell.keyboardFocus === WlrKeyboardFocus.None
                           && !flareLayer.mask.item && flareLayer.mask.width === 0 && flareLayer.mask.height === 0,
                           "decorative flare window captures input")
            } else if (root.phase === 1) {
                if (overlay.revealProgress > 0 && overlay.revealProgress < 1) root.sawOpening = true
                if (!overlay.interactionReady) return
                root.check(root.sawOpening, "opening skipped the morph")
                root.check(overlay.visible && root.card.x === overlay.defaultX
                           && root.card.y === overlay.defaultY, "default position")
                for (var panel of ["navigation", "settings", "hakumenu", "notifications", "actionMenu", ""]) {
                    UiState.activePanel = panel
                    root.check(overlay.panelOpen && overlay.visible, "panel switch closed note: " + panel)
                }
                root.resizeNote(120, 80)
                root.check(root.card.width > 460 && root.card.height > 330
                           && root.card.x === overlay.defaultX && root.card.y === overlay.defaultY,
                           "lower-right grip did not enlarge the note in place")
                root.check(UiState.tempNoteRect.width === root.card.width
                           && UiState.tempNoteRect.height === root.card.height,
                           "resizing left stale pointer-handoff geometry")
                root.resizeNote(-10000, -10000)
                root.check(root.card.width === 280 && root.card.height === 180,
                           "resize did not enforce minimum dimensions")
                // Resizing near the top-left must preserve its origin when default bounds change.
                overlay.dragOffset = Qt.point(20 - overlay.defaultX, 30 - overlay.defaultY)
                root.resizeNote(10000, 10000)
                root.check(root.card.x === 20 && root.card.y === 30
                           && root.card.width === overlay.width - 20 && root.card.height === overlay.height - 30,
                           "resize moved the origin or exceeded output bounds")
                root.check(TextStore.scratchDraft === "persisted note", "resizing changed the draft")
                overlay.resetPosition()
                root.check(input.mousePress(root.card, root.card.width / 2, 16, Qt.LeftButton, Qt.NoModifier, 0),
                           "drag press")
                input.mouseMove(overlay.contentItem, overlay.defaultX + root.card.width / 2 + 20,
                                overlay.defaultY + 36, 0, Qt.LeftButton, Qt.NoModifier)
                input.mouseMove(overlay.contentItem, overlay.defaultX + root.card.width / 2 + 90,
                                overlay.defaultY + 96, 0, Qt.LeftButton, Qt.NoModifier)
                input.mouseRelease(overlay.contentItem, overlay.defaultX + root.card.width / 2 + 90,
                                   overlay.defaultY + 96, Qt.LeftButton, Qt.NoModifier, 0)
            } else if (root.phase === 2) {
                root.check(root.card.x > overlay.defaultX && root.card.y > overlay.defaultY,
                           "dedicated handle did not drag card")
                // Keep the complete card reachable at both extremes of its drag offset.
                overlay.dragOffset = Qt.point(10000, 10000)
                root.check(root.card.x === overlay.maxCardX && root.card.y === overlay.maxCardY, "lower drag bounds")
                overlay.dragOffset = Qt.point(-10000, -10000)
                root.check(root.card.x === 0 && root.card.y === 0, "upper drag bounds")
                overlay.dragOffset = Qt.point(40, 20)
                UiState.tempNoteFocusRequested(root.screenName)
                TextStore.setScratchDraft("Tiếng Việt")
                input.keyClick(Qt.Key_End, Qt.NoModifier, 0)
                input.keyClick(Qt.Key_X, Qt.NoModifier, 0)
                root.flushesBeforeClose = TextStore.flushes
                input.mouseClick(root.card, root.card.width - 22, 22, Qt.LeftButton, Qt.NoModifier, 0)
                root.check(!UiState.tempNoteOpen && TextStore.flushes > root.flushesBeforeClose
                           && TextStore.flushedText === "Tiếng Việtx",
                           "close button did not flush typed text: " + TextStore.flushedText
                           + "; flushes=" + TextStore.flushes + "; open=" + UiState.tempNoteOpen)
                root.check(overlay.visible && !overlay.interactionReady && overlay.dragOffset.x === 40,
                           "close hid or reset the card before morphing")
                root.check(overlay.WlrLayershell.keyboardFocus === WlrKeyboardFocus.None,
                           "closing retained keyboard focus")
            } else if (root.phase === 3) {
                if (overlay.revealProgress > 0 && overlay.revealProgress < 1) root.sawClosing = true
                if (overlay.visible) return
                root.check(root.sawClosing && overlay.morphProgress === 0, "closing skipped the morph")
                root.check(overlay.dragOffset.x === 0 && overlay.dragOffset.y === 0, "close reset")
                UiState.openTempNote(root.screenName)
            } else if (root.phase === 4) {
                if (!overlay.interactionReady) return
                root.check(root.card.x === overlay.defaultX && root.card.y === overlay.defaultY, "reopen reset")
                root.check(root.card.width === 460 && root.card.height === 330, "reopen did not reset size")
                // Text selection and scrolling must never acquire the card's drag handler.
                input.mousePress(root.card, 40, 90, Qt.LeftButton, Qt.NoModifier, 0)
                input.mouseMove(root.card, 160, 110, 0, Qt.LeftButton, Qt.NoModifier)
                input.mouseRelease(root.card, 160, 110, Qt.LeftButton, Qt.NoModifier, 0)
                input.mouseWheel(root.card, 80, 90, Qt.NoButton, Qt.NoModifier, 0, -120, 0)
                root.check(root.card.x === overlay.defaultX && root.card.y === overlay.defaultY,
                           "editor interaction moved card")
                root.flushesBeforeClose = TextStore.flushes
                input.keyClick(Qt.Key_Escape, Qt.NoModifier, 0)
                root.check(!UiState.tempNoteOpen && TextStore.flushes > root.flushesBeforeClose, "Escape did not flush and close")
            } else if (root.phase === 5) {
                if (overlay.visible) return
                UiState.openTempNote(root.screenName)
            } else if (root.phase === 6) {
                if (!overlay.interactionReady) return
                overlay.dragOffset = Qt.point(overlay.maxCardX - overlay.defaultX, overlay.maxCardY - overlay.defaultY)
                root.flushesBeforeClose = TextStore.flushes
                UiState.toggleTempNote(Quickshell.screens.length > 1 ? Quickshell.screens[1].name : "another-output")
                root.check(!overlay.visible && TextStore.flushes > root.flushesBeforeClose, "transfer did not finish old editor")
                root.check(root.visibleNotes() === (Quickshell.screens.length > 1 ? 1 : 0), "multiple visible editors")
                UiState.openTempNote(root.screenName)
            } else if (root.phase === 7) {
                if (!overlay.interactionReady) return
                root.check(overlay.visible && root.card.x === overlay.defaultX
                           && root.card.y === overlay.defaultY, "transfer did not reset position")
                root.check(root.visibleNotes() === 1, "ownership did not return to one editor")
                overlay.dragOffset = Qt.point(40, 20)
                root.resizeNote(100, 60)
                root.flushesBeforeClose = TextStore.flushes
                UiState.closeTempNoteIfScreen(root.screenName)
                root.check(!UiState.tempNoteOpen && TextStore.flushes > root.flushesBeforeClose,
                           "close request did not flush")
            } else if (root.phase === 8) {
                root.check(overlay.revealProgress > 0 && overlay.revealProgress < 1, "close did not retain visual state")
                // Reversing an in-flight close must preserve both shape and dragged position.
                var before = overlay.morphProgress // Capture the current frame before reopening.
                UiState.openTempNote(root.screenName)
                root.check(overlay.morphProgress === before && overlay.dragOffset.x === 40
                           && overlay.cardSize.width > 460 && overlay.cardSize.height > 330,
                           "rapid reopen jumped to a different frame or position")
            } else if (root.phase === 9) {
                if (!overlay.interactionReady) return
                root.check(root.card.x === overlay.defaultX + 40 && root.card.y === overlay.defaultY + 20,
                           "reversed animation lost the dragged position")
                UiState.closeTempNoteIfScreen(root.screenName)
                root.check(!overlay.interactionReady, "closing retained editor interaction")
            } else if (root.phase === 10) {
                if (overlay.visible) return
                root.check(overlay.dragOffset.x === 0 && overlay.dragOffset.y === 0, "final close did not reset position")
                root.flushesBeforeRemoval = TextStore.flushes
                if (Quickshell.screens.length > 1) {
                    UiState.openTempNote(Quickshell.screens[1].name)
                    otherNotes.model = []
                }
            } else if (root.phase === 11) {
                root.check(!UiState.tempNoteOpen && UiState.tempNoteScreenName === "",
                           "destroying the owning instance left stale ownership")
                root.check(Quickshell.screens.length > 1 ? TextStore.flushes > root.flushesBeforeRemoval
                                                       : TextStore.flushes === root.flushesBeforeRemoval,
                           "destroying the owning instance did not flush")
                UiState.openTempNote(root.screenName)
            } else if (root.phase === 12) {
                if (!overlay.interactionReady) return
                root.check(overlay.WlrLayershell.keyboardFocus === WlrKeyboardFocus.OnDemand,
                           "focused note retains an exclusive keyboard grab")
                root.clickOutput(root.card.x + 40, root.card.y + 90)
            } else if (root.phase === 13) {
                if (!overlay.contentItem.Window.active) return
                TextStore.setScratchDraft("")
                keyboard.write("text a\n")
            } else if (root.phase === 14) {
                root.check(TextStore.scratchDraft === "a", "clicking note did not focus editor")
                root.clickOutput(overlay.width - 30, overlay.height - 30)
            } else if (root.phase === 15) {
                if (!application.active) return
                root.check(UiState.tempNoteOpen && !UiState.ownsInteraction("tempNote", root.screenName)
                           && !overlay.keyboardRequested && TextStore.flushedText === "a",
                           "application focus did not release and flush the visible note")
                keyboard.write("text b\n")
            } else if (root.phase === 16) {
                root.check(applicationEditor.text === "b" && TextStore.scratchDraft === "a",
                           "underlying application did not receive typing")
                root.clickOutput(root.card.x + 40, root.card.y + 90)
            } else if (root.phase === 17) {
                if (!overlay.contentItem.Window.active) return
                root.check(UiState.ownsInteraction("tempNote", root.screenName)
                           && overlay.WlrLayershell.keyboardFocus === WlrKeyboardFocus.OnDemand,
                           "clicking note did not restore nonmodal focus")
                keyboard.write("key 107 4\ntext c\n")
            } else if (root.phase === 18) {
                root.check(TextStore.scratchDraft === "ac" && applicationEditor.text === "b",
                           "returning to note did not restore typing")
                root.clickOutput(overlay.width - 30, overlay.height - 30)
            } else if (root.phase === 19) {
                if (!application.active) return
                root.check(TextStore.flushedText === "ac", "leaving note did not save the latest edit")
                UiState.closeTempNote()
            } else {
                if (overlay.visible) return
                console.info("Temp Note overlay passed")
                Qt.quit()
                return
            }
            root.phase++
        }
    }
}
