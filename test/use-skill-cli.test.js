#!/usr/bin/env node
/**
 * CLI-level regression tests for `superpowers-augment.js use-skill`.
 *
 * Regression guard for the forceSpp/forceSpo scope bug (fixed in
 * hotfix/skill-router-forcespp-scope): `useSkill()` referenced the flags
 * as if they were in its own scope, but they were locals inside
 * `resolveSkillNamespace()`. Any unknown skill name crashed with
 * `Fatal: forceSpp is not defined` before the "not found" / "did you
 * mean" suggestion path could run — stalling agents mid-workflow.
 *
 * Run: node test/use-skill-cli.test.js
 */

'use strict';

const { spawnSync } = require('child_process');
const path = require('path');

const CLI = path.resolve(__dirname, '..', 'superpowers-augment.js');

let pass = 0;
let fail = 0;

function run(args, extraEnv) {
  const env = Object.assign({}, process.env, extraEnv || {});
  const result = spawnSync('node', [CLI, ...args], {
    env,
    encoding: 'utf8',
    timeout: 20000,
  });
  return {
    code: result.status,
    stdout: result.stdout || '',
    stderr: result.stderr || '',
    combined: (result.stdout || '') + (result.stderr || ''),
  };
}

function assert(condition, msg) {
  if (condition) {
    pass++;
    console.log(`  ✅ ${msg}`);
  } else {
    fail++;
    console.log(`  ❌ ${msg}`);
  }
}

function assertContains(haystack, needle, msg) {
  assert(haystack.includes(needle), `${msg} (expected to contain: ${JSON.stringify(needle)})`);
}

function assertNotContains(haystack, needle, msg) {
  assert(!haystack.includes(needle), `${msg} (expected to NOT contain: ${JSON.stringify(needle)})`);
}

console.log('\n--- use-skill: unknown skill name (regression for forceSpp scope bug) ---');
{
  const r = run(['use-skill', 'zzz-nonexistent-skill-xyz']);
  assertNotContains(r.combined, 'forceSpp is not defined',
    'does NOT emit "forceSpp is not defined" on unknown skill');
  assertNotContains(r.combined, 'forceSpo is not defined',
    'does NOT emit "forceSpo is not defined" on unknown skill');
  assertContains(r.combined, 'not found',
    'emits a "not found" error on unknown skill');
  assert(r.code === 1, `exits non-zero on unknown skill (got: ${r.code}, want: 1)`);
}

console.log('\n--- use-skill: unknown spp: prefix (exercises forceSpp branch) ---');
{
  // SPP_SOURCE_DIR must be set for this path to reach the not-found branch
  // rather than the early "SPP_SOURCE_DIR not set" exit.
  const sppDir = process.env.SPP_SOURCE_DIR || path.resolve(__dirname, '..');
  const r = run(['use-skill', 'spp:zzz-nonexistent-skill-xyz'], { SPP_SOURCE_DIR: sppDir });
  assertNotContains(r.combined, 'forceSpp is not defined',
    'does NOT crash on spp: prefix lookup for unknown skill');
  assertContains(r.combined, 'not found',
    'emits "not found" for unknown spp: skill');
  assert(r.code === 1, `exits non-zero (got: ${r.code}, want: 1)`);
}

console.log('\n--- use-skill: known skill still loads ---');
{
  const r = run(['use-skill', 'systematic-debugging']);
  assertNotContains(r.combined, 'forceSpp is not defined',
    'known-skill path does not regress');
  assert(r.code === 0, `exits 0 on known skill (got: ${r.code}, want: 0)`);
  assertContains(r.stdout, '# Skill: systematic-debugging',
    'emits skill header on stdout');
}

console.log('\n--- use-skill: no skill name argument ---');
{
  const r = run(['use-skill']);
  assertContains(r.combined, 'skill name required',
    'reports missing-argument error');
  assert(r.code === 1, `exits 1 on missing argument (got: ${r.code}, want: 1)`);
}

console.log('\n--- use-skill: spo: without SP_OVERLAY_SOURCE_DIR (early-error return shape) ---');
{
  // Regression guard for the return-shape fix: the overlay early-error path
  // previously omitted forceSpp/forceSpo from its return object. Callers that
  // destructure those flags after inspecting .error would have observed
  // undefined instead of documented booleans. The CLI surfaces the early-error
  // message verbatim, so "SP_OVERLAY_SOURCE_DIR not set" appearing without any
  // ReferenceError is proof the early return is now structurally complete.
  const env = Object.assign({}, process.env);
  delete env.SP_OVERLAY_SOURCE_DIR;
  const result = spawnSync('node', [CLI, 'use-skill', 'spo:any-name'], {
    env, encoding: 'utf8', timeout: 20000,
  });
  const combined = (result.stdout || '') + (result.stderr || '');
  assertNotContains(combined, 'forceSpp is not defined',
    'overlay early-error path does not crash with forceSpp ReferenceError');
  assertNotContains(combined, 'forceSpo is not defined',
    'overlay early-error path does not crash with forceSpo ReferenceError');
  assertContains(combined, 'SP_OVERLAY_SOURCE_DIR not set',
    'surfaces the documented early-error message');
}

console.log('\n--- bootstrap: still works ---');
{
  const r = run(['bootstrap']);
  assertNotContains(r.combined, 'forceSpp is not defined',
    'bootstrap does not regress');
  assert(r.code === 0, `bootstrap exits 0 (got: ${r.code}, want: 0)`);
}

console.log(`\n=== Results: ${pass} passed, ${fail} failed ===`);
process.exit(fail === 0 ? 0 : 1);
