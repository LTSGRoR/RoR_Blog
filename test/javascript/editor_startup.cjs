const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const { execFileSync } = require('node:child_process');
const { chromium } = require(process.argv[2] || 'playwright');
(async () => {
  const gem = execFileSync('bundle',['show','action_text-trix'],{encoding:'utf8'}).trim().split('\n').at(-1);
  const asset = fs.readFileSync(path.join(gem,'app/assets/javascripts/trix.js'),'utf8');
  const config = fs.readFileSync('app/javascript/rich_text_alignment.js','utf8');
  const dataURL = source => 'data:text/javascript;base64,' + Buffer.from(source).toString('base64');
  const browser = await chromium.launch({headless:true,...(process.argv[3]?{executablePath:process.argv[3]}:{})});
  try {
    const page = await browser.newPage();
    const errors = [];
    page.on('pageerror',error=>errors.push(error.message));
    await page.setContent(`<style>${fs.readFileSync('app/assets/builds/tailwind.css','utf8')}</style>
      <script type="importmap">${JSON.stringify({imports:{trix:dataURL(asset),rich_text_alignment:dataURL(config)}})}</script>
      <script type="module">import "rich_text_alignment";window.alignmentLoaded=true;</script>
      <div class="prose-trix"><input id="body" type="hidden"><trix-editor input="body"></trix-editor></div>`);
    await page.waitForFunction(()=>window.alignmentLoaded && document.querySelector('trix-editor').editor,{},{timeout:5000});
    assert.deepEqual(errors,[],'actual Rails Trix module must load without import errors');
    await page.locator('trix-editor').fill('Typing works');
    await page.waitForFunction(()=>document.querySelector('#body').value.includes('Typing works'));
    const controller = fs.readFileSync('app/javascript/controllers/editor_alignment_controller.js','utf8')
      .replace(/^import .*\n/,'').replace('export default class','window.AlignmentController = class');
    await page.addScriptTag({content:'const Controller = class {};\n'+controller});
    await page.evaluate(()=>{
      const c = new window.AlignmentController();
      Object.assign(c,{editorTarget:document.querySelector('trix-editor'),leftValue:'Align left',centerValue:'Align center',rightValue:'Align right',labelValue:'Text alignment'});
      c.connect();window.alignmentController=c;
    });
    for(const direction of ['center','right','left']) {
      await page.locator(`[data-editor-align="${direction}"]`).click();
      await page.waitForFunction(direction=>document.querySelector('trix-editor .rt-align-'+direction),direction);
      assert.equal(await page.locator('trix-editor').textContent(),'Typing works');
      const saved = await page.locator('#body').inputValue();
      assert(saved.includes('rt-align-'+direction),'alignment must be serialized');
      await page.evaluate(html=>document.querySelector('trix-editor').editor.loadHTML(html),saved);
      await page.waitForFunction(direction=>document.querySelector('trix-editor .rt-align-'+direction),direction);
    }
    await page.locator('trix-editor').press('End');
    await page.locator('trix-editor').pressSequentially(' after alignment');
    await page.waitForFunction(()=>document.querySelector('#body').value.includes('after alignment'));
    await page.evaluate(() => {
      const editor = document.querySelector('trix-editor').editor;
      editor.loadHTML('<div>First</div><div>Second</div><h1>Heading</h1><blockquote>Quote</blockquote><pre>puts 1</pre><ul><li>A</li><li>B</li></ul>');
    });
    await page.waitForFunction(() => document.querySelector('trix-editor li')?.textContent === 'A');
    const original = await page.evaluate(() => {
      const editor = document.querySelector('trix-editor').editor;
      const text = editor.getDocument().toString();
      editor.setSelectedRange([0, text.length - 1]);
      return text;
    });
    await page.locator('[data-editor-align="center"]').click();
    assert.equal(await page.evaluate(() => document.querySelector('trix-editor').editor.getDocument().toString()),original,'alignment must preserve all selected block content');
    for (const tag of ['h1','blockquote','pre','li']) assert(await page.locator(`trix-editor ${tag}.rt-align-center`).count(),`${tag} should retain formatting and alignment`);
    await page.evaluate(() => {window.alignmentController.disconnect();window.alignmentController.connect()});
    assert.equal(await page.locator('[data-editor-align]').count(),3,'reconnecting must restore exactly one alignment group');
    assert.deepEqual(errors,[],'typing and alignment must not throw browser errors');
    console.log('PASS: real ES module startup, editable body, typing, all alignment buttons, serialization, reopening, and typing afterward');
  } finally {await browser.close()}
})().catch(error=>{console.error(error);process.exitCode=1});
