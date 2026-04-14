/**
 * compress.js — Shared skill content compression.
 *
 * Two-phase compression:
 *   Phase 1 (structural): Strip boilerplate sections, DOT graphs, HTML comments.
 *                         EXTREMELY_IMPORTANT blocks are extracted and re-inserted
 *                         AFTER section stripping so they survive even when their
 *                         parent section heading is in STRIP_SECTIONS.
 *   Phase 2 (density):    Reduce prose verbosity, deduplicate formatting patterns,
 *                         compress navigation boilerplate, tighten whitespace.
 *
 * Preserves: <EXTREMELY_IMPORTANT> block content (extracted pre-strip, restored
 *            post-strip), SUBAGENT-STOP, Failure Modes, Hallucination Prevention,
 *            Incident Log/Record/History, References (pointer sections), code blocks,
 *            data tables, checklists, procedures, compress:false opt-out.
 *
 * NOTE: "Preserves" means the code actively protects these items. If you add a
 * heading to STRIP_SECTIONS, verify it does not appear in skills with
 * <EXTREMELY_IMPORTANT> content under it. The extraction mechanism is a safety
 * net, not a license to strip critical sections.
 *
 * Used by: superpowers-augment.js, mcp/superpowers-mcp.js
 */
'use strict';

// Phase 1: Sections to strip — heading text patterns that are boilerplate/routing info.
//
// EXCLUDED (operational — must survive compression):
//   "Failure Modes", "SUBAGENT-STOP", "Hallucination Prevention",
//   "Incident Log", "Incident Record", "Incident History",
//   "References" (pointer sections to reference files).
//
// Incident: 2026-04-14 — Stripping "Hallucination Prevention" deleted
// <EXTREMELY_IMPORTANT> URL verification rules from link-verification and
// issue-link-verification skills. Stripping "References" deleted pointers
// to references/incidents.md (78 lines of real failure history).
// Stripping "Incident Log/Record/History" deleted recurrence-prevention
// context. Result: wiki authoring regressed to producing broken hyperlinks.
const STRIP_SECTIONS = [
    'When to Use', 'Overview', 'Common Rationalizations',
    'Why (?:Order|This|It|the Gate) (?:Matters|Exists)', 'Quick Reference',
    'Related Skills', 'Cross[- ]?References', 'Integration with .*',
    'Reference Files', // routing metadata, distinct from "References" (pointer sections — preserved)
    'When This Skill Fires', 'When NOT to Use',
    'Manual Invocation', "I'm Stuck",
    // Routing/navigation metadata — agent has skill index from bootstrap
    'Companion Skills', 'Escalation Path',
    // Examples are educational, not operational — strip to save tokens
    'Example', 'Example Invocation', 'Example:.*',
    // Rationalization/anti-pattern tables are motivational, not procedural
    'Rationalizations to Reject', 'Anti-Patterns',
    // Purpose as standalone section (already in frontmatter/header)
    'Purpose',
    // Success criteria — aspirational framing
    'Success Criteria',
    // Stop conditions — already enforced by gate logic
    'Stop Conditions', 'Escalation Conditions',
    // Routing variants found in domain-specific skills
    // NOTE: "Next Steps" deliberately EXCLUDED — contains operational routing tables
    'When to Invoke', '🚨 WHEN TO USE THIS SKILL',
    'Trigger Conditions',
    //
    // ---- REMOVED (incident 2026-04-14) — these are OPERATIONAL, not boilerplate ----
    // 'References?(?::.*)?'   — pointers to reference files (incidents.md, etc.)
    // 'Incident Log'          — real failure records that prevent recurrence
    // 'Incident Record'       — same
    // 'Incident History'      — same
    // 'Hallucination Prevention' — contains <EXTREMELY_IMPORTANT> verification gates
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

    // === Phase 1: Structural stripping ===

    // Strip DOT graphs BEFORE code block protection (DOT blocks are code blocks
    // that we want removed, not preserved).
    result = result.replace(/```dot[\s\S]*?```/g, '');

    // Step 0: Protect remaining code blocks from EI extraction. Tags inside
    // fenced code blocks (e.g., a skill documenting EI usage) must NOT be
    // extracted. We reuse protectCodeBlocks and restore after step 1c.
    const { text: codeProtected, restore: restoreCodeBlocks } = protectCodeBlocks(result);
    result = codeProtected;

    // Step 1a: EXTRACT <EXTREMELY_IMPORTANT> blocks BEFORE section stripping.
    // These blocks contain operative safety gates (URL verification, hallucination
    // prevention, scope restrictions). They must survive even if their parent
    // heading is in STRIP_SECTIONS. We extract them, strip sections, then
    // re-insert them. The tags themselves are removed (unwrapped) — only the
    // inner content is preserved.
    //
    // Incident 2026-04-14: Previously, tags were unwrapped first (exposing bare
    // content), then section stripping deleted the content along with its parent
    // heading. The comment on line 9 falsely claimed HARD-GATE preservation —
    // no such logic existed. This extraction/restoration fixes that.
    // Nesting is unsupported — nested tags produce orphaned raw tags in output.
    // No skill currently nests these. If you need nesting, loop extraction until
    // no tags remain. See incident 2026-04-14.
    const importantBlocks = [];
    const extractImportantBlock = (_, inner) => {
        const trimmed = inner.trim();
        if (!trimmed) return ''; // Empty blocks → discard, don't insert blank lines
        importantBlocks.push(trimmed);
        return `\x00IMPORTANT_${importantBlocks.length - 1}\x00\n`;
    };
    // Two separate passes — prevents cross-variant matching (e.g., _IMPORTANT
    // open tag closed by -IMPORTANT). Each pass enforces matched open/close.
    result = result.replace(/<EXTREMELY_IMPORTANT>\n?([\s\S]*?)<\/EXTREMELY_IMPORTANT>\n{0,2}/g, extractImportantBlock);
    result = result.replace(/<EXTREMELY-IMPORTANT>\n?([\s\S]*?)<\/EXTREMELY-IMPORTANT>\n{0,2}/g, extractImportantBlock);

    // Step 1b: Strip boilerplate heading sections (table-driven).
    // Placeholders from step 1a survive this — they are plain text tokens that
    // get deleted along with their parent section, then restored in step 1c.
    const strippedPlaceholders = new Set();
    for (const heading of STRIP_SECTIONS) {
        const midDoc = new RegExp(`##+ ${heading}[\\s\\S]*?(?=\\n## |\\n# )`, 'g');
        const atEnd = new RegExp(`##+ ${heading}[\\s\\S]*$`, 'g');
        // Track which placeholders are inside stripped sections
        const collectStripped = (match) => {
            const placeholderRe = /\x00IMPORTANT_(\d+)\x00/g;
            let m;
            while ((m = placeholderRe.exec(match)) !== null) {
                strippedPlaceholders.add(parseInt(m[1], 10));
            }
            return '';
        };
        result = result.replace(midDoc, collectStripped);
        result = result.replace(atEnd, collectStripped);
    }

    // Step 1c: Restore EXTREMELY_IMPORTANT content.
    // - Placeholders that survived section stripping: restore in-place.
    // - Placeholders that were inside stripped sections: append at end of
    //   document so the operative content is not lost.
    result = result.replace(/\x00IMPORTANT_(\d+)\x00\n?/g, (_, i) => {
        return (importantBlocks[parseInt(i, 10)] || '') + '\n\n';
    });
    // Re-insert blocks that were inside stripped sections — append with a
    // synthetic heading so rescued content has semantic context (not orphaned
    // bare text at EOF that an LLM might ignore).
    if (strippedPlaceholders.size > 0) {
        const rescued = [];
        for (const idx of strippedPlaceholders) {
            if (importantBlocks[idx]) rescued.push(importantBlocks[idx]);
        }
        if (rescued.length > 0) {
            result += '\n\n## Critical Rules (preserved from compression)\n\n' + rescued.join('\n\n') + '\n';
        }
    }

    // Restore code blocks protected in Step 0 (before EI extraction).
    result = restoreCodeBlocks(result);

    // Strip YAML frontmatter (already parsed), horizontal rules, HTML comments
    result = result.replace(/^---\n[\s\S]*?\n---\n*/g, '');
    result = result.replace(/\n---\n/g, '\n');
    result = result.replace(/<!--[\s\S]*?-->/g, '');

    // === Phase 2: Density reduction (protect code blocks again for density rules) ===

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
