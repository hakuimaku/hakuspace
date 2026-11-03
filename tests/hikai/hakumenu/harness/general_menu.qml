import QtQuick
import QtTest
import Quickshell
import Quickshell.Io
import "services"
import "components/hakumenu"

ShellRoot {
    id: root
    // Drive real pointer events against only the General view and its editor.
    property int step: 0
    property string identity: ""
    property string staleRevision: ""
    property int deletePhase: 0
    property int launches: 0
    property bool closeOnLaunch: false
    property int failedMutations: 0
    property bool edited: false
    property string rofiText: ""
    property bool rofiReady: false

    // Fail without continuing the state machine after an assertion.
    function check(condition, message) {
        if (condition) return
        console.error("General menu step " + step + ": " + message)
        Qt.exit(1)
        throw new Error(message)
    }
    // Find actual delegates and controls, including loaded editor content.
    function find(item, name, visibleOnly) {
        if (!item) return null
        if (item.objectName === name && (!visibleOnly || item.visible)) return item
        for (var child of item.children || []) {
            var found = find(child, name, visibleOnly)
            if (found) return found
        }
        return null
    }
    // Dispatch actual mouse events so action controls cannot bypass propagation tests.
    function click(name, button) {
        var target = find(list, name, true)
        check(!!target && target.visible, "visible target " + name)
        input.mouseMove(target, target.width / 2, target.height / 2, 0, Qt.NoButton, Qt.NoModifier)
        input.mouseClick(target, target.width / 2, target.height / 2, button || Qt.LeftButton, Qt.NoModifier, 0)
    }
    // Inspect Classic output after the same mutations performed from Hikai.
    function readRofi() { rofiReady = false; rofi.running = true }

    Window {
        id: window
        width: 640
        height: 760
        visible: true
        GeneralList {
            id: list
            anchors.fill: parent
            onLaunched: { root.launches++; if (root.closeOnLaunch) UiState.closeHakuMenu() }
        }
        TestEvent { id: input }
    }
    Connections {
        target: GeneralMenuService
        function onMutationFinished(operation, success) { if (!success) root.failedMutations++ }
    }
    Process {
        id: editor
        command: ["python3", "-c", "import os; p=os.environ['HAKUSPACE_GENERAL_MENU_FILE']; open(p,'ab').write(b'\\n')"]
        onExited: code => { root.check(code === 0, "external editor"); root.edited = true }
    }
    Process {
        id: rofi
        command: ["bash", Quickshell.env("HAKU_GENERAL_ADAPTER")]
        environment: ({ROFI_RETV: "0", ROFI_INFO: ""})
        stdout: StdioCollector { id: rofiOutput }
        onExited: code => {
            root.check(code === 0, "Classic snapshot")
            root.rofiText = rofiOutput.text
            root.rofiReady = true
        }
    }
    // Simulate an external document with no enabled Hikai custom rows.
    Process {
        id: emptyCustom
        command: ["python3", "-c", "import json,os; p=os.environ['HAKUSPACE_GENERAL_MENU_FILE']; d=json.load(open(p)); [v.update(enabled=False) for v in d['items']]; open(p,'w').write(json.dumps(d))"]
        onExited: code => root.check(code === 0, "disable custom fixture")
    }
    Timer {
        interval: 40
        running: true
        repeat: true
        onTriggered: {
            if (GeneralMenuService.busy || editor.running || rofi.running || emptyCustom.running) return
            if (list.itemEditor && !list.editorRequested) return
            switch (root.step) {
            case 0:
                if (!GeneralMenuService.revision) return
                root.check(GeneralMenuService.items.length === 7, "backend custom only")
                root.check(list.customItems.length === 6 && list.staticItems.length === 7 && list.visibleItems.length === 13, "6 custom + 7 static")
                root.check(list.visibleItems[0].id === "code-editor" && list.visibleItems[6].id === "static-wifi", "custom/static order")
                root.check(list.visibleItems[6].sectionStart, "divider at the block boundary")
                root.readRofi()
                root.step++
                break
            case 1:
                if (!root.rofiReady) return
                root.check(root.rofiText.indexOf("App Menu") >= 0 && root.rofiText.indexOf("Wifi") < 0 && root.rofiText.indexOf("Bluetooth") < 0, "Classic sees custom only")
                GeneralMenuService.update("app-menu", {label: "Whatever"})
                root.step++
                break
            case 2:
                root.check(!list.visibleItems.some(item => item.id === "app-menu"), "renamed app-menu stays hidden by ID")
                root.click("general-row-browser", Qt.RightButton)
                root.check(list.actionRowId === "browser" && root.launches === 0, "right click does not launch")
                root.check(root.find(list, "general-rail-browser").visible, "custom controls visible")
                root.click("general-row-code-editor", Qt.RightButton)
                root.check(list.actionRowId === "code-editor" && !root.find(list, "general-rail-browser").visible, "only one rail")
                root.click("general-row-static-wifi", Qt.RightButton)
                root.check(!list.actionRowId && !root.find(list, "general-rail-static-wifi").visible, "static has no rail")
                root.click("general-row-browser", Qt.RightButton)
                list.query = "> Browser"
                root.check(!list.actionRowId, "query change closes context")
                root.step++
                break
            case 3:
                root.check(list.visibleItems.length === 1 && !list.visibleItems[0].sectionStart, "custom-only search has no divider")
                root.click("general-row-browser", Qt.RightButton)
                root.click("general-edit-browser")
                root.check(root.launches === 0 && list.editorRequested, "edit click never bubbles into launch")
                root.step++
                break
            case 4:
                if (!list.itemEditor) return
                root.check(list.itemEditor.editing && list.itemEditor.labelText === "Browser", "shared edit form")
                root.click("general-cancel")
                list.query = "> Wifi"
                root.step++
                break
            case 5:
                root.check(list.visibleItems.length === 1 && list.visibleItems[0].kind === "static" && !list.visibleItems[0].sectionStart, "static-only search has no divider")
                list.query = "o"
                root.step++
                break
            case 6:
                if (list.query === "o") {
                    root.check(list.visibleItems.some(item => item.sectionStart) && !root.find(list, "general-add", true), "search keeps boundary but hides Add")
                    list.query = ""
                    return
                }
                root.click("general-add")
                root.step++
                break
            case 7:
                if (!list.itemEditor) return
                root.check(!list.itemEditor.editing && list.currentIndex === 0, "Add is outside row selection")
                list.itemEditor.save()
                root.check(list.itemEditor.error.length > 0 && !list.itemEditor.saving, "required fields validated")
                list.itemEditor.iconText = "󰈹"
                list.itemEditor.labelText = "Browser"
                list.itemEditor.commandText = 'printf "unterminated'
                root.click("general-save")
                root.step++
                break
            case 8:
                root.check(list.editorRequested && list.itemEditor.error.length > 0 && GeneralMenuService.items.length === 7, "backend parsing error keeps draft open")
                list.itemEditor.commandText = "python3 -c \"import os; open(os.environ['HAKU_GENERAL_LAUNCHED'], 'w').write('launched')\""
                root.click("general-save")
                root.step++
                break
            case 9:
                root.check(!list.editorRequested && GeneralMenuService.items.length === 8, "Add closes only on success")
                root.identity = GeneralMenuService.items[7].id
                root.check(list.customItems[6].id === root.identity, "Add appends above divider")
                list.query = "> Browser"
                root.readRofi()
                root.step++
                break
            case 10:
                root.check(root.rofiText.indexOf(root.identity) >= 0 && list.visibleItems.length === 2, "Add visible in both frontends with duplicate labels")
                root.click("general-row-" + root.identity, Qt.RightButton)
                root.click("general-edit-" + root.identity)
                root.step++
                break
            case 11:
                if (!list.itemEditor) return
                list.itemEditor.labelText = "Renamed"
                list.itemEditor.commandText = "python3 -c \"import os; open(os.environ['HAKU_GENERAL_LAUNCHED'], 'w').write('edited-launch')\""
                root.staleRevision = GeneralMenuService.revision
                editor.running = true
                root.step++
                break
            case 12:
                if (!root.edited) return
                root.click("general-save")
                root.step++
                break
            case 13:
                if (GeneralMenuService.revision === root.staleRevision) return
                root.check(list.editorRequested && list.itemEditor.labelText === "Renamed" && list.itemEditor.error.length > 0, "conflict preserves editor draft and error after refresh")
                root.check(root.failedMutations === 2, "conflicting save rejected")
                root.click("general-save")
                root.step++
                break
            case 14:
                root.check(!list.editorRequested && GeneralMenuService.items[7].id === root.identity, "retry preserves ID")
                list.query = "> Renamed"
                root.readRofi()
                root.step++
                break
            case 15:
                root.check(root.rofiText.indexOf("Renamed") >= 0 && list.visibleItems[0].id === root.identity, "Edit seen by both frontends")
                list.activateIndex(0)
                list.query = ""
                root.step++
                break
            case 16:
                root.check(!GeneralMenuService.error && root.launches === 1, "custom launches by ID")
                if (root.deletePhase === 0) {
                    root.click("general-row-" + root.identity, Qt.RightButton)
                } else if (root.deletePhase === 1) {
                    root.click("general-delete-" + root.identity)
                    root.check(list.deleteRowId === root.identity && GeneralMenuService.items.length === 8, "first delete click only confirms")
                } else if (root.deletePhase === 2) {
                    root.click("general-delete-cancel-" + root.identity)
                    root.check(!list.deleteRowId, "cancel inline confirmation")
                } else if (root.deletePhase === 3) {
                    root.click("general-delete-" + root.identity)
                } else {
                    root.staleRevision = GeneralMenuService.revision
                    root.edited = false
                    editor.running = true
                    root.step++
                }
                root.deletePhase++
                break
            case 17:
                if (!root.edited) return
                root.click("general-delete-" + root.identity)
                root.step++
                break
            case 18:
                if (GeneralMenuService.revision === root.staleRevision) return
                root.check(list.actionRowId === root.identity && list.deleteRowId === root.identity && list.actionError.length > 0, "delete conflict keeps rail and confirmation")
                root.check(root.failedMutations === 3 && root.launches === 1, "delete clicks never launch")
                root.click("general-delete-" + root.identity)
                root.step++
                break
            case 19:
                root.check(!list.actionRowId && GeneralMenuService.items.length === 7, "Delete closes rail only on success")
                root.check(list.currentIndex === 6 && list.visibleItems[6].id === "static-wifi", "delete selects nearest surviving row: " + list.currentIndex)
                list.query = ""
                root.readRofi()
                root.step++
                break
            case 20:
                root.check(root.rofiText.indexOf(root.identity) < 0 && !list.customItems.some(item => item.id === root.identity), "Delete seen by both frontends")
                root.click("general-row-browser", Qt.RightButton)
                list.panelOpen = false
                root.check(!list.actionRowId && !list.editorRequested, "closing menu resets controls")
                list.panelOpen = true
                root.click("general-row-browser", Qt.RightButton)
                list.visible = false
                root.check(!list.actionRowId, "changing tabs clears context")
                list.visible = true
                root.click("general-row-browser", Qt.RightButton)
                root.click("general-row-browser", Qt.RightButton)
                root.check(!list.actionRowId, "right click again closes rail")
                root.click("general-row-static-wifi")
                root.check(root.launches === 2, "static launch stays in Hikai")
                root.step++
                break
            case 21:
                emptyCustom.running = true
                root.step++
                break
            case 22:
                GeneralMenuService.refresh()
                root.step++
                break
            case 23:
                root.check(list.customItems.length === 0 && list.visibleItems.length === 7, "empty custom block keeps static controls")
                root.check(!list.visibleItems.some(item => item.sectionStart), "no empty divider")
                root.click("general-add")
                root.step++
                break
            case 24:
                if (!list.itemEditor) return
                root.check(!list.itemEditor.editing, "Add remains reachable when custom is empty")
                // Traverse editor fields and buttons without leaving the draft surface.
                root.find(list, "general-name").forceActiveFocus()
                input.keyClick(Qt.Key_Tab, Qt.NoModifier, 0)
                root.check(root.find(list, "general-command").activeFocus, "Tab stays inside editor")
                root.click("general-cancel")
                root.step++
                break
            case 25:
                if (list.itemEditor) return
                root.check(!list.editorRequested, "editor released after visual closure")
                list.query = "Task Manager"
                root.step++
                break
            case 26:
                root.check(list.visibleItems.length === 1 && list.visibleItems[0].id === "static-task-manager", "Task Manager static row")
                root.click("general-row-static-task-manager", Qt.RightButton)
                root.check(!list.actionRowId, "Task Manager has no CRUD rail")
                UiState.hakuMenuScreenName = "fixture-output"
                root.click("general-row-static-task-manager")
                root.check(UiState.openedPanel === "taskManager" && UiState.openedScreenName === "fixture-output", "Task Manager uses native output handoff")
                list.query = "Settings"
                root.step++
                break
            case 27:
                root.check(list.visibleItems.length === 1 && list.visibleItems[0].id === "static-settings", "Settings static row")
                UiState.hakuMenuScreenName = "fixture-output"
                root.closeOnLaunch = true
                root.click("general-row-static-settings")
                root.check(UiState.openedPanel === "settings" && UiState.openedScreenName === "fixture-output" && UiState.hakuMenuScreenName === "", "Settings preserves output before menu closes")
                console.log("General menu QML integration passed")
                Qt.quit()
            }
        }
    }
    Timer {
        interval: 20000
        running: true
        onTriggered: { console.error("General menu harness timed out at step " + root.step); Qt.exit(1) }
    }
}
