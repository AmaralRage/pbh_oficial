import fs from 'node:fs/promises';
import vm from 'node:vm';
import test from 'node:test';
import assert from 'node:assert/strict';

const source = await fs.readFile(new URL('../web/pbh-push-sw.js', import.meta.url), 'utf8');
test('push click navigates existing app to the post, or opens it when closed', async () => {
  for (const open of [false, true]) {
    const handlers = {}, calls = [];
    const client = { url: 'https://pbh-oficial.vercel.app/?tab=profile', navigate: async url => { calls.push(url); return client; }, focus: async () => calls.push('focus') };
    vm.runInNewContext(source, { URL, self: { location: { origin: 'https://pbh-oficial.vercel.app' }, addEventListener: (name, handler) => handlers[name] = handler },
      clients: { matchAll: async () => open ? [client] : [], openWindow: async url => calls.push(url) } });
    let pending;
    const url = 'https://pbh-oficial.vercel.app/?community_post=bb070000-0000-4000-8000-000000000001';
    handlers.notificationclick({ notification: { close() {}, data: { url } }, waitUntil: promise => pending = promise });
    await pending;
    assert.deepEqual(calls, open ? [url, 'focus'] : [url]);
  }
});
test('unsafe destinations fall back to app and a similarly named origin is not reused', async () => {
  const handlers = {}, calls = [];
  vm.runInNewContext(source, { URL, self: { location: { origin: 'https://pbh-oficial.vercel.app' }, addEventListener: (name, handler) => handlers[name] = handler },
    clients: { matchAll: async () => [{ url: 'https://pbh-oficial.vercel.app.attacker.invalid/', navigate: async () => assert.fail('foreign origin reused') }], openWindow: async url => calls.push(url) } });
  let pending;
  handlers.notificationclick({ notification: { close() {}, data: { url: 'javascript:alert(1)' } }, waitUntil: p => pending = p });
  await pending;
  assert.deepEqual(calls, ['https://pbh-oficial.vercel.app/']);
});
