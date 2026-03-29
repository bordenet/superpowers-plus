---
name: agent-api-reference
parent: agent-api
description: Integration routing tables, agent tools catalog, decision flow diagram, and cross-reference investigation patterns for agent-api investigations.
---

# Agent API Reference

> **Loaded from:** `agent-api.md` → this file for routing tables, tools catalog, and investigation patterns.

## Integration Reference

Understanding which code path a call takes requires knowing the dealer's DMS type and scheduler type (from config-service). Use this reference to interpret agent logs.

### Customer Lookup Routing (by DMS type)

| DMS Type | Handler | Backend |
|----------|---------|---------|
| cdk | getCdkCustomer() | CDK API |
| mykaarma | getMyKaarmaCustomer() | MyKaarma API |
| dealer-fx | getDealerFxCustomer() | Dealer-FX API |
| update-promise | getUpdatePromiseCustomer() | UpdatePromise API |
| dealertrack | getMotiveCustomer() | Motive API (provider: dealertrack) |
| reynolds | getMotiveCustomer() | Motive API (provider: reynolds) |
| tekion | getMotiveCustomer() | Motive API (provider: tekion) |
| pbs | getMotiveCustomer() | Motive API (provider: pbs) |
| automate | getMotiveCustomer() | Motive API (provider: automate) |
| autosoft | getMotiveCustomer() | Motive API (provider: autosoft) |
| dealerpeak | getMotiveCustomer() | Motive API (provider: autosoft fallback) |

### Available Times Routing (by scheduler type)

| Scheduler Type | Handler | Special Behavior |
|----------------|---------|------------------|
| xtime | getXtimeAvailableTimes() | Chunks into 7-day windows, parallel requests, retries with extended range (max 3), advisor filtering |
| mykaarma | getMyKaarmaAvailableTimes() | Requires departmentId, custom advisor validation |
| dealer-fx | getDealerFxAvailableTimes() | Requires departmentId, vehicle services lookup |
| update-promise | getUpdatePromiseAvailableTimes() | Custom availability logic |
| cdk | getDmsAvailableTimes() | Uses DMS default path (via Motive) |
| tekion | getDmsAvailableTimes() | Uses DMS default path (via Motive) |
| (none / DMS only) | getDmsAvailableTimes() | Schedule building from local appointments, advisor filtering |

### Appointment Posting Routing

| Integration | Handler | Notes |
|-------------|---------|-------|
| xtime (scheduler) | postXtimeAppointment() | Transforms to Xtime format, vehicle fallback, retry logic |
| mykaarma (scheduler) | postMyKaarmaAppointment() | Custom customer/vehicle creation, transportation options |
| update-promise (scheduler) | postUpdatePromiseAppointment() | Custom format |
| dealer-fx (scheduler) | postDealerFxAppointment() | Requires departmentId |
| cdk (DMS) | postCdkAppointment() | Requires laborType on opcodes, department codes |
| default (DMS) | postDmsAppointment() | Generic Motive format |

### Cancel Appointment Routing

Same pattern as posting — routes by scheduler type first, then DMS type.

---

## Agent Tools Reference

### Scheduler Agent (15 tools)

| Tool | Purpose | Critical? | Key Log Messages |
|------|---------|-----------|------------------|
| lookup_customer | Find customer by phone/name in DMS | No | "Error in lookup" on failure |
| get_appointment_times | Fetch available slots from scheduler/DMS | No | "DMS available times response", "Xtime request params", "No availability, retrying" |
| schedule_appointment | Book the appointment | **Yes** | "Test account detected", "Xtime post body", "Xtime response", "Slot no longer available" |
| cancel_appointment | Cancel existing appointment | **Yes** | "Appointment cancelled", "Xtime cancel payload", "Error cancelling" |
| reschedule_appointment | Cancel + rebook | **Yes** | "Rescheduled successfully" |
| collect_existing_vehicle | Collect vehicle from customer record | No | — |
| collect_new_vehicle | Collect new vehicle details | No | — |
| collect_customer_name | Collect caller name | No | — |
| collect_recall | Collect recall information | No | — |
| collect_previous_advisor | Collect preferred advisor | No | — |
| collect_service_needs | Collect what services are needed | No | — |
| collect_upsell | Offer upsell services | No | — |
| collect_transportation_needs | Collect transportation preference | No | — |
| perform_transfer | Transfer to human agent | No | — |
| switch_language | Switch call language | No | — |

