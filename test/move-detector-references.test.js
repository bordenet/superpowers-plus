#!/usr/bin/env node
'use strict';

const assert = require('assert');
const fs = require('fs');
const os = require('os');
const path = require('path');
const { spawnSync } = require('child_process');

const ROOT = path.resolve(__dirname, '..');
const EI_DETECTOR = path.join(__dirname, 'ei-move-detector.test.js');
const OP_DETECTOR = path.join(__dirname, 'operative-move-detector.test.js');
const ei = require(EI_DETECTOR);
const operative = require(OP_DETECTOR);
const { DEBUG_CONDUCTOR_HELPERS } = require('../lib/protected-skill-sources');

assert.strictEqual(typeof ei.getProtectedSourcePaths, 'function',
    'EI detector must expose reference-aware source discovery');
assert.strictEqual(typeof ei.extractSkillProtectedBlocks, 'function',
    'EI detector must expose reference-aware protected-block extraction');
assert.strictEqual(typeof operative.getProtectedSourcePaths, 'function',
    'operative detector must expose reference-aware source discovery');
assert.strictEqual(typeof operative.countSkillPatterns, 'function',
    'operative detector must expose reference-aware pattern counting');

const realDebugDir = path.join(ROOT, 'skills', 'engineering', 'debug-conductor');
for (const helperName of DEBUG_CONDUCTOR_HELPERS) {
    const helperPath = path.join(realDebugDir, 'references', helperName);
    const helperBody = fs.readFileSync(helperPath, 'utf8');
    const helperBlocks = ei.extractAllProtectedBlocks(helperBody);
    const helperCounts = operative.countPatterns(helperBody);
    assert(helperBlocks.some(block => block.kind === 'SEC' && block.name === 'Failure Modes'),
        `${helperName} retains a protected Failure Modes protocol`);
    assert(helperCounts.step_headings > 0,
        `${helperName} retains operative step headings`);
    assert(helperCounts.code_fences > 0,
        `${helperName} retains operative fenced evidence/output structure`);
}

const tempRoot = fs.mkdtempSync(path.join(os.tmpdir(), 'move-detector-refs-'));
const skillsDir = path.join(tempRoot, 'skills');
const skillDir = path.join(skillsDir, 'engineering', 'debug-conductor');
const skillPath = path.join(skillDir, 'skill.md');
const siblingReference = path.join(skillDir, 'reference.md');
const nestedReference = path.join(skillDir, 'references', 'timeline-trace-investigator.md');
const eiBaseline = path.join(tempRoot, 'ei-baseline.json');
const opBaseline = path.join(tempRoot, 'operative-baseline.json');

function runDetector(script, args, extraEnv) {
    return spawnSync(process.execPath, [script, ...args], {
        cwd: ROOT,
        env: { ...process.env, ...extraEnv },
        encoding: 'utf8',
    });
}

