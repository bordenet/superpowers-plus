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
  getComposition
} = require('./lib/skill-router');

const homeDir = os.homedir();
const SUPERPOWERS_SKILLS_DIR = path.join(homeDir, '.codex', 'superpowers', 'skills');
const PERSONAL_SKILLS_DIR = path.join(homeDir, '.codex', 'skills');
const SESSION_FILE = path.join(homeDir, '.codex', '.superpowers-session');
const COST_WARNINGS_DIR = path.join(homeDir, '.codex', '.skill-cost-warnings');

// Source repo directories for namespace prefix resolution (spp:, spc:)
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

const SPP_SOURCE_DIR = discoverSourceDir('SPP_SOURCE_DIR', [
    '~/GitHub/Personal/superpowers-plus',
    '~/superpowers-plus',
    '~/.codex/superpowers-plus',
]);

const SPC_SOURCE_DIR = discoverSourceDir('SPC_SOURCE_DIR', [
    '~/GitHub/[Company]/Tools/superpowers-[company]',
    '~/superpowers-[company]',
]);

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
    [/\bTodoWrite\b/g, 'str-replace-editor on TODO.md (run todo-preflight.sh first to get path), then optionally add_tasks for UI'],
    [/\bTodoRead\b/g, 'view tool on TODO.md (run todo-preflight.sh first to get path), then optionally view_tasklist for UI'],
    [/\bTask\b tool with subagents/g, 'Note: Augment does not have subagents - do the work directly'],
    [/\bTask\b tool/g, 'launch-process (or handle directly)'],
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

function extractFrontmatter(filePath) {
    try {
        const content = fs.readFileSync(filePath, 'utf8');
        const lines = content.split('\n');
        let inFrontmatter = false;
        let inComposition = false;
        let name = '';
        let description = '';
        let triggers = [];
        let composition = null;
        let compositionLines = [];

        for (const line of lines) {
            if (line.trim() === '---') {
                if (inFrontmatter) break;
                inFrontmatter = true;
                continue;
            }
            if (inFrontmatter) {
                // Check for composition block start
                if (line.match(/^composition:/)) {
                    inComposition = true;
                    composition = {};
                    continue;
                }
                // Parse composition fields (indented with 2 spaces)
                if (inComposition && line.match(/^  \w+:/)) {
                    const compMatch = line.match(/^  (\w+):\s*(.+)?$/);
                    if (compMatch) {
                        const key = compMatch[1];
                        let value = compMatch[2] || '';
                        // Parse array values
                        if (value.startsWith('[')) {
                            value = value.replace(/[\[\]]/g, '').split(',').map(v => v.trim().replace(/"/g, '')).filter(v => v);
                        } else if (value === 'true') {
                            value = true;
                        } else if (value === 'false') {
                            value = false;
                        } else if (!isNaN(value) && value !== '') {
                            value = parseInt(value, 10);
                        }
                        composition[key] = value;
                    }
                } else if (inComposition && !line.match(/^  /)) {
                    inComposition = false; // End of composition block
                }

                // Check for triggers array
                const triggersMatch = line.match(/^triggers:\s*\[(.+)\]/);
                if (triggersMatch) {
                    const triggerStr = triggersMatch[1];
                    triggers = triggerStr.match(/"[^"]+"/g)?.map(t => t.replace(/"/g, '')) || [];
                }
                const match = line.match(/^(\w+):\s*"?([^"]*)"?$/);
                if (match) {
                    const key = match[1];
                    const value = match[2];
                    if (key === 'name') name = value.trim();
                    if (key === 'description') description = value.trim();
                }
            }
        }
        return { name, description, triggers, composition };
    } catch (error) {
        return { name: '', description: '', triggers: [], composition: null };
    }
}

function findSkillFile(dir) {
    const candidates = ['SKILL.md', 'skill.md'];
    for (const filename of candidates) {
        const filepath = path.join(dir, filename);
        if (fs.existsSync(filepath)) return filepath;
    }
    return null;
}