### Receptionist Agent (6 tools)

| Tool | Purpose | Critical? |
|------|---------|-----------|
| prepare_transfer | Prepare [[warm-transfer]] to extension | No |
| route_controller | Route call to correct department | No |
| collect_name | Collect caller name | No |
| transfer_to_scheduler | Hand off to scheduler agent | No |
| switch_language | Switch call language | No |
| switch_prompt | Switch agent prompt/persona | No |

### Acquisition Agent (7 tools)

| Tool | Purpose | Critical? |
|------|---------|-----------|
| book_appraisal | Book vehicle appraisal appointment | **Yes** |
| cancel_appraisal | Cancel appraisal | **Yes** |
| perform_transfer | Transfer to human | No |
| mark_declined | Mark lead as declined | No |
| handle_dnc | Handle do-not-call request | No |
| switch_language | Switch call language | No |
| switch_prompt | Switch agent prompt/persona | No |

**Critical tools** block speech-to-text during execution (voice channel) to prevent the caller from interrupting a booking/cancellation in progress.

---

## Agent Decision Flow

```
Call arrives -> agent-lambda handler
  |
  v
agentResponse(context, history, agentConfig)
  |
  v
1. Select model (index 0 = primary)
  |
  v
2. Build system message (from agent config + call context)
  |
  v
3. LLM request (streaming, temp=0.4)
  |  |
  |  +-- On error -> WARN log, failover to model index+1 (up to 5 models)
  |  +-- On empty response -> WARN log, retry with next model
  |
  v
4. Stream processing (extract tokens, TTS text, tool calls)
  |
  v
5. Critical operation? (schedule/cancel/reschedule)
  |  |
  |  +-- Voice channel: send pause signal, return for re-invocation
  |  +-- Text channel: proceed normally
  |
  v
6. Tool call? -> executeToolCall() -> add result to history
  |  |
  |  +-- In skip-second-completion list? -> return immediately
  |  +-- Otherwise -> recursive call for second LLM completion
  |
  v
7. Return message to caller via stream
```

---

## Cross-Reference Guide

When investigating a call, use this flow to connect the dots:

1. **Start with callId** -> Query CloudWatch (Query 1: Full Timeline)
2. **Extract lskinid** from the agent context logs (usually in the first few log entries)
3. **Look up dealer config** -> config-service.md (Query 2: Quick Status) to understand DMS type + scheduler type
4. **Identify integration path** -> Use the routing tables above to know which code path the call took
5. **Check call outcome** -> reporting-service.md (Query 1: Scheduler Call Drill-Down) for the final outcome
6. **If integration error** -> Use Query 5 (Integration Debug) to see the specific API failure
7. **If model error** -> Use Query 3 (Model Failover) to see which models failed and why

### Common Investigation Patterns

**"Show me what happened on the call" / "Walk me through the call"**
1. CloudWatch Query 1b (Conversation & Context) — get full dialogue, tool calls, and state progression
2. Parse the last Result entry's `history` array to reconstruct the conversation
3. Cross-reference `context.state` transitions to understand the agent's workflow

**"Why didn't the call book?"**
1. CloudWatch Query 1b (Conversation) — read the full dialogue to see where it went wrong
2. CloudWatch Query 4 (Tool Call Trace) — did the agent attempt schedule_appointment?
3. If yes: Query 5 (Integration Debug) — did the DMS/scheduler API fail?
4. If yes: Query 6 (Slot Unavailability) — was the slot taken?
5. If no tool call: Check `context.state` — did the agent ever reach `scheduling` state?

**"Why was the call transferred?"**
1. CloudWatch Query 1b (Conversation) — read the full dialogue to see why agent decided to transfer
2. CloudWatch Query 4 (Tool Call Trace) — look for perform_transfer tool call and its arguments
3. Reporting-service Query 1 — check transfer_reason field for the coded reason

**"The agent gave wrong information"**
1. CloudWatch Query 1b (Conversation) — read what the agent said vs what data it received
2. Query 5 (Integration Debug) — check what data the DMS/scheduler API returned
3. Config-service Query 1 — verify the dealer config is correct

**"The call was slow"**
1. CloudWatch Query 9 (Latency Analysis) — check first-completion and tool-call latencies
2. Query 3 (Model Failover) — did failover add latency?
3. Query 5 (Integration Debug) — was the DMS/scheduler API slow?
