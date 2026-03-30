#!/usr/bin/env node

/**
 * superpowers-plus MCP Server
 *
 * Exposes all skills from superpowers-plus as MCP tools.
 * Each skill becomes a tool that returns its SKILL.md content.
 *
 * Tools:
 * - find_skills: List all available skills
 * - use_skill: Load a specific skill by name
 * - match_skills: Semantic search for skills by intent (TF-IDF)
 *
 * Environment:
 * - SUPERPOWERS_SKILLS_DIR: Override skills directory path
 */

import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
} from '@modelcontextprotocol/sdk/types.js';
import fs from 'fs';
import path from 'path';
import os from 'os';
import { fileURLToPath } from 'url';
import { createRequire } from 'module';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const require = createRequire(import.meta.url);
const homeDir = os.homedir();

// Import skill router (CommonJS) for semantic matching
const { matchSkillsTfIdf } = require('../lib/skill-router');

// Multi-source skill directories (personal overrides superpowers)
const PERSONAL_SKILLS_DIR = process.env.PERSONAL_SKILLS_DIR || path.join(homeDir, '.codex', 'skills');
const SUPERPOWERS_SKILLS_DIR = process.env.SUPERPOWERS_SKILLS_DIR || path.join(homeDir, '.codex', 'superpowers', 'skills');

// Legacy single-dir compat
const skillsDir = PERSONAL_SKILLS_DIR;

/**
 * Extract YAML frontmatter from a SKILL.md file.
 */
function parseInlineArray(value) {
  return value.match(/"[^"]+"|'[^']+'/g)?.map(item => item.slice(1, -1)) || [];
}

