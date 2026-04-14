#!/usr/bin/env node
/**
 * superpowers-augment.js - Skill loader for Augment Code
 * Replaces the old superpowers-codex wrapper with direct skill discovery
 * Compatible with obra/superpowers v4.2.0+
 */
const fs = require('fs');
const path = require('path');
const os = require('os');

// Semantic skill routing and auto-composition
const {
  matchSkills: semanticMatch,
  embedSkills,
  getRouterInfo,
  matchSkillsTfIdf,
  buildPipeline,
  explainPipeline,
  pipelineToMermaid,
  getComposition,
  getCoordination
} = require('./lib/skill-router');

// Workflow state machine (advisory gate tracking)
const workflowState = require('./lib/workflow-state');

// Canonical frontmatter parser — single source of truth for all YAML parsing
const { extractFrontmatter, findSkillFile, stripFrontmatter } = require('./lib/frontmatter');

// Unified skill discovery — single source of truth for directory scanning + dedup
const { findSkillsInDir, deduplicateSkills, findAllSkills } = require('./lib/skill-discovery');

// Shared compression — single source of truth for content stripping
const { compressSkillContent } = require('./lib/compress');

const homeDir = os.homedir();
const SUPERPOWERS_SKILLS_DIR = process.env.SUPERPOWERS_SKILLS_DIR || path.join(homeDir, '.codex', 'superpowers', 'skills');
const PERSONAL_SKILLS_DIR = process.env.PERSONAL_SKILLS_DIR || path.join(homeDir, '.codex', 'skills');
const SESSION_FILE = path.join(homeDir, '.codex', '.superpowers-session');


// Load env file (shell-format KEY="value") into process.env
const ENV_FILE = path.join(homeDir, '.codex', '.env');
try {
    if (fs.existsSync(ENV_FILE)) {
        const envContent = fs.readFileSync(ENV_FILE, 'utf8');
        for (const line of envContent.split('\n')) {
            // Support: KEY=val, KEY="val", export KEY=val, inline # comments
            const cleaned = line.replace(/^\s*export\s+/, '').trim();
            // Try quoted form first (preserves # inside quotes)
            const quoted = cleaned.match(/^([A-Za-z_][A-Za-z0-9_]*)="([^"]*)"(\s*#.*)?$/);
            if (quoted) {
                if (!process.env[quoted[1]]) process.env[quoted[1]] = quoted[2];
                continue;
            }
            // Unquoted: strip inline comments first, then reject stray quotes
            const unquoted = cleaned.replace(/\s+#.*$/, '');
            if (unquoted.includes('"')) continue; // malformed — quotes didn't match quoted form
            const match = unquoted.match(/^([A-Za-z_][A-Za-z0-9_]*)=(.*)$/);
            if (match && !process.env[match[1]]) {
                process.env[match[1]] = match[2];
            }
        }
    }
} catch (_) { /* non-fatal */ }

// Source repo directories for namespace prefix resolution (spp:, spo:)
// These point to git source repos, NOT installed directories.
// Discovery order: env var → well-known paths → null (prefix unavailable)
function discoverSourceDir(envVar, wellKnownPaths) {
    if (process.env[envVar]) {
        const dir = process.env[envVar];
        if (fs.existsSync(dir)) return dir;
    }
    for (const p of wellKnownPaths) {
        const resolved = p.replace(/^~/, homeDir);
        if (fs.existsSync(resolved)) return resolved;
    }
    return null;
}

// Self-discover: if this script lives inside a superpowers-plus checkout, use that
// as the source dir (covers any clone location without hard-coding paths).
function discoverSppFromScript() {
    const scriptDir = path.resolve(__dirname);
    // Check if script is inside a superpowers-plus repo (has skills/ dir)
    if (fs.existsSync(path.join(scriptDir, 'skills')) && fs.existsSync(path.join(scriptDir, 'tools'))) {
        return scriptDir;
    }
    // Script may be in a subdirectory; check parent
    const parentDir = path.dirname(scriptDir);
    if (fs.existsSync(path.join(parentDir, 'skills')) && fs.existsSync(path.join(parentDir, 'tools'))) {
        return parentDir;
    }
    return null;
}

const SPP_SOURCE_DIR = discoverSourceDir('SPP_SOURCE_DIR', [
    // Self-discovery from script location (works for any clone path)
    discoverSppFromScript(),
    // Installed copy as fallback
    '~/.codex/superpowers-plus',
].filter(Boolean));

const OVERLAY_SOURCE_DIR = discoverSourceDir('SP_OVERLAY_SOURCE_DIR', [])
    || discoverSourceDir('SPC_SOURCE_DIR', []);  // backward compat (pre-v1.9)

/**
 * Find a skill.md in a source repo by searching domain subdirectories.
 * Source repos use {domain}/{skill-name}/skill.md layout.
 * Returns the skill file path or null.
 */
