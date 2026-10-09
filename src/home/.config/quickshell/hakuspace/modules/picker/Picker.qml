import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "../../services"

PanelWindow {
    id: root
    visible: false
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore
    
    anchors {
        top: true; bottom: true
        left: true; right: true
    }
    
    // Dimmed background
    color: "transparent"
    
    Rectangle {
        anchors.fill: parent
        color: Theme.scrim || "#80000000"
    }
    
    property string currentFifo: ""
    property var allItems: []
    property var filteredItems: []
    property bool passwordMode: false
    property bool noCustomMode: false
    property string promptText: "Select:"
    
    function open(fifo, prompt, items, password, noCustom) {
        if (currentFifo) cancel();
        currentFifo = fifo;
        promptText = prompt || "Select:";
        allItems = items || [];
        filteredItems = allItems;
        passwordMode = password;
        noCustomMode = noCustom;
        inputField.text = "";
        listView.currentIndex = 0;
        visible = true;
        inputField.forceActiveFocus();
    }
    
    function cancel() {
        if (currentFifo) {
            cancelWriter.command = ["sh", "-c", 'printf "%s
" "__CANCEL__" > "$1"', "_", currentFifo];
            cancelWriter.running = true;
            visible = false;
            currentFifo = "";
        }
    }
    
    function submit(text) {
        if (!currentFifo) return;
        writer.command = ["sh", "-c", 'cat > "$1"', "_", currentFifo];
        writer.running = true;
        writer.write(text + "\n");
;
        visible = false;
        currentFifo = "";
    }
    
    onVisibleChanged: {
        if (!visible && currentFifo) {
            cancel();
        }
    }
    
    Process {
        id: writer
        stdinEnabled: true
    }
    
    Process {
        id: cancelWriter
    }
    
    MouseArea {
        anchors.fill: parent
        onClicked: cancel()
    }
    
    Rectangle {
        width: 500
        height: Math.min(600, layout.implicitHeight + Theme.pad * 2)
        anchors.centerIn: parent
        color: Theme.surface
        radius: Theme.radius
        border.color: Theme.border
        border.width: Theme.borderWidth
        
        MouseArea {
            anchors.fill: parent
            // Prevent clicks from closing
        }
        
        ColumnLayout {
            id: layout
            anchors.fill: parent
            anchors.margins: Theme.pad
            spacing: Theme.gap
            
            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: root.promptText
                    color: Theme.accent
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                    font.bold: true
                }
                TextInput {
                    id: inputField
                    Layout.fillWidth: true
                    color: Theme.fg
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                    echoMode: root.passwordMode ? TextInput.Password : TextInput.Normal
                    clip: true
                    
                    onTextChanged: {
                        var q = text.toLowerCase();
                        if (q === "") {
                            root.filteredItems = root.allItems;
                        } else {
                            var filtered = [];
                            for (var i = 0; i < root.allItems.length; i++) {
                                if (root.allItems[i].toLowerCase().indexOf(q) !== -1) {
                                    filtered.push(root.allItems[i]);
                                }
                            }
                            root.filteredItems = filtered;
                        }
                        listView.currentIndex = 0;
                    }
                    
                    Keys.onPressed: (event) => {
                        if (event.key === Qt.Key_Escape) {
                            cancel();
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Up) {
                            if (listView.currentIndex > 0) listView.currentIndex--;
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Down) {
                            if (listView.currentIndex < listView.count - 1) listView.currentIndex++;
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            if (root.filteredItems.length > 0 && listView.currentIndex >= 0 && listView.currentIndex < root.filteredItems.length) {
                                submit(root.filteredItems[listView.currentIndex]);
                            } else if (!root.noCustomMode && text.trim() !== "") {
                                submit(text);
                            }
                            event.accepted = true;
                        }
                    }
                }
            }
            
            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Theme.border
                visible: root.allItems.length > 0
            }
            
            ListView {
                id: listView
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(contentHeight, 300)
                clip: true
                model: root.filteredItems
                visible: root.allItems.length > 0
                
                delegate: Rectangle {
                    width: listView.width
                    height: Theme.fontSize * 2
                    color: index === listView.currentIndex ? Theme.surfaceHi : "transparent"
                    radius: Theme.radiusSm
                    
                    Text {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.pad
                        verticalAlignment: Text.AlignVCenter
                        text: modelData
                        color: index === listView.currentIndex ? Theme.onAccentColor : Theme.fg
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                    }
                    
                    MouseArea {
                        anchors.fill: parent
                        onClicked: submit(modelData)
                    }
                }
            }
        }
    }
}
