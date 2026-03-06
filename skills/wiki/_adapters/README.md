# Wiki Adapters

Platform-specific configurations for wiki skills.

## Supported Platforms

| Platform | Adapter | Status |
|----------|---------|--------|
| [Outline](https://www.getoutline.com/) | [outline.md](outline.md) | ✅ Supported |
| Confluence | — | 🔮 Future |
| Notion | — | 🔮 Future |
| GitBook | — | 🔮 Future |

## Configuration

Set `WIKI_PLATFORM` in your `.env` file:

```bash
WIKI_PLATFORM=outline
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

```
wiki/
├── _adapters/
│   ├── README.md              # This file
│   ├── adapter-interface.md   # Generic interface
│   └── outline.md             # Outline-specific config
├── wiki-orchestrator/         # Generic (routes to adapter)
├── wiki-authoring/            # Generic (formatting rules)
├── wiki-verify/               # Generic (fact-checking)
├── wiki-debunker/             # Generic (claim verification)
├── wiki-secret-audit/         # Generic (security scanning)
├── link-verification/         # Uses adapter for URL patterns
└── wiki-editing/              # Generic workflow (uses adapters)
```

## Platform-Agnostic vs Platform-Specific Skills

| Skill | Type | Notes |
|-------|------|-------|
| `wiki-orchestrator` | Generic | Routes to appropriate adapter |
| `wiki-authoring` | Generic | Formatting rules (may vary by platform) |
| `wiki-verify` | Generic | Fact-checking against sources |
| `wiki-debunker` | Generic | Claim verification |
| `wiki-secret-audit` | Generic | Security scanning |
| `link-verification` | Uses adapter | URL patterns from adapter |
| `wiki-editing` | Generic (uses adapters) | Workflow and API operations |

