#!/usr/bin/env node
/**
 * Build a cross-repo override-dependency graph.
 *
 * For each skill name appearing across the given repos, list which repos
 * define it. When a name appears in multiple repos, the LATER repo (in
 * argv order, treated as install/load priority) is the override; earlier
 * is upstream.
 *
 * Critical use: archival in any repo of a skill whose name is overridden
 * downstream MUST be blocked — removing the upstream while a downstream
 * override depends on its loader-discovery position is a silent breakage.
 *
 * Usage:
 *   node tools/override-graph.js <upstream-repo> [<downstream-repo>...]
 *
 * Argv order matters: leftmost = most-upstream, rightmost = most-downstream
 * override priority. Output is JSON to stdout.
 */
'use strict';

const fs = require('fs');
const path = require('path');

function findAllSkills(dir) {
    const out = [];
    if (!fs.existsSync(dir)) return out;
    for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
        if (e.name.startsWith('.')) continue;
        if (e.name === 'node_modules') continue;
        const full = path.join(dir, e.name);
        if (e.isDirectory()) out.push(...findAllSkills(full));
        else if (e.name === 'skill.md') out.push(full);
    }
    return out;
}

function parseFrontmatterName(skillPath) {
    const raw = fs.readFileSync(skillPath, 'utf8');
    const m = raw.match(/^---\n([\s\S]*?)\n---/);
    if (!m) return null;
    const fm = m[1];
    const nm = fm.match(/^name:\s*"?([^"\n]+?)"?\s*$/m);
    if (nm) return nm[1].trim();
    // Fallback to directory name
    return path.basename(path.dirname(skillPath));
}

function main() {
    const repos = process.argv.slice(2);
    if (!repos.length) {
        console.error('Usage: node tools/override-graph.js <upstream-repo> [<downstream-repo>...]');
        process.exit(1);
    }

    const skills = {}; // name -> [{ repo, path }, ...]
    for (const repoRoot of repos) {
        const repoName = path.basename(repoRoot.replace(/\/$/, ''));
        for (const sp of findAllSkills(repoRoot)) {
            const rel = path.relative(repoRoot, sp);
            // Skip _archive/ etc
            if (rel.split(path.sep).some(seg => seg.startsWith('_'))) continue;
            const name = parseFrontmatterName(sp) || path.basename(path.dirname(sp));
            if (!skills[name]) skills[name] = [];
            skills[name].push({ repo: repoName, path: rel });
        }
    }

    const overrides = [];
    const graph = {};
    for (const [name, defs] of Object.entries(skills)) {
        graph[name] = {
            defined_in: defs,
            override_chain: defs.length > 1 ? defs.map(d => d.repo) : null,
            // overridden_by: every entry except the last is overridden by the next
            overridden_by: defs.length > 1 ? defs.slice(1).map(d => d.repo) : [],
            overrides: defs.length > 1 ? defs.slice(0, -1).map(d => d.repo) : [],
        };
        if (defs.length > 1) overrides.push({ name, chain: defs.map(d => d.repo) });
    }

    const out = {
        generated_at: new Date().toISOString(),
        repos: repos.map(r => path.basename(r.replace(/\/$/, ''))),
        argv_order_means: 'leftmost = most-upstream, rightmost = most-downstream override priority',
        total_unique_names: Object.keys(graph).length,
        total_overrides: overrides.length,
        overrides,
        graph,
    };
    process.stdout.write(JSON.stringify(out, null, 2) + '\n');
}

main();
