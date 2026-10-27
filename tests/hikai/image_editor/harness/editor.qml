import QtQuick
import Quickshell
import Quickshell.Io
import "services"
import "components/base" as Base
import "components/imageeditor" as Editing
import "components/notification" as NotificationUi

ShellRoot {
    id: root
    // Drive only the image editor and its two persistence consumers in a private session.
    property int phase: 0
    property int ticks: 0
    property bool clipboardReadRequested: false
    property int inputPhase: 0
    property int cropPhase: 0
    property int cropUndoCount: 0
    property real idleToolRadius: 0
    property QtObject notificationMemory: QtObject { property string recordsJson: "[]"; property int nextKey: 1 }
    property var testCard: null
    PersistentProperties {
        id: reloadMemory
        reloadableId: "image-editor-runtime-reload"
        property bool reloaded: false
        onLoaded: if (reloaded) root.phase = 15
    }
    property var hosts: []
    readonly property string fixture: Quickshell.env("IMAGE_EDITOR_FIXTURE")
    readonly property string source: fixture + "/source # with space.png"
    readonly property string screenshot: fixture + "/screenshot with space.png"
    property string firstScreen: ""
    property string secondScreen: ""
    function check(condition, message) {
        if (condition) return
        console.error("Image editor runtime failed: " + message)
        Qt.exit(1)
        throw new Error(message)
    }
    function loaded() { return hosts.filter(function(host) { return host && host.active }).length }
    Variants {
        model: Quickshell.screens
        Base.LifecycleLoader {
            id: host
            required property var modelData
            requested: !!modelData && UiState.activePanel === "imageEditor" && UiState.imageEditorScreenName === modelData.name
            Component.onCompleted: root.hosts = root.hosts.concat([host])
            Editing.ImageEditorOverlay { modelData: host.modelData }
        }
    }
    function find(item, predicate) {
        if (!item) return null
        if (predicate(item)) return item
        for (var child of item.children || []) { var found = find(child, predicate); if (found) return found }
        return null
    }
    function sendPointer(overlay, canvas, x, y, state) {
        var p = canvas.mapToItem(overlay.contentItem, canvas.width * x, canvas.height * y)
        pointer.write(Math.round(p.x) + " " + Math.round(p.y) + " " + overlay.width + " " + overlay.height + (state < 0 ? " 0\n" : " 272 " + state + "\n"))
    }
    Process { id: pointer; command: ["python3", root.fixture + "/wayland_pointer.py"]; stdinEnabled: true; running: root.firstScreen.length > 0; environment: ({HAKUSPACE_TEST_POINTER_OUTPUT: root.firstScreen}) }
    Process { id: keyboard; command: ["python3", root.fixture + "/wayland_keyboard.py"]; stdinEnabled: true; running: true }
    Process { id: capture; command: ["grim", "-o", root.firstScreen, Quickshell.env("IMAGE_EDITOR_ARTIFACTS") + "/preview.png"] }
    Process { id: cropCapture; command: ["grim", "-o", root.firstScreen, Quickshell.env("IMAGE_EDITOR_ARTIFACTS") + "/crop.png"] }
    Process {
        id: clipboardProbe
        property int resultCode: -1
        command: ["sh", "-c", 'exec wl-paste --type image/png > "$1"', "image-editor-clipboard", root.fixture + "/clipboard.png"]
        onStarted: resultCode = -1
        onExited: code => resultCode = code
    }
    Process { id: failClipboard; command: ["touch", root.fixture + "/fail-clipboard"] }
    Process { id: notify; command: ["notify-send", "-t", "0", "-h", "string:x-hakuspace-kind:screenshot", "-h", "string:x-hakuspace-path:" + root.screenshot, "Screenshot test"] }
    Component { id: card; NotificationUi.NotificationCard { record: NotificationStore.records[0] } }
    Process { id: removeOutput; command: ["wlr-randr", "--output", root.secondScreen, "--off"] }
    Timer {
        interval: 80; repeat: true; running: true
        onTriggered: {
            if (++root.ticks > 600) { root.check(false, "timeout at phase " + root.phase + ": " + ImageEditor.status()); return }
            if (root.phase === 0) {
                if (Quickshell.screens.length < 2) return
                root.firstScreen = Quickshell.screens[0].name; root.secondScreen = Quickshell.screens[1].name
                root.check(ImageEditor.open(root.source, root.firstScreen), "open generic image")
                root.check(!ImageEditor.open(root.source, root.secondScreen), "second open preserves active draft")
            } else if (root.phase === 1) {
                if (!ImageEditor.ready || !root.loaded() || !root.hosts[0].item || root.hosts[0].item.expansion < 1) return
                root.check(UiState.ownsInteraction("imageEditor", root.firstScreen), "standalone keyboard owner")
                var overlay = root.hosts[0].item
                var canvas = root.find(overlay.contentItem, function(item) { return item.replacing !== undefined })
                if (!canvas || !canvas.visible || !canvas.width) return
                var preview = root.find(overlay.contentItem, function(item) { return item.autoTransform !== undefined })
                root.check(preview && preview.sourceSize.width < ImageEditor.sourceWidth && preview.sourceSize.height < ImageEditor.sourceHeight, "preview decode is bounded to viewport")
                if (root.inputPhase === 0) { ImageEditor.tool = "pen"; root.sendPointer(overlay, canvas, .2, .3, 1); ++root.inputPhase; return }
                if (root.inputPhase === 1) { root.sendPointer(overlay, canvas, .4, .5, -1); ++root.inputPhase; return }
                if (root.inputPhase === 2) { root.sendPointer(overlay, canvas, .4, .5, 0); ++root.inputPhase; return }
                if (root.inputPhase === 3) {
                    root.check(ImageEditor.annotations.length === 1 && ImageEditor.undoStack.length === 1, "one pointer stroke is one undo step: " + ImageEditor.annotations.length + "/" + ImageEditor.undoStack.length + " on " + root.firstScreen)
                    keyboard.write("key 44 4\n"); ++root.inputPhase; return
                }
                if (root.inputPhase === 4) { root.check(!ImageEditor.annotations.length, "Ctrl+Z undoes stroke"); keyboard.write("key 44 5\n"); ++root.inputPhase; return }
                if (root.inputPhase === 5) {
                    root.check(ImageEditor.annotations.length === 1, "Ctrl+Shift+Z restores stroke")
                    ImageEditor.tool = "arrow"; root.sendPointer(overlay, canvas, .3, .4, 1); ++root.inputPhase; return
                }
                if (root.inputPhase === 6) { root.sendPointer(overlay, canvas, .7, .6, -1); ++root.inputPhase; return }
                if (root.inputPhase === 7) { root.sendPointer(overlay, canvas, .7, .6, 0); ++root.inputPhase; return }
                if (root.inputPhase === 8) {
                    root.check(ImageEditor.annotations.length === 2, "arrow pointer gesture")
                    ImageEditor.tool = "select"; root.sendPointer(overlay, canvas, .5, .5, 1); ++root.inputPhase; return
                }
                if (root.inputPhase === 9) { root.sendPointer(overlay, canvas, .5, .5, 0); ++root.inputPhase; return }
                if (root.inputPhase === 10) {
                    root.check(ImageEditor.selectedAnnotation === 1, "select arrow object")
                    root.sendPointer(overlay, canvas, .7, .6, 1); ++root.inputPhase; return
                }
                if (root.inputPhase === 11) { root.sendPointer(overlay, canvas, .8, .7, -1); ++root.inputPhase; return }
                if (root.inputPhase === 12) { root.sendPointer(overlay, canvas, .8, .7, 0); ++root.inputPhase; return }
                if (root.inputPhase === 13) {
                    root.check(ImageEditor.annotations[1].end.x > .79, "drag selected arrow endpoint")
                    capture.running = true; ++root.inputPhase; return
                }
                if (capture.running) return
                var select = root.find(overlay.contentItem, function(item) { return item.text === "Select" })
                var rail = select.parent
                root.check(select.height >= 40 && Math.abs(rail.children[4].y + rail.children[4].height - rail.height) < 1, "larger toolbar buttons fill the rail")
                var rotate = root.find(overlay.contentItem, function(item) { return item.text && item.text.endsWith("Rotate left 90°") })
                var flip = root.find(overlay.contentItem, function(item) { return item.text && item.text.endsWith("Flip horizontal") })
                root.check(rotate && flip && rotate.parent === flip.parent && rotate.parent !== rail
                    && rotate.mapToItem(overlay.contentItem,0,rotate.height).y < canvas.mapToItem(overlay.contentItem,0,0).y,
                    "rotation and mirror actions have their own row above the image")
                var cancel = root.find(overlay.contentItem, function(item) { return item.text === "Cancel" })
                var cancelPosition = cancel.mapToItem(overlay.contentItem,0,0)
                root.check(Math.abs(cancelPosition.x - ((overlay.width - Math.min(overlay.width * .88,1600)) / 2 + 28)) < 1
                    && Math.abs(cancelPosition.y - ((overlay.height - Math.min(overlay.height * .88,960)) / 2 + 24)) < 1,
                    "shared layer inset adds twelve pixels on each side")
                var cropOverlay = root.find(overlay.contentItem, function(item) { return item.handleReach !== undefined })
                var imageBounds = canvas.mapToItem(cropOverlay.parent.parent, 0, 0)
                root.check(imageBounds.x >= 28 && imageBounds.y >= 28, "image has padding outside its handles")
                if (root.cropPhase === 0) {
                    ImageEditor.reset(); ImageEditor.tool = "crop"
                    root.cropUndoCount = ImageEditor.undoStack.length
                    root.sendPointer(overlay, canvas, -10 / canvas.width, -10 / canvas.height, 1)
                    ++root.cropPhase; return
                }
                if (root.cropPhase === 1) { root.sendPointer(overlay, canvas, .15, .15, -1); ++root.cropPhase; return }
                if (root.cropPhase === 2) { root.sendPointer(overlay, canvas, .15, .15, 0); ++root.cropPhase; return }
                if (root.cropPhase === 3) {
                    root.check(ImageEditor.cropRectNormalized.x > .14 && ImageEditor.cropRectNormalized.y > .14 && ImageEditor.undoStack.length === root.cropUndoCount + 1, "outside corner grab commits one crop step")
                    ImageEditor.undo(false)
                    root.sendPointer(overlay, canvas, .5, -10 / canvas.height, 1)
                    ++root.cropPhase; return
                }
                if (root.cropPhase === 4) { root.sendPointer(overlay, canvas, .5, .2, -1); ++root.cropPhase; return }
                if (root.cropPhase === 5) { root.sendPointer(overlay, canvas, .5, .2, 0); ++root.cropPhase; return }
                if (root.cropPhase === 6) {
                    root.check(ImageEditor.cropRectNormalized.y > .19 && ImageEditor.cropRectNormalized.width === 1, "top edge grab resizes without moving side edges")
                    cropCapture.running = true
                    root.idleToolRadius = select.radius
                    var buttonPoint = select.mapToItem(overlay.contentItem, select.width / 2, select.height / 2)
                    pointer.write(Math.round(buttonPoint.x) + " " + Math.round(buttonPoint.y) + " " + overlay.width + " " + overlay.height + " 0\n")
                    ++root.cropPhase; return
                }
                if (root.cropPhase === 7) {
                    if (!select.hovered || Math.abs(select.radius - select.height / 2) > 1 || cropCapture.running) return
                    root.check(select.radius > root.idleToolRadius + 4 && select.horizontalScale > 1, "sidebar button morphs on hover")
                }
                ImageEditor.reset()
                ImageEditor.addAnnotation({type:"arrow",start:{x:.1,y:.2},end:{x:.7,y:.6},width:.006,color:"#ff3b30",opacity:1})
                ImageEditor.orient("cw")
                root.check(Math.abs(ImageEditor.annotations[0].start.x - .8) < .0001, "annotation rotates with image")
                ImageEditor.orient("horizontal")
                ImageEditor.setRatio(1)
                ImageEditor.undo(false); ImageEditor.undo(true)
                root.check(ImageEditor.dirty && ImageEditor.annotations.length === 1, "document history")
                ImageEditor.save(root.fixture + "/export.png")
            } else if (root.phase === 2) {
                if (ImageEditor.busy || ImageEditor.sourcePath || root.loaded()) return
                root.check(!ImageEditor.lastError, "generic export: " + ImageEditor.lastError)
                root.check(ImageEditor.openAvatar(root.source, root.secondScreen), "avatar opens independently")
            } else if (root.phase === 3) {
                if (!ImageEditor.ready) return
                root.check(ImageEditor.outputSize.width === 512 && ImageEditor.outputSize.height === 512, "avatar output contract")
                ImageEditor.save("")
            } else if (root.phase === 4) {
                if (ImageEditor.busy || ImageEditor.sourcePath || root.loaded()) return
                root.check(Avatar.revision === 1 && Avatar.hasAvatar, "avatar committed through controller")
                root.check(ImageEditor.openScreenshot(root.screenshot, root.firstScreen), "screenshot open")
            } else if (root.phase === 5) {
                if (!ImageEditor.ready) return
                ImageEditor.setOutput(.5,90)
                ImageEditor.save("")
                root.check(!ImageEditor.close(), "cancel cannot race a commit")
            } else if (root.phase === 6) {
                if (ImageEditor.busy || ImageEditor.sourcePath || root.loaded()) return
                root.check(!ImageEditor.lastError, "screenshot export: " + ImageEditor.lastError)
                if (!root.clipboardReadRequested) { root.clipboardReadRequested = true; clipboardProbe.running = true; return }
                if (clipboardProbe.running) return
                root.check(clipboardProbe.resultCode === 0, "real clipboard remains readable after export and editor teardown")
                ImageEditor.open(root.source, root.secondScreen)
            } else if (root.phase === 7) {
                if (!ImageEditor.ready) return
                ImageEditor.close()
                root.check(ImageEditor.open(root.source,root.secondScreen), "close/reopen reversal")
                removeOutput.running = true
            } else if (root.phase === 8) {
                if (removeOutput.running || Quickshell.screens.some(function(screen) { return screen.name === root.secondScreen })) return
                root.check(ImageEditor.screenName === root.firstScreen && UiState.ownsInteraction("imageEditor", root.firstScreen), "removed output transfers draft and input")
                ImageEditor.close()
            } else if (root.phase === 9) {
                if (ImageEditor.sourcePath || root.loaded()) return
                ImageEditor.open(root.fixture + "/missing.png",root.firstScreen)
            } else if (root.phase === 10) {
                if (ImageEditor.busy) return
                root.check(!!ImageEditor.lastError && !ImageEditor.ready, "missing source error is recoverable")
                ImageEditor.close()
            } else if (root.phase === 11) {
                if (ImageEditor.sourcePath || root.loaded()) return
                NotificationStore.start(root.notificationMemory)
            } else if (root.phase === 12) {
                if (!NotificationStore.server.objectAt(0)) return
                notify.running = true
            } else if (root.phase === 13) {
                if (notify.running || !NotificationStore.records.length) return
                root.check(NotificationStore.records[0].kind === "screenshot" && NotificationStore.records[0].imagePath === root.screenshot, "notification hints reach the shared record")
                var unrelated = Object.assign({}, NotificationStore.records[0], {key: 9000, kind: "", imagePath: "", popupEligible: true})
                NotificationStore.records = NotificationStore.records.concat([unrelated])
                root.testCard = card.createObject(null)
                var edit = root.find(root.testCard, function(item) { return item.text === "Edit" })
                root.check(edit && edit.visible, "shared popup and history card offers Edit")
                root.check(edit.width === edit.parent.width && edit.height >= 40 && Qt.colorEqual(edit.targetBackground, Theme.accent), "screenshot Edit fills the card with accent")
                edit.clicked()
                root.check(ImageEditor.mode === "screenshot" && !NotificationStore.records[0].popupEligible, "Edit opens session and dismisses popup")
                root.check(NotificationStore.records[1].popupEligible, "Edit preserves unrelated popups")
                root.testCard.destroy(); root.testCard = null
            } else if (root.phase === 14) {
                if (!ImageEditor.ready) return
                reloadMemory.reloaded = true
                Quickshell.reload(false)
                return
            } else if (root.phase === 15) {
                root.check(!ImageEditor.sourcePath && !root.loaded() && UiState.interactionOwner === "", "reload discards unsaved UI and releases input")
                root.firstScreen = Quickshell.screens[0].name
                NotificationStore.start(root.notificationMemory)
            } else if (root.phase === 16) {
                if (!NotificationStore.server.objectAt(0)) return
                failClipboard.running = true
                ImageEditor.openScreenshot(root.fixture + "/screenshot clipboard failure.png",root.firstScreen)
            } else if (root.phase === 17) {
                if (failClipboard.running || !ImageEditor.ready) return
                ImageEditor.setOutput(.75,90)
                ImageEditor.save("")
            } else if (root.phase === 18) {
                if (ImageEditor.busy || ImageEditor.sourcePath || root.loaded()) return
                root.check(ImageEditor.lastError.indexOf("clipboard") >= 0 && UiState.interactionOwner === "", "clipboard failure still closes the editor and releases focus")
                if (!NotificationStore.records.some(function(record) { return record.summary === "Image saved" && record.body.indexOf("clipboard") >= 0 })) return
                if (!root.clipboardReadRequested) { root.clipboardReadRequested = true; clipboardProbe.running = true; return }
                if (clipboardProbe.running) return
                root.check(clipboardProbe.resultCode === 0, "failed copy preserves the previous clipboard contents")
                console.log("Image editor real clipboard and warning-close checks passed")
                console.log("Image editor runtime checks passed")
                Qt.quit()
            }
            ++root.phase
        }
    }
}
