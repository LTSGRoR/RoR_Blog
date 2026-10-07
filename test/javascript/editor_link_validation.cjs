const fs = require('node:fs');
const assert = require('node:assert/strict');
const Controller = class {};
const source = fs.readFileSync('app/javascript/controllers/editor_link_controller.js','utf8')
  .replace(/^import .*\n/,'').replace('export default class','class EditorLinkController');
const Klass = eval(source+'\nEditorLinkController');
function setup(url, text='Hello ') {
  const c = new Klass();
  const actions = [];
  c.range = [0,6]; c.originalText = 'Hello ';
  c.textTarget = {value:text};
  c.urlTarget = {value:url, setAttribute:(key,value)=>actions.push([key,value]),focus:()=>actions.push(['focus'])};
  c.errorTarget = {hidden:true}; c.invalidValue = 'Invalid address';
  c.dialogTarget = {close:()=>actions.push(['close'])};
  c.editorTarget = {editor:{
    recordUndoEntry:description=>actions.push(['undo',description]),
    setSelectedRange:range=>actions.push(['range',range]),
    insertString:text=>actions.push(['insert',text]),
    activateAttribute:(key,value)=>actions.push([key,value])
  }};
  return {c,actions};
}
for (const url of ['javascript:alert(1)','data:text/html,bad','file:///etc/passwd','', 'mailto:','tel:','https://']) {
  const {c,actions}=setup(url);
  c.save({preventDefault(){}});
  assert.equal(c.errorTarget.hidden,false,url);
  assert(!actions.some(action=>action[0]==='undo'||action[0]==='close'), 'invalid input must not change the document');
}
for (const [url,expected] of [['example.com','https://example.com'],['https://example.org/docs','https://example.org/docs'],['mailto:writer@example.com','mailto:writer@example.com'],['tel:+123456789','tel:+123456789']]) {
  const {c,actions}=setup(url);
  c.save({preventDefault(){}});
  assert(actions.some(action=>action[0]==='href'&&action[1]===expected));
  assert(!actions.some(action=>action[0]==='insert'), 'unchanged text and its formatting must be preserved');
  assert.equal(actions.filter(action=>action[0]==='undo').length,1);
}
{
  const {c,actions}=setup('https://example.com','Docs');
  c.save({preventDefault(){}});
  assert(actions.some(action=>action[0]==='insert'&&action[1]==='Docs'));
  assert.deepEqual(c.range,[0,4]);
}
{
  const {c,actions}=setup('https://example.com');
  c.save({type:'keydown',target:{tagName:'BUTTON'},preventDefault(){throw new Error('must preserve the button action')}});
  assert.deepEqual(actions,[], 'Enter on Cancel or Remove must not insert a link');
}
console.log('PASS: link URL validation, domain normalization, original text preservation, replacement, undo grouping, and button keyboard semantics');
