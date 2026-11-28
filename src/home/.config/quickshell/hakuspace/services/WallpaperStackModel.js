.pragma library

var EDITED_PATTERN = /^(.+?)_\[edited\](?:_(.+))?$/
var OUTPUT_EXTENSIONS = [".png", ".jpg", ".jpeg", ".webp"]

function parseStem(stem) {
    var value = String(stem || "")
    var match = EDITED_PATTERN.exec(value)
    if (!match)
        return {base: value, isEdited: false, variant: ""}
    return {base: match[1], isEdited: true, variant: match[2] || ""}
}

function normalizeCategory(category) {
    return category ? String(category) : "[Root]"
}

function splitPath(filePath) {
    var path = String(filePath || "")
    var slash = path.lastIndexOf("/")
    var dir = slash >= 0 ? path.slice(0, slash) : ""
    var filename = slash >= 0 ? path.slice(slash + 1) : path
    var dot = filename.lastIndexOf(".")
    if (dot <= 0)
        return {dir: dir, filename: filename, stem: filename, ext: ""}
    return {dir: dir, filename: filename, stem: filename.slice(0, dot), ext: filename.slice(dot)}
}

function defaultOutputExtension(sourceExt) {
    var lower = String(sourceExt || "").toLowerCase()
    if (lower === ".jpeg") return ".jpg"
    if (OUTPUT_EXTENSIONS.indexOf(lower) >= 0) return lower
    return ".png"
}

function groupKeyFor(item) {
    if (!item || item.kind !== "static")
        return item ? String(item.path || "") : ""
    return normalizeCategory(item.category) + "\0" + parseStem(item.label).base
}

function layerDisplayLabel(parsed) {
    if (!parsed || !parsed.isEdited) return "Original"
    return parsed.variant ? "Edited · " + parsed.variant : "Edited"
}

function compareLayers(a, b) {
    if (a.isEdited !== b.isEdited) return a.isEdited ? -1 : 1
    var timeDelta = Number(b.previewVersion || 0) - Number(a.previewVersion || 0)
    if (timeDelta !== 0) return timeDelta
    if (a.isEdited && b.isEdited && (a.editVariant === "") !== (b.editVariant === ""))
        return a.editVariant === "" ? -1 : 1
    return String(a.label || "").toLowerCase().localeCompare(String(b.label || "").toLowerCase())
        || String(a.path || "").localeCompare(String(b.path || ""))
}

function resolveStack(stack, layerSelections) {
    // Support both native JS arrays and Qt QVariantList sequences from PathView delegates.
    if (!stack || !stack.layers || !stack.layers.length)
        return stack || null
    var selections = layerSelections || ({})
    var layers = stack.layers
    var count = layers.length
    var activeIndex = 0
    var rememberedPath = selections[stack.groupKey]
    if (rememberedPath) {
        for (var i = 0; i < count; ++i) {
            if (layers[i] && layers[i].path === rememberedPath) {
                activeIndex = i
                break
            }
        }
    }
    var active = layers[activeIndex]
    var backingThumbnails = []
    for (var offset = 1; offset < count && backingThumbnails.length < 2; ++offset) {
        var nextLayer = layers[(activeIndex + offset) % count]
        backingThumbnails.push(nextLayer && nextLayer.thumbnail ? nextLayer.thumbnail : "")
    }
    return Object.assign({}, active, {
        groupKey: stack.groupKey,
        baseLabel: stack.baseLabel,
        layers: layers,
        layerCount: count,
        activeLayerIndex: activeIndex,
        hasEdited: stack.hasEdited,
        latestPreviewVersion: stack.latestPreviewVersion,
        backingThumbnails: backingThumbnails
    })
}