function findSkillInSourceRepo(repoDir, skillName) {
    if (!repoDir) return null;
    // Check skills/ subdirectory first (superpowers-plus layout)
    const skillsSubdir = path.join(repoDir, 'skills');
    const searchRoots = fs.existsSync(skillsSubdir) ? [skillsSubdir] : [repoDir];
    for (const root of searchRoots) {
        try {
            const domains = fs.readdirSync(root, { withFileTypes: true });
            for (const domain of domains) {
                if (!domain.isDirectory()) continue;
                const skip = new Set(['node_modules', '.git', '.github', 'lib', 'docs', 'tools', 'mcp', 'setup', 'references']);
                if (domain.name.startsWith('_') || domain.name.startsWith('.') || skip.has(domain.name)) continue;
                const skillDir = path.join(root, domain.name, skillName);
                const skillFile = findSkillFile(skillDir);
                if (skillFile) return skillFile;
            }
            // Direct child of root (non-domain layout)
            const directDir = path.join(root, skillName);
            const directFile = findSkillFile(directDir);
            if (directFile) return directFile;
        } catch (_) { /* directory not readable */ }
    }
    return null;
}

// Session staleness threshold: 4 hours (sessions don't last longer than this)
const SESSION_MAX_AGE_MS = 4 * 60 * 60 * 1000;

function writeSessionMarker() {
    try {
        fs.writeFileSync(SESSION_FILE, JSON.stringify({
            bootstrapped: new Date().toISOString(),
            pid: process.ppid || process.pid
        }));
    } catch (_) { /* non-fatal */ }
}

function checkBootstrap() {
    try {
        if (!fs.existsSync(SESSION_FILE)) return false;
        const data = JSON.parse(fs.readFileSync(SESSION_FILE, 'utf8'));
        const age = Date.now() - new Date(data.bootstrapped).getTime();
        return age < SESSION_MAX_AGE_MS;
    } catch (_) {
        return false;
    }
}

const TOOL_MAPPINGS = [
    [/\bTodoWrite\b/g, 'todo-crud.sh (add/complete/move/defer) — NEVER use str-replace-editor or save-file on TODO.md. Run: ~/.codex/superpowers-plus/tools/todo-crud.sh add -p P2 -d "description" -t "#tag"'],
    [/\bTodoRead\b/g, 'todo-crud.sh cat (full file) or todo-crud.sh list (filtered) — NEVER use view tool on TODO.md directly. Run: ~/.codex/superpowers-plus/tools/todo-crud.sh cat'],
    [/Task tool with superpowers:code-reviewer type/g, 'sub-agent-code-reviewer tool'],
    [/Task tool \(superpowers:code-reviewer\):/g, 'sub-agent-code-reviewer tool:'],
    [/Dispatch superpowers:code-reviewer subagent/g, 'Dispatch sub-agent-code-reviewer'],
    [/\bcode-reviewer subagent\b/g, 'sub-agent-code-reviewer'],
    [/\bcode reviewer subagent\b/g, 'sub-agent-code-reviewer'],
    [/Dispatch final code-reviewer/g, 'Dispatch final sub-agent-code-reviewer'],
    [/dispatch final code reviewer/gi, 'Dispatch final sub-agent-code-reviewer'],
    [/\bTask\b tool(?! with superpowers:code-reviewer type| \(superpowers:code-reviewer\))/g, 'launch-process (or handle directly)'],
    [/\bRead\b tool/g, 'view tool'],
    [/\bWrite\b tool/g, 'save-file tool'],
    [/\bEdit\b tool/g, 'str-replace-editor tool'],
    [/`Read`/g, '`view`'],
    [/`Write`/g, '`save-file`'],
    [/`Edit`/g, '`str-replace-editor`'],
    [/\bBash\b tool/g, 'launch-process tool'],
    [/`Bash`/g, '`launch-process`'],
    [/Skill tool/g, 'superpowers-augment use-skill command'],
    [/superpowers-codex/g, 'superpowers-augment'],
];

function transformOutput(text) {
    let result = text;
    for (const [pattern, replacement] of TOOL_MAPPINGS) {
        result = result.replace(pattern, replacement);
    }
    return result;
}

// extractFrontmatter and findSkillFile are imported from ./lib/frontmatter (see top of file)

/**
 * Check if required MCP servers are registered in ~/.augment/settings.json.
 * Returns array of missing server names (empty = all good).
 */
function checkMcpPrerequisites(requiredServers) {
    if (!requiredServers || requiredServers.length === 0) return [];
    const settingsPath = path.join(homeDir, '.augment', 'settings.json');
    try {
        const settings = JSON.parse(fs.readFileSync(settingsPath, 'utf8'));
        const registered = Object.keys(settings.mcpServers || {});
        return requiredServers.filter(s => !registered.includes(s));
    } catch (_) {
        return requiredServers; // Can't read settings → assume all missing
    }
}