function parseYamlList(lines, startIndex) {
  const values = [];
  let nextIndex = startIndex;

  for (let i = startIndex + 1; i < lines.length; i++) {
    const itemMatch = lines[i].match(/^\s+-\s+(.+)$/);
    if (itemMatch) {
      values.push(itemMatch[1].trim().replace(/^['"]|['"]$/g, ''));
      nextIndex = i;
      continue;
    }
    if (lines[i].trim() === '') {
      nextIndex = i;
      continue;
    }
    break;
  }

  return { values, nextIndex };
}

function extractFrontmatter(filePath) {
  // Parse a YAML-inline array string like '"what\'s next", "I\'m stuck"'
  // into an array of unquoted strings. Handles apostrophes inside double-quoted
  // strings and vice versa. Supports escaped quotes (\" and \').
  function parseInlineArray(inner) {
    const items = [];
    let i = 0;
    while (i < inner.length) {
      // Skip whitespace and commas
      while (i < inner.length && (inner[i] === ' ' || inner[i] === ',' || inner[i] === '\t')) i++;
      if (i >= inner.length) break;
      const quote = inner[i];
      if (quote === '"' || quote === "'") {
        // Quoted string — find matching close quote (same type), respecting escapes
        let val = '';
        i++; // skip opening quote
        while (i < inner.length) {
          if (inner[i] === '\\' && i + 1 < inner.length) {
            // Escaped character — include the literal char after backslash
            val += inner[i + 1];
            i += 2;
          } else if (inner[i] === quote) {
            i++; // skip closing quote
            break;
          } else {
            val += inner[i];
            i++;
          }
        }
        if (val) items.push(val);
      } else {
        // Unquoted — read until comma or end
        let val = '';
        while (i < inner.length && inner[i] !== ',') { val += inner[i]; i++; }
        val = val.trim();
        if (val) items.push(val);
      }
    }
    return items;
  }

  // Strip surrounding YAML quotes and unescape: "value" or 'value' → value
  function unquoteYaml(s) {
    if (s.startsWith('"') && s.endsWith('"')) {
      return s.slice(1, -1).replace(/\\"/g, '"').replace(/\\\\/g, '\\');
    }
    if (s.startsWith("'") && s.endsWith("'")) {
      return s.slice(1, -1).replace(/''/g, "'"); // YAML single-quote escaping
    }
    return s;
  }

  try {
    const content = fs.readFileSync(filePath, 'utf8');
    const lines = content.replace(/\r\n/g, '\n').replace(/\r/g, '\n').split('\n');
    let inFrontmatter = false;
    let name = '';
    let description = '';
    let triggers = [];
    let compress = true;
    let triggerAccum = null; // accumulates bracket-multiline trigger arrays
    let yamlListField = null; // tracks which field is accumulating YAML-list items

    for (let i = 0; i < lines.length; i++) {
      const line = lines[i];
      if (line.trim() === '---') {
        if (inFrontmatter) break;
        inFrontmatter = true;
        continue;
      }
      if (inFrontmatter) {
        // Handle bracket-multiline accumulation: triggers: [\n  "a",\n  "b"\n]
        if (triggerAccum !== null) {
          triggerAccum += ' ' + line.trim();
          if (line.includes(']')) {
            const inner = triggerAccum.match(/\[(.+)\]/)?.[1] || '';
            triggers = parseInlineArray(inner);
            triggerAccum = null;
          }
          continue;
        }

        // Handle YAML-list accumulation: triggers:\n  - item\n  - item
        if (yamlListField && line.match(/^\s+-\s/)) {
          const raw = line.replace(/^\s+-\s*/, '').trim();
          const item = unquoteYaml(raw);
          if (item) triggers.push(item);
          continue;
        } else if (yamlListField) {
          // Line doesn't start with "  - ", list is done
          yamlListField = null;
          // Fall through to parse this line normally
        }

        const nameMatch = line.match(/^name:\s*(.*)$/);
        const descMatch = line.match(/^description:\s*(.*)$/);
        if (nameMatch) name = unquoteYaml(nameMatch[1].trim());
        if (descMatch) description = unquoteYaml(descMatch[1].trim());

        // Triggers — three forms
        if (line.match(/^triggers:\s*\[/)) {
          if (line.includes(']')) {
            // Form 1: Single-line inline: triggers: ["a", "b"]
            const inner = line.match(/\[(.+)\]/)?.[1] || '';
            triggers = parseInlineArray(inner);
          } else {
            // Form 2: Bracket-multiline: triggers: [\n  "a",\n  "b"\n]
            triggerAccum = line;
          }
        } else if (line.match(/^triggers:\s*$/)) {
          // Form 3: YAML-list: triggers:\n  - item
          yamlListField = 'triggers';
          triggers = [];
        }
        if (line.match(/^compress:\s*false/)) compress = false;
      }
    }

    // Fallback: use first non-empty, non-heading line after frontmatter
    if (!description) {
      let dashCount = 0;
      for (const line of lines) {
        if (line.trim() === '---') { dashCount++; continue; }
        if (dashCount >= 2 && line.trim() && !line.startsWith('#')) {
          description = line.trim().substring(0, 200);
          break;
        }
      }
    }
    return { name, description, triggers, compress };
  } catch {
    return { name: '', description: '', triggers: [], compress: true };
  }
}

/**
 * Compress skill content by stripping boilerplate.
 * Ported from superpowers-augment.js for token efficiency.
 */
function compressSkillContent(text) {
  let result = text;
  result = result.replace(/```dot[\s\S]*?```/g, '');
  result = result.replace(/<EXTREMELY-IMPORTANT>\n?([\s\S]*?)<\/EXTREMELY-IMPORTANT>/g, '$1');
  result = result.replace(/## When to Use[\s\S]*?(?=\n## )/g, '');
  result = result.replace(/## When to Use[\s\S]*$/g, '');
  result = result.replace(/## Overview\n[\s\S]*?(?=\n## )/g, '');
  result = result.replace(/## Overview\n[\s\S]*$/g, '');
  result = result.replace(/## Common Rationalizations[\s\S]*?(?=\n## )/g, '');
  result = result.replace(/## Why [^\n]+ Matters[\s\S]*?(?=\n## )/g, '');
  result = result.replace(/## Quick Reference[\s\S]*?(?=\n## )/g, '');
  result = result.replace(/## Related Skills[\s\S]*?(?=\n## )/g, '');
  result = result.replace(/## Cross-References[\s\S]*?(?=\n## )/g, '');
  result = result.replace(/## Integration with [^\n]*[\s\S]*?(?=\n## )/g, '');
  result = result.replace(/## Reference Files[\s\S]*?(?=\n## )/g, '');
  result = result.replace(/## When This Skill Fires[\s\S]*?(?=\n## )/g, '');
  result = result.replace(/## When NOT to Use[\s\S]*?(?=\n## )/g, '');
  result = result.replace(/## Manual Invocation[\s\S]*?(?=\n## )/g, '');
  result = result.replace(/## Incident Log[\s\S]*?(?=\n## )/g, '');
  result = result.replace(/## I'm Stuck[\s\S]*?(?=\n## )/g, '');
  result = result.replace(/^---\n[\s\S]*?\n---\n*/g, '');
  result = result.replace(/\n---\n/g, '\n');
  result = result.replace(/<!--[\s\S]*?-->/g, '');
  result = result.replace(/\n{3,}/g, '\n\n');
  return result.trim();
}

/**
 * Strip YAML frontmatter from content.
 */
function stripFrontmatter(content) {
  const lines = content.replace(/\r\n/g, '\n').replace(/\r/g, '\n').split('\n');
  let inFrontmatter = false;
  let frontmatterEnded = false;
  const result = [];
  for (const line of lines) {
    if (line.trim() === '---') {
      if (inFrontmatter) { frontmatterEnded = true; continue; }
      inFrontmatter = true;
      continue;
    }
    if (frontmatterEnded || !inFrontmatter) result.push(line);
  }
  return result.join('\n').trim();
}

/**
 * Find all SKILL.md files in a single directory (flat — matches CLI behavior).
 */
function findSkillsInDir(dir, sourceType) {
  const skills = [];
  if (!fs.existsSync(dir)) return skills;
  let entries;
  try { entries = fs.readdirSync(dir, { withFileTypes: true }); }
  catch { return skills; }

  for (const entry of entries) {
    if (entry.name.startsWith('.') || entry.name.startsWith('_')) continue;
    const skillDir = path.join(dir, entry.name);
    let isDir = entry.isDirectory();
    if (!isDir && entry.isSymbolicLink()) {
      try { isDir = fs.statSync(skillDir).isDirectory(); }
      catch (e) { if (e.code === 'ENOENT' || e.code === 'ELOOP') continue; throw e; }
    }
    if (!isDir) continue;
    // Look for skill.md (case-insensitive)
    const candidates = ['skill.md', 'SKILL.md'];
    let skillFile = null;
    for (const c of candidates) {
      const p = path.join(skillDir, c);
      if (fs.existsSync(p)) { skillFile = p; break; }
    }
    if (skillFile) {
      const meta = extractFrontmatter(skillFile);
      const fileSize = fs.statSync(skillFile).size;
      skills.push({
        path: entry.name,
        skillFile,
        skillDir,
        name: meta.name || entry.name,
        description: meta.description || `Skill: ${entry.name}`,
        dirName: entry.name,
        triggers: meta.triggers || [],
        compress: meta.compress,
        isSuperpower: (meta.triggers || []).length > 0,
        sourceType,
        tokens: Math.round(fileSize / 4)
      });
    }
  }
  return skills;
}

/**
 * Find all skills across all sources, with personal overriding superpowers.
 */
function findAllSkills() {
  const personalSkills = findSkillsInDir(PERSONAL_SKILLS_DIR, 'personal');
  const superpowersSkills = findSkillsInDir(SUPERPOWERS_SKILLS_DIR, 'superpowers');
  const allSkills = [...personalSkills, ...superpowersSkills];
  const seen = new Set();
  return allSkills.filter(s => {
    if (seen.has(s.name)) return false;
    seen.add(s.name);
    return true;
  });
}

// Legacy compat wrapper
function findSkills(dir, maxDepth = 4) {
  return findSkillsInDir(dir, 'personal');
}

/**
 * Resolve a skill name to its SKILL.md path (searches all sources).
 */
function resolveSkillPath(skillName) {
  const cleanName = skillName.replace(/^superpowers-plus:/, '').replace(/^superpowers:/, '');
  const allSkills = findAllSkills();
  for (const skill of allSkills) {
    if (skill.name === cleanName || skill.dirName === cleanName) return { skillFile: skill.skillFile, compress: skill.compress };
  }
  for (const skill of allSkills) {
    if (skill.path.endsWith(cleanName)) return { skillFile: skill.skillFile, compress: skill.compress };
  }
  return null;
}

// Create the MCP server
const server = new Server(
  { name: 'superpowers-plus', version: '3.0.0' },
  { capabilities: { tools: {} } }
);

// Register available tools
server.setRequestHandler(ListToolsRequestSchema, async () => ({
  tools: [
    {
      name: 'find_skills',
      description: 'List all available superpowers-plus skills with descriptions.',
      inputSchema: { type: 'object', properties: {}, required: [] }
    },
    {
      name: 'use_skill',
      description: 'Load a skill to guide your work. Returns the compressed SKILL.md content as context.',
      inputSchema: {
        type: 'object',
        properties: {
          skill_name: {
            type: 'string',
            description: 'Name of the skill (e.g., "detecting-ai-slop", "wiki-editing")'
          }
        },
        required: ['skill_name']
      }
    },
    {
      name: 'match_skills',
      description: 'Find skills by intent using semantic matching. Returns ranked results.',
      inputSchema: {
        type: 'object',
        properties: {
          query: {
            type: 'string',
            description: 'Natural language description of what you need (e.g., "my tests keep failing")'
          },
          top_n: {
            type: 'number',
            description: 'Number of results to return (default: 5)'
          }
        },
        required: ['query']
      }
    }
  ]
}));

// Handle tool calls
server.setRequestHandler(CallToolRequestSchema, async (request) => {
  const { name, arguments: args } = request.params;

  if (name === 'find_skills') {
    const skills = findAllSkills();
    if (skills.length === 0) {
      return { content: [{ type: 'text', text: 'No skills found.' }] };
    }
    const superpowers = skills.filter(s => s.isSuperpower);
    const explicit = skills.filter(s => !s.isSuperpower);
    let output = `# Superpowers Skills (${skills.length} total)\n\n`;
    output += `## Superpowers (${superpowers.length} auto-triggered)\n`;
    for (const skill of superpowers) {
      output += `- **${skill.name}**: ${skill.description}\n`;
    }
    output += `\n## Explicit Skills (${explicit.length} invoke by name)\n`;
    for (const skill of explicit) {
      output += `- **${skill.name}**: ${skill.description}\n`;
    }
    return { content: [{ type: 'text', text: output }] };
  }

  if (name === 'use_skill') {
    const { skill_name } = args;
    const resolved = resolveSkillPath(skill_name);
    if (!resolved) {
      return { content: [{ type: 'text', text: `Skill "${skill_name}" not found. Use find_skills to list available skills.` }] };
    }
    const { skillFile, compress } = resolved;
    const fullContent = fs.readFileSync(skillFile, 'utf8');
    const stripped = stripFrontmatter(fullContent);
    const content = compress === false ? stripped : compressSkillContent(stripped);
    const header = `# Skill: ${skill_name}`;
    return { content: [{ type: 'text', text: `${header}\n\n${content}` }] };
  }

  if (name === 'match_skills') {
    const { query, top_n = 5 } = args;
    const skills = findAllSkills();
    const results = matchSkillsTfIdf(query, skills, top_n);
    let output = `# Skill Match Results\n\nQuery: "${query}"\n\n`;
    output += '| Rank | Skill | Score | Type |\n|------|-------|-------|------|\n';
    results.forEach((r, i) => {
      const scoreDisplay = r.score.toFixed(2);
      const type = r.isSuperpower ? 'superpower' : 'explicit';
      output += `| ${i + 1} | ${r.name} | ${scoreDisplay} | ${type} |\n`;
    });
    if (results.length > 0) {
      output += `\nTop match: **${results[0].name}**\n`;
      output += `\nTo load: use_skill with skill_name="${results[0].name}"`;
    }
    return { content: [{ type: 'text', text: output }] };
  }

  throw new Error(`Unknown tool: ${name}`);
});

// Start the server
async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
  console.error('superpowers-plus MCP server v3.0.0 running');
}

main().catch((error) => {
  console.error('Server error:', error);
  process.exit(1);
});
