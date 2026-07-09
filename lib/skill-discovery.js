/**
 * lib/skill-discovery.js — Unified skill discovery and deduplication
 *
 * Single source of truth for:
 *   - findSkillsInDir()  — recursive skill directory scanner
 *   - deduplicateSkills() — combine + dedup skills by name
 *   - findAllSkills()     — multi-source aggregator
 *
 * Used by: superpowers-augment.js, mcp/superpowers-mcp.js
 * Depends on: lib/frontmatter.js (extractFrontmatter, findSkillFile)
 */
'use strict';

const fs = require('fs');
const path = require('path');
const { extractFrontmatter, findSkillFile, validateFrontmatter } = require('./frontmatter');

/**
 * Scan a directory for skills, building metadata for each.
 * Handles both flat (skills/{name}/skill.md) and domain-grouped
 * (skills/{domain}/{name}/skill.md) layouts by recursing into
 * subdirectories that don't contain skill.md.
 *
 * @param {string} dir - Directory to scan
 * @param {string} sourceType - 'personal' or 'superpowers'
 * @returns {Array<Object>} Array of skill metadata objects
 */
function findSkillsInDir(dir, sourceType, visitedRealDirs = new Set()) {
    const skills = [];
    if (!fs.existsSync(dir)) return skills;

    // Guard against symlink cycles (e.g. a domain dir symlinked into an
    // ancestor, or two domain dirs symlinked into each other). Without this,
    // recursion regrows the path string every level: it eventually fails
    // with ENAMETOOLONG once the rebuilt path exceeds the OS path limit, but
    // a cycle between two sibling directories has no such natural backstop
    // and can run for a very long time before that happens.
    let realDir;
    try {
      realDir = fs.realpathSync(dir);
    } catch (err) {
      // ENOENT/ELOOP mean "nothing usable here" -- same as the pre-existing
      // readdirSync catch below. Anything else (EACCES, EIO, ...) is a real
      // problem distinct from "doesn't exist" and worth surfacing, matching
      // the frontmatter-validation warning convention a few lines down.
      if (err.code !== 'ENOENT' && err.code !== 'ELOOP') {
        process.stderr.write(`[skill-discovery] ⚠ realpath failed for ${dir}: ${err.code}\n`);
      }
      return skills;
    }
    if (visitedRealDirs.has(realDir)) return skills;
    visitedRealDirs.add(realDir);

    let entries;
    try { entries = fs.readdirSync(dir, { withFileTypes: true }); }
    catch { return skills; }

    for (const entry of entries) {
        // Skip support directories (_shared, _archive, _adapters, etc.)
        if (entry.name.startsWith('_') || entry.name.startsWith('.')) continue;

        const skillDir = path.join(dir, entry.name);

        // Handle both directories and symlinks to directories
        let isDir = entry.isDirectory();
        if (!isDir && entry.isSymbolicLink()) {
            try { isDir = fs.statSync(skillDir).isDirectory(); }
            catch (err) {
                if (err.code === 'ENOENT' || err.code === 'ELOOP') continue;
                throw err;
            }
        }
        if (!isDir) continue;

        const skillFile = findSkillFile(skillDir);
        if (skillFile) {
            const meta = extractFrontmatter(skillFile);
            // Validate frontmatter schema and warn on malformed metadata
            const warnings = validateFrontmatter(meta, skillFile);
            if (warnings.length > 0) {
                process.stderr.write(`[skill-discovery] ⚠ ${entry.name}: ${warnings.join('; ')}\n`);
            }
            const hasTriggers = meta.triggers && meta.triggers.length > 0;
            const fileSize = fs.statSync(skillFile).size;
            skills.push({
                name: meta.name || entry.name,
                dirName: entry.name,
                description: meta.description || '',
                triggers: meta.triggers || [],
                anti_triggers: meta.anti_triggers || [],
                aliases: meta.aliases || [],
                composition: meta.composition || null,
                coordination: meta.coordination || null,
                source: meta.source || '',
                overrides: meta.overrides || '',
                summary: meta.summary || '',
                compress: meta.compress,
                isSuperpower: hasTriggers,
                sourceType,
                skillFile,
                skillDir,
                tokens: Math.round(fileSize / 4)  // ~4 chars per token approximation
            });
        } else {
            // Recurse for domain-grouped layouts: skills/{domain}/{name}/skill.md
            skills.push(...findSkillsInDir(skillDir, sourceType, visitedRealDirs));
        }
    }
    return skills;
}

/**
 * Deduplicate skills by name. First occurrence wins (personal before superpowers).
 *
 * @param {Array<Object>} skills - Array of skill objects
 * @returns {Array<Object>} Deduplicated array
 */
function deduplicateSkills(skills) {
    const seen = new Set();
    return skills.filter(s => {
        if (seen.has(s.name)) return false;
        seen.add(s.name);
        return true;
    });
}

/**
 * Discover all skills across personal and superpowers directories.
 * Personal skills override superpowers skills with the same name.
 *
 * @param {string} personalDir - Personal skills directory
 * @param {string} superpowersDir - Superpowers skills directory
 * @returns {Array<Object>} Deduplicated array of all skills
 */
function findAllSkills(personalDir, superpowersDir) {
    const personalSkills = findSkillsInDir(personalDir, 'personal');
    const superpowersSkills = findSkillsInDir(superpowersDir, 'superpowers');
    return deduplicateSkills([...personalSkills, ...superpowersSkills]);
}

module.exports = {
    findSkillsInDir,
    deduplicateSkills,
    findAllSkills,
};