function findSkillsInDir(dir, sourceType) {
    const skills = [];
    if (!fs.existsSync(dir)) return skills;
    const entries = fs.readdirSync(dir, { withFileTypes: true });
    for (const entry of entries) {
        // Handle both directories and symlinks to directories
        const skillDir = path.join(dir, entry.name);
        const isDir = entry.isDirectory() || (entry.isSymbolicLink() && fs.statSync(skillDir).isDirectory());
        if (!isDir) continue;
        const skillFile = findSkillFile(skillDir);
        if (skillFile) {
            const meta = extractFrontmatter(skillFile);
            const hasTriggers = meta.triggers && meta.triggers.length > 0;
            skills.push({
                name: meta.name || entry.name,
                description: meta.description || '',
                triggers: meta.triggers || [],
                composition: meta.composition || null,
                isSuperpower: hasTriggers,  // Superpowers have auto-triggers
                sourceType,
                skillFile,
                skillDir
            });
        }
    }
    return skills;
}

function stripFrontmatter(content) {
    const lines = content.split('\n');
    let inFrontmatter = false;
    let frontmatterEnded = false;
    const contentLines = [];
    for (const line of lines) {
        if (line.trim() === '---') {
            if (inFrontmatter) { frontmatterEnded = true; continue; }
            inFrontmatter = true;
            continue;
        }
        if (frontmatterEnded || !inFrontmatter) {
            contentLines.push(line);
        }
    }
    return contentLines.join('\n').trim();
}

