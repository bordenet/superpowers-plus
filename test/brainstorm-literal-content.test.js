'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs/promises');
const os = require('node:os');
const path = require('node:path');
const { spawn } = require('node:child_process');
const { once } = require('node:events');

test('visual companion preserves literal replacement tokens in supplied HTML', async (t) => {
  const dir = await fs.mkdtemp(path.join(os.tmpdir(), 'brainstorm-literal-'));
  const child = spawn(process.execPath, [path.join(__dirname,
    '../skills/engineering/brainstorming/scripts/server.cjs')], {
    env: { ...process.env, BRAINSTORM_DIR: dir, BRAINSTORM_HOST: '127.0.0.1',
      BRAINSTORM_PORT: '', BRAINSTORM_OWNER_PID: '' },
    stdio: ['ignore', 'pipe', 'pipe'],
  });
  const exited = once(child, 'exit');
  t.after(async () => {
    child.kill('SIGTERM');
    await exited;
    await fs.rm(dir, { recursive: true, force: true });
  });
  let errors = '';
  child.stderr.on('data', chunk => { errors += chunk; });
  const started = await new Promise((resolve, reject) => {
    const timer = setTimeout(() => reject(new Error(`Server did not start: ${errors}`)), 5000);
    let buffer = '';
    child.once('error', error => { clearTimeout(timer); reject(error); });
    child.once('exit', () => { clearTimeout(timer); reject(new Error(`Server exited: ${errors}`)); });
    child.stdout.on('data', chunk => {
      buffer += chunk;
      for (const line of buffer.split('\n')) {
        try {
          const value = JSON.parse(line);
          if (value.type === 'server-started') { clearTimeout(timer); resolve(value); }
        } catch { /* Other server messages are not startup records. */ }
      }
    });
  });
  const content = "<section>Literal: $& $$ $' $` $1</section>";
  await fs.writeFile(path.join(dir, 'content/screen.html'), content);
  const unkeyed = await fetch(`http://127.0.0.1:${started.port}/`);
  assert.equal(unkeyed.status, 403, 'requests without the session key must be rejected');
  await unkeyed.body?.cancel();
  // The keyed URL serves a bootstrap page and sets the session cookie, as a browser sees it.
  const keyed = await fetch(started.url, { redirect: 'manual' });
  const cookie = (keyed.headers.get('set-cookie') || '').split(';')[0];
  await keyed.body?.cancel();
  assert.ok(cookie, 'keyed URL must set the session cookie');
  const response = await fetch(`http://127.0.0.1:${started.port}/`, { headers: { cookie } });
  assert.equal(response.status, 200);
  const html = await response.text();
  assert.ok(html.includes(content), 'served fragment must preserve every supplied character');
});
