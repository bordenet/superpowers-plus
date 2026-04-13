/**
 * compress.js — Shared skill content compression.
 *
 * Two-phase compression:
 *   Phase 1 (structural): Strip boilerplate sections, DOT graphs, HTML comments.
 *   Phase 2 (density):    Reduce prose verbosity, deduplicate formatting patterns,
 *                         compress navigation boilerplate, tighten whitespace.
 *
 * Preserves: HARD-GATE blocks, SUBAGENT-STOP, Failure Modes, code blocks,
 *            data tables, checklists, procedures, compress:false opt-out.
 *
 * Used by: superpowers-augment.js, mcp/superpowers-mcp.js
 */
'use strict';

// Phase 1: Sections to strip — heading text patterns that are boilerplate/routing info.
// "Failure Modes" and "SUBAGENT-STOP" are deliberately EXCLUDED (operational).
const STRIP_SECTIONS = [
    'When to Use', 'Overview', 'Common Rationalizations',
    'Why (?:Order|This|It|the Gate) (?:Matters|Exists)', 'Quick Reference',
    'Related Skills', 'Cross[- ]?References', 'Integration with .*',
    'Reference Files', 'References?(?::.*)?', 'When This Skill Fires', 'When NOT to Use',
    'Manual Invocation', 'Incident Log', "I'm Stuck",
    // Routing/navigation metadata — agent has skill index from bootstrap
    'Companion Skills', 'Escalation Path',
    // Incident/history sections — operational learnings but high token cost
    'Incident Record', 'Incident History',
    // Examples are educational, not operational — strip to save tokens
    'Example', 'Example Invocation', 'Example:.*',
    // Rationalization/anti-pattern tables are motivational, not procedural
    'Rationalizations to Reject', 'Anti-Patterns',
    // Purpose as standalone section (already in frontmatter/header)
    'Purpose',
    // Hallucination prevention and success criteria — aspirational framing
    'Hallucination Prevention', 'Success Criteria',
    // Stop conditions — already enforced by gate logic
    'Stop Conditions', 'Escalation Conditions',
    // Routing variants found in domain-specific skills
    // NOTE: "Next Steps" deliberately EXCLUDED — contains operational routing tables
    'When to Invoke', '🚨 WHEN TO USE THIS SKILL',
    'Trigger Conditions',
];

