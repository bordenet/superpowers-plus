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

// Canonical frontmatter parser — single source of truth
const { extractFrontmatter, stripFrontmatter } = require('../lib/frontmatter');

// Unified skill discovery — shared with superpowers-augment.js
const { findSkillsInDir, findAllSkills } = require('../lib/skill-discovery');

// Shared compression — single source of truth
const { compressSkillContent } = require('../lib/compress');

// Multi-source skill directories (personal overrides superpowers)
const PERSONAL_SKILLS_DIR = process.env.PERSONAL_SKILLS_DIR || path.join(homeDir, '.codex', 'skills');
const SUPERPOWERS_SKILLS_DIR = process.env.SUPERPOWERS_SKILLS_DIR || path.join(homeDir, '.codex', 'superpowers', 'skills');

// Legacy single-dir compat
const skillsDir = PERSONAL_SKILLS_DIR;

// stripFrontmatter — imported from lib/frontmatter (see top of file)
// findSkillsInDir, findAllSkills — imported from lib/skill-discovery (see top of file)

/**
 * Resolve a skill name to its SKILL.md path (searches all sources).
 */
function resolveSkillPath(skillName) {
  const cleanName = skillName.replace(/^superpowers-plus:/, '').replace(/^superpowers:/, '');
  const allSkills = findAllSkills(PERSONAL_SKILLS_DIR, SUPERPOWERS_SKILLS_DIR);
  for (const skill of allSkills) {
    if (skill.name === cleanName || skill.dirName === cleanName) return { skillFile: skill.skillFile, compress: skill.compress };
  }
  for (const skill of allSkills) {
    if (skill.dirName.endsWith(cleanName)) return { skillFile: skill.skillFile, compress: skill.compress };
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
    const skills = findAllSkills(PERSONAL_SKILLS_DIR, SUPERPOWERS_SKILLS_DIR);
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
    const skills = findAllSkills(PERSONAL_SKILLS_DIR, SUPERPOWERS_SKILLS_DIR);
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
