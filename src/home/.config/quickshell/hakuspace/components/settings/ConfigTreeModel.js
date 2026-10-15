// Build visible directory and file rows from the safe backend file IDs.
function rows(files, group) {
    const root = { children: [] }
    for (const file of files) {
        if (file.group !== group || !file.id.startsWith(group + "/")) continue
        const parts = file.id.slice(group.length + 1).split("/")
        let parent = root
        for (let index = 0; index < parts.length; index++) {
            const type = index === parts.length - 1 ? "file" : "directory"
            let child = parent.children.find(node => node.name === parts[index] && node.type === type)
            if (!child) {
                child = { name: parts[index], type: type, file: type === "file" ? file : null, children: [] }
                parent.children.push(child)
            }
            parent = child
        }
    }

    const result = []
    // Directories lead each sibling group; names then sort case-insensitively.
    function flatten(children, depth, ancestorLast) {
        children.sort((a, b) => {
            if (a.type !== b.type) return a.type === "directory" ? -1 : 1
            const left = a.name.toLowerCase()
            const right = b.name.toLowerCase()
            return left < right ? -1 : left > right ? 1 : a.name < b.name ? -1 : a.name > b.name ? 1 : 0
        })
        children.forEach((node, index) => {
            const isLast = index === children.length - 1
            result.push({ type: node.type, label: node.name, depth: depth,
                          ancestorLast: ancestorLast, isLast: isLast,
                          fileId: node.file ? node.file.id : "" })
            if (node.children.length) flatten(node.children, depth + 1, ancestorLast.concat([isLast]))
        })
    }
    flatten(root.children, 0, [])
    return result
}
