const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const { execFileSync } = require('node:child_process');
const { chromium } = require(process.argv[2] || 'playwright');

(async () => {
  const gem = execFileSync('bundle', ['show', 'action_text-trix'], {encoding:'utf8'}).trim().split('\n').at(-1);
  const css = fs.readFileSync(path.join(gem, 'app/assets/stylesheets/trix.css'), 'utf8');
  const trix = fs.readFileSync(path.join(gem, 'app/assets/javascripts/trix.js'), 'utf8').replace(/<\/script/gi, '<\\/script');
  const dialog = execFileSync('bundle', ['exec', 'rails', 'runner', 'puts ApplicationController.render(partial: "shared/editor_link_dialog", locals: { dialog_id: "test-link-title" })'], {encoding:'utf8', env:{...process.env, EMBEDDINGS_AUTO_RUN_ON_BOOT:'false'}});
  const source = fs.readFileSync('app/javascript/controllers/editor_link_controller.js', 'utf8').replace(/^import .*\n/, '').replace('export default class', 'window.EditorLinkController = class');
  const browser = await chromium.launch({headless:true, ...(process.argv[3] ? {executablePath:process.argv[3]} : {})});
  try {
    for (const mobile of [false, true]) {
      const page = await browser.newPage({viewport:{width:mobile ? 360 : 1200,height:900},isMobile:mobile,hasTouch:mobile});
      const errors = [];
      page.on('pageerror', e => errors.push(e.message));
      await page.setContent(`<style>${css}</style><style>${fs.readFileSync('app/assets/builds/tailwind.css','utf8')}</style><form id="post-form"><div class="prose-trix" style="width:calc(100% - 48px);margin:24px"><input id="body" type="hidden"><trix-editor input="body"></trix-editor>${dialog}</div></form><script>${trix}</script>`);
      await page.waitForFunction(() => document.querySelector('trix-editor').editor);
      await page.addScriptTag({content:'const Controller = class {};\n' + source});
      await page.evaluate(() => {
        const c = new window.EditorLinkController();
        c.editorTarget = document.querySelector('trix-editor');
        for (const name of ['dialog','text','url','error','save','remove','notice']) c[name+'Target'] = document.querySelector(`[data-editor-link-target="${name}"]`);
        Object.assign(c,{insertValue:'Insert link',updateValue:'Update link',invalidValue:'Enter a valid address.',labelValue:'Edit link',selectionValue:'Selected content'});
        c.dialogTarget.addEventListener('cancel', e => c.cancel(e));
        c.dialogTarget.addEventListener('keydown', e => {if(e.key==='Enter') c.save(e)});
        c.saveTarget.addEventListener('click', e => c.save(e));
        c.removeTarget.addEventListener('click', e => c.remove(e));
        c.dialogTarget.querySelector('[data-action="editor-link#close"]').addEventListener('click', () => c.close());
        window.submissions = 0;
        document.querySelector('#post-form').addEventListener('submit', e => {e.preventDefault();window.submissions++});
        c.connect(); window.linkController=c;
        c.editorTarget.editor.loadHTML('<div><strong>Hello</strong> world</div>');
      });
      await page.waitForFunction(() => document.querySelector('trix-editor strong')?.textContent === 'Hello');
      await page.evaluate(() => {
        const e = document.querySelector('trix-editor'); e.focus(); e.editor.setSelectedRange([0,5]);
      });
      await page.waitForFunction(() => window.getSelection().toString() === 'Hello');
      const button = page.locator('[data-trix-action="link"]');
      const modal = page.locator('.editor-link-dialog');
      const url = page.locator('[data-editor-link-target="url"]');
      const text = page.locator('[data-editor-link-target="text"]');
      await button.click();
      assert.equal(await text.inputValue(), 'Hello');
      await url.fill('example.com');
      await page.locator('[data-editor-link-target="save"]').click();
      await modal.waitFor({state:'hidden'});
      assert.equal(await page.locator('trix-editor a').getAttribute('href'),'https://example.com');
      assert.equal(await page.locator('trix-editor a strong').textContent(),'Hello','preserve selected bold formatting');
      await page.evaluate(() => document.querySelector('trix-editor').editor.setSelectedRange([2,2]));
      await button.click();
      assert.equal(await text.inputValue(),'Hello','expand cursor to the existing link');
      assert.equal(await url.inputValue(),'https://example.com');
      await url.fill('https://example.org/docs');
      await url.press('Enter');
      await modal.waitFor({state:'hidden'});
      assert.equal(await page.locator('trix-editor a').getAttribute('href'),'https://example.org/docs');
      await button.click();
      await url.fill('javascript:alert(1)');
      await page.locator('[data-editor-link-target="save"]').click();
      assert.equal(await page.locator('[data-editor-link-target="error"]').isVisible(),true);
      assert.equal(await page.locator('trix-editor a').getAttribute('href'),'https://example.org/docs');
      await url.press('Escape');
      await modal.waitFor({state:'hidden'});
      await button.click();
      await page.locator('[data-editor-link-target="remove"]').click();
      await modal.waitFor({state:'hidden'});
      assert.equal(await page.locator('trix-editor a').count(),0);
      assert.equal(await page.locator('trix-editor strong').textContent(),'Hello');
      await page.evaluate(() => document.querySelector('trix-editor').editor.setSelectedRange([5,5]));
      await page.locator('trix-editor').press('Control+k');
      await text.fill('Docs');
      await url.fill('https://example.com/docs');
      await page.locator('[data-editor-link-target="save"]').click();
      await modal.waitFor({state:'hidden'});
      assert.equal(await page.locator('trix-editor a').textContent(),'Docs');
      const html = await page.locator('#body').inputValue();
      assert(html.includes('https://example.com/docs'),'link must reach saved rich text');
      await page.evaluate(() => document.querySelector('trix-editor').editor.loadHTML('<div><strong>First</strong></div><div><em>Second</em></div>'));
      await page.waitForFunction(() => document.querySelector('trix-editor em')?.textContent === 'Second');
      const original = await page.evaluate(() => {
        const e=document.querySelector('trix-editor'); e.focus();
        const original=e.editor.getDocument().toString();e.editor.setSelectedRange([0,original.length-1]);return original;
      });
      await button.click();
      await url.fill('https://example.com/paragraphs');
      await page.locator('[data-editor-link-target="save"]').click();
      await modal.waitFor({state:'hidden'});
      assert.equal(await page.evaluate(() => document.querySelector('trix-editor').editor.getDocument().toString()),original,'linking multiple paragraphs must not merge them');
      assert.equal(await page.locator('trix-editor strong').textContent(),'First');
      assert.equal(await page.locator('trix-editor em').textContent(),'Second');
      for (const tag of ['strong','em']) {
        assert(await page.locator(`trix-editor ${tag}`).evaluate(el => !!(el.closest('a') || el.querySelector('a'))),'selected formatting must retain its link');
      }
      await page.evaluate(() => {window.linkController.disconnect();window.linkController.connect()});
      await button.click();
      assert.equal(await modal.isVisible(),true,'link button must work after reconnect');
      await url.press('Escape');
      await modal.waitFor({state:'hidden'});
      await page.evaluate(() => {
        const svg='data:image/svg+xml,'+encodeURIComponent('<svg xmlns="http://www.w3.org/2000/svg" width="200" height="100"/>');
        const attachment=JSON.stringify({url:svg,contentType:'image/png',filename:'image.png',width:200,height:100,previewable:true});
        document.querySelector('trix-editor').editor.loadHTML(`<figure data-trix-attachment='${attachment}'><img src="${svg}"></figure>`);
      });
      await page.waitForFunction(() => document.querySelector('trix-editor img'));
      await page.evaluate(() => document.querySelector('trix-editor').editor.setSelectedRange([0,1]));
      await page.locator('trix-editor').press('Control+k');
      assert.equal(await modal.isVisible(),false,'keyboard shortcut must respect the disabled image-link button');
      assert.equal(await page.locator('trix-editor img').count(),1,'unsupported link actions must preserve the attachment');
      assert.equal(await page.evaluate(() => window.submissions),0,'link actions must not submit the post');
      assert.deepEqual(errors,[]);
      await page.close();
    }
    console.log('PASS: desktop/mobile link insertion, selection preservation, bold text, editing, removal, validation, Escape, keyboard shortcut, serialization, and no post submission');
  } finally { await browser.close(); }
})().catch(e => {console.error(e);process.exitCode=1});
