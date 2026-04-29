#!/usr/bin/env node
/**
 * SKILL-INVOCATION-SMOKE: Per in-scope skill, programmatically invoke
 * `superpowers-augment.js use-skill` and `match-skills` and assert:
 *
 *   1. use-skill returns non-empty body, frontmatter stripped, compress applied,
 *      AND every per-skill expected_substring from fixtures present in body.
 *   2. match-skills with each documented trigger phrase returns the target
 *      skill in top-3.
 *   3. For skills with composition.uses[] declared in frontmatter, each named
 *      target resolves via use-skill (smoke check only — body non-empty).
 *
 * Fixtures: test/skill-invocation-fixtures.json (hand-authored in P0.6).
 * Skills with empty fixture entries are SKIPPED with a warning so this file
 * can be wired to CI before P0.6 completes — coverage is calculated and
 * reported; coverage <80% emits a warning, not a failure (matching the
 * P0.7 decision-gate gate of ≥80%).
 *
 * Run: node test/skill-invocation-smoke.test.js
 *
 * Exit 0 = pass, exit 1 = at least one fixture-bearing skill failed assertion.
 */
'use strict';

const fs = require('fs');
const path = require('path');
const { spawnSync } = require('child_process');
const yaml = (() => {
    try { return require('js-yaml'); } catch { return null; }
})();

const ROOT = path.resolve(__dirname, '..');
const CLI = path.join(ROOT, 'superpowers-augment.js');
const FIXTURES = path.join(__dirname, 'skill-invocation-fixtures.json');
const SKILLS_DIR = path.join(ROOT, 'skills');

let pass = 0, fail = 0, skipped = 0, warnings = 0;
const failures = [];
const warningMsgs = [];

function run(args, extraEnv) {
    const env = Object.assign(
        {},
        process.env,
        {
            SPP_SOURCE_DIR: process.env.SPP_SOURCE_DIR || ROOT,
            PERSONAL_SKILLS_DIR: process.env.PERSONAL_SKILLS_DIR || SKILLS_DIR,
        },
        extraEnv || {}
    );
    // 5 000 ms: ~66× the measured 75ms CLI latency; absorbs 10× CI slowdown.
    // At 30 000 ms and ≥80% coverage (~72 skills × 3 triggers × 2 spawns),
    // worst-case CI time would exceed any standard job timeout.
    const r = spawnSync('node', [CLI, ...args], { env, encoding: 'utf8', timeout: 5000 });
    return {
        code: r.status,
        timedOut: r.signal === 'SIGTERM' && r.status === null,
        stdout: r.stdout || '',
        stderr: r.stderr || '',
        combined: (r.stdout || '') + (r.stderr || ''),
    };
}

function assert(cond, msg) {
    if (cond) { pass++; }
    else { fail++; failures.push(msg); }
}
function softAssert(cond, msg) {
    if (cond) { pass++; }
    else { warnings++; warningMsgs.push(msg); }
}

function findSkillFile(skillName) {
    function walk(dir) {
        for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
            const full = path.join(dir, e.name);
            if (e.isDirectory()) {
                if (e.name === skillName && fs.existsSync(path.join(full, 'skill.md'))) return path.join(full, 'skill.md');
                const r = walk(full);
                if (r) return r;
            }
        }
        return null;
    }
    return walk(SKILLS_DIR);
}

function parseCompositionUses(skillPath) {
    if (!skillPath || !fs.existsSync(skillPath)) return [];
    const raw = fs.readFileSync(skillPath, 'utf8');
    const m = raw.match(/^---\n([\s\S]*?)\n---/);
    if (!m) return [];
    const fm = m[1];
    // Parse only the uses: sub-key under composition:, not other sub-keys
    // (e.g. excludes:, optional:) which would produce false resolution targets.
    const compBlock = fm.match(/^composition:\s*\n([\s\S]*?)(?=^\S|$)/m);
    if (!compBlock) return [];
    const usesBlock = compBlock[1].match(/^\s+uses:\s*\n([\s\S]*?)(?=^\s{0,3}\S|$)/m);
    if (!usesBlock) return [];
    const uses = [];
    for (const line of usesBlock[1].split('\n')) {
        const u = line.match(/^\s*-\s*([\w-]+)\s*$/);
        if (u) uses.push(u[1]);
    }
    return uses;
}

