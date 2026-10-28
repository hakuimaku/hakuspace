import QtQuick
import QtQuick.Controls
import "../../services"
import "../../config/SettingsCatalog.js" as Catalog
import "SettingsNavigation.js" as Navigation
import "../motion" as Motion

Item {
    id: root
    property string category: "Look"
    property string highlightedId: ""
    property Item shortcutTarget: null
    property Component headerContent: null
    property Component leadingContent: null
    property Component trailingContent: null
    property var excludedGroups: []
    property var excludedIds: []
    property bool localContents: false
    property var extraSections: []
    readonly property var groups: Catalog.groups(category).filter(group => !excludedGroups.includes(group))
    readonly property var sidebarSections: groups.concat(extraSections)
    readonly property string activeSection: {
        var name = leading.item && leading.item.settingsNavSection || groups[0] || category
        for (var i = 0; i < cards.count; i++) { var card = cards.itemAt(i); if (card.visible && card.y <= scroll.contentY + 24) name = card.title }
        if (extraSections.length && trailing.y <= scroll.contentY + 24) name = extraSections[0]
        return name
    }
    readonly property var actionLabels: []
    readonly property string footerStatus: ""
    readonly property bool footerDirty: false
    readonly property bool footerError: false
    function canActivate(label) { return false }
    function activateAction(label) { }
    // Search waits for lazy page creation, then scrolls to a focused row.
    function reveal(id, section) {
        var specialized = leading.item || header.item
        if (specialized && typeof specialized.reveal === "function") {
            var target = specialized.reveal(id)
            if (target) { scroll.contentY = Math.max(0, Math.min(target.mapToItem(body, 0, 0).y, scroll.contentHeight - scroll.height)); return }
        }
        if (id === "layout" && header.item) { var targets = Navigation.collect(header.item); if (targets.length) targets[0].forceActiveFocus(); return }
        for (var i = 0; i < cards.count; i++) {
            var card = cards.itemAt(i)
            var row = card.form.reveal(id)
            if (row) { scroll.contentY = Math.max(0, Math.min(row.mapToItem(body, 0, 0).y, scroll.contentHeight - scroll.height)); return }
        }
    }
    function scrollToSection(name) { if (extraSections.includes(name)) { scroll.contentY = Math.max(0, Math.min(trailing.y, scroll.contentHeight - scroll.height)); return } for (var i = 0; i < cards.count; i++) { var card = cards.itemAt(i); if (card.title === name) scroll.contentY = Math.max(0, Math.min(card.y, scroll.contentHeight - scroll.height)) } }
    Column {
        anchors.fill: parent
        spacing: Theme.spaceMd
        Row {
            width: parent.width; spacing: Theme.spaceMd
            Text { text: root.category; color: Theme.fg; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize + 5; font.weight: Font.DemiBold }
            Text { visible: scroll.contentY > 8; anchors.verticalCenter: parent.verticalCenter; text: "› " + root.activeSection; color: Theme.fgMuted; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize - 1 }
        }
        Loader { id: header; width: parent.width; sourceComponent: root.headerContent }
        Item {
            width: parent.width; height: Math.max(0, parent.height - y)
            Column {
                id: contents
                anchors.right: parent.right
                width: visible ? 160 : 0
                visible: root.localContents && root.width >= 940
                spacing: Theme.spaceSm
                Repeater {
                    model: root.sidebarSections
                    delegate: SettingsActionButton {
                        required property string modelData
                        width: contents.width; height: 36; text: modelData; fontSize: Theme.fontSize - 2
                        selected: modelData === root.activeSection
                        activeFocusOnTab: true; focused: activeFocus
                        onClicked: root.scrollToSection(modelData)
                        Keys.onReturnPressed: clicked()
                        Keys.onSpacePressed: clicked()
                    }
                }
            }
        Flickable {
            id: scroll
            width: parent.width - (contents.visible ? contents.width + Theme.spaceMd : 0); height: parent.height
            contentWidth: width; contentHeight: body.implicitHeight + Theme.spaceLg
            clip: true; boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: Motion.HScrollBar {}
            Column {
                id: body
                width: Math.min(760, scroll.width - 12); x: Math.max(0, (scroll.width - width) / 2)
                spacing: Theme.sectionGap
                Loader { id: leading; width: parent.width; sourceComponent: root.leadingContent }
                Repeater {
                    id: cards
                    model: root.groups
                    delegate: SettingsSectionCard {
                        id: card
                        required property string modelData
                        property alias form: form
                        width: body.width; title: modelData
                        GeneralSettingsForm { id: form; width: parent.width; category: root.category; group: card.modelData; excludedIds: root.excludedIds; shortcutTarget: root.shortcutTarget; highlightedId: root.highlightedId }
                    }
                }
                Loader { id: trailing; width: parent.width; sourceComponent: root.trailingContent }
            }
        }
        }
    }
}
