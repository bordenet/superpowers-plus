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
const fs = require('fs');
const os = require('os');
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
  // Hermetic: do not depend on ~/.codex/skills being installed. Walk the
  // repo's domain layout the same way resolveSkillNamespace does for an
  // unprefixed name (personal dir -> findSkillInSourceRepo).
  const repoSkills = path.resolve(__dirname, '..', 'skills');
  const r = run(['use-skill', 'systematic-debugging'], {
    PERSONAL_SKILLS_DIR: repoSkills,
    SUPERPOWERS_SKILLS_DIR: '/dev/null',
  });
  assertNotContains(r.combined, 'forceSpp is not defined',
    'known-skill path does not regress');
  assert(r.code === 0, `exits 0 on known skill (got: ${r.code}, want: 0)`);
  assertContains(r.stdout, '# Skill: systematic-debugging',
    'emits skill header on stdout');
}

console.log('\n--- use-skill: real sibling prompt resource is transformed ---');
{
  const repoRoot = path.resolve(__dirname, '..');
  const r = run([
    'use-skill',
    'spp:subagent-driven-development',
    '--resource',
    'task-reviewer-prompt.md',
  ], {
    SPP_SOURCE_DIR: repoRoot,
    PERSONAL_SKILLS_DIR: '/dev/null',
    SUPERPOWERS_SKILLS_DIR: '/dev/null',
  });
  assert(r.code === 0, `exits 0 on real sibling prompt (got: ${r.code}, want: 0)`);
  assertContains(r.stdout,
    '# Skill Resource: spp:subagent-driven-development/task-reviewer-prompt.md',
    'identifies the rendered skill resource');
  assertContains(r.stdout,
    `# Skill Resource Origin: ${fs.realpathSync(path.join(
      repoRoot,
      'skills/engineering/subagent-driven-development/task-reviewer-prompt.md'))}`,
    'reports the loader-resolved source origin');
  assertContains(r.stdout, 'Controller contract: dispatch the following block.',
    'preserves the affirmative controller-contract marker');
  assertContains(r.stdout, "You are reviewing one task's implementation",
    'renders the real SDD task-reviewer prompt');
  assertContains(r.stdout, 'sub-agent-general-purpose tool:',
    'applies Augment tool transformation to the sibling prompt');
  assertNotContains(r.stdout, 'Subagent (general-purpose):',
    'does not leak the untransformed generic dispatch header');
}

console.log('\n--- use-skill: sibling prompt cannot escape the skill directory ---');
{
  const repoRoot = path.resolve(__dirname, '..');
  const r = run([
    'use-skill',
    'spp:subagent-driven-development',
    '--resource',
    '../requesting-code-review/code-reviewer.md',
  ], {
    SPP_SOURCE_DIR: repoRoot,
    PERSONAL_SKILLS_DIR: '/dev/null',
    SUPERPOWERS_SKILLS_DIR: '/dev/null',
  });
  assert(r.code === 1, `exits 1 on escaping resource path (got: ${r.code}, want: 1)`);
  assertContains(r.combined, 'resource path must stay within the skill directory',
    'rejects resource traversal with a deterministic error');
}

console.log('\n--- use-skill: sibling prompt rejects an absolute resource path ---');
{
  const repoRoot = path.resolve(__dirname, '..');
  const absoluteResource = path.join(
    repoRoot,
    'skills/engineering/subagent-driven-development/task-reviewer-prompt.md');
  const r = run([
    'use-skill',
    'spp:subagent-driven-development',
    '--resource',
    absoluteResource,
  ], {
    SPP_SOURCE_DIR: repoRoot,
    PERSONAL_SKILLS_DIR: '/dev/null',
    SUPERPOWERS_SKILLS_DIR: '/dev/null',
  });
  assert(r.code === 1, `exits 1 on absolute resource path (got: ${r.code}, want: 1)`);
  assertContains(r.combined, 'resource path must be a relative file within the skill directory',
    'rejects an absolute resource path with a deterministic error');
}

