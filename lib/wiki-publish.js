'use strict';

const {
    findMarkdownArtifacts,
    stripFrontmatterWithOffset,
} = require('./wiki-markdown');

function formatIssues(label, issues) {
    if (issues.length === 0) return [];
    return [`${label}:`, ...issues.map(issue => `  - ${issue}`)];
}

function assertArtifactFree(markdown, options = {}) {
    const label = options.label || 'markdown';
    const lineOffset = options.lineOffset || 0;
    const issues = findMarkdownArtifacts(markdown, { lineOffset });
    if (issues.length > 0) {
        throw new Error(formatIssues(label, issues).join('\n'));
    }
}

function prepareMarkdownForValidation(content, options = {}) {
    if (!options.stripFrontmatter) {
        return { markdown: content, lineOffset: 0 };
    }
    return stripFrontmatterWithOffset(content);
}

function assertRoundTripArtifacts(payload) {
    assertArtifactFree(payload.outboundMarkdown, {
        label: payload.outboundLabel || 'outbound markdown',
        lineOffset: payload.outboundLineOffset || 0,
    });
    assertArtifactFree(payload.persistedMarkdown, {
        label: payload.persistedLabel || 'persisted markdown',
        lineOffset: payload.persistedLineOffset || 0,
    });
}

module.exports = {
    assertArtifactFree,
    prepareMarkdownForValidation,
    assertRoundTripArtifacts,
};
