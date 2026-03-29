/**
 * Reference frontmatter parser — test harness and future consolidation target.
 *
 * STATUS: Not yet imported by superpowers-augment.js or superpowers-mcp.js.
 * Those files still have their own inline parsers. This file exists to:
 * 1. Define the canonical parsing behavior with tests
 * 2. Serve as the migration target when we consolidate (post-release)
 *
 * Handles:
 * - Inline quoted descriptions with escaped quotes: description: "User says \"build X\""
 * - Inline arrays: triggers: ["a", "b"]
 * - Multiline YAML arrays: triggers:\n  - a\n  - b
 * - Plain unquoted values: name: my-skill
 *
 * TODO: Wire into consumers after release. Track in post-release cleanup.
 */

'use strict';

const fs = require('fs');
const path = require('path');

/**
 * Parse a YAML inline array: ["a", "b", "c"]
 * Escape-aware: handles ["a\"b", 'c\\d'] correctly.
 */
function parseInlineArray(str) {
    const items = [];
    let i = str.indexOf('[');
    if (i < 0) return items;
    i++;
    while (i < str.length) {
        while (i < str.length && (str[i] === ' ' || str[i] === ',' || str[i] === '\t')) i++;
        if (str[i] === ']') break;
        if (str[i] === '"' || str[i] === "'") {
            const quote = str[i]; i++;
            let item = '';
            while (i < str.length && str[i] !== quote) {
                if (str[i] === '\\' && i + 1 < str.length) {
                    if (str[i + 1] === quote) { item += quote; i += 2; }
                    else if (str[i + 1] === '\\') { item += '\\'; i += 2; }
                    else { item += str[i]; i++; }
                } else { item += str[i]; i++; }
            }
            i++;
            items.push(item);
        } else {
            let item = '';
            while (i < str.length && str[i] !== ',' && str[i] !== ']') { item += str[i]; i++; }
            const trimmed = item.trim();
            if (trimmed) items.push(trimmed);
        }
    }
    return items;
}

/**
 * Parse a multiline YAML list starting after the current line.
 * Returns { values: string[], nextIndex: number }
 */
function parseYamlList(lines, startIndex) {
    const values = [];
    let i = startIndex + 1;
    while (i < lines.length) {
        const line = lines[i];
        const itemMatch = line.match(/^\s+-\s+["']?(.+?)["']?\s*$/);
        if (itemMatch) {
            values.push(itemMatch[1]);
            i++;
        } else {
            break;
        }
    }
    return { values, nextIndex: i - 1 };
}

/**
 * Extract a quoted string value, correctly handling escaped quotes.
 * Input: '"User says \\"build X\\"" ' → 'User says "build X"'
 * Input: 'plain text' → 'plain text'
 */
function extractStringValue(raw) {
    if (!raw) return '';
    raw = raw.trim();
    // Quoted string — handle escaped quotes inside
    if (raw.startsWith('"') && raw.endsWith('"')) {
        return raw.slice(1, -1).replace(/\\"/g, '"').replace(/\\\\/g, '\\');
    }
    if (raw.startsWith("'") && raw.endsWith("'")) {
        return raw.slice(1, -1);
    }
    // Unquoted — strip trailing quotes if malformed
    return raw.replace(/^["']|["']$/g, '');
}

/**
 * Parse frontmatter from a skill.md file content string.
 * Returns: { name, description, triggers, anti_triggers, requires_mcp, mcp_install_hint, composition, compress }
 */
function parseFrontmatter(content) {
    const result = {
        name: '', description: '', triggers: [], anti_triggers: [],
        requires_mcp: [], mcp_install_hint: '', composition: null, compress: true
    };
    const lines = content.replace(/\r\n/g, '\n').replace(/\r/g, '\n').split('\n');
    let inFrontmatter = false;

    for (let i = 0; i < lines.length; i++) {
        const line = lines[i];
        if (line.trim() === '---') {
            if (inFrontmatter) break;
            inFrontmatter = true;
            continue;
        }
        if (!inFrontmatter) continue;

        // Triggers (inline or multiline)
        const triggerInline = line.match(/^triggers:\s*(\[.+\])\s*$/);
        if (triggerInline) { result.triggers = parseInlineArray(triggerInline[1]); continue; }
        if (line.match(/^triggers:\s*$/)) {
            const parsed = parseYamlList(lines, i);
            result.triggers = parsed.values; i = parsed.nextIndex; continue;
        }

        // Anti-triggers
        const antiInline = line.match(/^anti_triggers:\s*(\[.+\])\s*$/);
        if (antiInline) { result.anti_triggers = parseInlineArray(antiInline[1]); continue; }
        if (line.match(/^anti_triggers:\s*$/)) {
            const parsed = parseYamlList(lines, i);
            result.anti_triggers = parsed.values; i = parsed.nextIndex; continue;
        }

        // requires_mcp
        const mcpInline = line.match(/^requires_mcp:\s*(\[.+\])\s*$/);
        if (mcpInline) { result.requires_mcp = parseInlineArray(mcpInline[1]); continue; }
        if (line.match(/^requires_mcp:\s*$/)) {
            const parsed = parseYamlList(lines, i);
            result.requires_mcp = parsed.values; i = parsed.nextIndex; continue;
        }

        // Simple key: value fields — must handle quoted strings with escaped quotes
        const kvMatch = line.match(/^(\w+):\s*(.+)$/);
        if (kvMatch) {
            const key = kvMatch[1];
            const rawVal = kvMatch[2];
            if (key === 'name') result.name = extractStringValue(rawVal);
            if (key === 'description') result.description = extractStringValue(rawVal);
            if (key === 'compress' && rawVal.trim() === 'false') result.compress = false;
            if (key === 'mcp_install_hint') result.mcp_install_hint = extractStringValue(rawVal);
            if (key === 'composition') result.composition = extractStringValue(rawVal);
        }
    }
    return result;
}

/**
 * Find skill.md in a directory (case-insensitive).
 */
function findSkillFile(dir) {
    for (const candidate of ['skill.md', 'SKILL.md']) {
        const fullPath = path.join(dir, candidate);
        if (fs.existsSync(fullPath)) return fullPath;
    }
    return null;
}

module.exports = { parseFrontmatter, parseInlineArray, parseYamlList, extractStringValue, findSkillFile };
