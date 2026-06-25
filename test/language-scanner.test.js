#!/usr/bin/env node
// Tests for ~/.codex/skills/professional-language-audit/language-scanner.js
// Exit-code contract: 0=PASS, 1=BLOCK (profanity found), 2=USAGE/IO error

'use strict';

const { spawnSync } = require('child_process');
const fs = require('fs');
const os = require('os');
const path = require('path');

const SCANNER = path.join(os.homedir(), '.codex/skills/professional-language-audit/language-scanner.js');
const TMP = fs.mkdtempSync(path.join(os.tmpdir(), 'lang-scan-test-'));

if (!fs.existsSync(SCANNER)) {
    console.error(`SKIP: scanner not installed at ${SCANNER}`);
    process.exit(0);
}

function scan(content) {
    const f = path.join(TMP, `input_${process.hrtime.bigint()}.md`);
    fs.writeFileSync(f, content);
    const r = spawnSync(process.execPath, [SCANNER, f], { encoding: 'utf8' });
    fs.unlinkSync(f);
    return r;
}

let pass = 0, fail = 0;
function assert(label, cond) {
    if (cond) { console.log(`  ✅ ${label}`); pass++; }
    else { console.error(`  ❌ FAIL: ${label}`); fail++; }
}

console.log('=== language-scanner tests ===');

// --- Exit 0: clean content ---
assert('clean prose: exits 0', scan('This is a clean professional document.').status === 0);

assert('technical terms pass: exits 0',
    scan('Run shellcheck on all .sh files before committing.').status === 0);

assert('[F-WORD] allowlist marker: exits 0',
    scan('The incident report used a [F-WORD] expletive.').status === 0);

assert('[REDACTED: reason] marker: exits 0',
    scan('The message contained [REDACTED: profanity].').status === 0);

// --- Exit 1: profanity found ---
let r = scan('This is absolute bullshit.');
assert('S-word in "bullshit": exits 1', r.status === 1);
assert('S-word: stderr has line number', r.stderr.includes('Line'));

r = scan('This fucking sucks.');
assert('F-word: exits 1', r.status === 1);

r = scan('What the hell is going on?');
assert('"hell" standalone: exits 1', r.status === 1);

r = scan('I am so damn frustrated.');
assert('"damn" religious profanity: exits 1', r.status === 1);

r = scan('Use wtf as the variable name.');
assert('wtf internet shorthand: exits 1', r.status === 1);

// --- Exit 2: usage errors ---
r = spawnSync(process.execPath, [SCANNER], { encoding: 'utf8' });
assert('no argument: exits 2', r.status === 2);

r = spawnSync(process.execPath, [SCANNER, '/nonexistent/missing.md'], { encoding: 'utf8' });
assert('non-existent file: exits 2', r.status === 2);

const f1 = path.join(TMP, 'a.md');
const f2 = path.join(TMP, 'b.md');
fs.writeFileSync(f1, 'clean'); fs.writeFileSync(f2, 'clean');
r = spawnSync(process.execPath, [SCANNER, f1, f2], { encoding: 'utf8' });
assert('multiple files: exits 2', r.status === 2);
fs.unlinkSync(f1); fs.unlinkSync(f2);

// --- Normalization: Cyrillic homoglyph evasion caught ---
// 'с' (U+0441 Cyrillic small es) looks like 'c' -- "shiт" with Cyrillic т should be caught
r = scan('shiт happens');  // Cyrillic т (U+0442) at end of "shit"
assert('Cyrillic homoglyph in profanity: exits 1', r.status === 1);

// Cleanup
try { fs.rmSync(TMP, { recursive: true }); } catch (_) {}

console.log(`\nlanguage-scanner: ${pass} passed, ${fail} failed`);
process.exit(fail > 0 ? 1 : 0);
