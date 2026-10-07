// Run with an installed Playwright module and optional Chromium executable:
// node test/javascript/rich_text_style_parity.cjs /path/to/playwright /path/to/chromium
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const { execFileSync } = require('node:child_process');
const { chromium } = require(process.argv[2] || 'playwright');

(async () => {
  const gem = execFileSync('bundle', ['show', 'action_text-trix'], { encoding: 'utf8' }).trim().split('\n').at(-1);
  const vendorCSS = fs.readFileSync(path.join(gem, 'app/assets/stylesheets/trix.css'), 'utf8');
  const vendorJS = fs.readFileSync(path.join(gem, 'app/assets/javascripts/trix.js'), 'utf8').replace(/<\/script/gi, '<\\/script');
  const alignmentConfig = fs.readFileSync('app/javascript/rich_text_alignment.js', 'utf8').replace(/^import .*\n/, '');
  const contentCSS = fs.readFileSync('app/assets/builds/tailwind.css', 'utf8');
  const browser = await chromium.launch({ headless: true, ...(process.argv[3] ? { executablePath: process.argv[3] } : {}) });
  try {
    const page = await browser.newPage({ viewport: { width: 1400, height: 1200 } });
    const errors = [];
    page.on('pageerror', error => errors.push(error.message));
    const fixture = `<style>${vendorCSS}</style><style>${contentCSS}</style>
      <div class="column prose-trix"><input id="body" type="hidden"><trix-editor input="body" class="border px-2 sm:text-sm"></trix-editor></div>
      <div class="column prose prose-slate text-lg leading-8"><div id="read" class="trix-content"></div></div>
      <script>${vendorJS}\n${alignmentConfig}</script>`;
    await page.setContent(fixture);
    await page.waitForFunction(() => document.querySelector('trix-editor').editor);
    await page.evaluate(() => {
      const svg = 'data:image/svg+xml,' + encodeURIComponent('<svg xmlns="http://www.w3.org/2000/svg" width="200" height="100"><rect width="200" height="100" fill="gray"/></svg>');
      const attachment = JSON.stringify({ url: svg, contentType: 'image/png', filename: 'image.png', width: 200, height: 100, previewable: true });
      document.querySelector('trix-editor').editor.loadHTML(
        '<h1>Heading</h1><div>Normal <strong>bold</strong> <em>italic</em> <del>strike</del> <a href="https://example.com">link</a></div>' +
        '<blockquote>A quote</blockquote><pre>puts "hello"\nlong code line</pre><ul><li>First</li><li>Second</li></ul><ol><li>Numbered</li></ol>' +
        `<figure data-trix-attachment='${attachment}' data-trix-attributes='{"caption":"Centered caption"}'><img src="${svg}" width="200" height="100"><figcaption>Centered caption</figcaption></figure>`
      );
    });
    await page.waitForFunction(() => document.querySelector('#body').value.includes('Centered caption'));
    const differences = await page.evaluate(async () => {
      const editor = document.querySelector('trix-editor');
      const reader = document.querySelector('#read');
      reader.innerHTML = document.querySelector('#body').value;
      await Promise.all([...document.images].map(image => image.decode().catch(() => {})));
      const selectors = ['h1', 'strong', 'em', 'del', 'a', 'blockquote', 'pre', 'ul', 'ol', 'li', 'figure.attachment', 'img', 'figcaption'];
      const properties = ['fontFamily', 'fontSize', 'fontWeight', 'fontStyle', 'lineHeight', 'color', 'backgroundColor', 'borderTopWidth', 'borderTopColor', 'borderLeftWidth', 'borderLeftColor', 'borderRadius', 'paddingTop', 'paddingRight', 'paddingBottom', 'paddingLeft', 'marginTop', 'marginRight', 'marginBottom', 'marginLeft', 'whiteSpace', 'overflowWrap', 'listStyleType', 'textDecorationLine', 'textAlign', 'display'];
      const differences = [];
      for (const width of [640, 320]) {
        document.querySelectorAll('.column').forEach(element => { element.style.width = `${width}px`; });
        for (const selector of selectors) {
          const edit = editor.querySelector(selector), read = reader.querySelector(selector);
          if (!edit || !read) { differences.push({ width, selector, error: 'missing element' }); continue; }
          const a = getComputedStyle(edit), b = getComputedStyle(read);
          for (const property of properties) {
            if (a[property] !== b[property]) differences.push({ width, selector, property, edit: a[property], read: b[property] });
          }
          if (edit.getBoundingClientRect().width !== read.getBoundingClientRect().width) differences.push({ width, selector, error: 'width differs' });
        }
      }
      return differences;
    });
    assert.deepEqual(errors, [], 'browser errors');
    assert.deepEqual(differences, [], 'editor and reader styles must match');
    await page.addStyleTag({ content: '.token.keyword { color: #cc99cd; } .token.comment { color: #999; }' });
    await page.evaluate(() => {
      document.querySelector('#read pre').innerHTML = '<code class="language-ruby"><span class="token keyword">puts</span> <span class="token comment"># comment</span></code>';
    });
    const codeColors = await page.evaluate(() => ({
      editor: getComputedStyle(document.querySelector('trix-editor pre')).color,
      reader: [...document.querySelectorAll('#read pre .token')].map(token => getComputedStyle(token).color),
      background: getComputedStyle(document.querySelector('#read pre')).backgroundColor
    }));
    assert.deepEqual(codeColors.reader, [codeColors.editor, codeColors.editor], 'saved syntax tokens should match plain editor text');
    assert.equal(codeColors.background, 'rgb(241, 245, 249)', 'use the original light code panel');
    const controllerSource = fs.readFileSync('app/javascript/controllers/image_size_controller.js', 'utf8')
      .replace(/^import .*\n/, '').replace('export default class', 'window.ImageSizeController = class');
    await page.addScriptTag({ content: 'const Controller = class {};\n' + controllerSource });
    const controls = fs.readFileSync('app/views/shared/_image_size_controls.html.erb', 'utf8')
      .replace(/<%=.*?%>/g, 'Resize image');
    await page.evaluate(controls => {
      const wrapper = document.querySelector('.prose-trix');
      wrapper.insertAdjacentHTML('beforeend', controls);
      const c = new window.ImageSizeController();
      Object.assign(c, { element: wrapper, editorTarget: wrapper.querySelector('trix-editor'),
        controlsTarget: wrapper.querySelector('[data-image-size-target="controls"]'),
        handleTarget: wrapper.querySelector('[data-image-size-target="handle"]') });
      c.editorTarget.addEventListener('click', event => c.select(event));
      c.editorTarget.addEventListener('trix-change', () => c.refresh());
      c.editorTarget.addEventListener('trix-selection-change', () => c.selectionChanged());
      for (const [event, method] of Object.entries({ pointerdown: 'startDrag', pointermove: 'moveDrag', pointerup: 'endDrag', pointercancel: 'cancelDrag', lostpointercapture: 'cancelDrag', keydown: 'keyResize' })) {
        c.handleTarget.addEventListener(event, e => c[method](e));
      }
      c.connect();
      window.imageResizer = c;
    }, controls);
    await page.locator('trix-editor img').click();
    const handle = page.locator('.image-resize-handle');
    await handle.waitFor({ state: 'visible' });
    await page.waitForTimeout(100);
    const corner = await handle.boundingBox();
    const startWidth = await page.evaluate(() => window.imageResizer.attachment.getAttribute('width'));
    await page.mouse.move(corner.x + corner.width / 2, corner.y + corner.height / 2);
    await page.mouse.down();
    await page.mouse.move(corner.x + corner.width / 2 + 60, corner.y + corner.height / 2 + 30, { steps: 5 });
    await page.mouse.up();
    const resized = await page.evaluate(() => window.imageResizer.attachment.getAttributes());
    assert(resized.width > startWidth, 'real pointer dragging should enlarge the selected image');
    assert.equal(resized.height, Math.round(resized.width / 2), 'browser drag should preserve proportions');
    await page.waitForFunction(width => {
      const parsed = new DOMParser().parseFromString(document.querySelector('#body').value, 'text/html');
      const figure = parsed.querySelector('figure[data-trix-attachment]');
      return JSON.parse(figure.dataset.trixAttachment).width === width;
    }, resized.width);

    for (const direction of ['center', 'right']) {
      await page.evaluate(direction => {
        const c=window.imageResizer;
        c.image.closest('figure').parentElement.className='rt-align-'+direction;
        c.refresh();
      }, direction);
      await page.waitForTimeout(50);
      const before=await page.evaluate(()=>window.imageResizer.attachment.getAttribute('width'));
      const corner=await handle.boundingBox();
      await page.mouse.move(corner.x+corner.width/2,corner.y+corner.height/2);
      await page.mouse.down();
      await page.mouse.move(corner.x+corner.width/2+20,corner.y+corner.height/2+10,{steps:3});
      await page.mouse.up();
      const after=await page.evaluate(()=>window.imageResizer.attachment.getAttribute('width'));
      assert(after>before,`${direction}-aligned images must be able to grow`);
    }

    const screenshot = process.env.EDITOR_AUDIT_SCREENSHOT || process.argv[4];
    if (screenshot) {
      await page.screenshot({ path: screenshot, fullPage: true });
    }
    const longCaption = await page.evaluate(() => {
      const caption = document.querySelector('#read figcaption');
      caption.textContent = 'A long caption that should stay centered below its image. '.repeat(8);
      const figure = caption.closest('figure');
      const image = figure.querySelector('img');
      return { caption: caption.getBoundingClientRect().width, image: image.getBoundingClientRect().width };
    });
    assert.equal(longCaption.caption, longCaption.image, 'long captions should not widen the image container');

    const mobile = await browser.newPage({ viewport: { width: 360, height: 900 }, isMobile: true, hasTouch: true });
    await mobile.setContent(fixture);
    await mobile.waitForFunction(() => document.querySelector('trix-editor').editor);
    await mobile.evaluate(() => document.querySelectorAll('.column').forEach(element => { element.style.width = '280px'; }));
    const toolbar = await mobile.evaluate(() => ({
      buttonSizes: [...document.querySelectorAll('trix-toolbar .trix-button-row .trix-button')].map(button => {
        const rect = button.getBoundingClientRect(); return { width: rect.width, height: rect.height };
      }),
      overflow: document.querySelector('trix-toolbar').scrollWidth > document.querySelector('trix-toolbar').clientWidth
    }));
    assert.equal(toolbar.overflow, false, 'mobile toolbar should wrap without horizontal scrolling');
    assert(toolbar.buttonSizes.every(size => size.width >= 36 && size.height >= 36), 'compact touch toolbar controls need 36px targets');
    await mobile.locator('[data-trix-action="link"]').click();
    await mobile.locator('.trix-input--dialog').focus();
    const dialog = await mobile.locator('.trix-input--dialog').evaluate(input => ({
      focus: getComputedStyle(input).outlineStyle,
      width: input.getBoundingClientRect().width,
      toolbarOverflow: getComputedStyle(input.closest('trix-toolbar')).overflowX
    }));
    assert.equal(dialog.focus, 'solid', 'link input needs a visible focus indicator');
    assert(dialog.width > 0, 'link dialog input must be visible');
    assert.equal(dialog.toolbarOverflow, 'visible', 'link dialog must not be clipped');
    await mobile.close();
    console.log('PASS: editor and reader formatting, code colors, captions, and widths match at 640px and 320px');
    console.log('PASS: long captions, mobile toolbar wrapping, touch targets, and link-dialog focus');
    console.log('PASS: real pointer image resizing updates serialized rich text');
  } finally {
    await browser.close();
  }
})().catch(error => { console.error(error); process.exitCode = 1; });
