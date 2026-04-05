#!/usr/bin/env node
/**
 * Unit tests for lib/workflow-state.js
 * Uses temp directory via WORKFLOW_STATE_FILE env var to avoid polluting real state.
 */
'use strict';

const fs = require('fs');
const path = require('path');
const os = require('os');

// Set up temp directory BEFORE requiring the module
const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'ws-test-'));
const tmpStateFile = path.join(tmpDir, '.workflow-state.json');
process.env.WORKFLOW_STATE_FILE = tmpStateFile;

// Now require — module reads STATE_FILE from env
const ws = require('../lib/workflow-state');

let pass = 0, fail = 0;
function assert(condition, msg) {
    if (condition) { console.log(`  ok: ${msg}`); pass++; }
    else { console.log(`  FAIL: ${msg}`); fail++; }
}

function cleanup() {
    if (fs.existsSync(tmpStateFile)) fs.unlinkSync(tmpStateFile);
    if (fs.existsSync(tmpStateFile + '.lock')) fs.unlinkSync(tmpStateFile + '.lock');
}

// ---- Test 1: initWorkflow creates state ----
cleanup();
const state1 = ws.initWorkflow('feature-development', { triggered_by: 'test' });
assert(state1 !== null, 'initWorkflow returns non-null state');
assert(state1.workflow === 'feature-development', 'initWorkflow sets workflow name');
assert(state1.triggered_by === 'test', 'initWorkflow preserves metadata');
assert(state1.current_phase === 0, 'initWorkflow starts at phase 0');

// ---- Test 2: readState returns persisted state ----
const state2 = ws.readState();
assert(state2 !== null, 'readState returns persisted state');
assert(state2.workflow === 'feature-development', 'readState preserves workflow name');

// ---- Test 3: recordGate records evidence ----
ws.recordGate('lint', { tool: 'shellcheck', exit_code: 0, output: 'all clean' });
const state3 = ws.readState();
assert(state3.gates.lint && state3.gates.lint.passed === true, 'recordGate records gate as passed');
assert(state3.gates.lint.tool === 'shellcheck', 'recordGate records tool name');

// ---- Test 4: canCommit with missing gates ----
const result4 = ws.canCommit();
assert(result4.ready === false, 'canCommit returns not-ready when gates missing');
assert(result4.missing.length > 0, 'canCommit lists missing gates');

// ---- Test 5: canCommit with all gates passed ----
for (const gate of ws.COMMIT_GATES) {
    ws.recordGate(gate, { tool: 'test', exit_code: 0, output: `${gate} passed` });
}
const result5 = ws.canCommit();
assert(result5.ready === true, 'canCommit returns ready when all commit gates passed');
assert(result5.missing.length === 0, 'canCommit has no missing gates');

// ---- Test 6: recordFilesChanged tracks files ----
ws.recordFilesChanged(['file1.js', 'file2.js']);
const state6 = ws.readState();
assert(state6.files_changed.includes('file1.js'), 'recordFilesChanged tracks files');
assert(state6.files_changed.length === 2, 'recordFilesChanged tracks correct count');

// ---- Test 7: recordFilesChanged invalidates completion gates ----
ws.recordGate('code_review', { tool: 'test', exit_code: 0 });
ws.recordFilesChanged(['file3.js']);
const state7 = ws.readState();
assert(state7._files_changed_after_gate && state7._files_changed_after_gate.code_review === true,
    'recordFilesChanged invalidates completion gates after new files');

// ---- Test 8: getStateAgeHours returns correct age ----
const age = ws.getStateAgeHours();
assert(age !== null && age >= 0 && age < 1, 'getStateAgeHours returns reasonable age (<1h)');

// ---- Test 9: archiveState moves state to archive ----
ws.archiveState(ws.readState());
assert(ws.readState() === null, 'archiveState removes active state');
const archiveDir = path.join(path.dirname(tmpStateFile), '.workflow-state-archive');
const archived = fs.readdirSync(archiveDir);
assert(archived.length > 0, 'archiveState creates archive file');

// ---- Test 10: clearWorkflow archives and clears ----
ws.initWorkflow('test-clear', {});
ws.clearWorkflow();
assert(ws.readState() === null, 'clearWorkflow clears active state');

// ---- Test 11: recordSkillInvocation without active state returns null ----
cleanup();
const result11 = ws.recordSkillInvocation('test-skill');
assert(result11 === null, 'recordSkillInvocation returns null without active workflow');

// ---- Test 12: getStatus format ----
ws.initWorkflow('feature-development', {});
const status = ws.getStatus();
assert(status !== null && status.includes('feature-development'), 'getStatus includes workflow name');
assert(status.includes('ADVISORY'), 'getStatus shows advisory mode by default');

// ---- Cleanup ----
cleanup();
try { fs.rmSync(tmpDir, { recursive: true }); } catch { /* ignore */ }

console.log('');
console.log(`=== Results: ${pass} passed, ${fail} failed ===`);
process.exit(fail > 0 ? 1 : 0);