try {
    fs.mkdirSync(path.dirname(nestedReference), { recursive: true });
    fs.writeFileSync(skillPath, [
        '# Fixture Skill',
        '',
        '## Phase 1: Resident procedure',
        '',
        'Keep the resident procedure.',
        '',
    ].join('\n'));
    fs.writeFileSync(siblingReference, [
        '# Sibling Reference',
        '',
        '<EXTREMELY_IMPORTANT name="reference-safety">',
        'Never bypass the reference-resident safety check.',
        '</EXTREMELY_IMPORTANT>',
        '',
        '## Step 2: Reference procedure',
        '',
        '⛔ Stop when evidence is incomplete.',
        '',
        '| Condition | Action |',
        '|-----------|--------|',
        '| Missing evidence | HARD GATE: halt |',
        '',
        '```bash',
        'printf "reference procedure\\n"',
        '```',
        '',
        '## Failure Modes',
        '',
        '| Failure | Recovery |',
        '|---------|----------|',
        '| Missing proof | Stop |',
        '',
    ].join('\n'));
    fs.writeFileSync(nestedReference, [
        '# Nested Helper',
        '',
        '## Stage 3: Helper procedure',
        '',
        '| Condition | Action |',
        '|-----------|--------|',
        '| Contradiction | MUST investigate |',
        '',
        '```text',
        'nested helper evidence',
        '```',
        '',
        '## Failure Modes',
        '',
        '| Failure | Recovery |',
        '|---------|----------|',
        '| Missing helper evidence | Stop |',
        '',
    ].join('\n'));

    const originalSiblingReference = fs.readFileSync(siblingReference, 'utf8');
    const originalNestedReference = fs.readFileSync(nestedReference, 'utf8');

    const expectedSources = [skillPath, siblingReference, nestedReference];
    assert.deepStrictEqual(ei.getProtectedSourcePaths(skillPath), expectedSources,
        'EI detector discovers skill.md, sibling reference.md, and nested references deterministically');
    assert.deepStrictEqual(operative.getProtectedSourcePaths(skillPath), expectedSources,
        'operative detector uses the same deterministic protected source set');

    const blocks = ei.extractSkillProtectedBlocks(skillPath);
    assert(blocks.some(block => block.kind === 'EI' && block.name === 'reference-safety'),
        'EI block resident in reference.md is protected');
    assert(blocks.some(block => block.kind === 'SEC' && block.name === 'Failure Modes'),
        'protected section resident in reference.md is protected');

    assert.deepStrictEqual(operative.countSkillPatterns(skillPath), {
        step_headings: 3,
        stop_markers: 1,
        hard_gate_table: 2,
        code_fences: 2,
    }, 'reference-resident steps, stop markers, hard gates, and fences are counted');

    let result = runDetector(EI_DETECTOR, ['--update'], {
        EI_MOVE_SKILLS_DIR: skillsDir,
        EI_MOVE_BASELINE_PATH: eiBaseline,
    });
    assert.strictEqual(result.status, 0, result.stderr || result.stdout);

    result = runDetector(OP_DETECTOR, ['--update'], {
        OP_MOVE_SKILLS_DIR: skillsDir,
        OP_MOVE_BASELINE_PATH: opBaseline,
    });
    assert.strictEqual(result.status, 0, result.stderr || result.stdout);

    fs.writeFileSync(siblingReference, '# Sibling Reference\n');

    result = runDetector(EI_DETECTOR, [], {
        EI_MOVE_SKILLS_DIR: skillsDir,
        EI_MOVE_BASELINE_PATH: eiBaseline,
    });
    assert.strictEqual(result.status, 1, 'removing reference-resident EI content must fail closed');
    assert.match(result.stdout, /reference-safety|Failure Modes/);

    result = runDetector(OP_DETECTOR, [], {
        OP_MOVE_SKILLS_DIR: skillsDir,
        OP_MOVE_BASELINE_PATH: opBaseline,
    });
    assert.strictEqual(result.status, 1, 'removing reference-resident operative content must fail closed');
    assert.match(result.stdout, /step_headings/);
    assert.match(result.stdout, /stop_markers/);
    assert.match(result.stdout, /hard_gate_table/);
    assert.match(result.stdout, /code_fences/);

    fs.writeFileSync(siblingReference, originalSiblingReference);
    fs.writeFileSync(nestedReference, '# Nested Helper\n');

    result = runDetector(EI_DETECTOR, [], {
        EI_MOVE_SKILLS_DIR: skillsDir,
        EI_MOVE_BASELINE_PATH: eiBaseline,
    });
    assert.strictEqual(result.status, 1, 'removing a nested helper protocol must fail EI protection');
    assert.match(result.stdout, /Failure Modes/);

    result = runDetector(OP_DETECTOR, [], {
        OP_MOVE_SKILLS_DIR: skillsDir,
        OP_MOVE_BASELINE_PATH: opBaseline,
    });
    assert.strictEqual(result.status, 1, 'removing a nested helper protocol must fail operative protection');
    assert.match(result.stdout, /step_headings/);
    assert.match(result.stdout, /hard_gate_table/);
    assert.match(result.stdout, /code_fences/);

    console.log('move detector reference coverage: all assertions passed');
} finally {
    fs.rmSync(tempRoot, { recursive: true, force: true });
}
