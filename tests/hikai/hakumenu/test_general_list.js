#!/usr/bin/env node
const assert = require('node:assert/strict')
const fs = require('node:fs')
const path = require('node:path')
const vm = require('node:vm')

const shell = path.resolve(__dirname, '../../../src/home/.config/quickshell/hakuspace')
const generalListSource = fs.readFileSync(path.join(shell, 'components/hakumenu/GeneralList.qml'), 'utf8')

// Ensure actionProcess is not used in GeneralList
assert.doesNotMatch(generalListSource, /id:\s*actionProcess\b/, 'GeneralList should not declare actionProcess')
assert.doesNotMatch(generalListSource, /actionProcess\./, 'GeneralList should not reference actionProcess')
assert.match(generalListSource, /import\s+Quickshell\b/, 'GeneralList must import Quickshell')

// Test activateIndex behavior
const activateIndexMatch = generalListSource.match(/function activateIndex\(index\)[\s\S]*?^    \}/m)
assert.ok(activateIndexMatch, 'activateIndex function found')

const detachedCalls = []
let launchedEmitted = false

const mockContext = vm.createContext({
    visibleItems: [
        {
            label: "Disk Manager",
            command: ["gparted"],
            fixed: true,
            raw: "󰋊  Disk Manager"
        },
        {
            label: "Storage Manager",
            command: ["kitty", "--class", "ncdu", "-e", "sudo", "ncdu", "/"],
            fixed: true,
            raw: "󰃢  Storage Manager"
        },
        {
            label: "Browser",
            fixed: false,
            raw: "  Browser"
        }
    ],
    Env: {
        binDir: "/fixture/bin"
    },
    Quickshell: {
        execDetached: (cmd) => {
            detachedCalls.push(cmd)
        }
    },
    root: {
        launched: () => {
            launchedEmitted = true
        }
    }
})

vm.runInContext(activateIndexMatch[0], mockContext)

const plain = (val) => JSON.parse(JSON.stringify(val))

// Test Disk Manager activation
mockContext.activateIndex(0)
assert.equal(detachedCalls.length, 1)
assert.deepEqual(plain(detachedCalls[0]), ["gparted"])
assert.equal(launchedEmitted, true)

// Test Storage Manager activation
launchedEmitted = false
mockContext.activateIndex(1)
assert.equal(detachedCalls.length, 2)
assert.deepEqual(plain(detachedCalls[1]), ["kitty", "--class", "ncdu", "-e", "sudo", "ncdu", "/"])
assert.equal(launchedEmitted, true)

// Test dynamic action activation
launchedEmitted = false
mockContext.activateIndex(2)
assert.equal(detachedCalls.length, 3)
assert.deepEqual(plain(detachedCalls[2]), ["/fixture/bin/hm_general.sh", "  Browser"])
assert.equal(launchedEmitted, true)

console.log("GeneralList activation tests passed.")
