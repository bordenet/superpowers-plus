---
name: [warm-transfer]-tester
source: superpowers-[product]
triggers: ["set up [[warm-transfer]] test", "[[warm-transfer]] test setup", "configure [[warm-transfer]] dev", "[[warm-transfer]] testing"]
anti_triggers: ["investigate [[warm-transfer]]", "[[warm-transfer]] failure", "why did [[warm-transfer]]", "[[warm-transfer]] metrics"]
description: Set up a Dev receptionist [warm-transfer] test. Temporarily routes one transfer extension to the user's phone, prints call instructions, restores when done. Dev only. NOT for investigating failures (use [product]-investigator).
summary: "Use when: setting up a Dev [warm-transfer] test session (not investigating calls)."
coordination:
  group: [product]
  order: 1
  requires: ['deploy-to-dev']
  enables: []
  escalates_to: []
  internal: false
---

# [[warm-transfer]] Test Setup

Set up a Dev [warm-transfer] test in under 2 minutes. Two paths: **Fast** (default) and **Custom** (user picks account). Use Fast unless user explicitly asks for a different account.

## Guardrails

- **Dev only** — base URL `https://zkzn5iympg.execute-api.us-east-1.amazonaws.com/dev` is a constant. Never swap.
- **API key** in shell variable only — never echo, log, or include in chat output.
- **One confirm** before any write. **One field** (`number`) on one extension. Never touch anything else.
- `POST /dev/all` body = `{ "account": {unchanged from GET}, "receptionist": {modified} }` — always omit `scheduler`. Never POST output of `GET /receptionist` to `/all` (different shapes).

## Prerequisite: API Key + Orphan Scan

**API key:** Try `$[PRODUCT]_CONFIG_API_KEY_DEV` env var. If unset:
```bash
API_KEY=$(AWS_PROFILE=[product] aws apigateway get-api-keys --region us-east-1 --include-values \
  --query "items[?contains(name,'config') && contains(name,'dev')].value" --output text 2>/dev/null)
```
If empty/error: *"Can't resolve Dev config API key. Run `aws sso login --profile [product]` or set `[PRODUCT]_CONFIG_API_KEY_DEV`."* Stop.

All API calls below require header `x-api-key: $API_KEY`.

**Orphan scan:** Check for `/tmp/[product]-wt-*.json`. If any exist, warn: *"Found {N} session file(s) from previous test(s): {filenames}. Want me to restore those first?"* If yes → run restore (Step 5) for each. If no → continue.

---

## Fast Path

### Step 1: Resolve Phone Number

**Check `$WARM_TRANSFER_TEST_PHONE`** (from `~/.codex/.env`). If set and valid (10 digits after normalization), use it silently — no need to ask.

If unset or invalid, ask:
*"I'll set up [[warm-transfer]] testing on Dev — XTime (177616) / dnisId 37525395. What phone number should receive the transfer?"*

Normalize: strip all non-digits, drop leading `1` if 11 digits. Must be exactly 10. If not, explain and re-ask.

### Step 2: Validate

`GET /dev/receptionist?lskinid=177616` — find extension where `dnisId` = `"37525395"`. Match on `dnisId` only — the `name` field is mutable (was `"Test 2"` originally, renamed to `"Service"` for realistic testing). Use whatever `name` is current in confirm/instructions.

| Condition | Action |
|-----------|--------|
| Not found | *"dnisId 37525395 missing from 177616. Use custom path."* Stop. |
| `[[warm-transfer]]` = `"Never"` | *"[[warm-transfer]] disabled on {name}."* Stop. |
| `number` = target | *"Already points there. No change needed, no restore later."* Skip to Step 4 (no-op). |
| `number` ≠ baseline `2222222222` | ⚠️ *"Currently {number}, not baseline. Another session active?"* Confirm or stop. |
| `number` = baseline | Normal. Proceed. |

### Step 3: Confirm + Write

```
⚠️  CONFIRM (Dev only)
Extension "{name}" on 177616:  {current}  →  {target}
Type "yes" to proceed.
```

On "yes":
1. Save session to `/tmp/[product]-wt-177616-37525395-{YYYYMMDD-HHMMSS}.json`: `{ lskinid, dnisId, extensionName, originalNumber, testNumber, startedAt }`
2. `GET /dev/all?lskinid=177616` → find extension by `dnisId` → set `number` = target → `POST /dev/all` (account unchanged, receptionist modified, scheduler omitted)
3. Verify: `GET /dev/receptionist?lskinid=177616` → confirm `number` = target. Mismatch → warn + stop.

### Step 4: Test Instructions

```
✅ Ready!
📞 Call 833-828-8105 — ask for "{name}" → [[warm-transfer]] → your phone ({number}) rings
⏱️ Timeout: 45s

TIPS:
• Answer with "hello" — silent answers cause dead air
• "Hold on" triggers REPEAT not WAIT (DELTA-1256) — say "one second please"
• Post-TTS stale threshold at ~10s (DELTA-1254)

Say "done" when finished → I'll restore the original config.
```

No-op variant: same instructions but replace last line with *"No restore needed — I didn't change anything."*

### Step 5: Restore

Triggered by: "done", "restore", "finished", "clean up".

**Load session:** Glob `/tmp/[product]-wt-177616-37525395-*.json`, use most recent. If none: ask *"Original number? XTime baseline is usually 2222222222."* Set `testNumber` = unknown.

**Check state:** `GET /dev/receptionist?lskinid=177616` → find by `dnisId` + `name`. If missing → *"Extension gone. Session file preserved. Restore manually."* Stop.

| Current | Action |
|---------|--------|
| = `originalNumber` | Already restored. Delete session file. Done. |
| = `testNumber` (or confirmed by user if unknown) | Restore: fetch-modify-post with `number` = `originalNumber`. Verify. Delete session file. |
| Neither | *"Unexpected value {actual}. Someone else changed it. Skipping."* Preserve session file. |

---

## Custom Path

Only when user explicitly asks for a different account/extension.

**Gather:** 1) lskinid (validate via GET), 2) show extensions where `[[warm-transfer]]` ≠ `"Never"` AND `type` ≠ `"fallback"` — user picks one, 3) Dev inbound number (skill can't derive this), 4) transfer target phone.

**Then follow Steps 2–5** substituting: user's lskinid, chosen `dnisId`/`name`, user-provided inbound number. No known baseline — collision check uses current number. Session file: `/tmp/[product]-wt-{lskinid}-{dnisId}-{timestamp}.json`. On missing-session restore, ask for original number without suggesting `2222222222`.

## Related

- [DELTA-1142 Test Matrix](https://wiki.int.[company].net/doc/delta-1142-[warm-transfer]-auto-repeat-silence-timer-after-wait-detection-DKECdvSEOf) — test procedures and known issues

## When to Use

- Setting up a Dev [warm-transfer] test call
- Routing a transfer extension to your phone temporarily for manual testing
- Testing receptionist transfer flow (not investigating failures — use [product]-investigator for that)

## Failure Modes

| Mode | Symptom | Recovery |
|------|---------|----------|
| Extension not routed | Call misses phone | Verify config mapping, check deploy |
| Config not restored | Dev left in test state | Run cleanup manually |
| Stale TTS cache | Old message plays | Clear TTS cache |
