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
        let name = '';
        let description = '';
        let triggers = [];
        for (const line of lines) {
            if (line.trim() === '---') {
                if (inFrontmatter) break;
                inFrontmatter = true;
                continue;
            }
            if (inFrontmatter) {
                // Check for triggers array
                const triggersMatch = line.match(/^triggers:\s*\[(.+)\]/);
                if (triggersMatch) {
                    // Extract quoted strings from the array
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
        return { name, description, triggers };
    } catch (error) {
        return { name: '', description: '', triggers: [] };
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
            console.log();
        }

        if (report.suggestions.length > 0) {
            console.log('## 💡 Pending Suggestions\n');
            for (const s of report.suggestions) {
                console.log(`- [${s.type}] ${s.skill}: "${s.suggested}" (${s.evidence_count} observations)`);
            }
        }
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
        console.log('Learning System:');
        console.log('  node superpowers-augment.js record-outcome <skill> <success|failure> [evidence]');
        console.log('  node superpowers-augment.js analyze-triggers       # Show trigger effectiveness');
        console.log('  node superpowers-augment.js suggest-trigger <skill> <phrase>');
        console.log('  node superpowers-augment.js record-pattern <pattern> [skill]  # Track recurring patterns');
        console.log('  node superpowers-augment.js learning-report        # Full effectiveness report');
        console.log('  node superpowers-augment.js learning-status        # Show learning state info');
        break;
}
