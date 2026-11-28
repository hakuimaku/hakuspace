pragma Singleton
import QtQuick

QtObject {
    id: root

    property var currentTarget: null
    property string currentText: ""
    property string placement: "auto"
    property bool active: false

    // Displays dashboard tooltip anchored to target item with given text and optional placement.
    function show(target, text, placement) {
        if (!target || !text || text.length === 0) {
            dismiss()
            return
        }
        currentTarget = target
        currentText = text
        root.placement = (placement && placement.length > 0) ? placement : "auto"
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
        placement = "auto"
    }
}