console.log('\n--- use-skill: sibling prompt rejects a missing resource file ---');
{
  const repoRoot = path.resolve(__dirname, '..');
  const r = run([
    'use-skill',
    'spp:subagent-driven-development',
    '--resource',
    'missing-reviewer-prompt.md',
  ], {
    SPP_SOURCE_DIR: repoRoot,
    PERSONAL_SKILLS_DIR: '/dev/null',
    SUPERPOWERS_SKILLS_DIR: '/dev/null',
  });
  assert(r.code === 1, `exits 1 on missing resource file (got: ${r.code}, want: 1)`);
  assertContains(r.combined, 'Skill resource not found: missing-reviewer-prompt.md',
    'reports the missing resource file');
}

console.log('\n--- use-skill: sibling prompt rejects a directory resource ---');
{
  const repoRoot = path.resolve(__dirname, '..');
  const r = run([
    'use-skill',
    'spp:subagent-driven-development',
    '--resource',
    'references',
  ], {
    SPP_SOURCE_DIR: repoRoot,
    PERSONAL_SKILLS_DIR: '/dev/null',
    SUPERPOWERS_SKILLS_DIR: '/dev/null',
  });
  assert(r.code === 1, `exits 1 on directory resource (got: ${r.code}, want: 1)`);
  assertContains(r.combined, 'Skill resource is not a file: references',
    'rejects a directory resource with a deterministic error');
}

console.log('\n--- use-skill: sibling prompt rejects a symlink escape ---');
{
  const fixtureRoot = fs.mkdtempSync(path.join(os.tmpdir(), 'augment-resource-'));
  const skillsDir = path.join(fixtureRoot, 'skills');
  const skillDir = path.join(skillsDir, 'fixture-resource-skill');
  const outsideResource = path.join(fixtureRoot, 'outside-prompt.md');
  fs.mkdirSync(skillDir, { recursive: true });
  fs.writeFileSync(path.join(skillDir, 'skill.md'), [
    '---',
    'name: fixture-resource-skill',
    'description: Resource fixture',
    '---',
    '',
    '# Fixture Resource Skill',
    '',
  ].join('\n'));
  fs.writeFileSync(outsideResource, 'Subagent (general-purpose):\n');
  fs.symlinkSync(outsideResource, path.join(skillDir, 'escape.md'));
  try {
    const r = run([
      'use-skill',
      'fixture-resource-skill',
      '--resource',
      'escape.md',
    ], {
      PERSONAL_SKILLS_DIR: skillsDir,
      SUPERPOWERS_SKILLS_DIR: '/dev/null',
    });
    assert(r.code === 1, `exits 1 on symlink escape (got: ${r.code}, want: 1)`);
    assertContains(r.combined, 'resource path must stay within the skill directory',
      'rejects a symlink that resolves outside the skill directory');
  } finally {
    fs.rmSync(fixtureRoot, { recursive: true, force: true });
  }
}

console.log('\n--- use-skill: --resource requires a value ---');
{
  const r = run(['use-skill', 'subagent-driven-development', '--resource']);
  assert(r.code === 1, `exits 1 when --resource has no value (got: ${r.code}, want: 1)`);
  assertContains(r.combined,
    'Usage: node superpowers-augment.js use-skill <name> --resource <relative-path>',
    'reports resource usage when the value is missing');
}

console.log('\n--- use-skill: --resource rejects an extra argument ---');
{
  const r = run([
    'use-skill',
    'subagent-driven-development',
    '--resource',
    'task-reviewer-prompt.md',
    'unexpected',
  ]);
  assert(r.code === 1, `exits 1 on an extra resource argument (got: ${r.code}, want: 1)`);
  assertContains(r.combined,
    'Usage: node superpowers-augment.js use-skill <name> --resource <relative-path>',
    'reports resource usage when an extra argument is present');
}

