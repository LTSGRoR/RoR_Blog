const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const { execFileSync } = require('node:child_process');
const { chromium } = require(process.argv[2] || 'playwright');

(async () => {
  const gem = execFileSync('bundle', ['show', 'action_text-trix'], { encoding: 'utf8' }).trim().split('\n').at(-1);
  const asset = fs.readFileSync(path.join(gem, 'app/assets/javascripts/trix.js'), 'utf8');
  const config = fs.readFileSync('app/javascript/rich_text_alignment.js', 'utf8');
  const translations = JSON.parse(execFileSync('ruby', ['-ryaml', '-rjson', '-e', 'puts YAML.load_file("config/locales/editor_ui.yml").to_json'], { encoding: 'utf8' }));
  const dataURL = source => 'data:text/javascript;base64,' + Buffer.from(source).toString('base64');
  const browser = await chromium.launch({ headless: true, ...(process.argv[3] ? { executablePath: process.argv[3] } : {}) });
  try {
    const page = await browser.newPage();
    const errors = [];
    page.on('pageerror', error => errors.push(error.message));
    await page.setContent(`<meta name="editor-translations" content="{}">
      <script type="importmap">${JSON.stringify({ imports: { trix: dataURL(asset) } })}</script>
      <script type="module">import ${JSON.stringify(dataURL(config))};window.ready=true;</script>`);
    await page.waitForFunction(() => window.ready);
    // Simulate Turbo navigation: new locale and editor, same loaded JS module.
    for (const locale of ['en', 'vi', 'ja']) {
      const actual = await page.evaluate(async lang => {
        document.querySelector('trix-editor')?.remove();
        document.querySelectorAll('trix-toolbar').forEach(toolbar => toolbar.remove());
        document.querySelector('meta[name="editor-translations"]').content = JSON.stringify(lang);
        const element = document.createElement('trix-editor');
        document.body.append(element);
        await new Promise(resolve => element.addEventListener('trix-initialize', resolve, { once: true }));
        element.editor.insertHTML('<figure data-trix-attachment=\'{"contentType":"image/png","url":"https://example.com/image.png","width":100,"height":100}\'></figure>');
        return {
          bold: element.toolbarElement.querySelector('[data-trix-attribute="bold"]').title,
          attach: element.toolbarElement.querySelector('[data-trix-action="attachFiles"]').title,
          caption: element.querySelector('figcaption').getAttribute('data-trix-placeholder')
        };
      }, translations[locale].editor_trix);
      assert.deepEqual(actual, {
        bold: translations[locale].editor_trix.bold,
        attach: translations[locale].editor_trix.attachFiles,
        caption: translations[locale].editor_trix.captionPlaceholder
      });
    }
    assert.deepEqual(errors, []);
    console.log('PASS: toolbar and image captions follow English, Vietnamese, and Japanese, including locale navigation');
  } finally { await browser.close(); }
})().catch(error => { console.error(error); process.exit(1); });