// findSkillsInDir, stripFrontmatter, deduplicateSkills — imported from lib/ (see top of file)

function findSkills(filterMode = 'all') {
    const deduped = findAllSkills(PERSONAL_SKILLS_DIR, SUPERPOWERS_SKILLS_DIR);
    // Categorize
    const superpowers = deduped.filter(s => s.isSuperpower);
    const explicitSkills = deduped.filter(s => !s.isSuperpower);

    // Token cost tier helper
    function tokenTier(tokens) {
        if (tokens >= 2000) return '🔴';  // HIGH
        if (tokens >= 1000) return '🟡';  // MEDIUM
        return '🟢';                       // LOW
    }

    if (filterMode === 'superpowers') {
        console.log('🦸 Superpowers (auto-triggered):');
        console.log('=================================\n');
        console.log('These skills activate automatically when trigger phrases are detected.\n');
        for (const skill of superpowers) {
            const displayName = skill.sourceType === 'superpowers' ? 'superpowers:' + skill.name : skill.name;
            console.log(`${displayName} ${tokenTier(skill.tokens)} ~${skill.tokens} tokens`);
            if (skill.description) console.log('  ' + skill.description);
            if (skill.triggers.length > 0) {
                console.log('  Triggers: ' + skill.triggers.slice(0, 3).map(t => `"${t}"`).join(', ') + (skill.triggers.length > 3 ? '...' : ''));
            }
            console.log();
        }
        console.log(`Total: ${superpowers.length} superpowers\n`);
    } else if (filterMode === 'explicit') {
        console.log('🔧 Explicit Skills (invoke by name):');
        console.log('=====================================\n');
        console.log('These skills must be explicitly invoked — they do not auto-trigger.\n');
        for (const skill of explicitSkills) {
            const displayName = skill.sourceType === 'superpowers' ? 'superpowers:' + skill.name : skill.name;
            console.log(`${displayName} ${tokenTier(skill.tokens)} ~${skill.tokens} tokens`);
            if (skill.description) console.log('  ' + skill.description + '\n');
            else console.log();
        }
        console.log(`Total: ${explicitSkills.length} explicit skills\n`);
    } else {
        // Default: show both categories
        console.log('🦸 SUPERPOWERS (auto-triggered)');
        console.log('================================\n');
        for (const skill of superpowers) {
            const displayName = skill.sourceType === 'superpowers' ? 'superpowers:' + skill.name : skill.name;
            console.log(displayName);
            if (skill.description) console.log('  ' + skill.description + '\n');
            else console.log();
        }
        console.log('🔧 EXPLICIT SKILLS (invoke by name)');
        console.log('====================================\n');
        for (const skill of explicitSkills) {
            const displayName = skill.sourceType === 'superpowers' ? 'superpowers:' + skill.name : skill.name;
            console.log(displayName);
            if (skill.description) console.log('  ' + skill.description + '\n');
            else console.log();
        }
    }
    // Token budget summary
    const totalTokens = deduped.reduce((sum, s) => sum + (s.tokens || 0), 0);
    const highCost = deduped.filter(s => s.tokens >= 2000);
    console.log(`Token budget: ${deduped.length} skills, ${totalTokens.toLocaleString()} tokens total installed`);
    if (highCost.length > 0) {
        console.log(`  🔴 ${highCost.length} high-cost skills (≥2000 tokens): ${highCost.map(s => s.name).join(', ')}`);
    }
    console.log('Usage:');
    console.log('  node ~/.codex/superpowers-augment/superpowers-augment.js use-skill <skill-name>   # Load a specific skill');
    console.log('  superpowers-augment find-skills              # List all skills');
    console.log('  superpowers-augment find-skills superpowers  # List only superpowers (auto-triggered)');
    console.log('  superpowers-augment find-skills explicit     # List only explicit skills\n');
    console.log('Naming convention:');
    console.log('  superpowers:skill-name  → from ~/.codex/superpowers/skills/ (obra/superpowers)');
    console.log('  skill-name              → from ~/.codex/skills/ (personal/superpowers-plus)');
    console.log('  Personal skills override superpowers skills when names match.');
    console.log('');
    console.log('Namespace prefixes (resolve to source repos, not installed dir):');
    console.log('  spp:skill-name          → superpowers-plus source repo' + (SPP_SOURCE_DIR ? ' (' + SPP_SOURCE_DIR + ')' : ' (not found)'));
    console.log('  spo:skill-name          → overlay source repo' + (OVERLAY_SOURCE_DIR ? ' (' + OVERLAY_SOURCE_DIR + ')' : ' (not found)'));
    console.log('');
    console.log('Dash shorthands (sp- expands to superpowers-):');
    console.log('  sp-doctor               → superpowers-doctor (normal resolution)');
    console.log('  spp-doctor              → superpowers-doctor from superpowers-plus source');
    console.log('  spo-doctor              → superpowers-doctor from overlay source\n');
    console.log(`Summary: ${superpowers.length} superpowers, ${explicitSkills.length} explicit skills, ${deduped.length} total`);
}


