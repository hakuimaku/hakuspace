// Pure range edits shared by the QML editor and Node fixtures.
function profileForFile(fileId) {
    var name = String(fileId || "").toLowerCase()
    if (/\.lua$/.test(name)) return { id: "lua", lineComment: "--" }
    if (/\.kdl$/.test(name) || /\.jsonc?$/.test(name) || name === "config/taskbar-pin-apps" || /^config\/waybar\/.+\/config$/.test(name)) return { id: "jsonc", lineComment: "//" }
    if (/\.css$/.test(name) || /\.rasi$/.test(name)) return { id: "style", blockStart: "/* ", blockEnd: " */" }
    if (/\.(conf|fish|sh|bash|zsh)$/.test(name)) return { id: "shell", lineComment: "#" }
    return { id: "plain" }
}

function linesOf(text) {
    var lines = [], start = 0
    for (var i = 0; i < text.length; i++) if (text[i] === "\n") {
        var end = i > start && text[i - 1] === "\r" ? i - 1 : i
        lines.push({ start: start, end: end, after: i + 1, eol: text.slice(end, i + 1) })
        start = i + 1
    }
    lines.push({ start: start, end: text.length, after: text.length, eol: "" })
    return lines
}

function affected(text, start, end, cursor) {
    var lines = linesOf(text), first = 0, last = 0
    while (first + 1 < lines.length && lines[first + 1].start <= start) first++
    var effectiveEnd = end > start && end > 0 && text[end - 1] === "\n" ? end - 1 : end
    while (last + 1 < lines.length && lines[last + 1].start <= effectiveEnd) last++
    return { lines: lines, first: first, last: last, selected: end > start, cursor: cursor }
}

function noEdit() { return { changed: false } }

function edit(text, start, end, replacement, selectionStart, selectionEnd, cursorPosition) {
    if (text.slice(start, end) === replacement) return noEdit()
    return { changed: true, rangeStart: start, rangeEnd: end, replacement: replacement,
             selectionStart: selectionStart, selectionEnd: selectionEnd, cursorPosition: cursorPosition }
}

function mapped(position, changes) {
    var delta = 0
    for (var i = 0; i < changes.length; i++) {
        var c = changes[i]
        if (position < c.at) break
        if (position < c.at + c.remove) return c.at + delta + c.insert.length
        delta += c.insert.length - c.remove
    }
    return position + delta
}

function lineEdit(text, start, end, cursor, transform) {
    var area = affected(text, start, end, cursor), changes = []
    for (var i = area.first; i <= area.last; i++) {
        var line = area.lines[i], oldLine = text.slice(line.start, line.end)
        var result = transform(oldLine)
        if (result && result.text !== oldLine) changes.push({ at: line.start + result.at, remove: result.remove, insert: result.insert })
    }
    if (!changes.length) return noEdit()
    if (changes.length === 1) {
        var only = changes[0]
        return edit(text, only.at, only.at + only.remove, only.insert,
                    mapped(start, changes), mapped(end, changes), mapped(cursor, changes))
    }
    var from = area.lines[area.first].start, to = area.lines[area.last].end
    var replacement = text.slice(from, to)
    for (var j = changes.length - 1; j >= 0; j--) {
        var c = changes[j], offset = c.at - from
        replacement = replacement.slice(0, offset) + c.insert + replacement.slice(offset + c.remove)
    }
    return edit(text, from, to, replacement, mapped(start, changes), mapped(end, changes), mapped(cursor, changes))
}

function toggleComment(text, start, end, cursor, profile) {
    if (!profile || (!profile.lineComment && !profile.blockStart)) return noEdit()
    var area = affected(text, start, end, cursor)
    if (profile.blockStart) {
        var from = area.lines[area.first].start, to = area.lines[area.last].end
        var content = text.slice(from, to), opening = profile.blockStart, closing = profile.blockEnd
        if (!content.length) return noEdit()
        var wrapped = content.startsWith(opening) && content.endsWith(closing)
        var replacement = wrapped ? content.slice(opening.length, -closing.length) : opening + content + closing
        var changes = wrapped ? [{ at: from, remove: opening.length, insert: "" }, { at: to - closing.length, remove: closing.length, insert: "" }]
                              : [{ at: from, remove: 0, insert: opening }, { at: to, remove: 0, insert: closing }]
        return edit(text, from, to, replacement, mapped(start, changes), mapped(end, changes), mapped(cursor, changes))
    }
    var prefix = profile.lineComment, allCommented = true, found = false
    // Tabs count as four visual columns, matching the code editor's indent unit.
    function nextColumn(line, index, current) { return current + (line[index] === "\t" ? 4 - current % 4 : 1) }
    var column = 0
    if (area.selected) for (var i = area.first; i <= area.last; i++) {
        var firstLine = text.slice(area.lines[i].start, area.lines[i].end)
        if (!firstLine.trim()) continue
        var leading = firstLine.search(/\S/)
        for (var c = 0; c < leading; c++) column = nextColumn(firstLine, c, column)
        break
    }
    function markerAt(line) {
        var indent = line.search(/\S/)
        var at = 0, current = 0
        while (at < indent && nextColumn(line, at, current) <= column) {
            current = nextColumn(line, at, current)
            at++
        }
        if (!area.selected && !line.startsWith(prefix) && line.slice(indent).startsWith(prefix)) at = indent
        return at
    }
    for (var i = area.first; i <= area.last; i++) {
        var content = text.slice(area.lines[i].start, area.lines[i].end)
        if (!content.trim()) continue
        found = true
        if (!content.slice(markerAt(content)).startsWith(prefix)) allCommented = false
    }
    if (!found) return noEdit()
    return lineEdit(text, start, end, cursor, function(line) {
        if (!line.trim()) return null
        var at = markerAt(line)
        if (allCommented) {
            var remove = prefix.length + (line[at + prefix.length] === " " ? 1 : 0)
            return { at: at, remove: remove, insert: "", text: line.slice(0, at) + line.slice(at + remove) }
        }
        return { at: at, remove: 0, insert: prefix + " ", text: line.slice(0, at) + prefix + " " + line.slice(at) }
    })
}

