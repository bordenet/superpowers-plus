#!/usr/bin/env node
/**
 * superpowers-augment.js - Skill loader for Augment Code
 * Replaces the old superpowers-codex wrapper with direct skill discovery
 * Compatible with obra/superpowers v4.2.0+
 */
const fs = require('fs');
const path = require('path');
const os = require('os');

// Learning state for skill effectiveness tracking
const {
  readState,
  recordOutcome,
  getMetricsSummary,
  addSuggestion,
  recordPattern,
  getSkillsNeedingAttention,
  generateTriggerReport
} = require('./lib/learning-state');

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

const TOOL_MAPPINGS = [
    [/\bTodoWrite\b/g, 'add_tasks/update_tasks'],
    [/\bTodoRead\b/g, 'view_tasklist'],
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
    console.log('  Personal skills override superpowers skills when names match.\n');
    console.log(`Summary: ${superpowers.length} superpowers, ${explicitSkills.length} explicit skills, ${deduped.length} total`);
}

function useSkill(skillName) {
    if (!skillName) {
        console.error('Error: skill name required');
        console.error('Usage: superpowers-augment use-skill <skill-name>');
        process.exit(1);
    }
    const forceSuperpowers = skillName.startsWith('superpowers:');
    const actualName = forceSuperpowers ? skillName.replace(/^superpowers:/, '') : skillName;
    let skillFile = null;
    if (!forceSuperpowers) {
        const personalDir = path.join(PERSONAL_SKILLS_DIR, actualName);
        const personalFile = findSkillFile(personalDir);
        if (personalFile) skillFile = personalFile;
    }
    if (!skillFile) {
        const superpowersDir = path.join(SUPERPOWERS_SKILLS_DIR, actualName);
        const superpowersFile = findSkillFile(superpowersDir);
        if (superpowersFile) skillFile = superpowersFile;
    }
    if (!skillFile) {
        console.error('Error: Skill "' + skillName + '" not found');
        console.error('Run "superpowers-augment find-skills" to see available skills');
        process.exit(1);
    }
    const content = fs.readFileSync(skillFile, 'utf8');
    const stripped = stripFrontmatter(content);
    const transformed = transformOutput(stripped);
    console.log('# Skill: ' + skillName + '\n');
    console.log(transformed);
}

function bootstrap() {
    console.log('# Superpowers Bootstrap\n');
    console.log('Loading skill system for Augment Code...\n');
    const usingSuperpowersFile = findSkillFile(path.join(SUPERPOWERS_SKILLS_DIR, 'using-superpowers'));
    if (usingSuperpowersFile) {
        const content = fs.readFileSync(usingSuperpowersFile, 'utf8');
        const stripped = stripFrontmatter(content);
        const transformed = transformOutput(stripped);
        console.log(transformed);
        console.log('\n---\n');
    }
    findSkills();

    // Show learning insights
    showLearningInsights();
}

/**
 * Analyze trigger effectiveness across all skills
 */
function analyzeTriggers() {
    const state = readState();
    console.log('# Trigger Effectiveness Analysis\n');

    const skills = Object.entries(state.trigger_metrics);
    if (skills.length === 0) {
        console.log('No data yet. Record outcomes with:');
        console.log('  superpowers-augment record-outcome <skill> <success|failure> [evidence]\n');
        return;
    }

    // Sort by total fires descending
    skills.sort((a, b) => b[1].total_fires - a[1].total_fires);

    console.log('| Skill | Fires | Success | Fail | Rate | Status |');
    console.log('|-------|-------|---------|------|------|--------|');

    for (const [skill, m] of skills) {
        const rate = (m.success_rate * 100).toFixed(0);
        let status;
        if (m.success_rate >= 0.8) status = '✅ Healthy';
        else if (m.success_rate >= 0.5) status = '🟡 Monitor';
        else status = '🔴 Needs work';

        console.log(`| ${skill} | ${m.total_fires} | ${m.successes} | ${m.failures} | ${rate}% | ${status} |`);
    }

    // Show common triggers
    console.log('\n## Common Trigger Phrases\n');
    for (const [skill, m] of skills) {
        if (m.common_triggers.length > 0) {
            console.log(`**${skill}:** ${m.common_triggers.slice(0, 5).map(t => `"${t}"`).join(', ')}`);
        }
    }

    // Show suggestions
    const suggestions = state.skill_suggestions.filter(s => s.status === 'pending');
    if (suggestions.length > 0) {
        console.log('\n## Suggested Improvements\n');
        for (const s of suggestions) {
            console.log(`- [${s.type}] Add "${s.suggested}" to ${s.skill} (${s.evidence_count} observations)`);
        }
    }

    // Recent outcomes
    const recent = state.outcomes.slice(-5).reverse();
    if (recent.length > 0) {
        console.log('\n## Recent Outcomes\n');
        for (const o of recent) {
            const icon = o.outcome === 'success' ? '✅' : '❌';
            const date = new Date(o.timestamp).toLocaleDateString();
            console.log(`${icon} ${o.skill} (${date}): ${o.evidence || 'no evidence'}`);
        }
    }
}