/**
 * Resolve a skill name (possibly with namespace prefix) to a file path.
 *
 * Namespace prefixes:
 *   superpowers:name → obra/superpowers skills only
 *   spp:name         → superpowers-plus source repo only
 *   spo:name         → overlay source repo only
 *   (no prefix)      → personal dir → superpowers dir → alias fallback
 *
 * Dash shorthands: sp-X → superpowers-X, spp-X → spp:superpowers-X
 *
 * @param {string} skillName - Raw skill name (possibly with prefix)
 * @returns {{ skillFile: string|null, actualName: string }} Resolved file and canonical name
 */
function resolveSkillNamespace(skillName) {
    let forceSuperpowers = skillName.startsWith('superpowers:');
    let forceSpp = skillName.startsWith('spp:');
    let forceSpo = skillName.startsWith('spo:') || skillName.startsWith('spc:');
    let actualName;

    // Dash shorthand expansion
    if (!forceSuperpowers && !forceSpp && !forceSpo) {
        if (skillName.startsWith('spp-')) {
            forceSpp = true;
            actualName = 'superpowers-' + skillName.slice(4);
        } else if (skillName.startsWith('spo-') || skillName.startsWith('spc-')) {
            forceSpo = true;
            actualName = 'superpowers-' + skillName.slice(4);
        } else if (skillName.startsWith('sp-')) {
            actualName = 'superpowers-' + skillName.slice(3);
        }
    }

    if (!actualName) {
        if (forceSuperpowers) actualName = skillName.replace(/^superpowers:/, '');
        else if (forceSpp) actualName = skillName.replace(/^spp:/, '');
        else if (forceSpo) actualName = skillName.replace(/^sp[oc]:/, '');
        else actualName = skillName;
    }

    let skillFile = null;

    if (forceSpp) {
        if (!SPP_SOURCE_DIR) return { skillFile: null, actualName, error: 'SPP_SOURCE_DIR not set' };
        skillFile = findSkillInSourceRepo(SPP_SOURCE_DIR, actualName);
    } else if (forceSpo) {
        if (!OVERLAY_SOURCE_DIR) return { skillFile: null, actualName, error: 'SP_OVERLAY_SOURCE_DIR not set' };
        skillFile = findSkillInSourceRepo(OVERLAY_SOURCE_DIR, actualName);
    } else if (!forceSuperpowers) {
        const personalDir = path.join(PERSONAL_SKILLS_DIR, actualName);
        const personalFile = findSkillFile(personalDir);
        if (personalFile) {
            skillFile = personalFile;
        } else {
            skillFile = findSkillInSourceRepo(PERSONAL_SKILLS_DIR, actualName);
        }
    }

    if (!skillFile && !forceSpp && !forceSpo) {
        const superpowersDir = path.join(SUPERPOWERS_SKILLS_DIR, actualName);
        const superpowersFile = findSkillFile(superpowersDir);
        if (superpowersFile) skillFile = superpowersFile;
    }

    if (!skillFile && forceSuperpowers) {
        const personalDir = path.join(PERSONAL_SKILLS_DIR, actualName);
        const personalFile = findSkillFile(personalDir);
        if (personalFile) skillFile = personalFile;
    }

    if (!skillFile && !forceSpp && !forceSpo) {
        skillFile = resolveAlias(actualName);
    }

    return { skillFile, actualName };
}


