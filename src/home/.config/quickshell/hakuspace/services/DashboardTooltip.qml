pragma Singleton
import QtQuick

QtObject {
    id: root

    property var currentTarget: null
    property string currentText: ""
    property bool active: false

    function show(target, text) {
        if (!target || !text || text.length === 0) {
            dismiss()
            return
        }
        currentTarget = target
        currentText = text
        active = true
    }

    function hide(target) {
        if (currentTarget === target) {
            dismiss()
        }
    }

    function dismiss() {
        active = false
        currentTarget = null
        currentText = ""
    }
}
