# Wiki Adapters

Platform-specific configurations for wiki skills.

## Supported Platforms

| Platform | Adapter | Status |
|----------|---------|--------|
| **Outline** | [outline.md](outline.md) | ✅ Supported |
| Custom platform | [platform-template.md](platform-template.md) | ⚙️ Configure locally |
| Confluence | — | 🔮 Future |
| Notion | — | 🔮 Future |
| GitBook | — | 🔮 Future |

## Configuration

Set `WIKI_PLATFORM` in your `.env` file:

```bash
WIKI_PLATFORM=your-platform
```

Each adapter documents its required environment variables and MCP tool mappings.

## Adding a New Adapter

1. Create `{platform}.md` in this directory
2. Implement all operations from [adapter-interface.md](adapter-interface.md)
3. Document required environment variables
4. Document MCP tool mappings (if available)
5. Add URL patterns for link verification
6. Update the table above

## Architecture

```markdown
wiki/
├── _adapters/
│   ├── README.md              # This file
│   ├── adapter-interface.md   # Generic interface
│   └── platform-template.md   # Provider-neutral adapter template
├── wiki-orchestrator/         # Generic workflow (routes to adapter, downloads, edits, publishes)
├── wiki-verify/               # Generic (fact-checking)
├── wiki-debunker/             # Generic (claim verification)
├── wiki-secret-audit/         # Generic (security scanning)
└── link-verification/         # Uses adapter for URL patterns
```

## Platform-Agnostic vs Platform-Specific Skills

| Skill | Type | Notes |
|-------|------|-------|
| `wiki-orchestrator` | Generic (uses adapters) | Orchestrates download, edit, publish workflow |
| `wiki-verify` | Generic | Fact-checking against sources |
| `wiki-debunker` | Generic | Claim verification |
| `wiki-secret-audit` | Generic | Security scanning |
| `link-verification` | Uses adapter | URL patterns from adapter |