function useSkill(skillName, options = {}) {
    if (!skillName) {
        console.error('Error: skill name required');
        console.error('Usage: node ~/.codex/superpowers-augment/superpowers-augment.js use-skill <skill-name>');
        process.exit(1);
    }

    // Enforce bootstrap-first discipline
    if (!checkBootstrap()) {
        console.error('');
        console.error('⚠️  BOOTSTRAP NOT RUN — Skills are degraded without session context.');
        console.error('');
        console.error('You MUST bootstrap before using skills. Run this FIRST:');
        console.error('');
        console.error('  node ~/.codex/superpowers-augment/superpowers-augment.js bootstrap');
        console.error('');
        console.error('Then retry: node ~/.codex/superpowers-augment/superpowers-augment.js use-skill ' + skillName);
        console.error('');
        console.error('WHY: Bootstrap establishes session context, priority ordering,');
        console.error('and red-flag detection. Without it, skills fire in isolation');
        console.error('without the meta-framework that makes them effective.');
        console.error('');
        // Don't block — still load the skill, but the warning is impossible to miss
    }

    // Resolve namespace prefix → file path
    const resolved = resolveSkillNamespace(skillName);
    const { actualName } = resolved;
    let { skillFile } = resolved;

    if (resolved.error) {
        console.error('Error: ' + resolved.error);
        process.exit(1);
    }
    // Alias fallback: scan all installed skills for a matching alias (case-insensitive)
    if (!skillFile && !forceSpp && !forceSpo) {
        skillFile = resolveAlias(actualName);
    }
    if (!skillFile) {
        console.error('Error: Skill "' + skillName + '" not found');
        if (forceSpp) console.error('Searched superpowers-plus source: ' + SPP_SOURCE_DIR);
        if (forceSpo) console.error('Searched overlay source: ' + OVERLAY_SOURCE_DIR);
        const suggestions = suggestSimilarSkills(actualName);
        if (suggestions.length > 0) {
            console.error('Did you mean: ' + suggestions.join(', ') + '?');
        }
        console.error('Run "superpowers-augment find-skills" to see available skills');
        process.exit(1);
    }
    const content = fs.readFileSync(skillFile, 'utf8');

    if (options.probe) {
        // Probe mode: output summary + token cost before loading
        const fmMatch = content.match(/^---\n([\s\S]*?)\n---/);
        const fileSize = fs.statSync(skillFile).size;
        const tokens = Math.round(fileSize / 4);
        const tier = tokens >= 2000 ? '🔴 HIGH' : tokens >= 1000 ? '🟡 MEDIUM' : '🟢 LOW';
        if (fmMatch) {
            const fm = fmMatch[1];
            const summaryMatch = fm.match(/^summary:\s*(.+)$/m) ||
                                 fm.match(/^summary:\s*>\s*\n((?:\s+.+\n?)*)/m);
            const descMatch = fm.match(/^description:\s*(.+)$/m) ||
                              fm.match(/^description:\s*"(.+)"$/m);
            const summary = summaryMatch ? (summaryMatch[1] || summaryMatch[2] || '').trim() : null;
            const desc = descMatch ? (descMatch[1] || descMatch[2] || '').trim() : null;
            console.log(`# Probe: ${skillName}  [${tier} ~${tokens} tokens]`);
            if (summary) {
                console.log(`\n${summary}`);
            } else if (desc) {
                console.log(`\n${desc}`);
            } else {
                console.log('\nNo summary available.');
            }
            console.log(`\nToken cost: ~${tokens} tokens (${tier})`);
            console.log(`Load full skill? \`node ~/.codex/superpowers-augment/superpowers-augment.js use-skill ${skillName}\``);
        }
        return;
    }

    const stripped = stripFrontmatter(content);
    // Respect per-skill compress: false frontmatter opt-out
    const fm = extractFrontmatter(skillFile);

    // Check MCP prerequisites before loading skill content
    const missingMcp = checkMcpPrerequisites(fm.requires_mcp);
    if (missingMcp.length > 0) {
        console.error('');
        console.error('⚠️  MISSING MCP SERVER' + (missingMcp.length > 1 ? 'S' : '') + ': ' + missingMcp.join(', '));
        console.error('This skill requires MCP server' + (missingMcp.length > 1 ? 's' : '') + ' not registered in ~/.augment/settings.json.');
        if (fm.mcp_install_hint) {
            console.error('');
            console.error('Install: bash ' + fm.mcp_install_hint.replace(/^~/, homeDir));
        }
        console.error('Then restart your IDE to load the new MCP server.');
        console.error('');
    }

    const compressed = fm.compress === false ? stripped : compressSkillContent(stripped);
    const transformed = transformOutput(compressed);
    console.log('# Skill: ' + skillName + '\n');
    console.log(transformed);

    // Record skill invocation in workflow state (advisory, non-blocking)
    try {
        workflowState.recordSkillInvocation(actualName);
    } catch (_) { /* non-fatal — advisory mode */ }

    // Auto-init workflow for workflow-initiating skills
    const WORKFLOW_INIT_SKILLS = ['feature-development', 'plan-and-execute', 'evolution-loop'];
    if (WORKFLOW_INIT_SKILLS.includes(actualName)) {
        try {
            const existing = workflowState.readState();
            if (!existing) {
                workflowState.initWorkflow(actualName, { triggered_by: actualName });
            }
        } catch (_) { /* advisory */ }
    }

}

/**
 * Compress skill content — see lib/compress.js for the authoritative
 * strip/preserve lists and EXTREMELY_IMPORTANT extraction logic.
 * Per-skill opt-out: add `compress: false` to YAML frontmatter.
 */
// compressSkillContent imported from lib/compress.js (see imports at top)