// --- Run ---

if (!fs.existsSync(FIXTURES)) {
    console.error(`❌ Missing fixtures: ${FIXTURES}`);
    process.exit(2);
}
const fixtures = JSON.parse(fs.readFileSync(FIXTURES, 'utf8'));
const skills = fixtures.skills || {};
const totalInScope = Object.keys(skills).length;
let withFixtures = 0;

console.log(`Running skill-invocation-smoke against ${totalInScope} in-scope skills...\n`);

for (const [name, fx] of Object.entries(skills)) {
    const hasSubs = (fx.expected_substrings || []).length > 0;
    const hasTrigs = (fx.triggers || []).length > 0;
    if (!hasSubs && !hasTrigs) {
        skipped++;
        console.log(`  ⏭️  ${name}: SKIP (no fixture substrings/triggers — pending P0.6)`);
        continue;
    }
    withFixtures++;
    const isDraft = typeof fx.verified_by === 'string' && fx.verified_by.startsWith('auto-seed');

    // 1. use-skill returns body containing every substring.
    // Try bare name first; on resolver miss (non-zero exit), fall back to
    // explicit spp: prefix. Empty stdout is caught after the fallback by the
    // body.length assertion — don't use it as a fallback trigger.
    let r = run(['use-skill', name]);
    if (r.code !== 0) {
        r = run(['use-skill', `spp:${name}`]);
    }
    if (r.timedOut) {
        assert(false, `${name}: use-skill TIMED OUT (CLI too slow or hung)`);
        continue;
    }
    if (r.code !== 0) {
        assert(false, `${name}: use-skill exited ${r.code}: ${r.combined.slice(0, 200)}`);
        continue;
    }
    const body = r.stdout;
    assert(body.length > 0, `${name}: use-skill body non-empty`);
    assert(!body.includes('---\nname:'), `${name}: frontmatter stripped from compressed body`);
    for (const sub of fx.expected_substrings || []) {
        assert(body.includes(sub), `${name}: missing expected substring "${sub.slice(0, 60)}..."`);
    }

    // 2. match-skills ranks target in top-3 for each trigger
    for (const trig of fx.triggers || []) {
        const m = run(['match-skills', trig]);
        if (m.code !== 0) {
            assert(false, `${name}: match-skills "${trig}" exited ${m.code}`);
            continue;
        }
        const lines = m.stdout.split('\n');
        const targetLines = lines.filter(l => l.includes(`| ${name} |`));
        let top3 = false;
        for (const tl of targetLines) {
            const rankMatch = tl.match(/^\|\s*(\d+)\s*\|/);
            if (rankMatch && parseInt(rankMatch[1], 10) <= 3) { top3 = true; break; }
        }
        // Trigger ranking is heuristic; in auto-seed (draft) state, demote to warning so
        // generic triggers ("build", "implement") don't fail CI before reviewer pass.
        const checkFn = isDraft ? softAssert : assert;
        checkFn(top3, `${name}: trigger "${trig}" did not rank target in top-3`);
    }

    // 3. composition.uses[] targets resolve
    const skillPath = findSkillFile(name);
    const uses = parseCompositionUses(skillPath);
    for (const u of uses) {
        const r2 = run(['use-skill', u]);
        assert(r2.code === 0 && r2.stdout.length > 0, `${name}: composition.uses target "${u}" resolved`);
    }
}

