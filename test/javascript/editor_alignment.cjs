const fs = require('node:fs');
const assert = require('node:assert/strict');
const Controller = class {};
const source = fs.readFileSync('app/javascript/controllers/editor_alignment_controller.js','utf8').replace(/^import .*\n/,'').replace('export default class','class EditorAlignmentController');
const Klass = eval(source+'\nEditorAlignmentController');
const c = new Klass();
const blocks = [
 {htmlAttributes:{class:'custom rt-align-right'},getAttributes:()=>[]},
 {htmlAttributes:{class:'rt-align-left'},getAttributes:()=>['heading1']},
 {htmlAttributes:{class:'language-ruby'},getAttributes:()=>['code']}
];
let range=[0,10];let undo=0;const conversions=[];
const positions=[0,6,11];
const doc={
 locationFromPosition:position=>({index:position>=11?2:position>=6?1:0}),
 positionFromLocation:({index})=>positions[index],
 getBlockAtPosition:position=>blocks[positions.indexOf(position)]
};
c.editorTarget={focus(){},editor:{
 getDocument:()=>doc,getSelectedRange:()=>range,setSelectedRange:r=>{range=r},
 recordUndoEntry:()=>{undo++},activateAttribute:attribute=>conversions.push(attribute),
 setHTMLAtributeAtPosition:(position,name,value)=>{blocks[positions.indexOf(position)].htmlAttributes[name]=value}
}};
c.update=()=>{};
c.align('center');
assert.deepEqual(range,[0,10]);
assert.equal(undo,1);
assert.equal(blocks[0].htmlAttributes.class,'custom rt-align-center');
assert.equal(blocks[1].htmlAttributes.class,'rt-align-center');
assert.equal(blocks[2].htmlAttributes.class,'language-ruby','unselected blocks must stay unchanged');
assert.deepEqual(conversions,['alignment'],'only plain paragraphs need the alignment container');
range=[11,11]; c.align('right');
assert.equal(blocks[2].htmlAttributes.class,'language-ruby rt-align-right');
assert.deepEqual(conversions,['alignment'],'code formatting must survive alignment');
c.align('justify'); assert.equal(undo,2,'ignore unsupported alignment');
range=[0,6];assert.equal(c.selectedBlocks().length,1,'selection ending at the next paragraph should not align that paragraph');
console.log('PASS: multiple paragraphs, selection boundaries, existing classes, heading/code preservation, and undo grouping');