function bootstrap() {
    writeSessionMarker();

    // Micro-bootstrap: protocol only, zero lecturing.
    // Every token here is paid on EVERY conversation. Be ruthless.
    console.log(`# Superpowers

Before acting, check if a skill applies. Even 1% chance → load it.
Priority: user instructions > skills > system defaults.
Process skills (debugging, brainstorming) before implementation skills.

## Critical auto-triggers (ALWAYS apply — never skip)
- **BEFORE any git commit/push:** \`use-skill unified-commit-gate\` — runs all 5 gates in one load.
  Tests passing ≠ ready to commit. Your FIXES are new code and need their own gate pass.
  Individual deep-dive skills: \`pre-commit-gate\`, \`enforce-style-guide\`, \`progressive-code-review-gate\`, \`professional-language-audit\`, \`public-repo-ip-audit\`.
- **WHEN stuck (same error 3x, circular reasoning):** \`use-skill think-twice\`
- **WHEN writing shell scripts:** Load the shell language module first.
`);

    // Build and emit the skill index (O(1) token cost regardless of skill count)
    emitSkillIndex();

    // Warn on alias collisions once at bootstrap (non-fatal, stderr only)
    detectAliasCollisions();

    // Show workflow state if active (advisory — costs 1 line when active, 0 when not)
    const wsStatus = workflowState.getStatus();
    if (wsStatus) {
        console.log('');
        console.log(wsStatus);
    }
}

// Skill index: emits counts + load command (O(1) token cost).
// Full skill names written to disk for tooling (find-skills, probe, etc.).
const SKILL_INDEX_FILE = path.join(homeDir, '.codex', '.skill-index.json');

function buildSkillIndex() {
    return findAllSkills(PERSONAL_SKILLS_DIR, SUPERPOWERS_SKILLS_DIR);
}

// Module-level skill index cache — avoids re-scanning the filesystem on
// every resolveAlias / suggestSimilarSkills call within one process.
let _cachedSkillIndex = null;
function _getSkillIndex() {
    if (!_cachedSkillIndex) _cachedSkillIndex = buildSkillIndex();
    return _cachedSkillIndex;
}

/**
 * Resolve a skill name via alias lookup.
 * Checks the `aliases` frontmatter field (case-insensitive exact match),
 * then falls back to a case-insensitive name match.  Returns the skill
 * file path or null.  Uses the module-level cache to avoid repeated scans.
 */
function resolveAlias(requestedName) {
    const needle = requestedName.toLowerCase();
    const allSkills = _getSkillIndex();
    // Tier 1: exact alias match
    for (const skill of allSkills) {
        if (skill.aliases && skill.aliases.some(a => a.toLowerCase() === needle)) {
            return skill.skillFile;
        }
    }
    // Tier 2: case-insensitive name match
    for (const skill of allSkills) {
        if (skill.name.toLowerCase() === needle) {
            return skill.skillFile;
        }
    }
    return null;
}

/**
 * Detect alias collisions across all installed skills.
 * Emits a console.error warning for any alias declared by more than one skill.
 * Called once at bootstrap — non-fatal (first-registered skill wins).
 */
function detectAliasCollisions() {
    const allSkills = _getSkillIndex();
    const aliasMap = new Map(); // alias → [skill names]
    for (const skill of allSkills) {
        if (!skill.aliases) continue;
        for (const alias of skill.aliases) {
            const key = alias.toLowerCase();
            if (!aliasMap.has(key)) aliasMap.set(key, []);
            aliasMap.get(key).push(skill.name);
        }
    }
    for (const [alias, owners] of aliasMap) {
        if (owners.length > 1) {
            console.error(`[superpowers-augment] WARNING: Alias "${alias}" claimed by multiple skills: ${owners.join(', ')} — first match wins`);
        }
    }
}

/**
 * Find close matches for a skill name (for "did you mean?" suggestions).
 * Returns up to 3 skill names ranked by match quality:
 *   1. Exact alias match
 *   2. Alias prefix/substring match
 *   3. Skill name contains the query (or query contains stripped name)
 * Consistent ordering regardless of filesystem directory enumeration order.
 */
function suggestSimilarSkills(requestedName) {
    const needle = requestedName.toLowerCase();
    const allSkills = _getSkillIndex();
    const tier1 = []; // exact alias
    const tier2 = []; // alias substring
    const tier3 = []; // name substring
    const added = new Set();

    const push = (tier, name) => {
        if (!added.has(name)) { tier.push(name); added.add(name); }
    };

    for (const skill of allSkills) {
        const nameLower = skill.name.toLowerCase();
        if (skill.aliases) {
            for (const alias of skill.aliases) {
                const al = alias.toLowerCase();
                if (al === needle)                     push(tier1, skill.name);
                else if (al.includes(needle) || needle.includes(al)) push(tier2, skill.name);
            }
        }
        if (nameLower.includes(needle) || needle.includes(nameLower.replace(/-/g, ''))) {
            push(tier3, skill.name);
        }
    }

    return [...tier1, ...tier2, ...tier3].slice(0, 3);
}

