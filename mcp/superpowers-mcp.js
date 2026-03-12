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
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Skills directory: env override or default to ../skills relative to this file
const skillsDir = process.env.SUPERPOWERS_SKILLS_DIR || path.join(__dirname, '..', 'skills');

/**
 * Extract YAML frontmatter from a SKILL.md file.
 */
function extractFrontmatter(filePath) {
  try {
    const content = fs.readFileSync(filePath, 'utf8');
    const lines = content.split('\n');
    let inFrontmatter = false;
    let name = '';
    let description = '';

    for (const line of lines) {
      if (line.trim() === '---') {
        if (inFrontmatter) break;
        inFrontmatter = true;
        continue;
      }
      if (inFrontmatter) {
        const nameMatch = line.match(/^name:\s*(.*)$/);
        const descMatch = line.match(/^description:\s*(.*)$/);
        if (nameMatch) name = nameMatch[1].trim();
        if (descMatch) description = descMatch[1].trim();
      }
    }

    // Fallback: use first non-empty line after frontmatter
    if (!description) {
      let pastFrontmatter = false;
      for (const line of lines) {
        if (line.trim() === '---') {
          if (pastFrontmatter) break;
          pastFrontmatter = true;
          continue;
        }
        if (pastFrontmatter && line.trim() && !line.startsWith('#')) {
          description = line.trim().substring(0, 200);
          break;
        }
      }
    }
    return { name, description };
  } catch {
    return { name: '', description: '' };
  }
}

/**
 * Strip YAML frontmatter from content.
 */
function stripFrontmatter(content) {
  const lines = content.split('\n');
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
 * Recursively find all SKILL.md files in a directory.
 */
function findSkills(dir, maxDepth = 4) {
  const skills = [];
  if (!fs.existsSync(dir)) return skills;

  function recurse(currentDir, depth) {
    if (depth > maxDepth) return;
    let entries;
    try { entries = fs.readdirSync(currentDir, { withFileTypes: true }); }
    catch { return; }

    for (const entry of entries) {
      if (entry.name.startsWith('.') || entry.name.startsWith('_')) continue;
      const fullPath = path.join(currentDir, entry.name);
      if (entry.isDirectory()) {
        const skillFile = path.join(fullPath, 'SKILL.md');
        if (fs.existsSync(skillFile)) {
          const { name, description } = extractFrontmatter(skillFile);
          skills.push({
            path: path.relative(dir, fullPath),
            skillFile,
            name: name || entry.name,
            description: description || `Skill: ${entry.name}`,
            dirName: entry.name
          });
        }
        recurse(fullPath, depth + 1);
      }
    }
  }
  recurse(dir, 0);
  return skills;
}

/**
 * Resolve a skill name to its SKILL.md path.
 */
function resolveSkillPath(skillName) {
  const cleanName = skillName.replace(/^superpowers-plus:/, '').replace(/^superpowers:/, '');
  const allSkills = findSkills(skillsDir);
  for (const skill of allSkills) {
    if (skill.name === cleanName || skill.dirName === cleanName) return skill.skillFile;
  }
  for (const skill of allSkills) {
    if (skill.path.endsWith(cleanName)) return skill.skillFile;
  }
  return null;
}

// Create the MCP server
const server = new Server(
  { name: 'superpowers-plus', version: '2.4.0' },
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
      description: 'Load a skill to guide your work. Returns the full SKILL.md content as context.',
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
    }
  ]
}));

// Handle tool calls
server.setRequestHandler(CallToolRequestSchema, async (request) => {
  const { name, arguments: args } = request.params;

  if (name === 'find_skills') {
    const skills = findSkills(skillsDir);
    if (skills.length === 0) {
      return { content: [{ type: 'text', text: `No skills found in ${skillsDir}` }] };
    }
    let output = `superpowers-plus skills (${skills.length} total):\n\n`;
    const grouped = {};
    for (const skill of skills) {
      const domain = skill.path.split(path.sep)[0] || 'root';
      if (!grouped[domain]) grouped[domain] = [];
      grouped[domain].push(skill);
    }
    for (const [domain, domainSkills] of Object.entries(grouped)) {
      output += `## ${domain}\n`;
      for (const skill of domainSkills) output += `- ${skill.name}: ${skill.description}\n`;
      output += '\n';
    }
    return { content: [{ type: 'text', text: output }] };
  }

  if (name === 'use_skill') {
    const { skill_name } = args;
    const skillFile = resolveSkillPath(skill_name);
    if (!skillFile) {
      return { content: [{ type: 'text', text: `Skill "${skill_name}" not found. Use find_skills to list available skills.` }] };
    }
    const fullContent = fs.readFileSync(skillFile, 'utf8');
    const { name: displayName, description } = extractFrontmatter(skillFile);
    const content = stripFrontmatter(fullContent);
    const header = `# ${displayName || skill_name}\n# ${description || ''}\n# Files: ${path.dirname(skillFile)}\n# ============================================`;
    return { content: [{ type: 'text', text: `${header}\n\n${content}` }] };
  }

  throw new Error(`Unknown tool: ${name}`);
});

// Start the server
async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
  console.error('superpowers-plus MCP server running');
}

main().catch((error) => {
  console.error('Server error:', error);
  process.exit(1);
});
