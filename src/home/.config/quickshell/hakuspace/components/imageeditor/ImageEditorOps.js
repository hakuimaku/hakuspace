// Copy plain session data so an undo snapshot never shares a mutable path.
function copy(value) { return JSON.parse(JSON.stringify(value)) }

// Snapshot only editable document data; tool selection and process state stay live.
function snapshot(session) {
    return copy({rotation: session.rotation, flipX: session.flipX, flipY: session.flipY,
        cropRectNormalized: session.cropRectNormalized, cropRatio: session.cropRatio, annotations: session.annotations,
        outputScale: session.outputScale, encodeQuality: session.encodeQuality})
}

// Record one complete user gesture and bound the session's history memory.
function commit(session, next) {
    if (JSON.stringify(snapshot(session)) === JSON.stringify(next)) return false
    session.undoStack = session.undoStack.concat([snapshot(session)]).slice(-50)
    session.redoStack = []
    apply(session, next)
    return true
}

// Restore document fields together after undo, redo or a completed gesture.
function apply(session, value) {
    Object.keys(value).forEach(function(key) { session[key] = copy(value[key]) })
    session.selectedAnnotation = -1
    session.dirty = JSON.stringify(snapshot(session)) !== session.originalState
}

// Move a complete snapshot between stacks without splitting a stroke into points.
function undo(session, redo) {
    var stack = redo ? session.redoStack : session.undoStack
    if (!stack.length) return
    var current = snapshot(session), value = stack[stack.length - 1]
    if (redo) {
        session.redoStack = stack.slice(0, -1)
        session.undoStack = session.undoStack.concat([current])
    } else {
        session.undoStack = stack.slice(0, -1)
        session.redoStack = session.redoStack.concat([current])
    }
    apply(session, value)
}