/**
 * Show learning insights during bootstrap
 */
function showLearningInsights() {
    const state = readState();
    const metrics = Object.entries(state.trigger_metrics);

    if (metrics.length === 0) return;

    console.log('\n---\n');
    console.log('📊 **Learning Insights**\n');
    console.log('Based on recorded outcomes. Use `record-outcome <skill> success|failure` after skill-guided work.\n');

    // Low performers (< 70% success rate with at least 3 fires)
    const lowPerformers = metrics.filter(([_, m]) => m.success_rate < 0.7 && m.total_fires >= 3);
    if (lowPerformers.length > 0) {
        console.log('⚠️ Skills needing attention (<70% success):');
        for (const [skill, m] of lowPerformers) {
            console.log(`  - ${skill}: ${(m.success_rate * 100).toFixed(0)}% success (${m.total_fires} fires)`);
        }
        console.log();
    }

    // Top performers (>= 90% success rate with at least 5 fires)
    const topPerformers = metrics.filter(([_, m]) => m.success_rate >= 0.9 && m.total_fires >= 5);
    if (topPerformers.length > 0) {
        console.log('✅ Top performing skills (90%+ success):');
        for (const [skill, m] of topPerformers) {
            console.log(`  - ${skill}: ${(m.success_rate * 100).toFixed(0)}% success (${m.total_fires} fires)`);
        }
        console.log();
    }

    // Total stats
    const totalFires = metrics.reduce((sum, [_, m]) => sum + m.total_fires, 0);
    const totalSuccesses = metrics.reduce((sum, [_, m]) => sum + m.successes, 0);
    const overallRate = totalFires > 0 ? ((totalSuccesses / totalFires) * 100).toFixed(0) : 0;
    console.log(`📈 Overall: ${totalFires} skill fires, ${overallRate}% success rate`);
    console.log('   Run `superpowers-augment analyze-triggers` for detailed analysis\n');
}

const command = process.argv[2];
const args = process.argv.slice(3);

