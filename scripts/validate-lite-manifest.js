#!/usr/bin/env node
'use strict';

// Source-only validation: scripts/ is not deployed by the Full installer.
// Full installation does not consult this manifest. Hosts map to destination
// names when an entry is selected. Unreferenced source entries default to
// on-demand, retaining the complete store without copying its entire catalog.
// Selection policy is not a complete installed-file ownership ledger.
const fs = require('node:fs');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

const SOURCE_ROOT = path.resolve(__dirname, '..');
const HOSTS = Object.freeze(['claude-code', 'augment', 'codex']);
const CORE = Object.freeze([
    'using-superpowers', 'push-authorization-gate', 'merge-authorization-gate',
    'unified-commit-gate', 'branch-sync-gate', 'superpowers-doctor',
    'systematic-debugging', 'verification-before-completion',
]);
// Canonical core metadata only; helpers and native host framing are separate.
// A manifest cannot increase the approved tighter listing ceiling.
const CORE_METADATA_MAX_BYTES = 3000;
const SLUG = /^[a-z0-9][a-z0-9-]*$/;

class ValidationError extends Error {}

function invalid(message) {
    throw new ValidationError(message);
}

function object(value, label) {
    if (!value || typeof value !== 'object' || Array.isArray(value)) {
        invalid(`${label} must be an object`);
    }
}

function fields(value, allowed, label) {
    object(value, label);
    for (const key of Object.keys(value)) {
        if (!allowed.includes(key)) invalid(`${label}: unknown field ${key}`);
    }
    for (const key of allowed) {
        if (!Object.hasOwn(value, key)) invalid(`${label}: missing field ${key}`);
    }
}

function metadataBytes(entries) {
    if (!Array.isArray(entries)) invalid('metadata entries must be an array');
    return entries.reduce((total, entry) => {
        if (typeof entry.name !== 'string' || typeof entry.description !== 'string') {
            invalid('metadata name and description must be decoded strings');
        }
        return total + Buffer.byteLength(entry.name + entry.description, 'utf8');
    }, 0);
}

function inventory(repoRoot) {
    const paths = [];
    function walk(directory) {
        const stat = fs.lstatSync(directory);
        if (stat.isSymbolicLink()) invalid(`source symlink is not allowed: ${directory}`);
        if (!stat.isDirectory()) invalid(`source directory is missing: ${directory}`);
        for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
            const file = path.join(directory, entry.name);
            if (entry.isSymbolicLink()) invalid(`source symlink is not allowed: ${file}`);
            if (entry.isDirectory()) walk(file);
            else if (entry.isFile() && entry.name.toLowerCase() === 'skill.md') paths.push(file);
        }
    }
    walk(path.join(repoRoot, 'skills'));
    paths.sort();
    if (!paths.length) invalid('source skill inventory is empty');
    // Reuse the existing 64-KiB bounded reader and canonical parser. No second
    // YAML parser, payload edits, or duplicated frontmatter-reading algorithm.
    const result = spawnSync(process.execPath,
        [path.join(SOURCE_ROOT, 'tools/frontmatter-batch.js')], {
            input: JSON.stringify(paths), encoding: 'utf8', maxBuffer: 8 * 1024 * 1024,
        });
    if (result.error) throw result.error;
    if (result.status !== 0) invalid(`frontmatter reader failed: ${result.stderr.trim()}`);
    let batch;
    try { batch = JSON.parse(result.stdout); } catch { invalid('invalid frontmatter reader response'); }
    if (batch.schema_version !== 1 || !Array.isArray(batch.results) || batch.results.length !== paths.length) {
        invalid('incomplete frontmatter reader response');
    }
    const entries = new Map();
    batch.results.forEach((row, index) => {
        if (row.path !== paths[index] || row.error || !row.frontmatter) {
            invalid(`invalid frontmatter: ${paths[index]}: ${row.error || 'missing metadata'}`);
        }
        const { name, description } = row.frontmatter;
        if (typeof name !== 'string' || !SLUG.test(name) ||
                typeof description !== 'string' || !description.trim()) {
            invalid(`invalid source metadata: ${paths[index]}`);
        }
        if (entries.has(name)) invalid(`duplicate canonical source name: ${name}`);
        entries.set(name, { name, description, path: path.relative(repoRoot, paths[index]).split(path.sep).join('/') });
    });
    return entries;
}

