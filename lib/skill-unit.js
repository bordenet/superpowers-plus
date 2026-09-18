#!/usr/bin/env node
/**
 * SKILL-UNIT: read a skill as the unit its loader can actually reach.
 *
 * A kernel-split skill keeps its resident contract in skill.md and moves the
 * rest into a sibling reference.md that skill.md loads on demand via the
 * embedded section loader. Content in reference.md has NOT left the skill --
 * it is still reachable, still executed, still protected.
 *
 * The move detectors (ei-move-detector, operative-move-detector) exist to catch
 * protected content silently leaving the loader's reach. Reading skill.md alone
 * makes every legitimate kernel split look like a deletion, which is both a
 * false positive and -- worse -- pressure to waive a safety gate. Reading the
 * unit keeps the gate honest in both directions: a split passes, but deleting
 * reference.md (or dropping content from it) still drops the counts and fails.
 *
 * Deliberately narrow: only the sibling reference.md counts. Other sibling .md
 * files (reviewer prompts, templates, nested references/) are addressed by path
 * from elsewhere and are not part of this skill's resident+on-demand contract.
 */
'use strict';

const fs = require('fs');
const path = require('path');
const { stripFrontmatter } = require('./frontmatter');

/** Sibling files that a skill.md's own loader can resolve. */
const REFERENCE_BASENAMES = ['reference.md'];

/**
 * Paths making up one skill unit: skill.md first, then any sibling references
 * that exist. Order is stable so concatenated text is deterministic.
 */
function skillUnitPaths(skillPath) {
    const dir = path.dirname(skillPath);
    const paths = [skillPath];
    for (const base of REFERENCE_BASENAMES) {
        const candidate = path.join(dir, base);
        if (fs.existsSync(candidate)) paths.push(candidate);
    }
    return paths;
}

/**
 * Frontmatter-stripped text of the whole skill unit, newline-joined.
 *
 * Each part is stripped individually: reference.md may carry its own
 * frontmatter, and a naive single strip would only handle the first file.
 */
function readSkillUnit(skillPath) {
    return skillUnitPaths(skillPath)
        .map(p => stripFrontmatter(fs.readFileSync(p, 'utf8')))
        .join('\n');
}

module.exports = { readSkillUnit, skillUnitPaths, REFERENCE_BASENAMES };
