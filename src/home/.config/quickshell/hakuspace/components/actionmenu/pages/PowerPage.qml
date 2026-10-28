import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import "../../../services"
import "../../../config/UiCatalog.js" as UiCatalog
import ".." as ActionMenu
import "../../motion" as Motion

ActionMenu.ActionMenuPage {
    id: root

    title: "Power Menu"
    subtitle: ""
    geometryProfile: "powerHorizontal"
    showHeader: false

    signal pushSubmenu(string pageUrl, var props, var seedGeom, string profile)

    property int selectedIndex: 0

    readonly property var actions: UiCatalog.actionMenuPowerActions

    Process {
        id: powerProc
        onExited: {
            root.requestClose();
        }
    }

    // Executes the power control command or initiates morph to the exit report session page.
    function activateAction(idx) {
        if (idx < 0 || idx >= actions.length) return;
        var act = actions[idx];
        var btn = buttonsRepeater.itemAt(idx);

        if (act.id === "logout") {
            // Power -> Logout morphs into ExitPage in the same layer!
            var geom = btn && btn.getSurfaceGeometry ? btn.getSurfaceGeometry() : null;
            root.pushSubmenu("pages/ExitPage.qml", { fromPower: true }, geom, "exitReport");
        } else {
            powerProc.command = [Env.binDir + "/power_ctl.sh", act.id];
            powerProc.running = true;
            root.requestClose();
        }
    }

    onScrollPrevious: {
        root.selectedIndex = Math.max(0, root.selectedIndex - 1);
    }

    onScrollNext: {
        root.selectedIndex = Math.min(actions.length - 1, root.selectedIndex + 1);
    }

    onSelectedIndexChanged: {
        var it = (buttonsRepeater.count > root.selectedIndex && root.selectedIndex >= 0)
            ? buttonsRepeater.itemAt(root.selectedIndex)
            : null;
        if (it) selectionPill.targetItem = it;
    }

    Keys.onLeftPressed: event => {
        root.selectedIndex = Math.max(0, root.selectedIndex - 1);
        event.accepted = true;
    }

    Keys.onRightPressed: event => {
        root.selectedIndex = Math.min(actions.length - 1, root.selectedIndex + 1);
        event.accepted = true;
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Home) {
            root.selectedIndex = 0;
            event.accepted = true;
        } else if (event.key === Qt.Key_End) {
            root.selectedIndex = actions.length - 1;
            event.accepted = true;
        }
    }

    // Executes currently focused power option.
    function activateCurrent() {
        activateAction(root.selectedIndex);
    }

    Keys.onReturnPressed: event => {
        activateCurrent();
        event.accepted = true;
    }

    Keys.onEnterPressed: event => {
        activateCurrent();
        event.accepted = true;
    }

    ActionMenu.ActionMenuSelectionPill {
        id: selectionPill
        z: 0
    }

    RowLayout {
        id: buttonsRow
        z: 1
        anchors.fill: parent
        spacing: Theme.pad

        Repeater {
            id: buttonsRepeater
            model: root.actions
            delegate: Motion.MorphButton {
                id: pBtn
                property bool danger: modelData.danger
                // Keep icon and label contrast in sync with the real pill fade.
                readonly property color contentForeground: selected || focused
                    ? root.selectionColor(danger ? Theme.danger : Theme.fg, foreground) : foreground
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: Theme.radius > 0 ? Theme.radius : 12

                text: ""
                selected: root.selectedIndex === index
                focused: selected
                selectedOverridesHover: true

                idleColor: modelData.danger ? Qt.rgba(1.0, 0.3, 0.3, 0.10) : "transparent"
                hoverColor: (selected || focused) ? "transparent"
                                                  : (modelData.danger ? Qt.rgba(1.0, 0.3, 0.3, 0.28)
                                                                      : Theme.surfaceSubtle(1.18))
                pressedColor: (selected || focused) ? "transparent"
                                                    : (modelData.danger ? Qt.rgba(1.0, 0.3, 0.3, 0.42)
                                                                        : Theme.surfaceSubtle(1.35))
                selectedColor: "transparent"
                focusColor: "transparent"

                foregroundColor: (selected || focused) ? (modelData.danger ? "#ffffff" : Theme.onAccentColor)
                                                       : (modelData.danger ? Theme.danger : Theme.fg)
                hoverForegroundColor: (selected || focused) ? foregroundColor
                                                            : (modelData.danger ? "#ffffff" : Theme.fg)
                selectedForegroundColor: modelData.danger ? "#ffffff" : Theme.onAccentColor

                Component.onCompleted: {
                    if (selected) {
                        selectionPill.targetItem = this;
                    }
                }

                onSelectedChanged: {
                    if (selected) {
                        selectionPill.targetItem = this;
                    }
                }

                Connections {
                    target: root
                    function onPointerSelectionMoved() { if (pBtn.hovered) root.selectedIndex = index }
                }

                // Returns button screen coordinates and styling metrics for seed morphing animations.
                function getSurfaceGeometry(surfaceItem) {
                    // Match the selection pill's layout bounds during button feedback.
                    var screenPt = parent.mapToItem(null, pBtn.x, pBtn.y);
                    return {
                        screenX: screenPt.x,
                        screenY: screenPt.y,
                        x: screenPt.x,
                        y: screenPt.y,
                        width: pBtn.width,
                        height: pBtn.height,
                        radius: pBtn.radius,
                        color: modelData.danger ? Theme.dangerFill : Theme.accent,
                        icon: modelData.icon,
                        label: modelData.label
                    };
                }

                onClicked: {
                    root.selectedIndex = index;
                    activateAction(index);
                }

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 6

                    Text {
                        text: modelData.icon
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize * 2.2
                        color: pBtn.contentForeground
                        Layout.alignment: Qt.AlignHCenter
                    }

                    Text {
                        text: modelData.label
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize + 1
                        font.weight: pBtn.selected ? Font.DemiBold : Font.Normal
                        color: pBtn.contentForeground
                        Layout.alignment: Qt.AlignHCenter
                    }
                }
            }
        }
    }
}