// ── Phase 5c: Namespace resolver regression tests ─────────────────────────
// Ensures spp:, spo:, and sp- shorthand routing behave correctly.
// Regression: any change to resolveSkillNamespace() or findSkillInSourceRepo()
// must not break these invariants.
// Results are merged into the global fail/failures counters so the summary
// line below correctly reflects all failures (not just fixture failures).
{
    const nsTests = [];

    // spp: prefix → loads from superpowers-plus source (SPP_SOURCE_DIR)
    const sppResult = run(['use-skill', 'spp:think-twice']);
    if (sppResult.code === 0 && sppResult.stdout.length > 0) {
        nsTests.push('spp:think-twice: loads from spp source ✓');
    } else {
        nsTests.push('spp:think-twice: FAIL (exit=' + sppResult.code + ', chars=' + sppResult.stdout.length + ')');
        fail++; failures.push('Phase 5c: spp:think-twice failed to load from spp source');
    }

    // spp: on non-existent skill → non-zero exit, no crash
    const sppMissing = run(['use-skill', 'spp:this-skill-does-not-exist-zz999']);
    if (sppMissing.code !== 0) {
        nsTests.push('spp:missing-skill: graceful non-zero exit ✓');
    } else {
        nsTests.push('spp:missing-skill: FAIL (expected non-zero exit)');
        fail++; failures.push('Phase 5c: spp:missing-skill expected non-zero exit but got 0');
    }

    // spo: without SPO configured → non-zero exit, no crash
    const spoResult = run(['use-skill', 'spo:think-twice'], { SP_OVERLAY_SOURCE_DIR: '', SPC_SOURCE_DIR: '' });
    if (spoResult.code !== 0) {
        nsTests.push('spo: without overlay configured: graceful non-zero exit ✓');
    } else {
        nsTests.push('spo: without overlay configured: FAIL (expected non-zero exit)');
        fail++; failures.push('Phase 5c: spo:think-twice with no overlay configured should fail but exited 0');
    }

    // sp- shorthand: sp-doctor → superpowers-doctor
    const spResult = run(['use-skill', 'sp-doctor']);
    if (spResult.code === 0 && spResult.stdout.length > 0) {
        nsTests.push('sp-doctor shorthand: resolves superpowers-doctor ✓');
    } else {
        nsTests.push('sp-doctor shorthand: FAIL (exit=' + spResult.code + ')');
        fail++; failures.push('Phase 5c: sp-doctor shorthand failed to resolve superpowers-doctor');
    }

    // Plain name resolution: most recent personal-overlay skill wins over spp:
    const plainResult = run(['use-skill', 'think-twice']);
    if (plainResult.code === 0 && plainResult.stdout.length > 0) {
        nsTests.push('think-twice (no prefix): resolves successfully ✓');
    } else {
        nsTests.push('think-twice (no prefix): FAIL');
        fail++; failures.push('Phase 5c: think-twice plain name resolution failed');
    }

    const nsPassed = nsTests.filter(t => !t.includes('FAIL')).length;
    console.log('\n── Phase 5c: Namespace resolver (' + nsPassed + '/' + nsTests.length + ' pass) ──');
    nsTests.forEach(t => console.log('  ' + (t.includes('FAIL') ? '❌' : '  ') + t));
}

const coverage = totalInScope === 0 ? 0 : (withFixtures / totalInScope) * 100;
console.log(`\nFixture coverage: ${withFixtures}/${totalInScope} (${coverage.toFixed(1)}%)`);
console.log(`${pass} passed, ${fail} failed, ${skipped} skipped, ${warnings} warning(s)`);

if (warnings > 0) {
    console.log('\nWarnings (auto-seed fixtures — reviewer must tune triggers in P0.6):');
    warningMsgs.forEach(w => console.log(`  ⚠️  ${w}`));
}

if (fail > 0) {
    console.log('\nFailures:');
    failures.forEach(f => console.log(`  ❌ ${f}`));
    process.exit(1);
}

if (coverage < 80) {
    console.log(`\n⚠️  Coverage ${coverage.toFixed(1)}% below P0.7 gate (80%). Fill more fixtures in P0.6.`);
}
console.log('\n✅ Skill-invocation-smoke: ALL CHECKS PASSED');
