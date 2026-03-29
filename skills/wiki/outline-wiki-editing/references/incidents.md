# Incident Log — Outline Wiki Editing

Real failures that drove each rule in this skill. Reference these when questioning why a gate exists.

## Link Verification Failures

| Date | Page | Failure | Rule Created |
|------|------|---------|-------------|
| 2026-03-04 | Interviewer On-Boarding | Used short-ID links (`/doc/Buc2GNFqhG`) instead of full slugs | Link verification HARD BLOCK |
| 2026-03-04 | Recruiting Documentation Map | Unverified emoji anchors broke | Anchor verification |
| 2026-02-20 | Getting Started | Hallucinated `/doc/vpn-netbird-setup-YlxEoSpFRk` — caught by USER | Link verification mandatory |

## Write Scope Failures

| Date | Failure | Impact | Rule Created |
|------|---------|--------|-------------|
| 2026-03-17 | Published PRD under "PRD Drafts" in Joseph's People section instead of Team Delta | Document in wrong team area; user had to move manually | Parent chain verification |
| 2026-02-16 | Wiki cleanup affected pages outside Matt's ownership | Other teams' docs modified | Write scope restriction |

## Download-Before-Edit Failures

| Date | Failure | Impact | Rule Created |
|------|---------|--------|-------------|
| 2026-03-17 | Agent tried to `documents.move` without fetching current state; user had already moved it | Would have undone user's fix | Always download first |

## Deletion Failures

| Date | Failure | Impact | Rule Created |
|------|---------|--------|-------------|
| 2026-02-16 | Both "Rules of Engagement (ROE)" pages deleted during duplicate cleanup | Pages lost until recovered from trash | Pre-deletion backup mandatory |

## Duplicate Creation Failures

| Date | Failure | Impact | Rule Created |
|------|---------|--------|-------------|
| 2026-02-10 | Created 5 duplicate "Azure DevOps MCP Server" pages | 4 had to be manually deleted | Duplicate check before create |

## Secret Exposure

| Date | Failure | Impact | Rule Created |
|------|---------|--------|-------------|
| 2026-02-24 | SQL Server credentials published to wiki | Security incident | Secret scan mandatory |

## Content Formatting Failures

| Date | Failure | Impact | Rule Created |
|------|---------|--------|-------------|
| 2026-03-04 | Checkbox syntax `[ ]` in table cells escaped to `\[` | Broken rendering | Table cell syntax restrictions |
| 2026-03-04 | `&nbsp;` in table cells rendered as literal text | Broken rendering | No HTML entities in tables |
| 2026-02-27 | Heredoc with emojis/pipes produced garbled output | Corrupted terminal | No heredocs rule |

## URL Construction Failures

| Date | Failure | Impact | Rule Created |
|------|---------|--------|-------------|
| 2026-02-19 | Used `urlId` to construct URL, got 404 despite curl returning 200 (SPA routing) | User saw "Not Found" | Use `url` field, not `urlId` |

## API Access Failures

| Date | Failure | Impact | Rule Created |
|------|---------|--------|-------------|
| 2026-03-25 | Agent used `web-fetch` on Outline SPA, got empty HTML shell, then GAVE UP and asked user to paste content | User had to correct agent; wasted time and trust | RULE ZERO: Never give up on Outline access — always use API via curl with `~/.codex/.env` credentials |

## Bulk Edit Content Destruction

| Date | Failure | Impact | Rule Created |
|------|---------|--------|-------------|
| 2026-03-25 | Sub-agents performing bulk TOC-toggle updates passed truncated text to `update_document_outline`, replacing full page content with fragments | 5 pages destroyed: DELTA-1234 (~30K chars → 447 chars), Engineer Onboarding, "Heroics" Culture kills, "Disagree and Commit", Coding Agent: Augment.ai. 3 additional pages restored programmatically from context. Required manual revision restore via Outline UI for the 5 destroyed pages. | Pre-edit snapshot mandatory (`references/edit-snapshot.md`); post-update verification mandatory; sub-agents must not perform mid-page text surgery on large pages |

## Embed Failures

| Date | Failure | Impact | Rule Created |
|------|---------|--------|-------------|
| 2026-02-20 | API update broke embedded "Plan-of-Record" document | Embed became plain link | Embed detection warning |