function indent(text, start, end, cursor, unit, outdent) {
    unit = unit || "    "
    var area = affected(text, start, end, cursor)
    if (!outdent && !area.selected) return edit(text, start, end, unit, start + unit.length, start + unit.length, start + unit.length)
    return lineEdit(text, start, end, cursor, function(line) {
        if (!outdent) return { at: 0, remove: 0, insert: unit, text: unit + line }
        var count = line[0] === "\t" ? 1 : 0
        if (!count && unit.indexOf("\t") < 0) while (count < unit.length && line[count] === " ") count++
        if (!count) return null
        return { at: 0, remove: count, insert: "", text: line.slice(count) }
    })
}

function selectLine(text, start, end, cursor) {
    var area = affected(text, start, end, cursor)
    return { changed: true, selectionOnly: true, selectionStart: area.lines[area.first].start,
             selectionEnd: area.lines[area.last].end, cursorPosition: area.lines[area.last].end }
}

function lineCommand(text, start, end, cursor, command) {
    var area = affected(text, start, end, cursor), lines = area.lines
    var first = lines[area.first], last = lines[area.last], block = text.slice(first.start, last.end)
    var separator = last.eol || (text.indexOf("\r\n") >= 0 ? "\r\n" : "\n")
    if (command === "delete") {
        var from = first.start, to = last.after
        if (to === text.length && from > 0) from = lines[area.first - 1].end
        return edit(text, from, to, "", from, from, from)
    }
    if (command === "duplicateUp" || command === "duplicateDown") {
        var at = command === "duplicateUp" ? first.start : last.end
        var added = command === "duplicateUp" ? block + separator : separator + block
        var chosen = command === "duplicateUp" ? at : at + separator.length
        var copiedCursor = chosen + cursor - first.start
        return edit(text, at, at, added, area.selected ? chosen : copiedCursor,
                    area.selected ? chosen + block.length : copiedCursor, copiedCursor)
    }
    if (command === "moveUp") {
        if (area.first === 0) return noEdit()
        var prev = lines[area.first - 1], moved = block + prev.eol + text.slice(prev.start, prev.end)
        var upCursor = prev.start + cursor - first.start
        return edit(text, prev.start, last.end, moved, area.selected ? prev.start : upCursor,
                    area.selected ? prev.start + block.length : upCursor, upCursor)
    }
    if (command === "moveDown") {
        if (area.last >= lines.length - 1) return noEdit()
        var next = lines[area.last + 1], movedDown = text.slice(next.start, next.end) + last.eol + block
        var chosenStart = first.start + (next.end - next.start) + last.eol.length
        var downCursor = chosenStart + cursor - first.start
        return edit(text, first.start, next.end, movedDown, area.selected ? chosenStart : downCursor,
                    area.selected ? chosenStart + block.length : downCursor, downCursor)
    }
    return noEdit()
}

function newline(text, start, end) {
    var lines = linesOf(text), current = 0
    while (current + 1 < lines.length && lines[current + 1].start <= start) current++
    var prefix = (text.slice(lines[current].start, lines[current].end).match(/^[ \t]*/) || [""])[0]
    var value = (text.indexOf("\r\n") >= 0 ? "\r\n" : "\n") + prefix
    return edit(text, start, end, value, start + value.length, start + value.length, start + value.length)
}

if (typeof module !== "undefined") module.exports = { profileForFile: profileForFile, toggleComment: toggleComment,
    indent: indent, lineCommand: lineCommand, selectLine: selectLine, newline: newline }
