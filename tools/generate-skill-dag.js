#!/usr/bin/env node

// Skill Dependency Graph Generator
// Parses all skills/*/*/skill.md files, extracts coordination fields,
// and generates a Mermaid diagram showing skill relationships.
// Usage: node tools/generate-skill-dag.js

const fs = require('fs');
const path = require('path');
const { parseInlineArray, extractStringValue } = require('../lib/frontmatter.js');

const SKILLS_DIR = path.join(__dirname, '..', 'skills');
const DEFAULT_OUTPUT = path.join(__dirname, '..', 'docs', 'skill-dependency-graph.md');

// Unquote a YAML scalar value: strip outer quotes and handle escapes.
function unquoteYaml(s) {
  s = s.trim();
  if (s.startsWith('"') && s.endsWith('"'))
    return s.slice(1, -1).replace(/\\"/g, '"').replace(/\\\\/g, '\\');
  if (s.startsWith("'") && s.endsWith("'"))
    return s.slice(1, -1).replace(/''/g, "'");
  return s;
}

function parseFrontmatter(content) {
  // Normalize CRLF/CR to LF before parsing
  content = content.replace(/\r\n/g, '\n').replace(/\r/g, '\n');
  const match = content.match(/^---\n([\s\S]*?)\n---/);
  if (!match) return null;
  try {
    const lines = match[1].split('\n');
    const result = {};
    let currentKey = null;
    let inCoordination = false;
    let coordObj = {};
    let coordCurrentKey = null;

    for (const line of lines) {
      if (line.startsWith('coordination:')) {
        inCoordination = true;
        coordObj = {};
        coordCurrentKey = null;
        continue;
      }
      if (inCoordination) {
        if (line.match(/^[a-z]/)) {
          inCoordination = false;
          coordCurrentKey = null;
          result.coordination = coordObj;
        } else {
          // Multiline list item: "    - value"
          const listItemMatch = line.match(/^\s+-\s+(.+)$/);
          if (listItemMatch && coordCurrentKey) {
            const item = unquoteYaml(listItemMatch[1].trim());
            if (!Array.isArray(coordObj[coordCurrentKey])) {
              coordObj[coordCurrentKey] = [];
            }
            if (item) coordObj[coordCurrentKey].push(item);
            continue;
          }
          const coordMatch = line.match(/^\s+(\w+):\s*(.*)$/);
          if (coordMatch) {
            coordCurrentKey = coordMatch[1];
            let val = coordMatch[2].trim();
            if (val.startsWith('[')) {
              val = parseInlineArray(val).filter(Boolean); // drop empty strings
            } else if (val === '' || val === undefined) {
              // Empty value — may be followed by multiline list items
              val = [];
            } else if (val === 'true') val = true;
            else if (val === 'false') val = false;
            else if (/^\d+$/.test(val)) val = parseInt(val);
            else val = unquoteYaml(val);
            coordObj[coordCurrentKey] = val;
          }
        }
      }
      const keyMatch = line.match(/^(\w+):\s*(.*)$/);
      if (keyMatch && !inCoordination) {
        let val = keyMatch[2].trim();
        if (val.startsWith('[')) {
          val = parseInlineArray(val).filter(Boolean);
        }
        result[keyMatch[1]] = (typeof val === 'string') ? unquoteYaml(val) : val;
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
      // Warn about malformed coordination metadata
      if (fm.coordination && !fm.coordination.group) {
        console.error('WARNING: ' + fm.name + ' has coordination block but missing group — skipped from DAG');
      }
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

// One 122-node graph.TD with every group as a subgraph is unreadable at
// GitHub's rendering width (the failure mode this replaces). Instead: one
// small flowchart PER coordination.group (internal edges only), plus a
// separate table of edges that cross group boundaries so no information is
// lost -- decomposition instead of density.
function generateMermaidByGroup(skills) {
  const groups = {};
  const skillGroup = {}; // name -> group, for cross-edge classification

  for (const skill of skills) {
    if (skill.coordination && skill.coordination.group) {
      if (!groups[skill.coordination.group]) groups[skill.coordination.group] = [];
      groups[skill.coordination.group].push(skill);
      skillGroup[skill.name] = skill.coordination.group;
    }
  }

  for (const group of Object.values(groups)) {
    group.sort((a, b) => (a.coordination.order || 99) - (b.coordination.order || 99));
  }

  const crossEdges = [];
  const groupDiagrams = [];

  for (const groupKey of Object.keys(groups).sort()) {
    const groupSkills = groups[groupKey];
    const lines = ['flowchart LR'];
    for (const skill of groupSkills) {
      const nodeId = skill.name.replace(/-/g, '_');
      const label = skill.coordination.internal ? skill.name + ' [internal]' : skill.name;
      lines.push('  ' + nodeId + '["' + label + '"]');
    }

    const edges = {};
    for (const skill of groupSkills) {
      const fromId = skill.name.replace(/-/g, '_');

      // requires: dashed arrow FROM required skill TO this skill (required runs first)
      for (const req of skill.coordination.requires || []) {
        if (skillGroup[req] !== groupKey) {
          crossEdges.push({ from: req, to: skill.name, type: 'requires' });
          continue;
        }
        const reqId = req.replace(/-/g, '_');
        const edge = reqId + '-.->' + fromId;
        if (!edges[edge]) { lines.push('  ' + reqId + ' -.->|then| ' + fromId); edges[edge] = true; }
      }

      // enables: solid arrow FROM this skill TO enabled skill
      for (const en of skill.coordination.enables || []) {
        if (skillGroup[en] !== groupKey) {
          crossEdges.push({ from: skill.name, to: en, type: 'enables' });
          continue;
        }
        const enId = en.replace(/-/g, '_');
        const edge = fromId + '-->' + enId;
        if (!edges[edge]) { lines.push('  ' + fromId + ' -->|enables| ' + enId); edges[edge] = true; }
      }

      // escalates_to: thick arrow FROM this skill TO fallback
      for (const esc of skill.coordination.escalates_to || []) {
        if (skillGroup[esc] !== groupKey) {
          crossEdges.push({ from: skill.name, to: esc, type: 'escalates to' });
          continue;
        }
        const escId = esc.replace(/-/g, '_');
        const edge = fromId + '==>' + escId;
        if (!edges[edge]) { lines.push('  ' + fromId + ' ==>|escalates to| ' + escId); edges[edge] = true; }
      }
    }

    groupDiagrams.push({
      key: groupKey,
      name: formatGroupName(groupKey),
      purpose: getGroupPurpose(groupKey),
      count: groupSkills.length,
      mermaid: lines.join('\n'),
    });
  }

  // De-dup cross edges (same from/to/type can be recorded twice: once from
  // the source group's skip, once implicitly if the target also references
  // it) -- keyed on the triple.
  const seen = {};
  const dedupedCrossEdges = crossEdges.filter(function(e) {
    const k = e.from + '|' + e.type + '|' + e.to;
    if (seen[k]) return false;
    seen[k] = true;
    return true;
  });

  return { groupDiagrams, crossEdges: dedupedCrossEdges };
}

function getGroupPurpose(group) {
  var purposes = {
    'commit-gates': 'Quality checks before git commit',
    'wiki-pipeline': 'Wiki authoring quality pipeline',
    'stuck-escalation': 'Getting unstuck when blocked',
    'completion-gate': 'Verification and TODO maintenance before claiming done',
    'thinking': 'Metacognition and thinking orchestration',
  };
  return purposes[group] || 'Coordinated skill group';
}

function generateMarkdown(skills, dag) {
  var coordinated = skills.filter(function(s) { return s.coordination && s.coordination.group; });
  var groupSet = {};
  coordinated.forEach(function(s) { groupSet[s.coordination.group] = true; });
  var groups = Object.keys(groupSet).filter(function(g) { return g && g !== 'undefined'; }).sort();
  var today = new Date().toISOString().split('T')[0];

  var groupTable = groups.map(function(g) {
    var gSkills = coordinated.filter(function(s) { return s.coordination.group === g; })
      .sort(function(a, b) { return (a.coordination.order || 99) - (b.coordination.order || 99); });
    var names = gSkills.map(function(s) { return '`' + s.name + '`'; }).join(', ');
    return '| ' + formatGroupName(g) + ' | ' + names + ' | ' + getGroupPurpose(g) + ' |';
  }).join('\n');

  var groupDiagramSections = dag.groupDiagrams.map(function(gd) {
    return '### ' + gd.name + ' (' + gd.count + ')\n\n' +
      gd.purpose + '\n\n' +
      '```mermaid\n' + gd.mermaid + '\n```\n';
  }).join('\n');

  var crossEdgeTable = dag.crossEdges.length
    ? dag.crossEdges
        .sort(function(a, b) { return a.from.localeCompare(b.from); })
        .map(function(e) { return '| `' + e.from + '` | ' + e.type + ' | `' + e.to + '` |'; })
        .join('\n')
    : '| _none_ | | |';

  return '# Skill Dependency Graph\n\n' +
    '> **Auto-generated** by `tools/generate-skill-dag.js`\n' +
    '> **Last updated:** ' + today + '\n\n' +
    'This document visualizes the coordination relationships between skills in superpowers-plus. ' +
    'One diagram per `coordination.group` (internal edges only) -- a single graph with all ' +
    (skills.length) + ' skills and every cross-group edge is unreadable at GitHub\'s rendering ' +
    'width, so edges that cross group boundaries are listed in ' +
    '[Cross-Group Edges](#cross-group-edges) below instead of drawn.\n\n' +
    '## Diagrams by Group\n\n' +
    groupDiagramSections + '\n' +
    '## Cross-Group Edges\n\n' +
    'Edges whose source and target skills belong to different coordination groups -- not drawn above to keep each group\'s diagram readable.\n\n' +
    '| From | Edge | To |\n' +
    '|------|------|-----|' + '\n' +
    crossEdgeTable + '\n\n' +
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
var dag = generateMermaidByGroup(skills);
var markdown = generateMarkdown(skills, dag);

var outputPath = process.argv[2] === '--output' ? process.argv[3] : DEFAULT_OUTPUT;
var outputDir = path.dirname(outputPath);
if (!fs.existsSync(outputDir)) fs.mkdirSync(outputDir, { recursive: true });
fs.writeFileSync(outputPath, markdown);

console.log('Generated skill dependency graph: ' + outputPath);
console.log('  - ' + skills.length + ' total skills');
console.log('  - ' + skills.filter(function(s) { return s.coordination; }).length + ' with coordination');
