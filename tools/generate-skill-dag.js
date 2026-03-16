#!/usr/bin/env node

// Skill Dependency Graph Generator
// Parses all skills/*/*/skill.md files, extracts coordination fields,
// and generates a Mermaid diagram showing skill relationships.
// Usage: node tools/generate-skill-dag.js

const fs = require('fs');
const path = require('path');

const SKILLS_DIR = path.join(__dirname, '..', 'skills');
const DEFAULT_OUTPUT = path.join(__dirname, '..', 'docs', 'skill-dependency-graph.md');

function parseFrontmatter(content) {
  const match = content.match(/^---\n([\s\S]*?)\n---/);
  if (!match) return null;
  try {
    const lines = match[1].split('\n');
    const result = {};
    let currentKey = null;
    let inCoordination = false;
    let coordObj = {};

    for (const line of lines) {
      if (line.startsWith('coordination:')) {
        inCoordination = true;
        coordObj = {};
        continue;
      }
      if (inCoordination) {
        if (line.match(/^[a-z]/)) {
          inCoordination = false;
          result.coordination = coordObj;
        } else {
          const coordMatch = line.match(/^\s+(\w+):\s*(.*)$/);
          if (coordMatch) {
            let val = coordMatch[2].trim();
            if (val.startsWith('[')) {
              val = val.replace(/[\[\]"]/g, '').split(',').map(s => s.trim()).filter(Boolean);
            } else if (val === 'true') val = true;
            else if (val === 'false') val = false;
            else if (/^\d+$/.test(val)) val = parseInt(val);
            coordObj[coordMatch[1]] = val;
          }
        }
      }
      const keyMatch = line.match(/^(\w+):\s*(.*)$/);
      if (keyMatch && !inCoordination) {
        let val = keyMatch[2].trim();
        if (val.startsWith('[')) {
          val = val.replace(/[\[\]"]/g, '').split(',').map(s => s.trim());
        }
        result[keyMatch[1]] = val;
      }
    }
    if (inCoordination) result.coordination = coordObj;
    return result;
  } catch (e) {
    return null;
  }
}

function findSkillFiles(dir) {
  const files = [];
  try {
    const entries = fs.readdirSync(dir, { withFileTypes: true });
    for (const entry of entries) {
      const fullPath = path.join(dir, entry.name);
      if (entry.isDirectory() && !entry.name.startsWith('_')) {
        files.push(...findSkillFiles(fullPath));
      } else if (entry.name === 'skill.md') {
        files.push(fullPath);
      }
    }
  } catch (e) {}
  return files;
}

function extractSkillData() {
  const skillFiles = findSkillFiles(SKILLS_DIR);
  const skills = [];
  for (const file of skillFiles) {
    const content = fs.readFileSync(file, 'utf8');
    const fm = parseFrontmatter(content);
    if (fm && fm.name) {
      skills.push({
        name: fm.name,
        path: path.relative(SKILLS_DIR, file),
        coordination: fm.coordination || null,
        triggers: fm.triggers || [],
      });
    }
  }
  return skills;
}

function formatGroupName(name) {
  return name.split('-').map(w => w.charAt(0).toUpperCase() + w.slice(1)).join(' ');
}

function generateMermaid(skills) {
  const lines = ['graph TD'];
  const groups = {};

  for (const skill of skills) {
    if (skill.coordination && skill.coordination.group) {
      if (!groups[skill.coordination.group]) groups[skill.coordination.group] = [];
      groups[skill.coordination.group].push(skill);
    }
  }

  for (const group of Object.values(groups)) {
    group.sort((a, b) => (a.coordination.order || 99) - (b.coordination.order || 99));
  }

  for (const [groupName, groupSkills] of Object.entries(groups)) {
    lines.push('  subgraph ' + groupName + '["' + formatGroupName(groupName) + '"]');
    for (const skill of groupSkills) {
      const nodeId = skill.name.replace(/-/g, '_');
      const label = skill.coordination.internal ? skill.name + ' [internal]' : skill.name;
      lines.push('    ' + nodeId + '["' + label + '"]');
    }
    lines.push('  end');
    lines.push('');
  }

  // Track edges to avoid duplicates
  var edges = {};
  for (const skill of skills) {
    if (!skill.coordination) continue;
    const fromId = skill.name.replace(/-/g, '_');

    // requires: arrow FROM required skill TO this skill (required runs first)
    for (const req of skill.coordination.requires || []) {
      const reqId = req.replace(/-/g, '_');
      const edge = reqId + ' --> ' + fromId;
      if (!edges[edge]) {
        lines.push('  ' + reqId + ' -->|then| ' + fromId);
        edges[edge] = true;
      }
    }

    // escalates_to: thick arrow FROM this skill TO fallback
    for (const esc of skill.coordination.escalates_to || []) {
      const escId = esc.replace(/-/g, '_');
      const edge = fromId + ' ==> ' + escId;
      if (!edges[edge]) {
        lines.push('  ' + fromId + ' ==>|escalates to| ' + escId);
        edges[edge] = true;
      }
    }
  }
  return lines.join('\n');
}

function getGroupPurpose(group) {
  var purposes = {
    'commit-gates': 'Quality checks before git commit',
    'wiki-pipeline': 'Wiki authoring quality pipeline',
    'stuck-escalation': 'Getting unstuck when blocked',
  };
  return purposes[group] || 'Coordinated skill group';
}

function generateMarkdown(skills, mermaid) {
  var coordinated = skills.filter(function(s) { return s.coordination; });
  var groupSet = {};
  coordinated.forEach(function(s) { groupSet[s.coordination.group] = true; });
  var groups = Object.keys(groupSet);
  var today = new Date().toISOString().split('T')[0];

  var groupTable = groups.map(function(g) {
    var gSkills = coordinated.filter(function(s) { return s.coordination.group === g; });
    var names = gSkills.map(function(s) { return '`' + s.name + '`'; }).join(', ');
    return '| ' + formatGroupName(g) + ' | ' + names + ' | ' + getGroupPurpose(g) + ' |';
  }).join('\n');

  return '# Skill Dependency Graph\n\n' +
    '> **Auto-generated** by `tools/generate-skill-dag.js`\n' +
    '> **Last updated:** ' + today + '\n\n' +
    'This document visualizes the coordination relationships between skills in superpowers-plus.\n\n' +
    '## Diagram\n\n' +
    '```mermaid\n' + mermaid + '\n```\n\n' +
    '## Coordination Groups\n\n' +
    '| Group | Skills | Purpose |\n' +
    '|-------|--------|---------|' + '\n' +
    groupTable + '\n\n' +
    '## Legend\n\n' +
    '| Edge Type | Meaning |\n' +
    '|-----------|---------|' + '\n' +
    '| `-->` solid | "enables" — this skill unlocks the next |\n' +
    '| `-.->` dashed | "requires" — must run before |\n' +
    '| `==>` thick | "escalates to" — fallback if insufficient |\n' +
    '| `[internal]` | Not user-invocable; called by other skills |\n\n' +
    '## Namespaced Triggers\n\n' +
    'Skills now support namespaced triggers (`domain:action`) for disambiguation:\n\n' +
    '| Domain | Example Triggers |\n' +
    '|--------|------------------|' + '\n' +
    '| `commit:` | `commit:pre-check`, `commit:style`, `commit:language`, `commit:ip-audit` |\n' +
    '| `wiki:` | `wiki:create`, `wiki:update`, `wiki:edit-internal`, `wiki:verify-links` |\n' +
    '| `stuck:` | `stuck:reasoning`, `stuck:research`, `stuck:knowledge` |\n\n' +
    '## Regenerating This Document\n\n' +
    '```bash\nnode tools/generate-skill-dag.js\n```\n';
}

// Main
var skills = extractSkillData();
var mermaid = generateMermaid(skills);
var markdown = generateMarkdown(skills, mermaid);

var outputPath = process.argv[2] === '--output' ? process.argv[3] : DEFAULT_OUTPUT;
var outputDir = path.dirname(outputPath);
if (!fs.existsSync(outputDir)) fs.mkdirSync(outputDir, { recursive: true });
fs.writeFileSync(outputPath, markdown);

console.log('Generated skill dependency graph: ' + outputPath);
console.log('  - ' + skills.length + ' total skills');
console.log('  - ' + skills.filter(function(s) { return s.coordination; }).length + ' with coordination');
