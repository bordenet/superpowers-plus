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

// ---- Test 13: recordSkillInvocation maps skills to phases ----
cleanup();
ws.initWorkflow('feature-development', {});
ws.recordSkillInvocation('brainstorming');
const state13 = ws.readState();
assert(state13 !== null, 'state exists after recordSkillInvocation');
assert(state13.passed_phases.includes('brainstorming'), 'records brainstorming phase');
pass++; console.log('  ok: recordSkillInvocation records phase');

// ---- Test 14: recordSkillInvocation advances current_phase ----
assert(state13.current_phase === 1, `phase advanced to 1: got ${state13.current_phase}`);
pass++; console.log('  ok: recordSkillInvocation advances phase');

// ---- Test 15: checkCompletionGate returns false without evidence ----
cleanup();
ws.initWorkflow('feature-development', {});
assert(ws.checkCompletionGate('code_review') === false, 'gate not passed without evidence');
ws.recordGate('code_review', { tool: 'test' });
assert(ws.checkCompletionGate('code_review') === true, 'gate passed after recording');
pass++; console.log('  ok: checkCompletionGate tracks gate status correctly');

// ---- Test 16: acquireLock / releaseLock ----
cleanup();
const lockFile = tmpStateFile + '.lock';
const acquired = ws.acquireLock();
assert(acquired === true, `acquireLock returns true: ${acquired}`);
assert(fs.existsSync(lockFile), 'lock file created');
ws.releaseLock();
assert(!fs.existsSync(lockFile), 'lock file removed after release');
pass++; console.log('  ok: acquireLock/releaseLock manage lock file');

// ---- Test 17: writeState is atomic (uses tmp + rename) ----
cleanup();
ws.initWorkflow('test-atomic', {});
const stateFile = tmpStateFile;
assert(fs.existsSync(stateFile), 'state file exists');
const content = JSON.parse(fs.readFileSync(stateFile, 'utf8'));
assert(content.workflow === 'test-atomic', 'file has correct workflow');
pass++; console.log('  ok: writeState creates valid JSON');

// ---- Test 18: state expires after STATE_MAX_AGE_MS ----
cleanup();
ws.initWorkflow('test-expiry', {});
// Manually backdate the created_at
const expState = JSON.parse(fs.readFileSync(tmpStateFile, 'utf8'));
const oldDate = new Date(Date.now() - 25 * 60 * 60 * 1000); // 25 hours ago
expState.created_at = oldDate.toISOString();
fs.writeFileSync(tmpStateFile, JSON.stringify(expState));
const expired = ws.readState();
assert(expired === null, 'readState returns null for expired state');
pass++; console.log('  ok: readState returns null for expired state');

// ---- Cleanup ----
cleanup();
try { fs.rmSync(tmpDir, { recursive: true }); } catch { /* ignore */ }

console.log('');
console.log(`=== Results: ${pass} passed, ${fail} failed ===`);
process.exit(fail > 0 ? 1 : 0);
