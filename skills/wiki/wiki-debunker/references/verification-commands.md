# Wiki Debunker — Verification Commands

> Reference material for the `wiki-debunker` skill.
> See `skill.md` for core guidance.

## Git History Verification

```bash
# Who introduced a concept?
git log --all --oneline --grep="websocket" | head -10

# When was file last changed?
git log -1 --format="%ci %an" -- src/telephony/websocket.ts

# What changed in a date range?
git log --since="2026-01-01" --until="2026-01-31" --oneline

# Who's responsible for specific lines?
git blame -L 50,60 src/config.ts

# Find merge commits (decisions)
git log --merges --oneline --since="2026-01-01"
```

### PR as Decision Record

```
# Use your repository adapter to get PR details
repo_get_pull_request(repository: "your-service", pullRequestId: 47)

# Get PR discussion threads
repo_get_pull_request_threads(repository: "your-service", pullRequestId: 47)
```

## Issue Tracker Verification

```
# Find ticket by topic
issue tracker query: "Search issues mentioning 'Telnyx' in Your Team"

# Get specific ticket with comments
issue tracker query: "Get issue TICKET-123 with all comments"

# Find decisions in comments
issue tracker query: "Get comments on TICKET-89 containing 'decided'"
```

**Verify before citing:**
- Does ticket exist?
- Does it actually contain the claimed decision?
- Is the attribution correct (assignee vs commenter)?

## Work Item / Build Verification

```
# Use your issue tracker adapter
issue_get(id: 1234)
issue_get_comments(id: 1234)

# Search commits using your repository adapter
repo_search_commits(repository: "your-service", searchText: "deploy")

# Find PR by branch
repo_list_pull_requests(repository: "your-service", sourceBranch: "feature/websocket-refactor")
```

## Meeting Transcript Verification

Use when claims reference meeting discussions, verbal agreements, or spoken quotes.

### Using Your Meeting Adapter

```
# Use your meeting transcript adapter to search
meeting_search(query: "KEYWORD")
meeting_list(limit: 10, include_transcript: true)
```

### Timestamp Deep Links

Many transcript services support `#t={seconds}` format:
- `share_url#t=645` → jumps to 10:45 in recording
- Conversion: `HH:MM:SS` → `HH*3600 + MM*60 + SS` = seconds

### Transcript Structure (Example)

```json
{
  "transcript": [
    {
      "speaker": { "display_name": "Person Name" },
      "timestamp": "00:10:45",
      "text": "Let's prioritize the vendor integration first."
    }
  ]
}
```

### Meeting Red Flags

| Signal | Action |
|--------|--------|
| Claim about meeting >30 days ago | May exceed transcript retention — verify |
| Quote but no transcript match | Possible fabrication — search all meetings |
| Speaker attribution mismatch | Cross-check `speaker` field in API |
| Meeting "discussed X" but no transcript hit | May be paraphrased or wrong meeting |

Note: Meeting share URLs may require authentication (redirect to sign-in).
