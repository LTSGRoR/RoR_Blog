const fs = require('node:fs');
const assert = require('node:assert/strict');
const Controller = class {};
const source = fs.readFileSync('app/javascript/controllers/ai_modal_controller.js', 'utf8').replace(/^import .*\n/, '').replace('export default class', 'class AiModalController');
const Klass = eval(source + '\nAiModalController');
const document = { querySelector: () => null };
const requests = [];
let failCreation = false;
let releaseCreation;
const fetch = async (url, options) => {
  requests.push({ url, options });
  if (url === '/chat_sessions') {
    await new Promise(resolve => { releaseCreation = resolve; });
    return { ok: !failCreation, json: async () => ({ id: 42, title: 'New chat' }) };
  }
  return { ok: true, json: async () => ({ id: 99, session_title: 'Hello' }) };
};
function controller() {
  const c = new Klass();
  c.signedInValue = true;
  c.url = '/chat';
  c.sessionsUrlValue = '/chat_sessions';
  c.element = { dataset: { sessionsError: 'Could not create chat' } };
  c.textareaTarget = { value: 'Hello', hasAttribute: () => false };
  c.sessionTitleTarget = {};
  c.hasTextareaTarget = true;
  c.hasSubmitTarget = true;
  c.submitTarget = { setAttribute() {}, classList: { add() {} } };
  c._requestHeaders = () => ({});
  for (const method of ['_renderSessions', '_showChat', '_showSpinner', '_startPendingPoller', '_resize', '_enableSubmit']) c[method] = () => {};
  c._setSubmitDisabled = disabled => { c.disabled = disabled; };
  return c;
}
(async () => {
  const c = controller();
  c._updateSubmitState();
  assert.equal(c.disabled, false, 'typing enables send without a conversation');
  const sending = c.submit();
  await c.submit();
  assert.equal(requests.length, 1, 'double submission creates only one conversation');
  releaseCreation();
  await sending;
  assert.equal(c.activeSessionId, 42);
  assert.deepEqual(JSON.parse(requests[1].options.body), { message: 'Hello', chat_session_id: 42 });
  assert.equal(c.textareaTarget.value, '');
  assert.equal(c.pendingChatId, 99);
  assert.equal(c.sessionTitleTarget.textContent, 'Hello');

  failCreation = true;
  const failed = controller();
  const originalError = console.error;
  console.error = () => {};
  try {
    const sendingFailure = failed.submit();
    releaseCreation();
    await sendingFailure;
  } finally { console.error = originalError; }
  assert.equal(failed.textareaTarget.value, 'Hello', 'failed creation preserves the draft');
  assert.equal(failed._submitting, false);
  assert.equal(requests.length, 3, 'failed creation does not send a message');
  assert.equal(failed.disabled, false, 'failed creation allows retry');
  console.log('PASS: first-message submission creates a conversation, prevents duplicates and preserves drafts on failure');
})();