switch (command) {
    case 'bootstrap': bootstrap(); break;
    case 'use-skill': useSkill(args[0]); break;
    case 'find-skills': findSkills(args[0] || 'all'); break;
    case 'list-superpowers': findSkills('superpowers'); break;
    case 'list-skills': findSkills('explicit'); break;

    // Learning system commands
    case 'record-outcome': {
        const skill = args[0];
        const outcome = args[1]; // success | failure
        const evidence = args.slice(2).join(' ') || '';
        if (!skill || !outcome || !['success', 'failure'].includes(outcome)) {
            console.error('Usage: record-outcome <skill> <success|failure> [evidence]');
            console.error('Example: record-outcome systematic-debugging success "bug fixed, tests pass"');
            process.exit(1);
        }
        const id = recordOutcome(skill, outcome, evidence);
        const icon = outcome === 'success' ? '✅' : '❌';
        console.log(`${icon} Recorded ${outcome} for ${skill}`);
        console.log(`   ID: ${id}`);
        const metrics = getMetricsSummary()[skill];
        if (metrics) {
            console.log(`   Success rate: ${(metrics.success_rate * 100).toFixed(0)}% (${metrics.total_fires} total)`);
        }
        break;
    }

    case 'analyze-triggers':
        analyzeTriggers();
        break;

    case 'suggest-trigger': {
        const skill = args[0];
        const trigger = args.slice(1).join(' ');
        if (!skill || !trigger) {
            console.error('Usage: suggest-trigger <skill> <trigger-phrase>');
            process.exit(1);
        }
        addSuggestion('new_trigger', skill, trigger, 1);
        console.log(`💡 Suggestion recorded: Add "${trigger}" to ${skill}`);
        break;
    }

    case 'learning-status': {
        const state = readState();
        console.log('# Learning State Status\n');
        console.log(`Last updated: ${state.last_updated}`);
        console.log(`Outcomes recorded: ${state.outcomes.length}`);
        console.log(`Skills tracked: ${Object.keys(state.trigger_metrics).length}`);
        console.log(`Pending suggestions: ${state.skill_suggestions.filter(s => s.status === 'pending').length}`);
        console.log(`Patterns observed: ${state.pattern_observations.length}`);
        break;
    }

    case 'record-pattern': {
        const pattern = args[0];
        const potentialSkill = args[1] || 'unknown';
        if (!pattern) {
            console.error('Usage: record-pattern "pattern description" [potential-skill-name]');
            process.exit(1);
        }
        recordPattern(pattern, potentialSkill);
        console.log(`📝 Pattern recorded: "${pattern}"`);
        console.log(`   Potential skill: ${potentialSkill}`);
        break;
    }

    case 'learning-report': {
        const report = generateTriggerReport();
        console.log('# Skill Effectiveness Report\n');
        console.log(`Generated: ${report.generated_at}\n`);

        console.log('## Overall Stats\n');
        console.log(`Total skill fires: ${report.overall.total_fires}`);
        console.log(`Successes: ${report.overall.total_successes}`);
        console.log(`Failures: ${report.overall.total_failures}`);
        console.log(`Success rate: ${(report.overall.success_rate * 100).toFixed(1)}%\n`);

        const issues = getSkillsNeedingAttention();
        if (issues.length > 0) {
            console.log('## ⚠️ Skills Needing Attention\n');
            for (const issue of issues) {
                console.log(`- ${issue.message}`);
            }
            console.log();
        }

        if (report.patterns.length > 0) {
            console.log('## 🔮 Emerging Patterns (potential new skills)\n');
            for (const p of report.patterns) {
                console.log(`- "${p.pattern}" (${p.frequency}x) → ${p.potential_skill}`);
            }
            console.log('\n💡 Run `superpowers-augment check-synthesis-candidates` to create skills from patterns.\n');
        }

        if (report.suggestions.length > 0) {
            console.log('## 💡 Pending Suggestions\n');
            for (const s of report.suggestions) {
                console.log(`- [${s.type}] ${s.skill}: "${s.suggested}" (${s.evidence_count} observations)`);
            }
        }
        break;
    }

    case 'check-synthesis-candidates': {
        const state = readState();
        const candidates = state.pattern_observations.filter(
            p => p.frequency >= 3 && p.status !== 'synthesized'
        );

        console.log('# Skill Synthesis Candidates\n');

        if (candidates.length === 0) {
            console.log('No synthesis candidates found.\n');
            console.log('Candidates appear when patterns are recorded 3+ times.');
            console.log('Record patterns with: `superpowers-augment record-pattern "description" potential-skill-name`\n');
            break;
        }

        console.log('These patterns have been observed frequently and may be worth codifying as skills:\n');
        console.log('| # | Pattern | Freq | Suggested Name | Last Seen |');
        console.log('|---|---------|------|----------------|-----------|');

        for (let i = 0; i < candidates.length; i++) {
            const p = candidates[i];
            const lastSeen = new Date(p.last_seen).toLocaleDateString();
            const truncPattern = p.pattern.length > 50 ? p.pattern.slice(0, 47) + '...' : p.pattern;
            console.log(`| ${i + 1} | ${truncPattern} | ${p.frequency}x | ${p.potential_skill} | ${lastSeen} |`);
        }

        console.log('\n## Next Steps\n');
        console.log('To create a skill from a pattern:\n');
        console.log('1. Review the pattern description above');
        console.log('2. Invoke skill-authoring Mode 2:');
        console.log('   ```');
        console.log('   "Turn this pattern into a skill: [pattern description]"');
        console.log('   ```');
        console.log('3. The skill-authoring skill will guide you through synthesis\n');

        if (candidates.length > 0) {
            const top = candidates[0];
            console.log(`**Top candidate:** "${top.pattern}" (${top.frequency}x)`);
            console.log(`\nTo synthesize this now, tell me:`);
            console.log(`> "Turn this pattern into a skill: ${top.pattern}"`);
        }
        break;
    }

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
        console.log('');
        console.log('Learning System:');
        console.log('  node superpowers-augment.js record-outcome <skill> <success|failure> [evidence]');
        console.log('  node superpowers-augment.js analyze-triggers       # Show trigger effectiveness');
        console.log('  node superpowers-augment.js suggest-trigger <skill> <phrase>');
        console.log('  node superpowers-augment.js record-pattern <pattern> [skill]  # Track recurring patterns');
        console.log('  node superpowers-augment.js learning-report        # Full effectiveness report');
        console.log('  node superpowers-augment.js learning-status        # Show learning state info');
        console.log('  node superpowers-augment.js check-synthesis-candidates  # Find patterns ready for skill synthesis');
        break;
}
