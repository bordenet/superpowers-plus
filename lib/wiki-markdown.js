'use strict';

function normalizeMarkdown(text) {
    return text.replace(/\r\n/g, '\n').replace(/\r/g, '\n');
}

function stripFrontmatterWithOffset(content) {
    const normalized = normalizeMarkdown(content);
    const match = normalized.match(/^---\n[\s\S]*?\n---(?:\n)+/);
    if (!match) return { markdown: normalized, lineOffset: 0 };
    return {
        markdown: normalized.slice(match[0].length),
        lineOffset: match[0].split('\n').length - 1,
    };
}

function stripFrontmatter(content) {
    return stripFrontmatterWithOffset(content).markdown;
}

function maskInlineCode(line) {
    let result = '';
    let index = 0;

    while (index < line.length) {
        if (line[index] !== '`') {
            result += line[index];
            index += 1;
            continue;
        }

        let tickCount = 1;
        while (line[index + tickCount] === '`') tickCount += 1;

        const fence = '`'.repeat(tickCount);
        const end = line.indexOf(fence, index + tickCount);
        if (end === -1) {
            result += line.slice(index);
            break;
        }

        result += ' '.repeat(end + tickCount - index);
        index = end + tickCount;
    }

    return result;
}

function parseFence(line) {
    const match = line.match(/^( {0,3})(`{3,}|~{3,})([^`]*)$/);
    if (!match) return null;
    return { char: match[2][0], length: match[2].length };
}

function isFenceClose(line, fence) {
    const match = line.match(/^( {0,3})(`+|~+)\s*$/);
    return Boolean(match && match[2][0] === fence.char && match[2].length >= fence.length);
}

function isIndentedCodeLine(line) {
    return /^( {4}|\t)/.test(line);
}

function stripBlockquotePrefix(line) {
    return line.replace(/^(?: {0,3}> ?)+/, '');
}

function scannableLines(markdown, lineOffset = 0) {
    const lines = normalizeMarkdown(markdown).split('\n');
    const result = [];
    let inFence = false;
    let activeFence = null;

    lines.forEach((line, index) => {
        const structuralLine = stripBlockquotePrefix(line);

        if (inFence) {
            if (isFenceClose(structuralLine, activeFence)) {
                inFence = false;
                activeFence = null;
            }
            return;
        }

        if (isIndentedCodeLine(structuralLine)) return;

        const fence = parseFence(structuralLine);
        if (fence) {
            inFence = true;
            activeFence = fence;
            return;
        }

        result.push({ line, number: index + 1 + lineOffset });
    });

    return result;
}

function isSeparatorCell(cell) {
    return /^:?-{3,}:?$/.test(cell.trim());
}

function hasMeaningfulContent(parts, start, end) {
    return parts.some((part, index) => {
        if (index >= start && index <= end) return false;
        const trimmed = part.trim();
        return trimmed !== '' && !isSeparatorCell(trimmed);
    });
}

function detectMalformedTables(markdown, options = {}) {
    const lineOffset = options.lineOffset || 0;
    return scannableLines(markdown, lineOffset)
        .flatMap(({ line, number }) => {
            const masked = maskInlineCode(line);
            const trimmed = masked.trim();
            if (!trimmed.includes('|')) return [];

            const normalized = trimmed.replace(/^\|/, '').replace(/\|$/, '');
            const parts = normalized.split('|');
            let runStart = -1;
            let runLength = 0;

            const flushRun = (endIndex) => {
                if (runLength >= 2 && hasMeaningfulContent(parts, runStart, endIndex)) {
                    const excerpt = line.trim().length > 120 ? `${line.trim().slice(0, 117)}...` : line.trim();
                    return [`line ${number}: collapsed table rows detected: ${excerpt}`];
                }
                return [];
            };

            for (let index = 0; index < parts.length; index += 1) {
                if (isSeparatorCell(parts[index])) {
                    if (runStart === -1) runStart = index;
                    runLength += 1;
                    continue;
                }

                if (runStart !== -1) {
                    const issues = flushRun(index - 1);
                    if (issues.length > 0) return issues;
                    runStart = -1;
                    runLength = 0;
                }
            }

            if (runStart !== -1) return flushRun(parts.length - 1);

            return [];
        });
}

function findMarkdownArtifacts(markdown, options = {}) {
    const lineOffset = options.lineOffset || 0;
    const issues = [];

    scannableLines(markdown, lineOffset).forEach(({ line, number }) => {
        const structuralLine = stripBlockquotePrefix(line);
        const masked = maskInlineCode(line);

        // Outline renders the document title automatically — an H1 in the body
        // creates a redundant duplicate header and wastes vertical space.
        // Use structuralLine so H1 inside a blockquote (e.g. "> # Title") is also caught.
        if (/^# /.test(structuralLine)) issues.push(`line ${number}: H1 heading found — Outline renders the page title automatically; remove this heading`);
        if (masked.includes('\\[')) issues.push(`line ${number}: escaped square bracket \\[ found`);
        if (masked.includes('\\]')) issues.push(`line ${number}: escaped square bracket \\] found`);
        if (masked.includes('&nbsp;')) issues.push(`line ${number}: literal &nbsp; found`);
        if (masked.includes('&mdash;')) issues.push(`line ${number}: literal &mdash; found`);
        if (/\[[^\]]+\]\(\s*\)/.test(masked)) issues.push(`line ${number}: empty href found`);
    });

    return issues.concat(detectMalformedTables(markdown, { lineOffset }));
}

module.exports = {
    normalizeMarkdown,
    stripFrontmatterWithOffset,
    stripFrontmatter,
    maskInlineCode,
    parseFence,
    isFenceClose,
    isIndentedCodeLine,
    stripBlockquotePrefix,
    scannableLines,
    detectMalformedTables,
    findMarkdownArtifacts,
};
