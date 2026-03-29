---
name: config-change-detection
parent: [product]-investigator
description: Detect config changes around an incident time. Queries CloudWatch audit logs for config-service upserts and correlates timestamps with observed issues.
---

# Config Change Detection

> **Purpose:** Answer "Did something change right before this broke?"
> **Log Group:** `/aws/lambda/[product]-config-post-all-production`
> **Profile:** [product]-prod

## When to Use

- Investigating why a dealer's behavior changed at a specific time
- Checking if a config update caused a booking/routing issue
- Auditing config change history for a dealer

## Procedure

### Step 1: Define the time window

Get the incident time from the user or from call data. Expand the window ±30 minutes to catch changes that happened just before or after.

```bash
# Example: incident at 16:57 UTC → check 16:27 to 17:27 UTC
START_TIME=$(date -u -j -f "%Y-%m-%dT%H:%M:%S" "2026-03-23T16:27:00" "+%s")
END_TIME=$(date -u -j -f "%Y-%m-%dT%H:%M:%S" "2026-03-23T17:27:00" "+%s")
```

### Step 2: Query config change audit trail

```bash
aws logs start-query \
  --log-group-name "/aws/lambda/[product]-config-post-all-production" \
  --start-time $START_TIME \
  --end-time $END_TIME \
  --query-string "fields @timestamp, @message
    | filter @message like /{lskinid}/
    | filter @message like /upsert/
    | sort @timestamp asc
    | limit 100" \
  --profile [product]-prod
```

Then retrieve results:
```bash
aws logs get-query-results --query-id {query_id} --profile [product]-prod
```

### Step 3: If no results in config-post, check broader config reads

Sometimes the change was applied but didn't go through `post-all`. Check the scheduler-specific endpoint:

```bash
aws logs start-query \
  --log-group-name "/aws/lambda/[product]-config-get-scheduler-production" \
  --start-time $START_TIME \
  --end-time $END_TIME \
  --query-string "fields @timestamp, @message
    | filter @message like /{lskinid}/
    | sort @timestamp asc
    | limit 50" \
  --profile [product]-prod
```

### Step 4: Correlate timestamps

Compare the config change timestamp against the incident timestamp:

| Scenario | Interpretation |
|----------|---------------|
| Config changed **before** incident | Config change may have caused the issue |
| Config changed **after** incident | Config change was the FIX, not the cause — the issue predates it |
| Config changed **during** incident | Race condition — calls processed before config took effect |
| No config changes found | Issue is not config-related; investigate other services |

### Step 5: Check what specifically changed

If you find a config change, look at the payload to identify what was modified:

```bash
aws logs start-query \
  --log-group-name "/aws/lambda/[product]-config-post-all-production" \
  --start-time $START_TIME \
  --end-time $END_TIME \
  --query-string "fields @timestamp, @message
    | filter @message like /{lskinid}/ and @message like /upsert/
    | parse @message '\"scheduler\":{*}' as scheduler_config
    | sort @timestamp asc
    | limit 20" \
  --profile [product]-prod
```

Key config fields to look for:
- `offLimitsTimes` — blocked appointment time slots
- `lanes` — service lane definitions
- `hours` — business hours
- `transferRoutes` — call transfer routing
- `advisors` — service advisor assignments

## Output

Present findings as a timeline:

```
Config Change Timeline for lskinid {id}

  16:52 UTC — Call 6001543815826 booked appointment for 12:00 (noon)
  16:55 UTC — Call 6001543815912 booked appointment for 12:15
  17:02 UTC — ⚡ Config change: offLimitsTimes updated to block 12:00-12:45
  17:08 UTC — Call 6001543816203 attempted 12:00 → DECLINED (off-limits working)

  Conclusion: Bookings at 16:52 and 16:55 occurred BEFORE the config fix landed at 17:02.
```

## References

- Log group details: `references/cloudwatch-map.md`
- AWS credentials: `references/aws-credentials.md`
