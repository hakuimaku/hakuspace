import QtQuick
import Quickshell
import Quickshell.Widgets
import "../../services"
import "../motion" as Motion

Item {
    id: root
    property var menuHandle: null
    property var parentPage: null
    property var nextHandle: null
    property real maxHeight: 144
    property real bottomPadding: 4
    readonly property real rowHeight: Math.max(26, Theme.fontSize * 1.8)
    readonly property real ownHeight: (parentPage ? rowHeight : 0) + entries.implicitHeight + bottomPadding
    readonly property var leafPage: childLoader.item ? childLoader.item.leafPage : root
    implicitHeight: Math.min(maxHeight, leafPage.ownHeight)

    signal dismissed()

    function openChild(entry) {
        nextHandle = entry
        childLoader.active = true
    }

    function closeChild() {
        childLoader.active = false
        nextHandle = null
    }

    function reset() {
        closeChild()
    }

    QsMenuOpener {
        id: opener
        menu: root.menuHandle
    }

    Column {
        anchors.fill: parent
        visible: !childLoader.active

        Motion.MorphButton {
            id: backButton
            width: parent.width
            height: visible ? root.rowHeight : 0
            visible: root.parentPage !== null
            radius: 0
            idleColor: Theme.surface
            hoverColor: Theme.surfaceHi
            pressedColor: Theme.surfaceHi
            foregroundColor: Theme.fg
            hoverForegroundColor: Theme.onAccentColor
            pressedForegroundColor: Theme.onAccentColor
            hoverScaleDelta: 0
            pressScaleDelta: 0.010
            onClicked: root.parentPage.closeChild()

            Text {
                anchors.fill: parent
                anchors.leftMargin: Theme.pad
                verticalAlignment: Text.AlignVCenter
                text: "‹  Back"
                color: backButton.foreground
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
            }
        }

        Flickable {
            width: parent.width
            height: Math.max(0, root.height - (root.parentPage ? root.rowHeight : 0))
            contentWidth: width
            contentHeight: entries.implicitHeight + root.bottomPadding
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: entries
                width: parent.width
                Repeater {
                    model: opener.children
                    delegate: Item {
                        id: row
                        required property var modelData
                        width: entries.width
                        height: modelData.isSeparator ? Math.max(8, Theme.gap * 2) : root.rowHeight
                        opacity: modelData.enabled || modelData.isSeparator ? 1 : 0.45

                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.leftMargin: Theme.pad
                            anchors.rightMargin: Theme.pad
                            anchors.verticalCenter: parent.verticalCenter
                            height: 1
                            color: Theme.fgMuted
                            opacity: 0.7
                            visible: row.modelData.isSeparator
                        }

                        Motion.MorphButton {
                            id: rowButton
                            anchors.fill: parent
                            visible: !row.modelData.isSeparator
                            enabled: row.modelData.enabled
                            radius: 0
                            selected: row.modelData.checkState === Qt.Checked
                            selectedOverridesHover: false
                            idleColor: Theme.surface
                            hoverColor: Theme.surfaceHi
                            pressedColor: Theme.surfaceHi
                            selectedColor: Theme.hoverMuted
                            foregroundColor: Theme.fg
                            hoverForegroundColor: Theme.onAccentColor
                            pressedForegroundColor: Theme.onAccentColor
                            selectedForegroundColor: Theme.accent
                            disabledOpacity: 1
                            hoverScaleDelta: 0
                            pressScaleDelta: 0.010
                            onClicked: {
                                if (row.modelData.hasChildren) {
                                    root.openChild(row.modelData)
                                } else {
                                    row.modelData.triggered()
                                    root.dismissed()
                                }
                            }

                            Row {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.leftMargin: Theme.pad
                                anchors.rightMargin: Theme.pad
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: Theme.gap

                                Text {
                                    width: root.rowHeight * 0.8
                                    horizontalAlignment: Text.AlignHCenter
                                    text: row.modelData.buttonType === QsMenuButtonType.CheckBox
                                          ? (row.modelData.checkState === Qt.Checked ? "☑" : "☐")
                                          : row.modelData.buttonType === QsMenuButtonType.RadioButton
                                            ? (row.modelData.checkState === Qt.Checked ? "◉" : "○") : ""
                                    color: rowButton.foreground
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSize
                                }
                                IconImage {
                                    width: row.modelData.icon ? root.rowHeight * 0.7 : 0
                                    height: root.rowHeight * 0.7
                                    visible: width > 0
                                    source: row.modelData.icon || ""
                                }
                                Text {
                                    width: Math.max(0, root.width - Theme.pad * 2 - root.rowHeight * 1.8
                                                    - (row.modelData.icon ? root.rowHeight * 0.7 + Theme.gap : 0))
                                    text: row.modelData.text || ""
                                    elide: Text.ElideRight
                                    color: rowButton.foreground
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSize
                                    verticalAlignment: Text.AlignVCenter
                                }
                                Text {
                                    text: row.modelData.hasChildren ? "›" : ""
                                    color: rowButton.hovered || rowButton.pressed ? rowButton.foreground : Theme.fgDim
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSize

                                    Behavior on color {
                                        ColorAnimation {
                                            duration: HAnimation.buttonHoverDuration
                                            easing.type: Easing.BezierSpline
                                            easing.bezierCurve: HAnimation.buttonHoverCurve
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Loader {
        id: childLoader
        anchors.fill: parent
        active: false
        source: "MenuPage.qml"
        onLoaded: {
            item.parentPage = root
            item.maxHeight = root.maxHeight
            item.menuHandle = root.nextHandle
        }
    }

    Connections {
        target: childLoader.item
        function onDismissed() { root.dismissed() }
    }
}