// Phase 2: Inline density reductions — applied OUTSIDE code blocks only.
// Each entry: [pattern, replacement, description (for tests/docs)]
const DENSITY_RULES = [
    // --- Navigation boilerplate ---
    // "Wrong skill?" blockquotes: multi-line → single line
    [/^> \*\*Wrong skill\?\*\*[^\n]*(?:\n> [^\n]*)*\n?/gm,
     '', 'strip wrong-skill navigation blocks'],

    // "Announce at start" lines — redundant with frontmatter triggers
    [/\*\*Announce at start:\*\*[^\n]*\n\n?/g,
     '', 'strip announce-at-start lines'],

    // --- Formatting density ---
    // Bold label patterns: **Label:** → Label:  (saves 4 chars per instance × 500+ instances)
    [/\*\*(Purpose|Note|Source|Created|Pattern|Decision rule[s]?|Gate chain position|Why this exists|Mandatory activation|Core principle|Key insight|Exit gate|Last Updated|Scope|Role|Dispatched by|Evidence type|Invoke|Preferred|Adapter|Guidelines|Part of|Exception|Fix|Always|Root Cause|Full access|START FROM|PRIORITIZE|Prerequisite|Timing|Overrides|REQUIRED):\*\*/g,
     '$1:', 'unbold common label patterns'],

    // Standalone blockquote meta-lines (> **Purpose:** ..., > **Source:** ...)
    // that duplicate frontmatter — strip entire line
    [/^> \*\*(?:Source|Created|PRD|Version|Status|Last Updated|Part of):\*\*[^\n]*\n/gm,
     '', 'strip meta blockquote lines duplicating frontmatter'],

    // Blockquote-only lines that are just emphasis wrappers (> **text**)
    // with no operational content — often "Core principle" or "Pattern" summaries
    [/^> \*\*(?:Core principle|Pattern):\*\*[^\n]*\n(?:>\s*\n)*/gm,
     '', 'strip core-principle/pattern blockquote summaries'],

    // --- Redundant emphasis patterns ---
    // "⛔ **HARD GATE:**" → "⛔ HARD GATE:" (HARD-GATE content preserved, just debold)
    [/⛔\s*\*\*HARD GATE:\*\*/g,
     '⛔ HARD GATE:', 'debold hard-gate markers'],

    // Standalone bold emphasis on entire lines: **ALL CAPS TEXT** → ALL CAPS TEXT
    [/^\*\*([A-Z][A-Z ]{3,})\*\*$/gm,
     '$1', 'debold standalone all-caps lines'],

    // --- Whitespace tightening ---
    // Blank line after ANY heading (LLMs don't need markdown spacing)
    [/(^#{1,4} [^\n]+)\n\n/gm,
     '$1\n', 'remove blank line after headings'],

    // Blank line before heading (collapse to single newline)
    [/\n\n+(#{1,4} )/gm,
     '\n$1', 'collapse blank lines before headings'],

    // Multiple consecutive blank lines anywhere
    [/\n{3,}/g, '\n\n', 'collapse 3+ blank lines to 2'],

    // Trailing whitespace on lines
    [/[ \t]+$/gm, '', 'strip trailing whitespace'],

    // Empty blockquote lines ("> " with nothing after)
    [/^>\s*$/gm, '', 'strip empty blockquote lines'],

    // Blank line after table separator row
    [/(\|[-:| ]+\|\n)\n+/g, '$1', 'strip blank line after table separator'],

    // Blank line between consecutive list items
    [/(^[-*] [^\n]+)\n\n(?=[-*] )/gm,
     '$1\n', 'collapse blank lines between list items'],

    // Blank line between consecutive numbered list items
    [/(^\d+\. [^\n]+)\n\n(?=\d+\. )/gm,
     '$1\n', 'collapse blank lines between numbered list items'],
];

/**
 * Protect code blocks from density compression.
 * Extracts fenced code blocks, replaces with placeholders, returns restore fn.
 */
function protectCodeBlocks(text) {
    const blocks = [];
    const protected_ = text.replace(/```[\s\S]*?```/g, (match) => {
        blocks.push(match);
        return `\x00CODEBLOCK_${blocks.length - 1}\x00`;
    });
    return {
        text: protected_,
        restore: (t) => t.replace(/\x00CODEBLOCK_(\d+)\x00/g, (_, i) => blocks[i]),
    };
}

/**
 * Compress skill content by removing boilerplate sections and reducing density.
 *
 * @param {string} text - Raw skill markdown (frontmatter already stripped)
 * @returns {string} Compressed content
 */
function compressSkillContent(text) {
    let result = text;

    // === Phase 1: Structural stripping (operates on full text including code blocks) ===

    // Strip DOT graphs (not renderable in context)
    result = result.replace(/```dot[\s\S]*?```/g, '');

    // Unwrap EXTREMELY-IMPORTANT wrappers (keep inner content)
    result = result.replace(/<EXTREMELY-IMPORTANT>\n?([\s\S]*?)<\/EXTREMELY-IMPORTANT>/g, '$1');

    // Strip boilerplate heading sections (table-driven)
    for (const heading of STRIP_SECTIONS) {
        const midDoc = new RegExp(`##+ ${heading}[\\s\\S]*?(?=\\n## |\\n# )`, 'g');
        const atEnd = new RegExp(`##+ ${heading}[\\s\\S]*$`, 'g');
        result = result.replace(midDoc, '');
        result = result.replace(atEnd, '');
    }

    // Strip YAML frontmatter (already parsed), horizontal rules, HTML comments
    result = result.replace(/^---\n[\s\S]*?\n---\n*/g, '');
    result = result.replace(/\n---\n/g, '\n');
    result = result.replace(/<!--[\s\S]*?-->/g, '');

    // === Phase 2: Density reduction (protect code blocks first) ===

    const { text: safeText, restore } = protectCodeBlocks(result);
    let dense = safeText;

    for (const [pattern, replacement] of DENSITY_RULES) {
        dense = dense.replace(pattern, replacement);
    }

    result = restore(dense);

    // Final cleanup: collapse excessive blank lines (post-restore)
    result = result.replace(/\n{3,}/g, '\n\n');

    return result.trim();
}

module.exports = { compressSkillContent, STRIP_SECTIONS, DENSITY_RULES, protectCodeBlocks };