function validateManifest(manifest, { repoRoot = SOURCE_ROOT } = {}) {
    fields(manifest, ['schema_version', 'default_tier', 'skills'], 'manifest');
    if (manifest.schema_version !== 1) invalid('schema_version must be 1');
    if (manifest.default_tier !== 'on-demand') invalid('default_tier must be on-demand');
    if (!Array.isArray(manifest.skills) || !manifest.skills.length) invalid('skills must be a nonempty array');
    const names = new Set();
    const sourcePaths = new Set();
    const destinations = new Map(HOSTS.map(host => [host, new Set()]));
    const sharedDestinations = new Map();
    for (const entry of manifest.skills) {
        fields(entry, ['name', 'path', 'tier', 'hosts'], 'skill');
        if (typeof entry.name !== 'string' || !SLUG.test(entry.name)) invalid('invalid canonical skill name');
        if (names.has(entry.name)) invalid(`duplicate canonical name: ${entry.name}`);
        names.add(entry.name);
        if (typeof entry.path !== 'string' || !/^skills\/(?:[a-zA-Z0-9_-]+\/)+(?:skill|SKILL)\.md$/.test(entry.path)) {
            invalid(`invalid source path: ${entry.path}`);
        }
        if (sourcePaths.has(entry.path)) invalid(`duplicate source path: ${entry.path}`);
        sourcePaths.add(entry.path);
        if (!['core', 'on-demand'].includes(entry.tier)) invalid(`invalid tier for ${entry.name}`);
        object(entry.hosts, `hosts for ${entry.name}`);
        if (!Object.keys(entry.hosts).length) invalid(`no hosts for ${entry.name}`);
        for (const [host, destination] of Object.entries(entry.hosts)) {
            if (!HOSTS.includes(host)) invalid(`unknown host: ${host}`);
            if (typeof destination !== 'string' || !SLUG.test(destination)) {
                invalid(`invalid destination for ${entry.name} on ${host}`);
            }
            if (destinations.get(host).has(destination)) invalid(`duplicate destination on ${host}: ${destination}`);
            destinations.get(host).add(destination);
            if (host === 'augment' || host === 'codex') {
                const owner = sharedDestinations.get(destination);
                if (owner && owner !== entry.name) invalid(`duplicate destination on shared root: ${destination}`);
                sharedDestinations.set(destination, entry.name);
            }
        }
        if (entry.hosts.augment && entry.hosts.codex && entry.hosts.augment !== entry.hosts.codex) {
            invalid(`shared root destination must agree for Augment and Codex: ${entry.name}`);
        }
        if (entry.tier === 'core' && HOSTS.some(host => !Object.hasOwn(entry.hosts, host))) {
            invalid(`core entry must select every supported host: ${entry.name}`);
        }
    }
    const source = inventory(path.resolve(repoRoot));
    for (const entry of manifest.skills) {
        if (source.get(entry.name)?.path !== entry.path) invalid(`source path does not match metadata: ${entry.name}`);
    }
    const core = manifest.skills.filter(entry => entry.tier === 'core');
    if (core.length !== CORE.length || CORE.some(name => !core.some(entry => entry.name === name))) {
        invalid('core set must match interface v2 exactly');
    }
    const bytes = metadataBytes(core.map(entry => source.get(entry.name)));
    if (bytes > CORE_METADATA_MAX_BYTES) {
        invalid(`core metadata ${bytes} B exceeds ${CORE_METADATA_MAX_BYTES} B`);
    }
    return {
        schema_version: 1, skill_count: source.size, manifest_entry_count: manifest.skills.length,
        core_count: core.length, on_demand_count: source.size - core.length, default_tier: manifest.default_tier,
        core_metadata_bytes: bytes, core_metadata_max_bytes: CORE_METADATA_MAX_BYTES,
        metric: 'UTF-8 canonical name plus decoded description; no host framing or helpers',
    };
}

function main(args) {
    let repoRoot = SOURCE_ROOT;
    let manifestPath;
    let verbose = false;
    for (let i = 0; i < args.length; i++) {
        const arg = args[i];
        if (arg === '--help' || arg === '-h') {
            console.log('Usage: node scripts/validate-lite-manifest.js [--repo-root PATH] [--manifest FILE] [--verbose]');
            console.log('Read-only validation. Exit 0 valid, 1 invalid, 2 usage or I/O error.');
            return 0;
        }
        if (arg === '--verbose') { verbose = true; continue; }
        if (!['--repo-root', '--manifest'].includes(arg) || !args[i + 1] || args[i + 1].startsWith('--')) {
            console.error(`Usage error: ${arg} requires a supported option and value`);
            return 2;
        }
        const value = path.resolve(args[++i]);
        if (arg === '--repo-root') repoRoot = value;
        else manifestPath = value;
    }
    manifestPath ||= path.join(repoRoot, 'config/lite-manifest.json');
    try {
        const text = fs.readFileSync(manifestPath, 'utf8');
        let manifest;
        try { manifest = JSON.parse(text); } catch { invalid('manifest must contain valid JSON'); }
        const report = validateManifest(manifest, { repoRoot });
        if (verbose) console.error(`Validated ${manifestPath} against ${repoRoot}`);
        console.log(JSON.stringify(report));
        return 0;
    } catch (error) {
        console.error(error.message);
        return error instanceof ValidationError ? 1 : 2;
    }
}

module.exports = { validateManifest, metadataBytes };
if (require.main === module) process.exitCode = main(process.argv.slice(2));
