/**
 * Canonical frontmatter parser — single source of truth.
 *
 * Imported by superpowers-augment.js and mcp/superpowers-mcp.js.
 * All frontmatter parsing MUST go through this module.
 *
 * Handles:
 * - Inline quoted descriptions with escaped quotes: description: "User says \"build X\""
 * - Inline arrays on a single line:   triggers: ["a", "b"]
 * - Multiline YAML list arrays:        triggers:\n  - a\n  - b
 * - Bracket-multiline arrays:          triggers: ["a",\n  "b"]
 * - Composition blocks with nested fields
 * - Plain unquoted values:             name: my-skill
 * - requires_mcp arrays
 * - compress flag
 */

'use strict';

const fs = require('fs');
const path = require('path');

// ============================================================================
// Low-level parsing utilities
// ============================================================================

/**
 * State-machine parser for YAML inline arrays.
 * Handles apostrophes inside double-quoted strings and escaped quotes.
 * Input can be raw bracket content (without outer []) or a full [...] string.
 */
function parseInlineArray(value) {
    const inner = value.replace(/^\s*\[/, '').replace(/\]\s*$/, '');
    const items = [];
    let i = 0;
    while (i < inner.length) {
        while (i < inner.length && (inner[i] === ' ' || inner[i] === ',' || inner[i] === '\t')) i++;
        if (i >= inner.length) break;
        const quote = inner[i];
        if (quote === '"' || quote === "'") {
            let val = '';
            i++; // skip opening quote
            while (i < inner.length) {
                if (quote === '"' && inner[i] === '\\' && i + 1 < inner.length) {
                    val += inner[i + 1]; i += 2;
                } else if (quote === "'" && inner[i] === "'" && i + 1 < inner.length && inner[i + 1] === "'") {
                    val += "'"; i += 2; // YAML '' escape
                } else if (inner[i] === quote) {
                    i++; break;
                } else {
                    val += inner[i]; i++;
                }
            }
            if (val) items.push(val);
        } else {
            let val = '';
            while (i < inner.length && inner[i] !== ',') { val += inner[i]; i++; }
            val = val.trim();
            if (val) items.push(val);
        }
    }
    return items;
}

/**
 * Check if a string has a closing ] outside of quotes.
 * Used to detect the end of bracket-multiline arrays.
 */
function hasUnquotedClosingBracket(s) {
    let inQuote = null;
    for (let i = 0; i < s.length; i++) {
        const c = s[i];
        if (c === '\\' && inQuote && i + 1 < s.length) { i++; continue; }
        if (inQuote) { if (c === inQuote) inQuote = null; continue; }
        if (c === '"' || c === "'") { inQuote = c; continue; }
        if (c === ']') return true;
    }
    return false;
}

/**
 * Extract content between [ and the real closing ] (outside quotes).
 */
function extractBracketContent(s) {
    const start = s.indexOf('[');
    if (start === -1) return '';
    let inQuote = null;
    for (let i = start + 1; i < s.length; i++) {
        const c = s[i];
        if (c === '\\' && inQuote && i + 1 < s.length) { i++; continue; }
        if (inQuote) { if (c === inQuote) inQuote = null; continue; }
        if (c === '"' || c === "'") { inQuote = c; continue; }
        if (c === ']') return s.slice(start + 1, i);
    }
    return s.slice(start + 1);
}

/**
 * Strip surrounding YAML quotes and unescape.
 * "value" → value, 'value' → value
 */
