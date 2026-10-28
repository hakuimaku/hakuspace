import QtQuick
import QtQuick.Controls
import "../../services"
import "../motion" as Motion
import "../../config/SettingsCatalog.js" as Catalog

Item {
    id: root
    // Search results navigate to a row within the single category hierarchy.
    property bool guideOpen: false
    property Item shortcutTarget: null
    property alias shortcutButton: helpButton
    readonly property var results: Catalog.search(search.text)
    readonly property bool searching: search.text.trim().length > 0
    signal resultRequested(var result)
    signal shortcutsRequested()
    signal closeRequested()
    implicitHeight: width < 700 ? 108 : 62
    function focusSearch() { search.focusSearch() }
    Text { x: 12; y: 20; text: "HakuSpace Settings"; color: Theme.fg; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize + 2; font.weight: Font.DemiBold }
    Rectangle {
        x: root.width - 182; y: 12; width: 84; height: 40; radius: Theme.radius; color: Theme.hoverMuted
        Text { objectName: "settings-wm-label"; anchors.fill: parent; anchors.margins: Theme.spaceSm; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight; text: WM.displayName; color: Theme.fgMuted; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize - 2 }
        HoverHandler { id: contextHover }
        SettingsTooltip { target: parent; active: contextHover.hovered; text: "Settings adapt to the active compositor" }
    }
    SettingsSearchField {
        id: search
        x: root.width < 700 ? 12 : 230
        y: root.width < 700 ? 62 : 12
        width: Math.max(80, root.width - x - (root.width < 700 ? 12 : 190))
        shortcutTarget: root.shortcutTarget
        onAccepted: if (root.results.length) root.choose(root.results[0])
        onEscapeRequested: text = ""
        onNextRequested: if (resultList.count) { resultList.currentIndex = 0; resultList.forceActiveFocus() }
    }
    // Clear search only after the result has selected its category and anchor.
    function choose(result) { root.resultRequested(result); search.text = "" }
    Popup {
        parent: search
        x: 0; y: search.height + Theme.spaceSm
        width: search.width
        height: Math.min(360, Math.max(64, resultList.contentHeight + padding * 2))
        padding: Theme.spaceMd
        visible: root.searching
        closePolicy: Popup.NoAutoClose
        enter: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: HAnimation.fast; easing.type: Easing.OutCubic } }
        exit: Transition { NumberAnimation { property: "opacity"; to: 0; duration: 120; easing.type: Easing.OutCubic } }
        background: Rectangle { color: Theme.surface; radius: Theme.largeRadius; border.width: 0; border.color: Theme.hoverMuted }
        contentItem: ListView {
            id: resultList
            objectName: "settings-search-results"
            clip: true
            spacing: Theme.spaceXs
            model: root.results
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: Motion.HScrollBar { id: resultsBar }
            Keys.onReturnPressed: if (currentIndex >= 0) root.choose(root.results[currentIndex])
            Keys.onEnterPressed: if (currentIndex >= 0) root.choose(root.results[currentIndex])
            Keys.onSpacePressed: if (currentIndex >= 0) root.choose(root.results[currentIndex])
            Keys.onEscapePressed: { search.text = ""; search.focusSearch() }
            Motion.SelectionPill {
                parent: resultList.contentItem
                coordinateSpace: resultList.contentItem
                targetItem: resultList.currentItem
                z: 0
            }
            delegate: SettingsActionButton {
                id: result
                required property var modelData
                required property int index
                width: Math.max(0, resultList.width - resultsBar.reservedGutter)
                height: Math.max(48, labels.implicitHeight + Theme.spaceSm * 2)
                z: 1
                radius: Theme.radius
                selected: resultList.currentIndex === index
                idleColor: "transparent"
                selectedColor: "transparent"
                hoverColor: "transparent"
                pressedColor: "transparent"
                focusColor: "transparent"
                selectedOverridesHover: true
                hoverForegroundColor: selected ? Theme.onAccentColor : Theme.fg
                pressedForegroundColor: hoverForegroundColor
                focusForegroundColor: hoverForegroundColor
                Accessible.name: modelData.label + ", " + modelData.category
                onHoveredChanged: if (hovered) resultList.currentIndex = index
                onClicked: root.choose(modelData)
                Column {
                    id: labels
                    anchors { left: parent.left; right: parent.right; margins: Theme.spaceLg; verticalCenter: parent.verticalCenter }
                    spacing: 2
                    Text {
                        objectName: "settings-search-result-label"
                        width: parent.width
                        text: result.modelData.label
                        color: result.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize - 1
                        elide: Text.ElideRight
                    }
                    Text {
                        width: parent.width
                        text: Catalog.breadcrumb(result.modelData)
                        color: result.selected ? Theme.onAccentColor : Theme.fgMuted
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize - 2
                        elide: Text.ElideRight
                    }
                }
            }
            Text { visible: !resultList.count; anchors.centerIn: parent; text: "No matching settings"; color: Theme.fgDim; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize - 1 }
        }
    }
    SettingsActionButton {
        id: helpButton
        x: parent.width - 92; y: 12
        width: 40; height: 40; text: "?"
        activeFocusOnTab: true; focused: activeFocus
        Accessible.name: "Keyboard help"
        onClicked: root.shortcutsRequested()
        Keys.onReturnPressed: clicked()
        Keys.onSpacePressed: clicked()
    }
    SettingsActionButton {
        x: parent.width - 44; y: 12
        width: 40; height: 40; text: "×"
        activeFocusOnTab: true; focused: activeFocus
        Accessible.name: "Close settings"
        onClicked: root.closeRequested()
        Keys.onReturnPressed: clicked()
        Keys.onSpacePressed: clicked()
    }
}