function emitSkillIndex() {
    const deduped = buildSkillIndex();
    const superpowers = deduped.filter(s => s.isSuperpower);
    const explicit = deduped.filter(s => !s.isSuperpower);

    // Write full index to disk for tooling (find-skills, probe, etc.)
    try {
        const index = deduped.map(s => ({
            name: s.name, triggers: s.triggers, tokens: s.tokens,
            isSuperpower: s.isSuperpower, sourceType: s.sourceType
        }));
        fs.writeFileSync(SKILL_INDEX_FILE, JSON.stringify({ skills: index, built: new Date().toISOString() }));
    } catch (_) { /* non-fatal */ }

    // Emit count + load command + disambiguation hint.
    console.log(`${superpowers.length} superpowers (auto-trigger) + ${explicit.length} explicit skills installed.`);
    console.log('Load: `node ~/.codex/superpowers-augment/superpowers-augment.js use-skill <name>`');
    console.log('Unsure which skill? `node ~/.codex/superpowers-augment/superpowers-augment.js match-skills "your query"`');
}



const command = process.argv[2];
const args = process.argv.slice(3);

(async () => {
switch (command) {
    case 'bootstrap': bootstrap(); break;
    case 'use-skill': {
        const probeMode = args[0] === '--probe';
        const skillArg = probeMode ? args[1] : args[0];
        useSkill(skillArg, { probe: probeMode });
        break;
    }
    case 'find-skills': findSkills(args[0] || 'all'); break;
    case 'list-superpowers': findSkills('superpowers'); break;
    case 'list-skills': findSkills('explicit'); break;

    case 'compose-pipeline': {
        const capability = args[0];
        if (!capability) {
            console.error('Usage: compose-pipeline <target-capability>');
            console.error('Example: compose-pipeline publishes-wiki');
            console.error('\nAvailable capabilities:');
            console.error('  publishes-wiki     - Full wiki authoring pipeline');
            console.error('  validates-links    - Link verification only');
            console.error('  generates-content  - Content generation only');
            console.error('  detects-secrets    - Secret scanning only');
            process.exit(1);
        }

        // Gather all skills with composition metadata
        const allSkills = findAllSkills(PERSONAL_SKILLS_DIR, SUPERPOWERS_SKILLS_DIR);

        // Filter to skills with composition blocks
        const composableSkills = allSkills.filter(s => s.composition !== null);

        if (composableSkills.length === 0) {
            console.log('No skills with composition: blocks found.');
            process.exit(1);
        }

        console.log(`# Auto-Composition Pipeline\n`);
        console.log(`Target capability: ${capability}`);
        console.log(`Composable skills: ${composableSkills.length}\n`);

        // Build the pipeline
        const result = buildPipeline(capability, composableSkills, ['user-intent']);

        if (result.error) {
            console.log(`Error: ${result.error}\n`);
            console.log('Resolution trace:');
            console.log(result.explanation.join('\n'));
            process.exit(1);
        }

        console.log('## Pipeline Order\n');
        console.log('| Step | Skill | Consumes | Produces |');
        console.log('|------|-------|----------|----------|');
        result.pipeline.forEach((skill, i) => {
            const comp = skill.composition || {};
            const consumes = (comp.consumes || []).join(', ');
            const produces = (comp.produces || []).join(', ');
            console.log(`| ${i + 1} | ${skill.name} | ${consumes} | ${produces} |`);
        });

        console.log('\n## Mermaid Diagram\n');
        console.log('```mermaid');
        console.log(pipelineToMermaid(result.pipeline));
        console.log('```');

        console.log('\n## Resolution Trace\n');
        console.log(result.explanation.join('\n'));
        break;
    }

    case 'match-skills': {
        // Parse options: --tfidf, --embedding, or auto
        const useEmbedding = args.includes('--embedding');
        const useTfidf = args.includes('--tfidf');
        const queryArgs = args.filter(a => !a.startsWith('--'));
        const query = queryArgs.join(' ');

        if (!query) {
            console.error('Usage: match-skills [--tfidf|--embedding] <query>');
            console.error('Example: match-skills "my tests keep failing randomly"');
            console.error('\nOptions:');
            console.error('  --tfidf      Force TF-IDF mode (fast, offline)');
            console.error('  --embedding  Force OpenAI embeddings (requires OPENAI_API_KEY)');
            console.error('  (default)    Auto-select best available method');
            process.exit(1);
        }

        // Gather all skills
        const skills = findAllSkills(PERSONAL_SKILLS_DIR, SUPERPOWERS_SKILLS_DIR);

        // Determine method
        let method = 'auto';
        if (useTfidf) method = 'tfidf';
        if (useEmbedding) method = 'embedding';

        const routerInfo = getRouterInfo();
        const actualMethod = method === 'auto' ? routerInfo.default : method;

        try {
            // Fetch extra matches to account for internal filtering
            const rawMatches = await semanticMatch(query, skills, { topN: 10, method });
            // Filter out internal skills from user-facing output (PHR finding #2)
            const matches = rawMatches.filter(m => {
                const coord = getCoordination(m);
                return !coord || !coord.internal;
            }).slice(0, 5);

            console.log(`# Skill Match Results\n`);
            console.log(`Query: "${query}"`);
            console.log(`Method: ${actualMethod.toUpperCase()}${method === 'auto' ? ' (auto-selected)' : ''}\n`);
            // Keep existing 4-column table structure stable for parsers (PHR finding #4)
            console.log('| Rank | Skill | Score | Type |');
            console.log('|------|-------|-------|------|');
            for (let i = 0; i < matches.length; i++) {
                const m = matches[i];
                const type = m.isSuperpower ? 'superpower' : 'explicit';
                const scoreDisplay = actualMethod === 'tfidf'
                    ? m.score.toFixed(2)
                    : (m.score * 100).toFixed(1) + '%';
                console.log(`| ${i + 1} | ${m.name} | ${scoreDisplay} | ${type} |`);
            }
            console.log(`\nTop match: **${matches[0]?.name}**`);
            console.log(`\nTo use: \`node ~/.codex/superpowers-augment/superpowers-augment.js use-skill ${matches[0]?.name}\``);

            // Show coordination info below the table (appended, not column change)
            const coordMatches = matches.filter(m => getCoordination(m));
            if (coordMatches.length > 0) {
                console.log('\n## Coordination');
                for (const m of coordMatches) {
                    const coord = getCoordination(m);
                    const parts = [`group: ${coord.group || '(none)'}`];
                    if (coord.requires.length) parts.push(`requires: ${coord.requires.join(', ')}`);
                    if (coord.enables.length) parts.push(`enables: ${coord.enables.join(', ')}`);
                    if (coord.escalates_to.length) parts.push(`escalates: ${coord.escalates_to.join(', ')}`);
                    console.log(`- **${m.name}**: ${parts.join(' | ')}`);
                }
            }
        } catch (err) {
            console.error('Error:', err.message);
            process.exit(1);
        }
        break;
    }

    case 'router-info': {
        const info = getRouterInfo();
        console.log('# Skill Router Info\n');
        console.log('Available methods:');
        console.log(`  • TF-IDF: ${info.tfidf.available ? '✅' : '❌'} ${info.tfidf.description}`);
        console.log(`  • Embedding: ${info.embedding.available ? '✅' : '❌'} ${info.embedding.description}`);
        console.log(`\nDefault method: ${info.default.toUpperCase()}`);
        break;
    }

    case 'embed-skills': {
        // Pre-embed all skills (optional, for embedding mode)
        const skills = findAllSkills(PERSONAL_SKILLS_DIR, SUPERPOWERS_SKILLS_DIR);

        const forceRefresh = args.includes('--force');
        console.log(`Embedding ${skills.length} skills...${forceRefresh ? ' (force refresh)' : ''}`);
        console.log('(Requires OPENAI_API_KEY)\n');

        try {
            const cache = await embedSkills(skills, forceRefresh);
            const count = Object.keys(cache.embeddings).length;
            console.log(`\n✅ Embedded ${count} skills`);
            console.log(`Cache: ~/.codex/.skill-embeddings.json`);
        } catch (err) {
            console.error('Error:', err.message);
            if (err.message.includes('OPENAI_API_KEY')) {
                console.error('\nNote: Embedding is optional. TF-IDF mode works without an API key.');
                console.error('Run: match-skills --tfidf "your query"');
            }
            process.exit(1);
        }
        break;
    }

    default:
        console.log('Superpowers for Augment\n');
        console.log('Usage:');
        console.log('  node superpowers-augment.js bootstrap              # Initialize session');
        console.log('  node superpowers-augment.js use-skill <name>       # Load a specific skill');
        console.log('  node superpowers-augment.js use-skill sp-<name>   # sp-X → superpowers-X shorthand');
        console.log('  node superpowers-augment.js use-skill spp:<name>  # Load from superpowers-plus source');
        console.log('  node superpowers-augment.js use-skill spo:<name>  # Load from overlay source repo');
        console.log('  node superpowers-augment.js use-skill spp-<name>  # spp-X from superpowers-plus source');
        console.log('  node superpowers-augment.js find-skills            # List all (categorized)');
        console.log('  node superpowers-augment.js find-skills superpowers # List auto-triggered only');
        console.log('  node superpowers-augment.js find-skills explicit   # List explicit-invoke only');
        console.log('');
        console.log('Skill Matching (find skills by intent):');
        console.log('  node superpowers-augment.js match-skills <query>   # Auto-select best method');
        console.log('  node superpowers-augment.js match-skills --tfidf <query>  # Fast offline mode');
        console.log('  node superpowers-augment.js match-skills --embedding <query>  # OpenAI (optional)');
        console.log('  node superpowers-augment.js router-info            # Show available methods');
        console.log('  node superpowers-augment.js embed-skills [--force] # Pre-embed (optional)');
        console.log('  node superpowers-augment.js compose-pipeline <capability>  # Build auto-composition pipeline');

        break;
}
})().catch(err => { console.error('Fatal:', err.message); process.exit(1); });