function unquoteYaml(s) {
    if (s.startsWith('"') && s.endsWith('"')) {
        return s.slice(1, -1).replace(/\\"/g, '"').replace(/\\\\/g, '\\');
    }
    if (s.startsWith("'") && s.endsWith("'")) {
        return s.slice(1, -1).replace(/''/g, "'");
    }
    return s;
}

/**
 * Parse a multiline YAML list starting after the current line.
 * Skips blank lines within the list.
 * Returns { values: string[], nextIndex: number }
 */
function parseYamlList(lines, startIndex) {
    const values = [];
    let nextIndex = startIndex;
    for (let i = startIndex + 1; i < lines.length; i++) {
        const itemMatch = lines[i].match(/^\s+-\s+(.+)$/);
        if (itemMatch) {
            values.push(unquoteYaml(itemMatch[1].trim()));
            nextIndex = i;
            continue;
        }
        if (lines[i].trim() === '') { nextIndex = i; continue; }
        break;
    }
    return { values, nextIndex };
}

// ============================================================================
// Main parser
// ============================================================================

/**
 * Parse an array field (triggers, anti_triggers, requires_mcp) in three forms:
 * 1. Inline:          field: ["a", "b"]
 * 2. Bracket-multiline: field: ["a",\n  "b"]  (accumulator-based)
 * 3. YAML list:       field:\n  - a\n  - b
 *
 * Returns { handled: boolean, values?: string[], accum?: string }
 */
function parseArrayField(fieldName, line, lines, i) {
    // Form 1 & 2: bracket start
    const bracketRe = new RegExp(`^${fieldName}:\\s*\\[`);
    if (line.match(bracketRe)) {
        if (hasUnquotedClosingBracket(line.slice(line.indexOf('[') + 1))) {
            return { handled: true, values: parseInlineArray(extractBracketContent(line)) };
        }
        return { handled: true, accum: line }; // bracket-multiline start
    }
    // Form 3: YAML list
    const listRe = new RegExp(`^${fieldName}:\\s*$`);
    if (line.match(listRe)) {
        const parsed = parseYamlList(lines, i);
        return { handled: true, values: parsed.values, nextIndex: parsed.nextIndex };
    }
    return { handled: false };
}

/**
 * Parse frontmatter from a skill.md content string.
 * Returns: { name, description, triggers, anti_triggers, requires_mcp,
 *            mcp_install_hint, composition, compress }
 */
function parseFrontmatter(content) {
    const result = {
        name: '', description: '', triggers: [], anti_triggers: [], aliases: [],
        requires_mcp: [], mcp_install_hint: '', composition: null, compress: true
    };
    const lines = content.replace(/\r\n/g, '\n').replace(/\r/g, '\n').split('\n');
    let inFrontmatter = false;
    let inComposition = false;
    let triggerAccum = null;
    let antiAccum = null;
    let aliasAccum = null;
    let mcpAccum = null;

    for (let i = 0; i < lines.length; i++) {
        const line = lines[i];
        if (line.trim() === '---') {
            if (inFrontmatter) break;
            inFrontmatter = true;
            continue;
        }
        if (!inFrontmatter) continue;

        // --- Bracket-multiline accumulation ---
        // Guard: if a new top-level key starts before bracket closes, the
        // frontmatter is malformed. Abandon accumulation (fail-safe).
        // /^\w+:(?:[^/]|$)/ matches "key: v", "key:v", "key:" but not http://
        const accums = [
            { ref: 'triggerAccum', target: 'triggers' },
            { ref: 'antiAccum', target: 'anti_triggers' },
            { ref: 'aliasAccum', target: 'aliases' },
            { ref: 'mcpAccum', target: 'requires_mcp' },
        ];
        const accumState = { triggerAccum, antiAccum, aliasAccum, mcpAccum };
        let accumulated = false;
        for (const { ref, target } of accums) {
            if (accumState[ref] !== null) {
                if (line.match(/^\w+:(?:[^/]|$)/)) {
                    accumState[ref] = null;
                } else {
                    accumState[ref] += ' ' + line.trim();
                    if (hasUnquotedClosingBracket(accumState[ref])) {
                        result[target] = parseInlineArray(extractBracketContent(accumState[ref]));
                        accumState[ref] = null;
                    }
                    accumulated = true;
                }
                break; // only one accumulator active at a time
            }
        }
        triggerAccum = accumState.triggerAccum;
        antiAccum = accumState.antiAccum;
        aliasAccum = accumState.aliasAccum;
        mcpAccum = accumState.mcpAccum;
        if (accumulated) continue;

        // --- Composition block ---
        if (line.match(/^composition:/)) {
            inComposition = true;
            result.composition = {};
            continue;
        }
        if (inComposition && line.match(/^  \w+:/)) {
            const compMatch = line.match(/^  (\w+):\s*(.+)?$/);
            if (compMatch) {
                const key = compMatch[1];
                let value = compMatch[2] || '';
                if (value.startsWith('[')) {
                    value = value.replace(/[\[\]]/g, '').split(',').map(v => v.trim().replace(/"/g, '')).filter(v => v);
                } else if (value === 'true') {
                    value = true;
                } else if (value === 'false') {
                    value = false;
                } else if (!isNaN(value) && value !== '') {
                    value = parseInt(value, 10);
                }
                result.composition[key] = value;
            }
            continue;
        } else if (inComposition && !line.match(/^  /)) {
            inComposition = false;
        }

        // --- Array fields (triggers, anti_triggers, requires_mcp) ---
        for (const [field, target, accumRef] of [
            ['triggers', 'triggers', 'triggerAccum'],
            ['anti_triggers', 'anti_triggers', 'antiAccum'],
            ['aliases', 'aliases', 'aliasAccum'],
            ['requires_mcp', 'requires_mcp', 'mcpAccum'],
        ]) {
            const parsed = parseArrayField(field, line, lines, i);
            if (parsed.handled) {
                if (parsed.values) result[target] = parsed.values;
                if (parsed.accum) {
                    if (accumRef === 'triggerAccum') triggerAccum = parsed.accum;
                    else if (accumRef === 'antiAccum') antiAccum = parsed.accum;
                    else if (accumRef === 'aliasAccum') aliasAccum = parsed.accum;
                    else mcpAccum = parsed.accum;
                }
                if (parsed.nextIndex !== undefined) i = parsed.nextIndex;
                break; // only one field per line
            }
        }

        // --- Simple key: value fields ---
        const match = line.match(/^(\w+):\s*(.+)$/);
        if (match) {
            const key = match[1];
            let value = unquoteYaml(match[2].trim());
            if (key === 'name') result.name = value;
            if (key === 'description') result.description = value;
            if (key === 'compress' && value === 'false') result.compress = false;
            if (key === 'mcp_install_hint') result.mcp_install_hint = value;
        }
    }
    return result;
}

/**
 * Parse frontmatter from a file path (convenience wrapper).
 * Returns the same shape as parseFrontmatter, with safe defaults on error.
 */
function extractFrontmatter(filePath) {
    try {
        const content = fs.readFileSync(filePath, 'utf8');
        return parseFrontmatter(content);
    } catch (error) {
        if (process.env.DEBUG) {
            console.error(`[DEBUG] Failed to parse frontmatter: ${filePath}: ${error.message}`);
        }
        return {
            name: '', description: '', triggers: [], anti_triggers: [], aliases: [],
            requires_mcp: [], mcp_install_hint: '', composition: null, compress: true
        };
    }
}

/**
 * Find skill.md in a directory (case-insensitive).
 */
function findSkillFile(dir) {
    for (const candidate of ['SKILL.md', 'skill.md']) {
        const fullPath = path.join(dir, candidate);
        if (fs.existsSync(fullPath)) return fullPath;
    }
    return null;
}

/**
 * Strip YAML frontmatter from content, returning just the body.
 */
function stripFrontmatter(content) {
    const lines = content.replace(/\r\n/g, '\n').replace(/\r/g, '\n').split('\n');
    let inFrontmatter = false;
    let frontmatterEnded = false;
    const contentLines = [];
    for (const line of lines) {
        if (line.trim() === '---') {
            if (inFrontmatter && !frontmatterEnded) { frontmatterEnded = true; continue; }
            if (!frontmatterEnded) { inFrontmatter = true; continue; }
        }
        if (!inFrontmatter || frontmatterEnded) contentLines.push(line);
    }
    return contentLines.join('\n').trim();
}

module.exports = {
    // Primary API
    parseFrontmatter,
    extractFrontmatter,
    findSkillFile,
    stripFrontmatter,
    // Low-level utilities (exported for testing)
    parseInlineArray,
    parseYamlList,
    unquoteYaml,
    hasUnquotedClosingBracket,
    extractBracketContent,
};