function buildStacks(items, kind, activeCategory, query, sort, layerSelections) {
    var list = Array.isArray(items) ? items : []
    var needle = String(query || "").trim().toLowerCase()
    var groups = {}
    var groupOrder = []

    for (var i = 0; i < list.length; ++i) {
        var item = list[i]
        if (!item || item.kind !== kind) continue
        var cat = normalizeCategory(item.category)
        if (activeCategory !== "" && (activeCategory === "[Root]" ? cat !== "[Root]" : item.category !== activeCategory))
            continue
        var key = groupKeyFor(item)
        if (!groups[key]) {
            groups[key] = []
            groupOrder.push(key)
        }
        var parsed = item.kind === "static" ? parseStem(item.label) : {base: String(item.label || ""), isEdited: false, variant: ""}
        var annotated = Object.assign({}, item, {
            groupKey: key,
            baseLabel: parsed.base,
            isEdited: parsed.isEdited,
            editVariant: parsed.variant,
            layerLabel: layerDisplayLabel(parsed)
        })
        groups[key].push(annotated)
    }

    var stacks = []
    for (var g = 0; g < groupOrder.length; ++g) {
        var groupKey = groupOrder[g]
        var layers = groups[groupKey]
        if (layers.length > 1) layers.sort(compareLayers)

        var originalLayer = null
        var latestVersion = 0
        var hasEdited = false
        for (var j = 0; j < layers.length; ++j) {
            if (!layers[j].isEdited && !originalLayer) originalLayer = layers[j]
            if (layers[j].isEdited) hasEdited = true
            var ver = Number(layers[j].previewVersion || 0)
            if (ver > latestVersion) latestVersion = ver
        }
        var baseLabel = originalLayer ? originalLayer.baseLabel : layers[0].baseLabel

        if (needle) {
            var matches = baseLabel.toLowerCase().indexOf(needle) >= 0
                || layers.some(function(layer) { return String(layer.label || "").toLowerCase().indexOf(needle) >= 0 })
            if (!matches) continue
        }

        var baseStack = {
            groupKey: groupKey,
            baseLabel: baseLabel,
            layers: layers,
            layerCount: layers.length,
            hasEdited: hasEdited,
            latestPreviewVersion: latestVersion
        }
        stacks.push(resolveStack(baseStack, layerSelections))
    }

    stacks.sort(function(a, b) {
        var byName = a.baseLabel.toLowerCase().localeCompare(b.baseLabel.toLowerCase())
            || a.groupKey.localeCompare(b.groupKey)
        if (sort === "newest")
            return Number(b.latestPreviewVersion || 0) - Number(a.latestPreviewVersion || 0) || byName
        return sort === "name-desc" ? -byName : byName
    })
    return stacks
}

function defaultEditStem(sourceStem, existingStems) {
    var parsed = parseStem(sourceStem)
    if (parsed.isEdited)
        return String(sourceStem || "")
    var used = {}
    if (Array.isArray(existingStems)) {
        for (var i = 0; i < existingStems.length; ++i)
            used[String(existingStems[i])] = true
    }
    var baseCandidate = parsed.base + "_[edited]"
    if (!used[baseCandidate])
        return baseCandidate
    for (var n = 2; n < 10000; ++n) {
        var numbered = baseCandidate + "_" + n
        if (!used[numbered])
            return numbered
    }
    return baseCandidate + "_" + Date.now()
}

function classifyOutputName(sourcePath, candidateStem, candidateExt, existingPaths) {
    var src = splitPath(sourcePath)
    var sourceParsed = parseStem(src.stem)
    var stem = String(candidateStem || "").trim()
    var ext = String(candidateExt || "").toLowerCase()
    if (!stem) {
        return {valid: false, error: "Enter a file name.", targetPath: "", overwrite: false, stacksWithSource: false, targetBase: sourceParsed.base}
    }
    if (stem === "." || stem === ".." || /[\/\\\u0000-\u001f]/.test(stem)) {
        return {valid: false, error: "File name cannot contain slashes or control characters.", targetPath: "", overwrite: false, stacksWithSource: false, targetBase: sourceParsed.base}
    }
    if (OUTPUT_EXTENSIONS.indexOf(ext) < 0) {
        return {valid: false, error: "Choose PNG, JPEG or WebP format.", targetPath: "", overwrite: false, stacksWithSource: false, targetBase: sourceParsed.base}
    }
    var targetPath = (src.dir ? src.dir + "/" : "/") + stem + ext
    var isSameAsSource = targetPath === sourcePath
    var canOverwrite = isSameAsSource && sourceParsed.isEdited
    var existing = {}
    if (Array.isArray(existingPaths)) {
        for (var i = 0; i < existingPaths.length; ++i)
            existing[String(existingPaths[i])] = true
    }
    if (isSameAsSource && !sourceParsed.isEdited) {
        return {valid: false, error: "Original wallpaper cannot be overwritten. Use a new name.", targetPath: targetPath, overwrite: false, stacksWithSource: false, targetBase: sourceParsed.base}
    }
    if (!canOverwrite && existing[targetPath]) {
        return {valid: false, error: "A wallpaper with this name already exists.", targetPath: targetPath, overwrite: false, stacksWithSource: false, targetBase: sourceParsed.base}
    }
    var targetParsed = parseStem(stem)
    var stacksWithSource = targetParsed.isEdited && targetParsed.base === sourceParsed.base
    return {
        valid: true,
        error: "",
        targetPath: targetPath,
        overwrite: canOverwrite,
        stacksWithSource: stacksWithSource,
        targetBase: sourceParsed.base
    }
}
