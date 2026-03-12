#!/usr/bin/env node

/**
 * Smoke test for superpowers-plus MCP server.
 * Validates that all skills are discovered and can be loaded.
 */

import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const skillsDir = path.join(__dirname, '..', 'skills');

// Import the findSkills function logic
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
          skills.push({
            name: entry.name,
            path: path.relative(dir, fullPath),
            skillFile
          });
        }
        recurse(fullPath, depth + 1);
      }
    }
  }
  recurse(dir, 0);
  return skills;
}

console.log('superpowers-plus MCP Smoke Test\n');
console.log('Skills directory:', skillsDir);
console.log('');

const skills = findSkills(skillsDir);

if (skills.length === 0) {
  console.error('FAIL: No skills found');
  process.exit(1);
}

console.log(`Found ${skills.length} skills:\n`);

// Group by domain
const grouped = {};
for (const skill of skills) {
  const domain = skill.path.split(path.sep)[0] || 'root';
  if (!grouped[domain]) grouped[domain] = [];
  grouped[domain].push(skill);
}

let hasError = false;
for (const [domain, domainSkills] of Object.entries(grouped)) {
  console.log(`## ${domain}`);
  for (const skill of domainSkills) {
    // Verify file is readable
    try {
      const content = fs.readFileSync(skill.skillFile, 'utf8');
      const hasFrontmatter = content.startsWith('---');
      const status = hasFrontmatter ? '✓' : '⚠ (no frontmatter)';
      console.log(`  ${status} ${skill.name}`);
    } catch (err) {
      console.log(`  ✗ ${skill.name} - ${err.message}`);
      hasError = true;
    }
  }
  console.log('');
}

console.log('---');
console.log(`Total: ${skills.length} skills in ${Object.keys(grouped).length} domains`);

if (hasError) {
  console.log('\nSome skills failed validation.');
  process.exit(1);
} else {
  console.log('\nAll skills passed validation. MCP server ready.');
  process.exit(0);
}

