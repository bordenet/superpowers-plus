/**
 * compress.js — Shared skill content compression.
 *
 * Strips boilerplate sections, DOT graphs, HTML comments, and excessive
 * whitespace from skill markdown before injecting into agent context.
 *
 * Used by: superpowers-augment.js, mcp/superpowers-mcp.js
 */
'use strict';

// Sections to strip — heading text patterns that are boilerplate/routing info.
// "Failure Modes" and "SUBAGENT-STOP" are deliberately EXCLUDED (operational).
const STRIP_SECTIONS = [
    'When to Use', 'Overview', 'Common Rationalizations',
    'Why (?:Order|This|It) Matters', 'Quick Reference',
    'Related Skills', 'Cross[- ]?References', 'Integration with .*',
    'Reference Files', 'When This Skill Fires', 'When NOT to Use',
    'Manual Invocation', 'Incident Log', "I'm Stuck",
    // Routing/navigation metadata — agent has skill index from bootstrap
    'Companion Skills', 'Escalation Path',
];

/**
 * Compress skill content by removing boilerplate sections and formatting noise.
 *
 * @param {string} text - Raw skill markdown (frontmatter already stripped)
 * @returns {string} Compressed content
 */
function compressSkillContent(text) {
    let result = text;

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

    // Collapse excessive blank lines
    result = result.replace(/\n{3,}/g, '\n\n');

    return result.trim();
}

module.exports = { compressSkillContent, STRIP_SECTIONS };
