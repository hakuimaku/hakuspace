import QtQuick
import QtQuick.Controls
import QtQuick.Window
import "../../services"
import "../motion" as Motion
import "SettingsScroll.js" as KeyboardScroll

Dialog {
    id: root
    // The question button supplies both the reveal and return destination.
    required property Item sourceItem
    property rect sourceRect: Qt.rect(0, 0, 0, 0)
    property Item previousFocus: null
    // F1 reverses an in-progress close instead of starting another close request.
    property bool closing: false
    // One shared progress keeps position, size, corners and content synchronized.
    property real morphProgress: 0
    readonly property real expandedWidth: Math.max(0, Math.min(920, parent.width - 96))
    readonly property real expandedHeight: Math.max(0, Math.min(700, parent.height - 96))
    x: sourceRect.x + ((parent.width - expandedWidth) / 2 - sourceRect.x) * morphProgress
    y: sourceRect.y + ((parent.height - expandedHeight) / 2 - sourceRect.y) * morphProgress
    width: sourceRect.width + (expandedWidth - sourceRect.width) * morphProgress
    height: sourceRect.height + (expandedHeight - sourceRect.height) * morphProgress
    padding: 0
    modal: true
    dim: true
    focus: true
    closePolicy: Popup.CloseOnEscape

    // Capture transformed button bounds without changing its layout or hit target.
    function captureSource() {
        var start = sourceItem.mapToItem(parent, 0, 0)
        var end = sourceItem.mapToItem(parent, sourceItem.width, sourceItem.height)
        sourceRect = Qt.rect(start.x, start.y, end.x - start.x, end.y - start.y)
    }
    // Keep rapid keyboard toggles continuous in both transition directions.
    function toggle() {
        if (visible && !closing) close()
        else open()
    }
    onAboutToShow: {
        closing = false
        if (morphProgress === 0) previousFocus = parent.Window.window.activeFocusItem
        captureSource()
        guideScroll.contentY = 0
    }
    onAboutToHide: { closing = true; captureSource() }
    onOpened: closeGuide.forceActiveFocus(Qt.PopupFocusReason)
    onClosed: {
        if (previousFocus && previousFocus.visible && previousFocus.enabled) previousFocus.forceActiveFocus()
    }
    enter: Transition {
        NumberAnimation {
            target: root; property: "morphProgress"; to: 1
            duration: HAnimation.slow
            easing.type: Easing.BezierSpline
            easing.bezierCurve: HAnimation.actionLayerMorphCurve
        }
    }
    exit: Transition {
        NumberAnimation {
            target: root; property: "morphProgress"; to: 0
            duration: HAnimation.slow
            easing.type: Easing.BezierSpline
            easing.bezierCurve: HAnimation.actionLayerMorphCurve
        }
    }
    Overlay.modal: Rectangle { color: Qt.alpha(Theme.surface, root.morphProgress * 0.72) }
    background: Rectangle {
        radius: Theme.radius + (Theme.largeRadius - Theme.radius) * root.morphProgress
        color: Qt.tint(Theme.surface, Qt.alpha(Theme.hoverMuted, 1 - root.morphProgress))
        border.width: 1
        border.color: Theme.hoverMuted
    }
    contentItem: Item {
        clip: true
        focus: true
        Keys.onPressed: event => {
            if (event.modifiers === Qt.NoModifier && event.key === Qt.Key_F1) {
                if (!event.isAutoRepeat) root.toggle()
                event.accepted = true
            } else KeyboardScroll.handleKey(guideScroll, event)
        }
        Text {
            anchors.centerIn: parent
            text: "?"
            color: Theme.fg
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            opacity: Math.max(0, 1 - root.morphProgress * 3)
        }
        Item {
            id: guide
            anchors.centerIn: parent
            width: root.expandedWidth
            height: root.expandedHeight
            opacity: Math.max(0, Math.min(1, (root.morphProgress - 0.55) / 0.45))
            enabled: root.opened
            // Fixed content geometry avoids reflowing text inside the moving shell.
            Column {
                id: heading
                x: 24; y: 24
                width: Math.max(0, parent.width - 48)
                spacing: 6
                Rectangle {
                    width: Math.min(parent.width, guideTitle.implicitWidth + 24)
                    height: guideTitle.implicitHeight + 12
                    radius: Theme.radius
                    color: Theme.accent
                    Text {
                        id: guideTitle
                        anchors.centerIn: parent
                        text: "Keyboard shortcuts"
                        color: "#000000"
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize + 5
                        font.weight: Font.DemiBold
                    }
                }
                Text {
                    width: parent.width
                    text: "Move, edit and read without leaving the keyboard."
                    color: Theme.fgDescription
                    font.family: Theme.fontFamily
                    font.pixelSize: Math.max(11, Theme.fontSize - 1)
                    wrapMode: Text.Wrap
                }
            }
            Flickable {
                id: guideScroll
                x: 24
                y: heading.y + heading.height + 20
                width: Math.max(0, parent.width - 48)
                height: Math.max(0, guideFooter.y - y - 16)
                contentWidth: width
                contentHeight: groups.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: Motion.HScrollBar { id: guideBar }
                Grid {
                    id: groups
                    width: Math.max(0, guideScroll.width - guideBar.reservedGutter)
                    columns: width >= 700 ? 2 : 1
                    spacing: 16
                    Repeater {
                        model: [
                            {title: "Navigation", color: Theme.guideNavigation, rows: [
                                {keys: ["← / →"], detail: "Move within a row. Topbar domains wrap; sidebar Right enters content."},
                                {keys: ["↑ / ↓"], detail: "Move between rows. Tabs Down enters sidebar; first/last row exits to tabs/actions."},
                                {keys: ["←"], detail: "At a row's left edge, return to sidebar. Text keeps caret movement until its start."},
                                {keys: ["↑"], detail: "First sidebar item returns to tabs; footer returns to the last content control."},
                                {keys: ["Home / End"], detail: "First or last domain, sidebar item or footer action."},
                                {keys: ["Enter", "Space"], detail: "Activate a button or toggle; open a focused dropdown."},
                                {keys: ["F6", "Shift+F6"], detail: "Cycle focus regions; leave the editor or Info reader."},
                                {keys: ["Ctrl+↑", "Ctrl+←", "Ctrl+→ / ↓"], detail: "Jump directly to tabs, sidebar or content."}
                            ]},
                            {title: "Actions", color: Theme.guideActions, rows: [
                                {keys: ["Ctrl+F"], detail: "Search General settings."},
                                {keys: ["Ctrl+S"], detail: "Apply or save the current page."},
                                {keys: ["Enter"], detail: "Enter slider editing. Otherwise arrows move focus without changing its value."},
                                {keys: ["↑ / ↓ / ← / →", "Home / End"], detail: "Adjust values only while editing a slider."},
                                {keys: ["Enter", "Esc"], detail: "Finish slider editing; Escape keeps Settings open."},
                                {keys: ["F5"], detail: "Reload or refresh. Unsaved edits require confirmation."},
                                {keys: ["← / →", "Enter", "Esc"], detail: "Choose, activate or cancel a dialog action. Background navigation stays blocked."}
                            ]},
                            {title: "Config editor", color: Theme.guideEditing, rows: [
                                {keys: ["↑ / ↓ / ← / →"], detail: "Always move the caret, including at document edges."},
                                {keys: ["Tab", "Shift+Tab"], detail: "Indent or unindent code."},
                                {keys: ["Ctrl+←", "Ctrl+→", "F6", "Shift+F6"], detail: "Leave the editor or return through explicit region shortcuts."}
                            ]},
                            {title: "Reading & help", color: Theme.guideReading, rows: [
                                {keys: ["↑ / ↓", "PgUp / PgDn", "Home / End"], detail: "Scroll Info or this guide. Info Left returns to sidebar."},
                                {keys: ["↑ / ↓", "Esc"], detail: "An open dropdown keeps native arrows. Escape closes only the dropdown."},
                                {keys: ["Alt+1…5"], detail: "Optional direct domain switching."},
                                {keys: ["Ctrl+Tab", "Ctrl+Shift+Tab"], detail: "Optional next or previous Settings domain."},
                                {keys: ["Tab", "Shift+Tab"], detail: "Compatibility / accessibility focus traversal. Config keeps indentation."},
                                {keys: ["F1"], detail: "Open or close this guide."},
                                {keys: ["Esc"], detail: "Close the guide, cancel a dialog or close Settings with draft protection."}
                            ]}
                        ]
                        delegate: Rectangle {
                            id: group
                            required property var modelData
                            width: (groups.width - (groups.columns - 1) * groups.spacing) / groups.columns
                            height: groupContent.implicitHeight + 32
                            radius: Theme.radius
                            color: Qt.tint(Theme.surface, Qt.alpha(modelData.color, 0.035))
                            border.width: 1
                            border.color: Qt.alpha(modelData.color, 0.22)
                            Column {
                                id: groupContent
                                x: 16; y: 16
                                width: Math.max(0, parent.width - 32)
                                spacing: 14
                                Rectangle {
                                    width: Math.min(parent.width, groupTitle.implicitWidth + 20)
                                    height: groupTitle.implicitHeight + 12
                                    radius: Theme.radius
                                    color: Theme.accent
                                    Text {
                                        id: groupTitle
                                        anchors.centerIn: parent
                                        text: group.modelData.title.toUpperCase()
                                        color: "#000000"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Math.max(11, Theme.fontSize - 1)
                                        font.weight: Font.DemiBold
                                        font.letterSpacing: 0.8
                                    }
                                }
                                Repeater {
                                    model: group.modelData.rows
                                    delegate: Row {
                                        id: shortcut
                                        required property var modelData
                                        width: groupContent.width
                                        height: Math.max(keycaps.height, description.implicitHeight)
                                        spacing: 14
                                        Flow {
                                            id: keycaps
                                            width: Math.min(154, shortcut.width * 0.46)
                                            height: childrenRect.height
                                            spacing: 6
                                            Repeater {
                                                model: shortcut.modelData.keys
                                                delegate: Rectangle {
                                                    required property string modelData
                                                    width: Math.min(keycaps.width, keyText.implicitWidth + 14)
                                                    height: keyText.implicitHeight + 10
                                                    radius: Theme.radius
                                                    color: Qt.alpha(Theme.accent, 0.1)
                                                    border.width: 1
                                                    border.color: Qt.alpha(Theme.accent, 0.2)
                                                    Text {
                                                        id: keyText
                                                        anchors.centerIn: parent
                                                        width: Math.max(0, parent.width - 14)
                                                        text: parent.modelData
                                                        color: Theme.accent
                                                        font.family: Theme.fontFamily
                                                        font.pixelSize: Math.max(10, Theme.fontSize - 2)
                                                        font.weight: Font.DemiBold
                                                        horizontalAlignment: Text.AlignHCenter
                                                        wrapMode: Text.Wrap
                                                    }
                                                }
                                            }
                                        }
                                        Text {
                                            id: description
                                            width: Math.max(0, shortcut.width - keycaps.width - shortcut.spacing)
                                            text: shortcut.modelData.detail
                                            color: Theme.fgDescription
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Math.max(11, Theme.fontSize - 1)
                                            wrapMode: Text.Wrap
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            Item {
                id: guideFooter
                x: 24; y: parent.height - height - 20
                width: Math.max(0, parent.width - 48)
                height: 40
                Text {
                    width: Math.max(0, parent.width - closeGuide.width - 16)
                    anchors.verticalCenter: parent.verticalCenter
                    text: "↑ / ↓ to scroll · Esc to close"
                    color: Theme.fgMuted
                    font.family: Theme.fontFamily
                    font.pixelSize: Math.max(10, Theme.fontSize - 2)
                    wrapMode: Text.Wrap
                }
                SettingsActionButton {
                    id: closeGuide
                    anchors.right: parent.right
                    width: 120
                    height: parent.height
                    text: "Close guide"
                    idleColor: Theme.hoverMuted
                    foregroundColor: Theme.fg
                    activeFocusOnTab: enabled
                    focused: activeFocus
                    onClicked: root.close()
                    Keys.onReturnPressed: clicked()
                    Keys.onSpacePressed: clicked()
                    Keys.onPressed: event => KeyboardScroll.handleKey(guideScroll, event)
                }
            }
        }
    }
}
