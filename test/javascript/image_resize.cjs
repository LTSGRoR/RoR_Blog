const fs = require("node:fs")
const assert = require("node:assert/strict")
const Controller = class {}
const source = fs.readFileSync("app/javascript/controllers/image_size_controller.js", "utf8")
  .replace(/^import .*\n/, "").replace("export default class", "class ImageSizeController")
const Klass = eval(source + "\nImageSizeController")
global.getComputedStyle = () => ({ paddingRight: "10px" })

function setup() {
  const c = new Klass()
  let attributes = { width: 400, height: 200 }
  let capture = null
  let undos = 0
  let removed = false
  const attachment = {
    getAttributes: () => ({ ...attributes }),
    setAttributes: (values) => { attributes = { ...attributes, ...values } }
  }
  const image = { closest: () => null, getBoundingClientRect: () => ({ left: 20, top: 50, width: attributes.width, height: attributes.height }) }
  c.editorTarget = {
    editor: {
      getDocument: () => ({ getAttachmentById: (id) => id === 7 && !removed ? attachment : null }),
      recordUndoEntry: () => { undos++ }
    },
    querySelector: () => removed ? null : image,
    getBoundingClientRect: () => ({ right: 830, width: 810 })
  }
  c.element = {
    classList: { add() {}, remove() {} },
    getBoundingClientRect: () => ({ left: 10, top: 30 }),
    scrollLeft: 0, scrollTop: 0
  }
  c.controlsTarget = { hidden: true, style: {} }
  c.handleTarget = {
    focus() {},
    setPointerCapture: (id) => { capture = id },
    hasPointerCapture: (id) => capture === id,
    releasePointerCapture: () => { capture = null }
  }
  c.attachmentId = 7
  c.refresh = () => c.positionControls()
  const event = (x, y, pointerId = 1) => ({ button: 0, pointerId, clientX: x, clientY: y, preventDefault() {} })
  return { c, event, attributes: () => attributes, undos: () => undos, capture: () => capture, remove: () => { removed = true } }
}

{
  const { c, event, attributes, undos, capture } = setup()
  c.startDrag(event(420, 250))
  assert.equal(capture(), 1)
  c.moveDrag(event(620, 350))
  assert.deepEqual(attributes(), { width: 600, height: 300 })
  c.moveDrag(event(720, 400))
  assert.deepEqual(attributes(), { width: 700, height: 350 })
  assert.equal(undos(), 1, "one drag should be one undo action")
  c.endDrag(event(720, 400))
  assert.equal(capture(), null)
  assert.equal(c.drag, null)
  assert.equal(c.controlsTarget.style.width, "700px")
  assert.equal(c.controlsTarget.style.left, "10px")
  assert.equal(c.controlsTarget.style.top, "20px")
}

{
  const { c, event, attributes, undos } = setup()
  c.startDrag(event(420, 250))
  c.moveDrag(event(900, 500, 2))
  assert.deepEqual(attributes(), { width: 400, height: 200 }, "ignore unrelated pointers")
  assert.equal(undos(), 0)
  c.moveDrag(event(9000, 5000))
  assert.equal(attributes().width, 800, "stay inside the editor")
  c.moveDrag(event(-9000, -5000))
  assert.equal(attributes().width, 48, "keep the handle usable at the minimum size")
  c.cancelDrag()
  assert.deepEqual(attributes(), { width: 400, height: 200 }, "cancellation restores the initial size")
  assert.equal(c.drag, null)
}

{
  const { c, event, attributes, undos } = setup()
  c.startDrag(event(420, 250))
  c.endDrag(event(420, 250))
  assert.equal(undos(), 0, "clicking without dragging should not add an undo action")
  c.keyResize({ key: "ArrowRight", shiftKey: false, preventDefault() {} })
  assert.deepEqual(attributes(), { width: 410, height: 205 })
  c.keyResize({ key: "ArrowLeft", shiftKey: true, preventDefault() {} })
  assert.deepEqual(attributes(), { width: 370, height: 185 })
}

{
  const { c, remove } = setup()
  c.positionControls()
  assert.equal(c.controlsTarget.hidden, false)
  remove()
  c.positionControls()
  assert.equal(c.controlsTarget.hidden, true, "hide the handle after the selected attachment is deleted")
}

{
  const { c, event, remove, capture } = setup()
  c.startDrag(event(420, 250))
  remove()
  c.moveDrag(event(620, 350))
  assert.equal(c.drag, null, "deleting an image during resizing must finish the drag safely")
  assert.equal(capture(), null)
  assert.equal(c.controlsTarget.hidden, true)
}

console.log("PASS: image drag resizing, aspect ratio, bounds, cancellation, keyboard adjustments, and undo grouping")