console.log('\n--- use-skill: installed-layout sibling prompt is transformed ---');
{
  const fixtureRoot = fs.mkdtempSync(path.join(os.tmpdir(), 'augment-installed-resource-'));
  const skillsDir = path.join(fixtureRoot, 'skills');
  const skillDir = path.join(skillsDir, 'fixture-resource-skill');
  fs.mkdirSync(skillDir, { recursive: true });
  fs.writeFileSync(path.join(skillDir, 'skill.md'), [
    '---',
    'name: fixture-resource-skill',
    'description: Installed resource fixture',
    '---',
    '',
    '# Installed Resource Fixture',
    '',
  ].join('\n'));
  fs.writeFileSync(path.join(skillDir, 'reviewer-prompt.md'), [
    'Controller contract: dispatch the following block.',
    'Subagent (general-purpose):',
    '  description: "Installed reviewer"',
    '  model: [MODEL, REQUIRED: choose explicitly]',
    '  prompt: |',
    '    Installed reviewer body.',
    '',
  ].join('\n'));
  try {
    const r = run([
      'use-skill',
      'fixture-resource-skill',
      '--resource',
      'reviewer-prompt.md',
    ], {
      PERSONAL_SKILLS_DIR: skillsDir,
      SUPERPOWERS_SKILLS_DIR: '/dev/null',
    });
    assert(r.code === 0, `exits 0 on installed-layout resource (got: ${r.code}, want: 0)`);
    assertContains(r.stdout,
      '# Skill Resource: fixture-resource-skill/reviewer-prompt.md',
      'identifies the installed-layout resource');
    assertContains(r.stdout,
      `# Skill Resource Origin: ${fs.realpathSync(path.join(skillDir, 'reviewer-prompt.md'))}`,
      'reports the loader-resolved installed origin');
    assertContains(r.stdout, 'sub-agent-general-purpose tool:',
      'transforms the installed-layout sibling prompt');
    assertNotContains(r.stdout, 'Subagent (general-purpose):',
      'does not leak the installed Claude dispatch header');
  } finally {
    fs.rmSync(fixtureRoot, { recursive: true, force: true });
  }
}

console.log('\n--- use-skill: complete resource rejection matrix covers source and installed layouts ---');
{
  const fixtureRoot = fs.mkdtempSync(path.join(os.tmpdir(), 'augment-resource-matrix-'));
  const sourceRoot = path.join(fixtureRoot, 'source');
  const sourceSkillDir = path.join(
    sourceRoot, 'skills', 'engineering', 'fixture-resource-skill');
  const installedSkills = path.join(fixtureRoot, 'installed');
  const installedSkillDir = path.join(installedSkills, 'fixture-resource-skill');

  function createLayout(skillDir, marker) {
    const outsideResource = path.join(path.dirname(skillDir), `${marker}-outside.md`);
    fs.mkdirSync(path.join(skillDir, 'references'), { recursive: true });
    fs.writeFileSync(path.join(skillDir, 'skill.md'), [
      '---',
      'name: fixture-resource-skill',
      `description: ${marker} resource fixture`,
      '---',
      '',
      `# ${marker} Resource Fixture`,
      '',
    ].join('\n'));
    fs.writeFileSync(path.join(skillDir, 'reviewer-prompt.md'), `${marker} REVIEWER PROMPT\n`);
    fs.writeFileSync(outsideResource, `${marker} OUTSIDE PROMPT\n`);
    fs.symlinkSync(outsideResource, path.join(skillDir, 'escape.md'));
  }

  createLayout(sourceSkillDir, 'SOURCE');
  createLayout(installedSkillDir, 'INSTALLED');

  const layouts = [
    {
      label: 'source',
      skill: 'spp:fixture-resource-skill',
      absolute: path.join(sourceSkillDir, 'reviewer-prompt.md'),
      env: {
        SPP_SOURCE_DIR: sourceRoot,
        PERSONAL_SKILLS_DIR: '/dev/null',
        SUPERPOWERS_SKILLS_DIR: '/dev/null',
      },
    },
    {
      label: 'installed',
      skill: 'fixture-resource-skill',
      absolute: path.join(installedSkillDir, 'reviewer-prompt.md'),
      env: {
        PERSONAL_SKILLS_DIR: installedSkills,
        SUPERPOWERS_SKILLS_DIR: '/dev/null',
      },
    },
  ];

  try {
    for (const layout of layouts) {
      const cases = [
        {
          label: 'traversal',
          args: ['use-skill', layout.skill, '--resource', '../outside.md'],
          error: 'resource path must stay within the skill directory',
        },
        {
          label: 'absolute path',
          args: ['use-skill', layout.skill, '--resource', layout.absolute],
          error: 'resource path must be a relative file within the skill directory',
        },
        {
          label: 'missing file',
          args: ['use-skill', layout.skill, '--resource', 'missing.md'],
          error: 'Skill resource not found: missing.md',
        },
        {
          label: 'directory',
          args: ['use-skill', layout.skill, '--resource', 'references'],
          error: 'Skill resource is not a file: references',
        },
        {
          label: 'symlink escape',
          args: ['use-skill', layout.skill, '--resource', 'escape.md'],
          error: 'resource path must stay within the skill directory',
        },
        {
          label: 'missing value',
          args: ['use-skill', layout.skill, '--resource'],
          error: 'Usage: node superpowers-augment.js use-skill <name> --resource <relative-path>',
        },
        {
          label: 'extra argument',
          args: ['use-skill', layout.skill, '--resource', 'reviewer-prompt.md', 'unexpected'],
          error: 'Usage: node superpowers-augment.js use-skill <name> --resource <relative-path>',
        },
      ];

      for (const testCase of cases) {
        const r = run(testCase.args, layout.env);
        assert(r.code === 1,
          `${layout.label} layout rejects ${testCase.label} (got: ${r.code}, want: 1)`);
        assertContains(r.combined, testCase.error,
          `${layout.label} layout reports ${testCase.label}`);
      }
    }
  } finally {
    fs.rmSync(fixtureRoot, { recursive: true, force: true });
  }
}

