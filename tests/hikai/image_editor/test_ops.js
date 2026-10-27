#!/usr/bin/env node
// Exercise whole-stroke history, branching redo and snapshot isolation.
const assert = require('node:assert/strict')
const fs = require('node:fs')
const vm = require('node:vm')
const path = require('node:path')
const ops = vm.createContext({})
vm.runInContext(fs.readFileSync(path.resolve(__dirname, '../../../src/home/.config/quickshell/hakuspace/components/imageeditor/ImageEditorOps.js'), 'utf8'), ops)
const session = {rotation:0,cropRatio:0,flipX:false,flipY:false,cropRectNormalized:{x:0,y:0,width:1,height:1},annotations:[],outputScale:1,encodeQuality:90,undoStack:[],redoStack:[]}
session.originalState = JSON.stringify(ops.snapshot(session))
const next = ops.snapshot(session)
next.annotations.push({type:'stroke', points:[{x:.1,y:.1},{x:.5,y:.5}]})
ops.commit(session,next)
assert.equal(session.undoStack.length,1)
next.annotations[0].points[0].x = .9
assert.equal(session.annotations[0].points[0].x,.1)
ops.undo(session,false)
assert.equal(session.annotations.length,0)
assert.equal(session.dirty,false)
ops.undo(session,true)
assert.equal(session.annotations.length,1)
ops.undo(session,false)
const branch = ops.snapshot(session); branch.rotation = 90
ops.commit(session,branch)
assert.equal(session.redoStack.length,0)
for(let index=0;index<80;index++) {const value=ops.snapshot(session);value.encodeQuality=index+1;ops.commit(session,value)}
assert.equal(session.undoStack.length,50)
console.log('Image editor operations passed')
// Verify service orientation composition against a point mapped through independent mirrors.
const geometry = vm.createContext({})
vm.runInContext(fs.readFileSync(path.resolve(__dirname, '../../../src/home/.config/quickshell/hakuspace/components/imageeditor/ImageEditorGeometry.js'), 'utf8'), geometry)
const source = fs.readFileSync(path.resolve(__dirname, '../../../src/home/.config/quickshell/hakuspace/services/ImageEditor.qml'), 'utf8')
const orient = source.match(/    function orient\(operation\) \{[\s\S]*?\n    }/)[0]
for (const rotation of [0,90,180,270]) for (const flipX of [false,true]) for (const flipY of [false,true]) {
    for (const operation of ['cw','ccw','horizontal','vertical']) {
        const original = {x:.2,y:.7}
        const map = (point, angle, horizontal, vertical) => {
            let p = {...point}
            for (let turn=0;turn<angle;turn+=90) p = {x:1-p.y,y:p.x}
            if(horizontal)p.x=1-p.x
            if(vertical)p.y=1-p.y
            return p
        }
        const point = map(original,rotation,flipX,flipY)
        const value = {...session,rotation,flipX,flipY,ready:true,busy:false,cropRatio:0,undoStack:[],redoStack:[],annotations:[{type:'arrow',start:point,end:{...point}}]}
        value.Ops = ops; value.Geometry = geometry; value.root = value
        value.commit = next => ops.commit(value,next)
        const context = vm.createContext(value)
        vm.runInContext(orient,context);context.orient(operation)
        const expected = geometry.transformPoint(point,operation)
        const actual = map(original,value.rotation,value.flipX,value.flipY)
        assert(Math.abs(actual.x-expected.x)<1e-9 && Math.abs(actual.y-expected.y)<1e-9)
        assert(Math.abs(value.annotations[0].start.x-expected.x)<1e-9 && Math.abs(value.annotations[0].start.y-expected.y)<1e-9)
    }
}
console.log('Image editor orientation composition passed')
