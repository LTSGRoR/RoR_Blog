const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const { chromium } = require(process.argv[2] || 'playwright');

(async () => {
  const browser = await chromium.launch({ headless: true, ...(process.argv[3] ? { executablePath: process.argv[3] } : {}) });
  const snapshots = path.resolve('tmp/account-ui-audit');
  const output = process.env.ACCOUNT_UI_SCREENSHOTS || '/tmp/account-ui-audit';
  fs.mkdirSync(output, { recursive: true });
  try {
    for (const width of [1280, 390]) {
      const page = await browser.newPage({ viewport: { width, height: 900 } });
      const errors = [];
      page.on('pageerror', error => errors.push(error.message));
      // Real controller-rendered HTML from the isolated test DB; app assets
      // load normally. Never submit actions to the development database.
      await page.route('**/*', async route => {
        const request = route.request();
        const url = new URL(request.url());
        if (request.method() !== 'GET') return route.abort();
        if (url.pathname.startsWith('/account-audit/')) {
          const name = path.basename(url.pathname);
          return route.fulfill({ contentType: 'text/html', body: fs.readFileSync(path.join(snapshots, name), 'utf8') });
        }
        if (/\/assets\/tailwind[^/]*\.css$/.test(url.pathname)) {
          return route.fulfill({ contentType: 'text/css', body: fs.readFileSync('app/assets/builds/tailwind.css', 'utf8') });
        }
        return route.continue();
      });
      for (const name of ['banned-comments', 'suspended-comments-en', 'suspended-comments-vi', 'suspended-comments-ja']) {
        await page.goto(`http://localhost:3000/account-audit/${name}.html`, { waitUntil: 'networkidle' });
        assert.equal(await page.getByText('Restricted author original comment', { exact: true }).count(), 0);
        const reply = page.getByText('Other author preserved reply', { exact: true });
        await reply.scrollIntoViewIfNeeded();
        assert(await reply.isVisible());
        const parent = page.locator('article[id^="comment_"]').filter({ has: reply }).first();
        const placeholder = parent.locator(':scope > p');
        assert(await placeholder.isVisible());
        assert((await placeholder.textContent()).trim().length > 0);
        assert.equal(await parent.locator(':scope > .pl-11').count(), 0, 'hidden parent exposes no reactions or reply button');
        const geometry = await parent.evaluate(element => {
          const box = element.getBoundingClientRect();
          return { left: box.left, right: box.right, viewport: innerWidth, overflow: document.documentElement.scrollWidth > innerWidth };
        });
        assert(geometry.left >= 0 && geometry.right <= width + 1, `${name}: thread clips at ${width}px`);
        assert(!geometry.overflow, `${name}: page overflows at ${width}px`);
        const authorLayout = await reply.locator('..').locator('header .flex-1').evaluate(element => {
          const name = element.querySelector('p');
          return { direction: getComputedStyle(element).flexDirection, nameWidth: name.getBoundingClientRect().width };
        });
        if (width < 640) {
          assert.equal(authorLayout.direction, 'column', 'mobile author and timestamp should stack');
          assert(authorLayout.nameWidth > 40, 'author name must have readable space');
        }
        if (name === 'suspended-comments-en') await parent.screenshot({ path: path.join(output, `hidden-thread-${width}.png`) });
      }
      await page.goto('http://localhost:3000/account-audit/restored-comments.html', { waitUntil: 'networkidle' });
      assert(await page.getByText('Restricted author original comment', { exact: true }).isVisible());
      await page.goto('http://localhost:3000/account-audit/admin-users.html', { waitUntil: 'networkidle' });
      for (const action of ['openBan', 'openSuspend']) {
        const trigger = page.locator(`[data-action="click->suspend-form#${action}"]`).first();
        await trigger.click();
        const dialog = page.locator('[role="dialog"]:visible');
        await dialog.waitFor();
        const box = await dialog.boundingBox();
        assert(box.x >= 0 && box.x + box.width <= width + 1);
        assert(box.y >= 0 && box.y + box.height <= 900);
        assert(await dialog.evaluate(element => element.contains(document.activeElement)), 'focus must enter dialog');
        await page.keyboard.press('Shift+Tab');
        assert(await dialog.evaluate(element => element.contains(document.activeElement)), 'keyboard focus must stay inside dialog');
        await dialog.screenshot({ path: path.join(output, `${action}-${width}.png`) });
        await page.keyboard.press('Escape');
        assert.equal(await page.locator('[role="dialog"]:visible').count(), 0);
        assert(await trigger.evaluate(element => element === document.activeElement), 'Escape should restore trigger focus');
      }
      assert.deepEqual(errors, []);
      await page.close();
    }
    console.log('PASS: desktop/mobile hidden threads, restored comments, all locales, dialog layout, focus trapping, Escape and no horizontal overflow');
  } finally { await browser.close(); }
})().catch(error => { console.error(error); process.exit(1); });
