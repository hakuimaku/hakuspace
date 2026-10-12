pragma Singleton
import QtQuick

QtObject {
    id: root

    property var currentTarget: null
    property string currentText: ""
    property bool active: false

    // Displays dashboard tooltip anchored to target item with given text.
    function show(target, text) {
        if (!target || !text || text.length === 0) {
            dismiss()
            return
        }
        currentTarget = target
        currentText = text
        active = true
    }

    // Hides dashboard tooltip if currently associated with target item.
    function hide(target) {
        if (currentTarget === target) {
            dismiss()
        }
    }

    // Dismisses active dashboard tooltip unconditionally.
    function dismiss() {
        active = false
        currentTarget = null
        currentText = ""
    }
}
