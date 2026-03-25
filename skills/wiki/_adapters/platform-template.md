# Wiki Adapter Template

Use this file as the starting point for a provider-specific wiki adapter.

## Document here

- Required MCP operations for `create_page`, `update_page`, `get_page`, and `search_pages`
- Required environment variables and auth setup
- Canonical URL pattern for page links and anchors
- Field mappings from generic wiki fields to provider fields
- Any provider-specific rendering or API gotchas that shared skills should not hardcode

## Table of Contents Behavior

Document how this platform handles TOCs:

| Field | Value | Notes |
|-------|-------|-------|
| `toc_behavior` | `auto` / `manual` / `unsupported` | How the platform generates TOCs |
| `toc_syntax` | (e.g., `[[_TOC_]]`) | Markup to insert if `manual`. Leave blank for `auto`/`unsupported`. |
| `toc_placement` | (e.g., "after intro, before first H2") | Where to place markup. Leave blank for `auto`/`unsupported`. |
| `toc_anchor_format` | (e.g., `#heading-slug`) | How platform generates heading anchors. Optional. |

**Values and required fields per value:**

| `toc_behavior` | `toc_syntax` | `toc_placement` | `toc_anchor_format` | Description |
|----------------|-------------|-----------------|---------------------|-------------|
| `auto` | Leave blank | Leave blank | Optional | Platform renders TOC from headings automatically. Do NOT add manual markup. |
| `manual` | **Required** | **Required** | Optional | Platform needs explicit markup. Insert when page has 4+ H2/H3 headings. |
| `unsupported` | Leave blank | Leave blank | Leave blank | Platform has no TOC support. Never insert TOC markup. |

The **4+ H2/H3 heading threshold** is a global orchestrator rule (see wiki-orchestrator Stage 2), not adapter-specific.

`toc_anchor_format` documents how the **platform** generates heading anchors (e.g., `#heading-slug`, `#user-content-heading-slug`). This is for agents generating manual anchor links, not for TOC insertion.
