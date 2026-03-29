# Edit Snapshot Recovery

This is a cross-reference. The canonical recovery procedure lives in `outline-wiki-editing/references/edit-snapshot.md`.

## Quick Recovery Steps

1. Check `~/.codex/_edit_snapshots/{document-id}.md` for the pre-edit snapshot
2. If snapshot exists: `documents.update` with the snapshot content
3. If no snapshot: check Outline's revision history (Settings → History)
4. Last resort: `documents.restore` from Outline's trash (if deleted)

For the full procedure with curl examples, see `outline-wiki-editing/references/edit-snapshot.md`.
