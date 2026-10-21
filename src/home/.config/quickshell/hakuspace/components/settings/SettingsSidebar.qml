import QtQuick
import QtQuick.Controls
import "../../services"
import "../motion" as Motion

Rectangle {
    id: root
    // Context navigation follows the current page's visible section anchors.
    required property var page
    property bool compact: false
    property bool configBrowser: false
    readonly property var sectionNames: page.sidebarSections || []
    signal fileSelected(string fileId)
    color: Qt.tint(Theme.surface, Qt.alpha(Theme.hoverMuted, 0.13))
    clip: true
    SettingsConfigBrowser {
        anchors.fill: parent
        visible: root.configBrowser
        compact: root.compact
        onFileSelected: fileId => root.fileSelected(fileId)
    }
    ComboBox {
        anchors.fill: parent
        anchors.margins: 4
        visible: root.compact && !root.configBrowser
        model: root.sectionNames
        currentIndex: root.sectionNames.indexOf(root.page.activeSection || "")
        font.family: Theme.fontFamily
        palette.button: Theme.surface
        palette.buttonText: Theme.fg
        palette.base: Theme.surface
        palette.text: Theme.fg
        palette.highlight: Theme.accent
        palette.highlightedText: "#000000"
        Accessible.name: "Settings sections"
        onActivated: index => root.page.scrollToSection(model[index])
    }
    Flickable {
        id: sectionScroll
        anchors.fill: parent
        anchors.margins: 14
        visible: !root.compact && !root.configBrowser
        contentWidth: width
        contentHeight: sections.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: Motion.HScrollBar {}
        // The shared accent follows the active section inside scroll content.
        Motion.SelectionPill {
            id: sectionSelection
            parent: sectionScroll.contentItem
            coordinateSpace: sectionScroll.contentItem
            opacity: shown && targetItem && targetItem.selected ? 1 : 0
            z: 0
            duration: HAnimation.slow
            trailFactor: 1.15
        }
        Column {
            id: sections
            z: 1
            width: parent.width
            spacing: 8
            onPositioningComplete: sectionSelection.syncTarget(false)
            Text {
                width: parent.width
                height: 30
                text: "// SECTIONS"
                color: Theme.fgMuted
                font.family: Theme.fontFamily
                font.pixelSize: Math.max(10, Theme.fontSize - 3)
            }
            Repeater {
                model: root.sectionNames
                delegate: SettingsActionButton {
                    id: section
                    required property string modelData
                    width: sections.width
                    height: 40
                    text: ""
                    selected: root.page.activeSection === modelData
                    selectedOverridesHover: true
                    idleColor: "transparent"
                    hoverColor: Theme.hoverMuted
                    selectedColor: "transparent"
                    pressedColor: selected ? "transparent" : Theme.hoverMuted
                    foregroundColor: Theme.fgDim
                    selectedForegroundColor: "#000000"
                    hoverForegroundColor: Theme.fg
                    pressedForegroundColor: selected ? "#000000" : Theme.fg
                    onSelectedChanged: { if (selected) sectionSelection.targetItem = section }
                    Component.onCompleted: {
                        if (selected) sectionSelection.targetItem = section
                    }
                    activeFocusOnTab: true
                    focused: activeFocus
                    Accessible.name: modelData
                    Accessible.role: Accessible.Button
                    Accessible.onPressAction: clicked()
                    onClicked: root.page.scrollToSection(modelData)
                    Keys.onReturnPressed: clicked()
                    Keys.onSpacePressed: clicked()
                    Text {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 8
                        verticalAlignment: Text.AlignVCenter
                        text: section.modelData
                        color: section.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: Math.max(10, Theme.fontSize - 1)
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }
    Rectangle { anchors.right: parent.right; width: root.compact ? parent.width : 1; height: root.compact ? 1 : parent.height; anchors.bottom: parent.bottom; color: Theme.hoverMuted }
}
