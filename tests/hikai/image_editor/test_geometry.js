#!/usr/bin/env node
// Verify normalized orientation, pixel aspect ratios and export boundary rounding.
const assert = require('node:assert/strict')
const fs = require('node:fs')
const vm = require('node:vm')
const path = require('node:path')
const root = path.resolve(__dirname, '../../../src/home/.config/quickshell/hakuspace/components/imageeditor')
const geometry = vm.createContext({})
vm.runInContext(fs.readFileSync(path.join(root, 'ImageEditorGeometry.js'), 'utf8'), geometry)
const plain = value => JSON.parse(JSON.stringify(value))
const near = (a, b) => assert(Math.abs(a - b) < 1e-9, `${a} != ${b}`)
for (const operation of ['cw', 'ccw', 'horizontal', 'vertical']) {
    const inverse = operation === 'cw' ? 'ccw' : operation === 'ccw' ? 'cw' : operation
    const point = {x: .2, y: .7}
    const restored = geometry.transformPoint(geometry.transformPoint(point, operation), inverse)
    near(restored.x, point.x); near(restored.y, point.y)
    const rect = {x: .1, y: .2, width: .6, height: .3}
    const back = geometry.transformRect(geometry.transformRect(rect, operation), inverse)
    Object.keys(rect).forEach(key => near(back[key], rect[key]))
}
for (const [width, height] of [[7680,4320], [1000,4000], [4000,1000]]) {
    for (const ratio of [1, 4/3, 16/9]) {
        const rect = geometry.ratioRect({x: 0, y: 0, width: 1, height: 1}, ratio, width, height)
        near(rect.width * width / (rect.height * height), ratio)
        assert(rect.x >= 0 && rect.y >= 0 && rect.x + rect.width <= 1 && rect.y + rect.height <= 1)
    }
}
assert.deepEqual(plain(geometry.outputSize({x: 0, y: 0, width: 1, height: 1}, 2560, 1440, .75, false)), {width:1920,height:1080})
assert.deepEqual(plain(geometry.outputSize({x: .1, y: .1, width: .5, height: .5}, 101, 101, 1, true)), {width:512,height:512})
near(geometry.segmentDistance({x:.5,y:.6}, {x:0,y:.5}, {x:1,y:.5},100,200),20)
const edge = geometry.transformRect({x:.2,y:.2,width:.8,height:.8000000000000002},'cw')
assert(edge.x >= 0 && edge.y >= 0)
console.log('Image editor geometry passed')
// Expanded hit zones include corners and every edge, even outside the full image.
const crop = {x:.2,y:.2,width:.6,height:.6}
for (const [handle, x, y] of [['nw',.19,.19],['n',.5,.19],['ne',.81,.19],['e',.81,.5],
    ['se',.81,.81],['s',.5,.81],['sw',.19,.81],['w',.19,.5]]) {
    assert.equal(geometry.cropHandle({x,y},crop,1000,600,22),handle)
}
assert.equal(geometry.cropHandle({x:-.015,y:-.015},{x:0,y:0,width:1,height:1},1000,600,22),'nw')
assert.equal(geometry.cropHandle({x:.5,y:.5},crop,1000,600,22),'move')
assert.equal(geometry.cropHandle({x:0,y:0},crop,1000,600,22),'')
// Resizing preserves bounds and the opposite anchor across portrait, landscape and square crops.
for (const [width,height] of [[4000,1000],[1000,4000],[512,512]]) {
    for (const ratio of [0,1,4/3,16/9]) {
        const initial = geometry.ratioRect({x:.1,y:.1,width:.8,height:.8},ratio,width,height)
        for (const handle of ['nw','n','ne','e','se','s','sw','w']) {
            for (const point of [{x:.3,y:.4},{x:0,y:0},{x:1,y:1}]) {
                const result = geometry.resizeCrop(initial,handle,point,ratio,width,height)
                assert(result.x>=-1e-9 && result.y>=-1e-9 && result.x+result.width<=1+1e-9 && result.y+result.height<=1+1e-9)
                assert(result.width*width>=1-1e-9 && result.height*height>=1-1e-9)
                if(ratio) near(result.width*width/(result.height*height),ratio)
                if(handle.includes('w')) near(result.x+result.width,initial.x+initial.width)
                if(handle.includes('e')) near(result.x,initial.x)
                if(handle.includes('n')) near(result.y+result.height,initial.y+initial.height)
                if(handle.includes('s')) near(result.y,initial.y)
            }
        }
    }
}
for (const handle of ['nw','n','ne','e','se','s','sw','w']) {
    const tiny = geometry.ratioRect({x:0,y:0,width:1,height:1},16/9,1,1)
    const resized = geometry.resizeCrop(tiny,handle,{x:.5,y:.5},16/9,1,1)
    assert(resized.x>=-1e-9 && resized.y>=-1e-9 && resized.x+resized.width<=1+1e-9 && resized.y+resized.height<=1+1e-9)
}
console.log('Image editor crop edge/corner resizing passed')