console.log('\n--- use-skill: real source SDD preserves namespace over divergent installed copy ---');
{
  const fixtureRoot = fs.mkdtempSync(path.join(os.tmpdir(), 'augment-sdd-origin-'));
  const installedSkills = path.join(fixtureRoot, 'installed');
  const installedSdd = path.join(installedSkills, 'subagent-driven-development');
  fs.mkdirSync(installedSdd, { recursive: true });
  fs.writeFileSync(path.join(installedSdd, 'skill.md'), [
    '---',
    'name: subagent-driven-development',
    'description: stale installed fixture',
    '---',
    '',
    '# STALE INSTALLED SDD',
    '',
  ].join('\n'));
  fs.writeFileSync(
    path.join(installedSdd, 'task-reviewer-prompt.md'),
    'STALE INSTALLED REVIEWER PROMPT\n');

  const env = {
    SPP_SOURCE_DIR: path.resolve(__dirname, '..'),
    PERSONAL_SKILLS_DIR: installedSkills,
    SUPERPOWERS_SKILLS_DIR: installedSkills,
  };

  try {
    const skill = run(['use-skill', 'spp:subagent-driven-development'], env);
    assert(skill.code === 0, `source SDD loads (got: ${skill.code}, want: 0)`);
    assertContains(skill.stdout,
      'use-skill spp:subagent-driven-development --resource <prompt-file>',
      'source SDD tells the controller to preserve its namespace');
    assertNotContains(skill.stdout, '# STALE INSTALLED SDD',
      'source SDD does not render the installed skill');

    const resource = run([
      'use-skill',
      'spp:subagent-driven-development',
      '--resource',
      'task-reviewer-prompt.md',
    ], env);
    assert(resource.code === 0,
      `source SDD sibling renders (got: ${resource.code}, want: 0)`);
    assertContains(resource.stdout, "You are reviewing one task's implementation",
      'source SDD renders its source sibling');
    assertContains(resource.stdout,
      `# Skill Resource Origin: ${fs.realpathSync(path.join(
        path.resolve(__dirname, '..'),
        'skills/engineering/subagent-driven-development/task-reviewer-prompt.md'))}`,
      'source SDD reports its source sibling origin');
    assertNotContains(resource.stdout, 'STALE INSTALLED REVIEWER PROMPT',
      'source SDD does not fall back to the divergent installed sibling');
  } finally {
    fs.rmSync(fixtureRoot, { recursive: true, force: true });
  }
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
