.pragma library

// Share bounded keyboard scrolling without changing the selected section.
function handleKey(view, event) {
    if (event.modifiers !== Qt.NoModifier) return
    var next = view.contentY
    if (event.key === Qt.Key_Down) next += 40
    else if (event.key === Qt.Key_Up) next -= 40
    else if (event.key === Qt.Key_PageDown) next += view.height * 0.9
    else if (event.key === Qt.Key_PageUp) next -= view.height * 0.9
    else if (event.key === Qt.Key_Home) next = 0
    else if (event.key === Qt.Key_End) next = view.contentHeight
    else return
    view.cancelFlick()
    view.contentY = Math.max(0, Math.min(next, view.contentHeight - view.height))
    event.accepted = true
}
