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
 * - Nested blocks (composition:, coordination:) with sub-keys and lists
 * - Plain unquoted values:             name: my-skill
 * - requires_mcp arrays
 * - compress flag
 * - Overlay fields: source, overrides, summary
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
 * Parse a nested YAML block (2-space indented sub-keys, 4-space list items).
 * Used for both composition: and coordination: blocks.
 * Sub-key values are coerced: arrays, booleans, integers, or strings.
 *
 * @param {Object} target - Object to populate with parsed sub-keys
 * @param {string} line - Current line being parsed
 * @param {string|null} listKey - Active list accumulator key (or null)
 * @returns {{ consumed: boolean, listKey: string|null, ended: boolean }}
 */
function parseNestedBlock(target, line, listKey) {
    // YAML list item under a sub-key: "    - value"
    const listItem = line.match(/^    - (.+)$/);
    if (listItem && listKey) {
        if (!Array.isArray(target[listKey])) target[listKey] = [];
        target[listKey].push(listItem[1].trim().replace(/^["']|["']$/g, ''));
        return { consumed: true, listKey, ended: false };
    }
    // Sub-key: "  key: value" or "  key:"
    if (line.match(/^  [a-zA-Z_]+:/)) {
        listKey = null;
        const m = line.match(/^  ([a-zA-Z_]+):\s*(.+)?$/);
        if (m) {
            const key = m[1];
            let value = (m[2] || '').trim();
            if (!value) {
                // Empty value — expect YAML list items on subsequent lines
                target[key] = [];
                return { consumed: true, listKey: key, ended: false };
            } else if (value.startsWith('[')) {
                target[key] = value.replace(/[\[\]]/g, '').split(',')
                    .map(v => v.trim().replace(/"/g, '')).filter(v => v);
            } else if (value === 'true') {
                target[key] = true;
            } else if (value === 'false') {
                target[key] = false;
            } else if (!isNaN(value) && value !== '') {
                target[key] = parseInt(value, 10);  // Integer-only contract
            } else {
                target[key] = value;
            }
        }
        return { consumed: true, listKey: null, ended: false };
    }
    // Not indented enough — end of block
    if (!line.match(/^  /)) {
        return { consumed: false, listKey: null, ended: true };
    }
    return { consumed: true, listKey, ended: false };
}

/**
 * Parse frontmatter from a skill.md content string.
 * Returns: { name, description, triggers, anti_triggers, requires_mcp,
 *            mcp_install_hint, composition, coordination, source,
 *            overrides, summary, compress }
 */
function parseFrontmatter(content) {
    const result = {
        name: '', description: '', triggers: [], anti_triggers: [], aliases: [],
        requires_mcp: [], mcp_install_hint: '', composition: null,
        coordination: null, source: '', overrides: '', summary: '',
        compress: true
    };
    const lines = content.replace(/\r\n/g, '\n').replace(/\r/g, '\n').split('\n');
    let inFrontmatter = false;
    let activeBlock = null;   // 'composition' or 'coordination'
    let blockListKey = null;
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

        // --- Nested blocks: composition: / coordination: ---
        const blockMatch = line.match(/^(composition|coordination):/);
        if (blockMatch) {
            activeBlock = blockMatch[1];
            blockListKey = null;
            result[activeBlock] = {};
            continue;
        }
        if (activeBlock) {
            const parsed = parseNestedBlock(result[activeBlock], line, blockListKey);
            blockListKey = parsed.listKey;
            if (parsed.consumed) continue;
            if (parsed.ended) { activeBlock = null; blockListKey = null; }
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
            if (key === 'source') result.source = value;
            if (key === 'overrides') result.overrides = value;
            if (key === 'summary') result.summary = value;
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
            requires_mcp: [], mcp_install_hint: '', composition: null,
            coordination: null, source: '', overrides: '', summary: '',
            compress: true
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

// ============================================================================
// Schema validation
// ============================================================================

/**
 * Validate parsed frontmatter and return warnings for malformed metadata.
 * Does NOT throw — returns an array of warning strings (empty = valid).
 *
 * Checks:
 *   - name is non-empty
 *   - triggers is an array of strings (not objects or numbers)
 *   - anti_triggers is an array of strings
 *   - composition block has valid sub-keys when present
 *   - coordination block has valid sub-keys when present
 *   - compress is boolean
 *
 * @param {Object} fm - Parsed frontmatter object from parseFrontmatter()
 * @param {string} [source] - Optional source identifier for error messages
 * @returns {string[]} Array of warning strings (empty if valid)
 */
function validateFrontmatter(fm, source) {
    const warnings = [];
    const src = source ? ` (${source})` : '';

    // Name
    if (!fm.name || typeof fm.name !== 'string' || fm.name.trim() === '') {
        warnings.push(`Missing or empty "name" field${src}`);
    }

    // Array fields: must be arrays of strings
    for (const field of ['triggers', 'anti_triggers', 'aliases', 'requires_mcp']) {
        const val = fm[field];
        if (!Array.isArray(val)) {
            warnings.push(`"${field}" is not an array${src} (got ${typeof val})`);
        } else {
            for (let i = 0; i < val.length; i++) {
                if (typeof val[i] !== 'string') {
                    warnings.push(`"${field}[${i}]" is not a string${src} (got ${typeof val[i]})`);
                }
            }
        }
    }

    // Composition block validation
    if (fm.composition !== null && fm.composition !== undefined) {
        if (typeof fm.composition !== 'object' || Array.isArray(fm.composition)) {
            warnings.push(`"composition" must be an object${src} (got ${typeof fm.composition})`);
        } else {
            const validCompKeys = new Set(['produces', 'consumes', 'capabilities', 'priority', 'optional', 'requires_all']);
            for (const key of Object.keys(fm.composition)) {
                if (!validCompKeys.has(key)) {
                    warnings.push(`Unknown composition key "${key}"${src}`);
                }
            }
            for (const arrKey of ['produces', 'consumes', 'capabilities']) {
                const arrVal = fm.composition[arrKey];
                if (arrVal !== undefined && !Array.isArray(arrVal)) {
                    warnings.push(`composition.${arrKey} must be an array${src}`);
                } else if (Array.isArray(arrVal)) {
                    for (let i = 0; i < arrVal.length; i++) {
                        if (typeof arrVal[i] !== 'string') {
                            warnings.push(`composition.${arrKey}[${i}] must be a string${src} (got ${typeof arrVal[i]})`);
                        }
                    }
                }
            }
            if (fm.composition.priority !== undefined && typeof fm.composition.priority !== 'number') {
                warnings.push(`composition.priority must be a number${src}`);
            }
            for (const boolKey of ['optional', 'requires_all']) {
                if (fm.composition[boolKey] !== undefined && typeof fm.composition[boolKey] !== 'boolean') {
                    warnings.push(`composition.${boolKey} must be a boolean${src}`);
                }
            }
        }
    }

    // Coordination block validation
    if (fm.coordination !== null && fm.coordination !== undefined) {
        if (typeof fm.coordination !== 'object' || Array.isArray(fm.coordination)) {
            warnings.push(`"coordination" must be an object${src} (got ${typeof fm.coordination})`);
        } else {
            const validCoordKeys = new Set(['group', 'order', 'requires', 'enables', 'escalates_to', 'internal']);
            for (const key of Object.keys(fm.coordination)) {
                if (!validCoordKeys.has(key)) {
                    warnings.push(`Unknown coordination key "${key}"${src}`);
                }
            }
            for (const arrKey of ['requires', 'enables', 'escalates_to']) {
                const arrVal = fm.coordination[arrKey];
                if (arrVal !== undefined && !Array.isArray(arrVal)) {
                    warnings.push(`coordination.${arrKey} must be an array${src}`);
                } else if (Array.isArray(arrVal)) {
                    for (let i = 0; i < arrVal.length; i++) {
                        if (typeof arrVal[i] !== 'string') {
                            warnings.push(`coordination.${arrKey}[${i}] must be a string${src} (got ${typeof arrVal[i]})`);
                        }
                    }
                }
            }
            if (fm.coordination.order !== undefined && typeof fm.coordination.order !== 'number') {
                warnings.push(`coordination.order must be a number${src}`);
            }
            if (fm.coordination.internal !== undefined && typeof fm.coordination.internal !== 'boolean') {
                warnings.push(`coordination.internal must be a boolean${src}`);
            }
        }
    }

    // Compress flag
    if (typeof fm.compress !== 'boolean') {
        warnings.push(`"compress" must be a boolean${src} (got ${typeof fm.compress})`);
    }

    return warnings;
}

module.exports = {
    // Primary API
    parseFrontmatter,
    extractFrontmatter,
    findSkillFile,
    stripFrontmatter,
    validateFrontmatter,
    // Low-level utilities (exported for testing)
    parseNestedBlock,
    parseInlineArray,
    parseYamlList,
    unquoteYaml,
    hasUnquotedClosingBracket,
    extractBracketContent,
};