function findSkills(filterMode = 'all') {
    const personalSkills = findSkillsInDir(PERSONAL_SKILLS_DIR, 'personal');
    const superpowersSkills = findSkillsInDir(SUPERPOWERS_SKILLS_DIR, 'superpowers');
    const allSkills = [...personalSkills, ...superpowersSkills];
    const seen = new Set();
    const deduped = [];
    for (const skill of allSkills) {
        if (seen.has(skill.name)) continue;
        seen.add(skill.name);
        deduped.push(skill);
    }
    // Categorize
    const superpowers = deduped.filter(s => s.isSuperpower);
    const explicitSkills = deduped.filter(s => !s.isSuperpower);

    if (filterMode === 'superpowers') {
        console.log('🦸 Superpowers (auto-triggered):');
        console.log('=================================\n');
        console.log('These skills activate automatically when trigger phrases are detected.\n');
        for (const skill of superpowers) {
            const displayName = skill.sourceType === 'superpowers' ? 'superpowers:' + skill.name : skill.name;
            console.log(displayName);
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
            console.log(displayName);
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
    console.log('Usage:');
    console.log('  superpowers-augment use-skill <skill-name>   # Load a specific skill');
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
    console.log('  spc:skill-name          → overlay source repo' + (SPC_SOURCE_DIR ? ' (' + SPC_SOURCE_DIR + ')' : ' (not found)'));
    console.log('');
    console.log('Dash shorthands (sp- expands to superpowers-):');
    console.log('  sp-doctor               → superpowers-doctor (normal resolution)');
    console.log('  spp-doctor              → superpowers-doctor from superpowers-plus source');
    console.log('  spc-doctor              → superpowers-doctor from overlay source\n');
    console.log(`Summary: ${superpowers.length} superpowers, ${explicitSkills.length} explicit skills, ${deduped.length} total`);
}


// High-cost skill warning (one-time per installation)
function getHighCostSkills() {
    // Try installed location first, then source repo
    const locations = [
        path.join(homeDir, '.codex', 'superpowers-plus', 'tools', 'high-cost-skills.json'),
        path.join(__dirname, 'tools', 'high-cost-skills.json'),
    ];
    for (const loc of locations) {
        if (fs.existsSync(loc)) {
            try { return JSON.parse(fs.readFileSync(loc, 'utf8')); } catch { /* ignore */ }
        }
    }
    return [];
}

function showHighCostWarningOnce(skillName) {
    const highCost = getHighCostSkills();
    // Normalize: strip prefixes to get bare skill name
    const bare = skillName.replace(/^(superpowers:|spp:|spc:|sp-|spp-|spc-)/, '');
    if (!highCost.includes(bare)) return;

    // Check if warning already shown
    try { fs.mkdirSync(COST_WARNINGS_DIR, { recursive: true }); } catch { /* exists */ }
    const markerFile = path.join(COST_WARNINGS_DIR, bare);
    if (fs.existsSync(markerFile)) return;

    // Show warning and create marker
    console.error('');
    console.error(`⚠️  HIGH TOKEN COST: "${bare}" is a high-cost skill.`);
    console.error('   It loads references, chains to other skills, or spawns sub-agents.');
    console.error('   See docs/SKILL_TOKEN_COSTS.md for details.');
    console.error('   (This warning appears once per skill per installation.)');
    console.error('');
    try { fs.writeFileSync(markerFile, new Date().toISOString()); } catch { /* best effort */ }
}

function useSkill(skillName) {
    if (!skillName) {
        console.error('Error: skill name required');
        console.error('Usage: superpowers-augment use-skill <skill-name>');
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
        console.error('Then retry: use-skill ' + skillName);
        console.error('');
        console.error('WHY: Bootstrap loads the using-superpowers skill which governs');
        console.error('skill invocation discipline, priority ordering, and red-flag');
        console.error('detection. Without it, skills fire in isolation without the');
        console.error('meta-framework that makes them effective.');
        console.error('');
        // Don't block — still load the skill, but the warning is impossible to miss
    }

    // Namespace prefix resolution
    // superpowers:name → obra/superpowers skills only
    // spp:name         → superpowers-plus source repo only
    // spc:name         → overlay source repo only (set SPC_SOURCE_DIR)
    // name (no prefix) → installed dir (overlay overrides plus) → obra
    //
    // Dash shorthand (prefix expansion for fewer keystrokes):
    // sp-X   → expands to superpowers-X, normal resolution
    // spp-X  → expands to superpowers-X, spp: resolution
    // spc-X  → expands to superpowers-X, spc: resolution
    let forceSuperpowers = skillName.startsWith('superpowers:');
    let forceSpp = skillName.startsWith('spp:');
    let forceSpc = skillName.startsWith('spc:');
    let actualName;

    // Dash shorthand expansion: spp-X → spp:superpowers-X, spc-X → spc:superpowers-X, sp-X → superpowers-X
    if (!forceSuperpowers && !forceSpp && !forceSpc) {
        if (skillName.startsWith('spp-')) {
            forceSpp = true;
            actualName = 'superpowers-' + skillName.slice(4);
        } else if (skillName.startsWith('spc-')) {
            forceSpc = true;
            actualName = 'superpowers-' + skillName.slice(4);
        } else if (skillName.startsWith('sp-')) {
            actualName = 'superpowers-' + skillName.slice(3);
        }
    }

    if (!actualName) {
        if (forceSuperpowers) actualName = skillName.replace(/^superpowers:/, '');
        else if (forceSpp) actualName = skillName.replace(/^spp:/, '');
        else if (forceSpc) actualName = skillName.replace(/^spc:/, '');
        else actualName = skillName;
    }

    let skillFile = null;

    if (forceSpp) {
        // spp: → search superpowers-plus source repo only
        if (!SPP_SOURCE_DIR) {
            console.error('Error: spp: prefix used but superpowers-plus source repo not found.');
            console.error('Set SPP_SOURCE_DIR env var or clone to ~/GitHub/Personal/superpowers-plus');
            process.exit(1);
        }
        skillFile = findSkillInSourceRepo(SPP_SOURCE_DIR, actualName);
    } else if (forceSpc) {
        // spc: → search overlay source repo only
        if (!SPC_SOURCE_DIR) {
            console.error('Error: spc: prefix used but overlay source repo not found.');
            console.error('Set SPC_SOURCE_DIR env var to point to your overlay skill repo');
            process.exit(1);
        }
        skillFile = findSkillInSourceRepo(SPC_SOURCE_DIR, actualName);
    } else if (!forceSuperpowers) {
        // No prefix → personal/installed dir first (overlay overrides plus)
        const personalDir = path.join(PERSONAL_SKILLS_DIR, actualName);
        const personalFile = findSkillFile(personalDir);
        if (personalFile) skillFile = personalFile;
    }

    if (!skillFile && !forceSpp && !forceSpc) {
        // Fall through to obra/superpowers
        const superpowersDir = path.join(SUPERPOWERS_SKILLS_DIR, actualName);
        const superpowersFile = findSkillFile(superpowersDir);
        if (superpowersFile) skillFile = superpowersFile;
    }
    // Fallback: if superpowers: prefix was used but skill not found in superpowers dir,
    // check personal dir too (personal skills with triggers are listed as superpowers)
    if (!skillFile && forceSuperpowers) {
        const personalDir = path.join(PERSONAL_SKILLS_DIR, actualName);
        const personalFile = findSkillFile(personalDir);
        if (personalFile) skillFile = personalFile;
    }
    if (!skillFile) {
        console.error('Error: Skill "' + skillName + '" not found');
        if (forceSpp) console.error('Searched superpowers-plus source: ' + SPP_SOURCE_DIR);
        if (forceSpc) console.error('Searched overlay source: ' + SPC_SOURCE_DIR);
        console.error('Run "superpowers-augment find-skills" to see available skills');
        process.exit(1);
    }
    showHighCostWarningOnce(actualName);
    const content = fs.readFileSync(skillFile, 'utf8');
    const stripped = stripFrontmatter(content);
    const transformed = transformOutput(stripped);
    console.log('# Skill: ' + skillName + '\n');
    console.log(transformed);

}

function bootstrap() {
    console.log('# Superpowers Bootstrap\n');
    console.log('Loading skill system for Augment Code...\n');
    writeSessionMarker();
    const usingSuperpowersFile = findSkillFile(path.join(SUPERPOWERS_SKILLS_DIR, 'using-superpowers'));
    if (usingSuperpowersFile) {
        const content = fs.readFileSync(usingSuperpowersFile, 'utf8');
        const stripped = stripFrontmatter(content);
        // Strip DOT graph blocks (```dot ... ```) — not renderable in text
        const noDotGraph = stripped.replace(/```dot[\s\S]*?```/g, '');
        const transformed = transformOutput(noDotGraph);
        console.log(transformed);
        console.log('\n---\n');
    }
    // Compact catalog: names only (descriptions available via find-skills)
    findSkillsCompact();

}

function findSkillsCompact() {
    const personalSkills = findSkillsInDir(PERSONAL_SKILLS_DIR, 'personal');
    const superpowersSkills = findSkillsInDir(SUPERPOWERS_SKILLS_DIR, 'superpowers');
    const allSkills = [...personalSkills, ...superpowersSkills];
    const seen = new Set();
    const deduped = [];
    for (const skill of allSkills) {
        if (seen.has(skill.name)) continue;
        seen.add(skill.name);
        deduped.push(skill);
    }
    const superpowers = deduped.filter(s => s.isSuperpower);
    const explicitSkills = deduped.filter(s => !s.isSuperpower);

    console.log(`🦸 ${superpowers.length} superpowers (auto-triggered): ` +
        superpowers.map(s => s.sourceType === 'superpowers' ? 'superpowers:' + s.name : s.name).join(', '));
    console.log(`\n🔧 ${explicitSkills.length} explicit skills: ` +
        explicitSkills.map(s => s.sourceType === 'superpowers' ? 'superpowers:' + s.name : s.name).join(', '));
    console.log('\nUse `find-skills` for descriptions. Use `use-skill <name>` to load a skill.');
    console.log(`\nSummary: ${superpowers.length} superpowers, ${explicitSkills.length} explicit skills, ${deduped.length} total`);
}



const command = process.argv[2];
const args = process.argv.slice(3);

switch (command) {
    case 'bootstrap': bootstrap(); break;
    case 'use-skill': useSkill(args[0]); break;
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
        const personalSkills = findSkillsInDir(PERSONAL_SKILLS_DIR, 'personal');
        const superpowersSkills = findSkillsInDir(SUPERPOWERS_SKILLS_DIR, 'superpowers');
        const allSkills = [...personalSkills, ...superpowersSkills];

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
        const personalSkills = findSkillsInDir(PERSONAL_SKILLS_DIR, 'personal');
        const superpowersSkills = findSkillsInDir(SUPERPOWERS_SKILLS_DIR, 'superpowers');
        const allSkills = [...personalSkills, ...superpowersSkills];
        const seen = new Set();
        const skills = allSkills.filter(s => {
            if (seen.has(s.name)) return false;
            seen.add(s.name);
            return true;
        });

        // Determine method
        let method = 'auto';
        if (useTfidf) method = 'tfidf';
        if (useEmbedding) method = 'embedding';

        const routerInfo = getRouterInfo();
        const actualMethod = method === 'auto' ? routerInfo.default : method;

        semanticMatch(query, skills, { topN: 5, method })
            .then(matches => {
                console.log(`# Skill Match Results\n`);
                console.log(`Query: "${query}"`);
                console.log(`Method: ${actualMethod.toUpperCase()}${method === 'auto' ? ' (auto-selected)' : ''}\n`);
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
                console.log(`\nTo use: \`superpowers-augment use-skill ${matches[0]?.name}\``);
            })
            .catch(err => {
                console.error('Error:', err.message);
                process.exit(1);
            });
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
        const personalSkills = findSkillsInDir(PERSONAL_SKILLS_DIR, 'personal');
        const superpowersSkills = findSkillsInDir(SUPERPOWERS_SKILLS_DIR, 'superpowers');
        const allSkills = [...personalSkills, ...superpowersSkills];
        const seen = new Set();
        const skills = allSkills.filter(s => {
            if (seen.has(s.name)) return false;
            seen.add(s.name);
            return true;
        });

        const forceRefresh = args.includes('--force');
        console.log(`Embedding ${skills.length} skills...${forceRefresh ? ' (force refresh)' : ''}`);
        console.log('(Requires OPENAI_API_KEY)\n');

        embedSkills(skills, forceRefresh)
            .then(cache => {
                const count = Object.keys(cache.embeddings).length;
                console.log(`\n✅ Embedded ${count} skills`);
                console.log(`Cache: ~/.codex/.skill-embeddings.json`);
            })
            .catch(err => {
                console.error('Error:', err.message);
                if (err.message.includes('OPENAI_API_KEY')) {
                    console.error('\nNote: Embedding is optional. TF-IDF mode works without an API key.');
                    console.error('Run: match-skills --tfidf "your query"');
                }
                process.exit(1);
            });
        break;
    }

    default:
        console.log('Superpowers for Augment\n');
        console.log('Usage:');
        console.log('  node superpowers-augment.js bootstrap              # Initialize session');
        console.log('  node superpowers-augment.js use-skill <name>       # Load a specific skill');
        console.log('  node superpowers-augment.js use-skill sp-<name>   # sp-X → superpowers-X shorthand');
        console.log('  node superpowers-augment.js use-skill spp:<name>  # Load from superpowers-plus source');
        console.log('  node superpowers-augment.js use-skill spc:<name>  # Load from overlay source repo');
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
