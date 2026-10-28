// Parse conservative shell words while retaining source offsets for lossless edits.
function parse(text, flags, allowVariables) {
    var tokens = [], start = -1, quote = "", value = "", escaped = false
    for (var i = 0; i <= text.length; i++) {
        var c = text[i] || " "
        if (escaped) { value += c; escaped = false; continue }
        if (i < text.length && c === "\\" && quote !== "'") { if (start < 0) start = i; escaped = true; continue }
        if (quote) { if (c === quote) quote = ""; else value += c; continue }
        if (i < text.length && (c === "'" || c === '"')) { if (start < 0) start = i; quote = c; continue }
        if (/\s/.test(c)) { if (start >= 0) { tokens.push({value: value, start: start, end: i}); start = -1; value = "" } }
        else { if (start < 0) start = i; value += c }
    }
    if (quote || escaped || /[`;|&<>\r\n\0]|\$\(/.test(text) || (!allowVariables && /\$/.test(text))) return {safe: false, values: {}, extraArguments: text, spans: {}}
    var values = {}, spans = {}, extras = [], known = Object.keys(flags)
    for (var j = 0; j < tokens.length; j++) {
        var token = tokens[j], key = token.value.split("=")[0]
        if (!known.includes(key)) { extras.push(text.substring(token.start, token.end)); continue }
        if (spans[key]) return {safe: false, values: {}, extraArguments: text, spans: {}}
        var equals = token.value.indexOf("="), argument = equals >= 0 ? token.value.substring(equals + 1) : tokens[++j] && tokens[j].value
        if (argument === undefined || !flags[key].test(argument)) return {safe: false, values: {}, extraArguments: text, spans: {}}
        values[key] = argument
        spans[key] = {start: token.start, end: tokens[j].end}
    }
    return {safe: true, values: values, extraArguments: extras.join(" "), spans: spans}
}
// Replace only a recognized flag; all other bytes and custom arguments survive.
function replace(text, flags, key, value, allowVariables) {
    var parsed = parse(text, flags, allowVariables)
    if (!parsed.safe || !flags[key] || !flags[key].test(String(value))) return null
    var span = parsed.spans[key], replacement = key + " " + String(value)
    return span ? text.substring(0, span.start) + replacement + text.substring(span.end) : text + (text && !/\s$/.test(text) ? " " : "") + replacement
}
// Replace extra arguments only after validating that they contain no known flags.
function extras(text, flags, extra, allowVariables) {
    var parsed = parse(text, flags, allowVariables), candidate = parse(extra, flags, allowVariables)
    if (!parsed.safe || !candidate.safe || Object.keys(candidate.spans).length) return null
    var spans = Object.keys(parsed.spans).map(function(key) { return parsed.spans[key] }).sort(function(a, b) { return a.start - b.start })
    return spans.map(function(span) { return text.substring(span.start, span.end) }).concat(extra.trim() ? [extra] : []).join(" ")
}
var recording = {"--max-fps": /^[1-9][0-9]{0,2}$/}
var wallpaper = {"--transition-type": /^(none|simple|fade|left|right|top|bottom|wipe|wave|grow|center|any|outer|random)$/, "--transition-step": /^(?:[1-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])$/, "--transition-fps": /^[1-9][0-9]{0,2}$/, "--transition-duration": /^(?:0|[1-9][0-9]*)(?:\.[0-9]+)?$/}
