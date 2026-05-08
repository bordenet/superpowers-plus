---
name: screenshot
source: superpowers-plus
augment_menu: true
triggers: ["/sp-ss", "/sp-screenshot", "look at my screenshot", "screenshot shows", "check this screenshot", "I screenshotted"]
anti_triggers: ["search for screenshots", "screenshot tool", "take a screenshot", "capture screen"]
description: Visual input bridge. Grabs the N most recent screenshots from the configured folder and dispatches to an intent-driven action. Supports fix (with project context), explain, compare, spec, do-this, recap, and free-form. Cross-platform folder discovery with auto-populate to ~/.codex/.env.
summary: "Use when: passing screenshots to the AI for action. /sp-ss [N] [intent] — grabs N newest, acts on intent."
coordination:
  group: productivity
  order: 6
  requires: []
  enables: ["systematic-debugging", "brainstorming", "feature-development"]
  escalates_to: []
  internal: false
composition:
  consumes: [screenshot, image, visual-context]
  produces: [explanation, fix, spec, comparison, insight]
  capabilities: [reads-images, dispatches-intent, discovers-path]
  priority: 4
---

<!-- Credit: Allie K. Miller (https://www.linkedin.com/posts/alliekmiller_give-me-one-minute-and-ill-improve-your-share-7457142778410594304-_cdB) — original /ss concept. This skill extends that design with a formal intent dispatch table, cross-platform folder discovery, context injection, and operational guardrails. -->

# Screenshot

> **Wrong skill?** Take a screenshot → use your OS. Debug without a screenshot → `systematic-debugging`. Build a feature → `feature-development`.
>
> **Visual input bridge: grab screenshots and act on them.**

## Syntax

```
/sp-ss [N] [intent text...]
/sp-screenshot [N] [intent text...]
```

**Parse rule:** If the first token after the command matches `/^\d+$/` (one or more digit characters, no sign), it is parsed as count `N`. Otherwise `N=1` and the entire remainder is the intent. Details:
- Tokens like `1.5` and `abc` do not match the regex → become intent text
- `0` matches the regex but fails range validation (count must be ≥1) → default to 1 with a note
- Negative numbers (e.g., `-1`) do not match the regex → become intent text, not a defaulted count

If intent is omitted entirely, default to `huh`.

**Examples:**

| Command | Count | Intent |
|---|---|---|
| `/sp-ss` | 1 | huh (default) |
| `/sp-ss huh` | 1 | huh |
| `/sp-ss 3 fix` | 3 | fix |
| `/sp-ss 4 compare` | 4 | compare |
| `/sp-ss spec` | 1 | spec |
| `/sp-ss 2 make me an infographic` | 2 | free-form |
| `/sp-ss 0 fix` | 1 | fix (invalid count, defaulted to 1) |
| `/sp-ss abc fix` | 1 | abc fix (non-numeric, treated as intent) |

## Step 1: Resolve Screenshot Folder

Read `SCREENSHOT_DIR` from `~/.codex/.env`:
- Use the Bash tool: `grep "^SCREENSHOT_DIR=" ~/.codex/.env 2>/dev/null | cut -d= -f2-` — extract only this key, do NOT read the full `.env` file (it may contain unrelated secrets).
- If set **and** the path exists → use it, skip discovery.
- If not set **or** the path no longer exists → run platform discovery below.

**Platform discovery:**

```
macOS:
  path=$(defaults read com.apple.screencapture location 2>/dev/null)
  Quote the result when testing: [ -n "$path" ] && [ -d "$path" ]
  If path exists → use it
  Else → use ~/Desktop

WSL (detected via /proc/version containing "Microsoft" or "microsoft"):
  Try in order:
    1. username=$(cmd.exe /c "echo %USERNAME%" 2>/dev/null | tr -d '\r\n')
    2. If empty → username=$USER
    3. If still empty → username=$(whoami)
    4. If all fail → stop; print: "Could not determine Windows username for WSL
       path resolution. Set SCREENSHOT_DIR manually in ~/.codex/.env."
  Construct: /mnt/c/Users/<username>/Pictures/Screenshots
  Note: if the username contains spaces or special characters, quote the path.

Linux (non-WSL):
  try $XDG_SCREENSHOTS_DIR (rarely set — not part of XDG Base Dir spec; treat
    as a bonus hint, not a reliable default)
  → ~/Pictures/Screenshots
  → ~/Screenshots

Windows (PowerShell):
  path = [Environment]::GetFolderPath('MyPictures') + '\Screenshots'
  Note: on enterprise machines this may be a UNC path (\\server\...).
  UNC paths cannot be used directly in ~/.codex/.env without escaping.
  If GetFolderPath returns a UNC path, print a warning and ask the user to
  set SCREENSHOT_DIR manually.
```

**Validate before persisting:** After discovery returns a path, verify it is an existing directory (`[ -d "$path" ]` or equivalent) before writing to `.env`. If the check fails, fall back to the next discovery step rather than persisting an invalid path.

**Persist after discovery (upsert, not append-only):**

- If `SCREENSHOT_DIR` key is already present in `~/.codex/.env` (checked via grep): use the Edit tool to replace the existing `SCREENSHOT_DIR=<old value>` line with `SCREENSHOT_DIR=<discovered_path>`. This handles stale paths and avoids shell quoting issues with paths that contain spaces or special characters.
- If the key is absent: use the Bash tool to append: `echo "SCREENSHOT_DIR=<discovered_path>" >> ~/.codex/.env` (quote the path in the echo if it contains spaces).

If the write fails (read-only `.env`): print "Add `SCREENSHOT_DIR=<path>` to `~/.codex/.env` to persist this setting." Then proceed with the discovered path for this session only.

## Step 2: List and Select Files

List image files in the resolved folder, sorted newest-to-oldest by modification time. Use **case-insensitive** extension matching. Include: `.png`, `.jpg`, `.jpeg`, `.gif`, `.webp`, `.heic`, `.bmp`, `.tif`, `.tiff` (and their uppercase variants on case-sensitive filesystems).

Select the N most recent files.

**Guardrails:**

- **File size limit:** Skip any file exceeding `SCREENSHOT_MAX_FILE_MB` MB (default 10). If the configured value is `≤0` or non-numeric, treat as 10 and warn: "Invalid SCREENSHOT_MAX_FILE_MB; using default 10MB." To get file size in bytes: `stat -f%z <file>` (macOS) or `stat -c%s <file>` (Linux/WSL); divide by 1048576 to compare against the MB limit. Print: "Skipped `<filename>` (exceeds limit)." If all selected files are skipped, stop and report.
- **Max images per invocation:** `SCREENSHOT_MAX_IMAGES` in `~/.codex/.env` (default 4). If the configured value is `≤0` or non-numeric, treat as 4 (default) and warn: "Invalid SCREENSHOT_MAX_IMAGES; using default 4." If requested count > cap, warn and truncate: "Capped at N images (set `SCREENSHOT_MAX_IMAGES` to increase)."
- **Count > available:** Use all available, note: "Only X screenshots found; using X instead of requested N."
- **Count invalid:** Default to 1, note: "Invalid count; using 1."
- **No image files found:** Stop. Print: "No screenshots found in `<path>`. Have you taken a screenshot recently?"
- **Staleness warning (advisory only):** If the newest file is older than `SCREENSHOT_STALENESS_MINUTES` (default 30), print: "⚠️ Newest screenshot is `<age>` old — is this the right one?" Then proceed immediately without waiting.

## Step 3: Read Images

Read each selected file using the Read tool. For HEIC files that fail: "Could not read `<filename>.heic` — HEIC may not be supported here. Save screenshots as PNG (System Settings → Screenshots → Format) for best compatibility." Skip the failed file and continue with remaining selections.

## Step 4: Dispatch Intent

Match the intent text against the table using **case-insensitive semantic matching**: the keyword list for each row is illustrative, not a regex. Use judgment to recognize intent. Key rules:
- `spec` does NOT match "specification" (different concept); `fix` DOES match "fixing" or "broken" (same semantic family)
- When multiple rows match, use the **Priority** column — lowest number wins
- For genuinely ambiguous input (e.g., "compare and fix"), apply the highest-priority matching row

**Priority ordering (first matching row wins):**

| Priority | Intent keywords | Action |
|---|---|---|
| 1 | `compare`, `diff`, `vs`, `versus`, `difference` | **Hard gate:** requires N≥2. If N=1: stop and print "compare requires N≥2 screenshots. Try `/sp-ss 2 compare`." Otherwise: diff/contrast the screenshots — layout, content, state changes, or visual differences. |
| 2 | `spec`, `requirements`, `prd`, `design doc` | **Content-type inference first** (see below). If UI/design → generate product/design spec. If code/error/terminal → offer `fix` instead and explain why. |
| 3 | `fix`, `error`, `bug`, `broken`, `crash` | **Inject project context first** (see below), then diagnose the problem shown and apply the fix. |
| 4 | `do this`, `apply`, `implement`, `learn`, `remix` | **Inject project context first** (see below), then identify the concept or pattern in the screenshot and adapt it to the current project's goals. |
| 5 | `huh`, `explain`, `what`, `describe`, `what is` | Describe the screenshot content clearly. Identify what it shows and what state it represents. |
| 6 | `recap`, `summarize`, `summary`, `overview` | One-paragraph synthesis of all N screenshots. What do they collectively show? |
| 7 | *(no match)* | **Free-form fallback:** prepend the screenshots as context and treat the full intent text as the prompt. No transformation. |

### Content-Type Inference (for `spec` intent)

Read the screenshot(s) and classify before dispatching:

- **UI/design indicators:** Color gradients, component layouts (buttons, cards, nav bars), wireframe outlines, typography specimens, design system elements, mockup annotations.
- **Code/terminal indicators:** Monospace font regions, command prompts (`$`, `>`, `#`), stack traces, syntax highlighting, line numbers, IDE chrome.

If UI/design → proceed with spec generation.
If code/error/terminal → print: "This looks like a code/error screenshot — routing to `fix` instead. Type `/sp-ss spec` anyway if you want a spec from this." Then **run Project Context Injection** (see below) before running the `fix` flow.
If ambiguous → ask the user: "Is this a UI screenshot (spec) or a code/error screenshot (fix)?"

### Project Context Injection (for `fix` and `do this` intents)

Before interpreting the screenshot, check the current working directory for project markers. Use the Read tool on each file found:

1. `package.json` → extract `name` and top-level `dependencies`/`devDependencies` keys
2. `go.mod` → extract module name
3. `Cargo.toml` → extract `[package] name`
4. `pyproject.toml` → extract `[project] name` (preferred over `setup.py` if both exist)
5. `setup.py` → extract `name=` argument (fallback if no `pyproject.toml`)

If a marker is found, inject a 1–2 sentence prefix before interpreting the screenshot:
*"Project: `<name>` (<detected tech stack>)."*

If no marker is found in CWD: proceed without injection, no error, no mention.

## Configuration Reference

| Key | Default | Description |
|---|---|---|
| `SCREENSHOT_DIR` | auto-discovered | Folder to scan for screenshots |
| `SCREENSHOT_MAX_IMAGES` | `4` | Max images per invocation (minimum 1) |
| `SCREENSHOT_MAX_FILE_MB` | `10` | Max file size in MB; files exceeding this are skipped |
| `SCREENSHOT_STALENESS_MINUTES` | `30` | Age threshold (minutes) for staleness warning |

## Platform Notes

| Platform | Discovery method | Default path if unset |
|---|---|---|
| macOS | `defaults read com.apple.screencapture location` | `~/Desktop` |
| Linux | `$XDG_SCREENSHOTS_DIR` (rarely set) | `~/Pictures/Screenshots` |
| WSL | Windows `%USERNAME%` via `cmd.exe`, then `$USER`, then `whoami` | `/mnt/c/Users/<user>/Pictures/Screenshots` |
| Windows | PowerShell `GetFolderPath('MyPictures')` | `%USERPROFILE%\Pictures\Screenshots` |

**Image reading:** Uses the Read tool. Claude Code and Augment Code both support image reading. Other platforms may vary — if images fail to load, confirm your platform supports image input.

**iCloud on macOS:** If screenshots are saved to iCloud Drive, the resolved path may be inside `~/Library/Mobile Documents/`. Files may not be immediately readable due to sync latency. If listing succeeds but Read fails, wait a moment and retry, or move screenshots to a local folder.

## Failure States

| Situation | Response |
|---|---|
| `SCREENSHOT_DIR` path vanished | Re-run discovery, upsert `.env` with new path |
| No image files | "No screenshots found in `<path>`." |
| All files exceed size limit | "All selected screenshots exceed the `SCREENSHOT_MAX_FILE_MB` limit. Resize or save as PNG, or increase the limit in `~/.codex/.env`." |
| Re-discovery also fails | Print: "Screenshot folder not found and auto-discovery failed. Set `SCREENSHOT_DIR` manually in `~/.codex/.env`." |
| Read-only `.env` | Print path for manual addition, continue for session |
| HEIC unreadable | Skip with PNG recommendation, continue with remaining files |
| `compare` with N=1 | Hard stop, prompt user to add count |
| Count > cap | Warn, truncate to cap |
| Count > available | Use all available, note shortfall |
| WSL username resolution fails | Stop, ask user to set `SCREENSHOT_DIR` manually |
| UNC path from Windows enterprise | Warn, ask user to set `SCREENSHOT_DIR` manually |

## Execution Traces

### Trace A: `/sp-ss 2 fix` (first-discovery branch — SCREENSHOT_DIR not yet set)

```
1. Parse: N=2, intent="fix"

2. Step 1 — Folder resolution:
   grep "^SCREENSHOT_DIR=" ~/.codex/.env → (no output — key absent)
   First-discovery branch: run macOS discovery:
     defaults read com.apple.screencapture location → "NOT_SET" (empty/error)
     Fallback: ~/Desktop
   Key absent → append: echo "SCREENSHOT_DIR=/Users/matt/Desktop" >> ~/.codex/.env
   Resolved path: /Users/matt/Desktop

3. Step 2 — File listing (case-insensitive *.png,*.jpg,... on ~/Desktop):
   Found 4 image files; newest two:
     Screenshot 2026-05-07 at 1.24.54 PM.png  (age: 3 min)
     Screenshot 2026-05-07 at 1.20.11 PM.png  (age: 7 min)
   Staleness check: newest is 3 min old → no warning
   Select 2 files (N=2, cap=4 — no truncation)

4. Step 3 — Read images:
   Read "Screenshot 2026-05-07 at 1.24.54 PM.png" → success (2.1MB, under 10MB limit)
   Read "Screenshot 2026-05-07 at 1.20.11 PM.png" → success (1.8MB)

5. Step 4 — Intent dispatch:
   intent="fix" → matches Priority 3 (fix/error/bug)
   Context injection: check CWD for project markers
     Found: package.json → name="my-app", deps include "react", "typescript"
     Inject prefix: "Project: my-app (React + TypeScript)."
   Dispatch: diagnose error shown in screenshots within my-app React+TS context
```

### Trace B: `/sp-ss 1 compare` (hard-gate failure)

```
1. Parse: N=1, intent="compare"

2. Step 1 — Folder resolution:
   grep "^SCREENSHOT_DIR=" ~/.codex/.env → /Users/matt/Desktop (key present, path exists)
   Use cached path, skip discovery.

3. Step 2 — File listing:
   Found 6 image files; newest one selected.

   (Step 3 skipped — hard gate fires before image read)

4. Step 4 — Intent dispatch:
   intent="compare" → matches Priority 1 (compare/diff/vs)
   Hard gate: N=1 < 2 required
   STOP. Print: "compare requires N≥2 screenshots. Try /sp-ss 2 compare."
   No images read. No dispatch.
```

### Trace C: `/sp-ss huh` (stale path — upsert-update branch)

```
1. Parse: N=1, intent="huh"

2. Step 1 — Folder resolution:
   grep "^SCREENSHOT_DIR=" ~/.codex/.env → /Volumes/External/Screenshots
   Path check: /Volumes/External/Screenshots does not exist (drive unmounted)
   Stale path detected → run platform discovery:
     macOS: defaults read com.apple.screencapture location → (empty/error)
     Fallback: ~/Desktop
   Key already present in .env → Edit tool: replace line
     SCREENSHOT_DIR=/Volumes/External/Screenshots
     with: SCREENSHOT_DIR=/Users/matt/Desktop
   Resolved path: /Users/matt/Desktop

3. Step 2 — File listing:
   Found 3 image files; newest one:
     Screenshot 2026-05-07 at 1.24.54 PM.png  (age: 47 min)
   Staleness check: 47 min > SCREENSHOT_STALENESS_MINUTES (30) →
     Print: "Newest screenshot is 47 min old — is this the right one?"
     Proceed immediately.
   Select 1 file.

4. Step 3 — Read image:
   Read "Screenshot 2026-05-07 at 1.24.54 PM.png" → success (1.9MB)

5. Step 4 — Intent dispatch:
   intent="huh" → matches Priority 5 (huh/explain/describe)
   No context injection for huh intent.
   Dispatch: describe what the screenshot shows.
```

## Companion Skills

- **systematic-debugging**: For complex errors requiring root-cause investigation
- **feature-development**: For building features visible in a screenshot
- **brainstorming**: For exploring design directions suggested by a screenshot
