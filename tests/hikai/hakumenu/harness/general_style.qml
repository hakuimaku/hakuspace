import QtQuick
import QtTest
import Quickshell
import "services"
import "components/hakumenu"

ShellRoot {
    id: root
    // Exercise the actual root/content/editor height chain without unrelated pages.
    property int phase: 0
    property int scenario: 0
    property var list: null
    property var editor: null
    property bool openingFade: false
    property bool closingFade: false
    property bool captured: false
    property double tooltipStartedAt: 0
    readonly property bool reduced: Quickshell.env("HAKUSPACE_REDUCED_MOTION") === "1"
    readonly property var scenarios: [
        {height: 720, width: 486, font: 12, bottom: false},
        {height: 720, width: 486, font: 18, bottom: false},
        {height: 1080, width: 730, font: 12, bottom: false},
        {height: 720, width: 486, font: 12, bottom: true},
        {height: 720, width: 486, font: 18, bottom: true},
        {height: 1080, width: 730, font: 12, bottom: true}
    ]
    readonly property var size: scenarios[scenario]
    readonly property real baseHeight: size.height * 0.4

    // Report the failing case and stop before issuing more pointer actions.
    function check(ok, message) {
        if (ok) return
        console.error("General style phase=" + phase + " scenario=" + scenario + ": " + message)
        Qt.exit(1)
        throw new Error(message)
    }
    // Locate real row delegates, layout controls and dynamically loaded editors.
    function find(item, name) {
        if (!item) return null
        if (name === "list" ? item.editorRequested !== undefined : item.objectName === name) return item
        for (var child of item.children || []) { var match = find(child, name); if (match) return match }
        return null
    }
    // Verify controls are inside the editor without changing any scroll position.
    function inside(name) {
        var item = find(editor, name)
        check(!!item, name + " exists")
        var point = item.mapToItem(editor, 0, 0)
        check(point.y >= 0 && point.y + item.height <= editor.height + 1, name + " fully visible")
    }

    Window {
        id: window
        width: root.size.width + 40
        height: root.size.height
        visible: true
        color: Theme.surface
        HakuMenuRoot {
            id: page
            x: 20
            y: 20
            width: root.size.width
            height: Math.min(Math.max(root.baseHeight, editorHeight), window.height - 40)
            panelOpen: true
            interactionOwned: true
            bottomAttached: root.size.bottom
        }
        TestEvent { id: input }
    }
    Timer {
        running: true
        repeat: true
        interval: 25
        onTriggered: {
            if (GeneralMenuService.busy) return
            switch (root.phase) {
            case 0:
                if (GeneralMenuService.items.length === 0) return
                Theme.fontSize = root.size.font
                root.list = root.find(page, "list")
                if (!root.list) return
                root.list.rowClicked(0, Qt.RightButton)
                root.phase++
                break
            case 1:
                var row = root.find(page, "general-row-code-editor")
                var edit = root.find(page, "general-edit-code-editor")
                var trash = root.find(page, "general-delete-code-editor")
                var rail = root.find(page, "general-rail-code-editor")
                root.check(edit.idleColor.a > 0 && trash.idleColor.a > 0, "action backgrounds")
                root.check(rail.x - (row.x + row.width) >= Theme.spaceMd - 1, "pill and buttons have spacing")
                root.check(trash.x - (edit.x + edit.width) >= Theme.spaceSm - 1, "edit and delete have spacing")
                var tip = Array.from(trash.data).find(item => item.objectName === "general-delete-tooltip-code-editor")
                root.check(!!tip && tip.text === "Delete custom action", "delete tooltip text")
                if (root.scenario === 0) {
                    if (!root.tooltipStartedAt) {
                        input.mouseMove(trash, trash.width / 2, trash.height / 2, 0, Qt.NoButton, Qt.NoModifier)
                        root.tooltipStartedAt = Date.now()
                        return
                    }
                    if (!tip.visible) {
                        root.check(Date.now() - root.tooltipStartedAt < 2000, "delete tooltip appears on hover")
                        return
                    }
                }
                root.list.openEditor(null)
                root.phase++
                break
            case 2:
                root.editor = root.list.itemEditor
                if (!root.editor) return
                if (root.editor.opacity > 0 && root.editor.opacity < 1) root.openingFade = true
                if (root.editor.opacity < 0.999) return
                root.check(root.reduced || root.openingFade, "first opening fades")
                root.check(page.height > root.baseHeight && root.editor.height >= root.editor.implicitHeight - 1, "host grows to the complete editor")
                root.inside("general-icon"); root.inside("general-name"); root.inside("general-command")
                root.inside("general-cancel"); root.inside("general-save")
                root.check(root.find(root.editor, "general-save").parent.parent === root.editor, "footer is outside scrolling fields")
                if (!root.captured) {
                    var icon = root.find(root.editor, "general-icon")
                    var name = root.find(root.editor, "general-name")
                    var command = root.find(root.editor, "general-command")
                    var catalog = root.find(root.editor, "general-icon-catalog")
                    for (var field of [icon, name, command])
                        root.check(field.leftPadding >= Theme.spaceLg && field.rightPadding >= Theme.spaceLg, "textbox padding")
                    var commandBottom = command.mapToItem(root.editor, 0, command.height).y
                    var footer = root.find(root.editor, "general-save").parent
                    root.check(footer.y - commandBottom >= Theme.spaceLg - 1, "footer spacing")
                    icon.forceActiveFocus()
                    input.keyClick(Qt.Key_A, Qt.NoModifier, 0)
                    input.keyClick(Qt.Key_B, Qt.NoModifier, 0)
                    root.check(root.editor.iconText === "a", "typing keeps one character")
                    icon.clear()
                    Quickshell.clipboardText = "󰖩"
                    input.keyClick(Qt.Key_V, Qt.ControlModifier, 0)
                    root.check(root.editor.iconText === "󰖩" && root.editor.iconText.length === 2, "pasted supplementary glyph remains intact")
                    root.editor.iconText = "ab"
                    root.editor.labelText = "Valid"
                    root.editor.commandText = "true"
                    root.editor.save()
                    root.check(!root.editor.saving && root.editor.error.length > 0, "save rejects multiple icon characters")
                    root.editor.iconText = "󰖩"
                    root.editor.labelText = ""
                    root.editor.commandText = ""
                    root.editor.error = ""
                    icon.forceActiveFocus()
                    input.keyClick(Qt.Key_Tab, Qt.NoModifier, 0)
                    root.check(catalog.activeFocus, "icon reference is keyboard accessible")
                    input.keyClick(Qt.Key_Tab, Qt.NoModifier, 0)
                    root.check(name.activeFocus, "icon reference returns to Name")
                    root.captured = true
                    page.grabToImage(result => result.saveToFile("/tmp/haku-general-style-" + root.scenario + ".png"))
                    return
                }
                root.list.closeEditor()
                root.phase++
                break
            case 3:
                if (root.reduced) { root.phase = 5; return }
                root.check(root.list.editorHeight > 0 && page.height > root.baseHeight, "host remains expanded during close")
                if (root.editor.opacity <= 0 || root.editor.opacity >= 0.95) return
                root.closingFade = true
                root.list.openEditor(null)
                root.check(root.list.itemEditor === root.editor, "reopening reverses the same editor")
                root.phase++
                break
            case 4:
                if (root.editor.opacity < 0.999) return
                root.check(root.closingFade, "closing fade observed")
                root.list.closeEditor()
                root.phase++
                break
            case 5:
                if (root.list.itemEditor) return
                root.check(page.editorHeight === 0 && page.height === root.baseHeight, "height restores after fade completion")
                if (root.scenario === root.scenarios.length - 1) {
                    console.log("General editor style passed")
                    Qt.quit()
                    return
                }
                root.scenario++
                root.phase = 0
                root.openingFade = false
                root.closingFade = false
                root.captured = false
                break
            }
        }
    }
    Timer { running: true; interval: 25000; onTriggered: { console.error("General style timed out"); Qt.exit(1) } }
}
