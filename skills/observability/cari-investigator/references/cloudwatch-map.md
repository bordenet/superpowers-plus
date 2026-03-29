---
name: cloudwatch-map
parent: cari-investigator
description: CloudWatch log group reference for Cari services. Maps services to log groups, key fields, and useful query patterns.
---

# CloudWatch Log Group Map

> **AWS Account:** 055570533261 (production)
> **AWS Profile:** cari-prod (or telephony-prod)
> **Region:** us-east-1

## Service → Log Group Mapping

### Core Cari Services

| Service | Log Group | Key Fields | Use When |
|---------|-----------|------------|----------|
| Agent API (main) | `/aws/lambda/cari-agent-lambda-production` | lskinid, callEvents, tool calls | Investigating agent behavior, appointment bookings, tool call arguments |
| Call Processing | `/aws/lambda/cari-call-processing-production` | callid, ani, dnis | Call routing, processing flow |
| Telephony | `/ecs/cari-telephony-production` | SIP messages, transfer events | Transfer failures, SIP errors |
| Speech Service | `CariSpeechServiceProd-*` (multiple) | transcription events | Speech recognition issues |
| Conversation Engine | `/aws/lambda/conversation-engine_PROD` | dialog state | Conversation flow issues |

### Config Service

| Service | Log Group | Key Fields | Use When |
|---------|-----------|------------|----------|
| Config GET (all) | `/aws/lambda/cari-config-get-all-production` | lskinid, config data | Checking what config was served |
| Config POST (all) | `/aws/lambda/cari-config-post-all-production` | lskinid, upsert data | **Audit trail: when config was changed** |
| Config GET scheduler | `/aws/lambda/cari-config-get-scheduler-production` | lskinid | Scheduler-specific config reads |
| Config advisors | `/aws/lambda/cari-config-get-advisors-production` | lskinid | Advisor list lookups |
| Config opcodes | `/aws/lambda/cari-config-get-opcodes-production` | lskinid | OpCode syncs |

### Integration Platform

| Service | Log Group | Key Fields | Use When |
|---------|-----------|------------|----------|
| Integration Platform | `/aws/lambda/cari-integration-platform-production` | lskinid, DMS events | DMS polling, data sync |
| CDK Webhook | `/aws/apigateway/cari-cdk-webhook-api-production` | webhook payloads | CDK integration events |
| Polling Service | `/aws/lambda/cari-polling-service-production` | poll results | Polling health checks |

### Reporting

| Service | Log Group | Key Fields | Use When |
|---------|-----------|------------|----------|
| Reporting Event Processor | `/aws/lambda/cari-reporting-event-processor-production` | call events | Event processing pipeline |
| Scheduler Dashboard | `/aws/lambda/cari-reporting-scheduler-dashboard-production` | dashboard data | Dashboard queries |
| Receptionist Dashboard | `/aws/lambda/cari-reporting-receptionist-dashboard-production` | dashboard data | Receptionist reports |

### Other Services

| Service | Log Group | Key Fields | Use When |
|---------|-----------|------------|----------|
| Agent Line Sync | `/aws/lambda/cari-agent-line-sync-*-production` | extension data | Agent line provisioning |
| Alert Forwarder | `/aws/lambda/cari-alert-forwarder-production` | alert data | Alarm/alert routing |
| Token Rotation | `/aws/lambda/cari-token-rotation-production` | rotation events | Auth token issues |
| Acquisition API | `/aws/lambda/cari-acquisition-api-post-lead-production` | lead data | SellMyRide leads |

### RDS Logs

| Database | Log Group | Use When |
|----------|-----------|----------|
| Config DB | `/aws/rds/instance/cari-config-prod/postgresql` | Slow queries, connection issues |
| Reporting DB | `/aws/rds/instance/cari-reporting-prod/postgresql` | Reporting DB issues |
| Main RDS | `/aws/rds/instance/cari-rds-production/postgresql` | Core DB issues |

## Common Query Patterns

### Find agent tool calls for a specific ANI (phone number)

```
fields @timestamp, @message
| filter @message like /schedule_appointment/ and @message like /{ani}/
| sort @timestamp asc
| limit 50
```

### Find what appointment time was booked

```
fields @timestamp, @message
| filter @message like /Agent API: Result/ and @message like /scheduledAppt/
| parse @message '"dateTime":"*"' as booked_time
| parse @message '"laneId":*,' as lane_id
| sort @timestamp asc
| limit 50
```

### Find config changes for a dealer

```
fields @timestamp, @message
| filter @message like /upsert/ and @message like /{lskinid}/
| sort @timestamp asc
| limit 100
```

### Find all calls processed for a dealer today

```
fields @timestamp, @message
| filter @message like /{lskinid}/ and @message like /callEvent/
| sort @timestamp asc
| limit 200
```

### Check for errors in a specific service

```
fields @timestamp, @message
| filter @message like /ERROR/ or @message like /error/
| sort @timestamp desc
| limit 50
```

## Key Patterns in Agent API Logs

The `cari-agent-lambda-production` log group contains JSON-structured messages. Key patterns:

| Pattern | What It Means | How to Search |
|---------|--------------|---------------|
| `"Agent API: Result"` | End-of-call summary with outcomes | `filter @message like /Agent API: Result/` |
| `"callEvents":["scheduledAppt"]` | Appointment was booked | `filter @message like /scheduledAppt/` |
| `"schedule_appointment"` | Agent called the booking tool | `filter @message like /schedule_appointment/` |
| `"dateTime"` | Appointment time in tool call args | `parse @message '"dateTime":"*"' as dt` |
| `"selectedTime"` | Time slot chosen by caller | `parse @message '"selectedTime":"*"' as st` |
| `"laneId"` | Service lane ID for the booking | `parse @message '"laneId":*,' as lane` |

## Tips

1. **Time range is critical.** CloudWatch Insights charges by data scanned. Always use the narrowest possible time window.
2. **Log group names are case-sensitive.** `/aws/lambda/cari-agent-lambda-production` ≠ `/aws/lambda/Cari-Agent-Lambda-Production`.
3. **Use `--profile cari-prod`** for all AWS CLI commands targeting production.
4. **JSON parsing is fragile.** Use `like` filters first to narrow results, then `parse` to extract fields.
5. **Config change audit trail** is in `cari-config-post-all-production`. This is the definitive source for "when was this config changed?"
