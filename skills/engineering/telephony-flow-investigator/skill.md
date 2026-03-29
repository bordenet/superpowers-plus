---
name: telephony-flow-investigator
source: superpowers-plus
description: >
  Specialized investigator for diagnosing telephony call flow failures: SIP signaling
  issues, call state machine divergences, codec mismatches, RTP quality degradation,
  and timing-sensitive call setup problems. Dispatched by debug-conductor.
triggers: []
anti_triggers: []
coordination:
  group: engineering
  order: 10
  requires: ["debug-conductor"]
  enables: []
  escalates_to: ["debug-conductor"]
  internal: true
composition:
  produces: [telephony-evidence, call-flow-analysis, signaling-anomalies]
  consumes: [incident-description, call-ids, expected-behavior, call-flow-description]
  capabilities: [sip-trace-analysis, call-state-validation, rtp-quality-assessment]
  priority: 2
  optional: true
  requires_all: false
---

# Telephony Flow Investigator

> **Role:** Diagnose telephony-specific failures: SIP signaling, call state machines, codec negotiation, RTP media quality.
> **Dispatched by:** `debug-conductor` — never invoked directly by user.
> **Evidence type:** `TelephonyEvidence` (see `skills/_shared/evidence-schema.md`)

## When to Invoke

Dispatched by `debug-conductor` when the incident involves telephony call flow — SIP signaling failures, one-way audio, call state divergence, codec mismatches, or RTP quality issues.

## Investigation Protocol

### Step 1: Classify the Telephony Failure Mode

| Mode | Symptoms | Path |
|------|----------|------|
| **Call setup failure** | Calls don't connect; timeout or rejection | Step 2A: SIP signaling trace |
| **One-way audio** | One party can't hear the other | Step 2B: RTP media path analysis |
| **Call state divergence** | Call drops unexpectedly; state machine inconsistency | Step 2C: State machine audit |
| **Audio quality degradation** | Choppy, delayed, or garbled audio | Step 2D: RTP quality metrics |
| **Codec mismatch** | Calls fail during media negotiation | Step 2E: SDP offer/answer analysis |

### Step 2A: SIP Signaling Trace

1. Retrieve SIP traces for affected call IDs
2. Walk the SIP ladder diagram: INVITE → 1xx → 2xx → ACK → BYE
3. Identify where the flow deviates from expected:
   - Missing response? (network issue or server crash)
   - Unexpected response code? (4xx client error, 5xx server error)
   - Timeout? (measure actual vs. configured timeout)
4. Check SIP headers for routing anomalies (Via, Record-Route, Contact)

### Step 2B: RTP Media Path Analysis

1. Verify SDP negotiation succeeded (both parties agreed on codec + ports)
2. Trace RTP packet flow in both directions:
   - Caller → media-server → customer (outbound)
   - Customer → media-server → caller (inbound)
3. Identify where packets stop flowing:
   - NAT traversal failure? (check STUN/TURN, symmetric RTP)
   - Firewall/security group blocking? (port range, IP allowlist)
   - Packet size issue? (MTU, SRTP overhead)
4. Check for asymmetry (one direction works, other doesn't)

### Step 2C: Call State Machine Audit

1. Extract call state transitions from call router logs
2. Compare expected sequence vs. actual sequence:
   - Expected: `idle → ringing → connected → active → disconnected`
   - Check for out-of-order transitions (event ordering bug)
   - Check for missing transitions (silent state skip)
3. Correlate state transitions with SIP events (are they in sync?)
4. Check for race conditions: did two events arrive simultaneously?

### Step 2D: RTP Quality Metrics

1. Collect MOS scores, jitter, packet loss, latency for affected calls
2. Compare against baseline: is quality degradation correlated with incident?
3. Check for patterns: specific codecs, specific routes, specific time windows

### Step 2E: SDP Offer/Answer Analysis

1. Parse SDP from INVITE and 200 OK
2. Verify codec negotiation: did both parties agree on same codec?
3. Check for SRTP cipher mismatch or version incompatibility
4. Verify port assignments and IP addresses match expectations

### Step 3: Produce Evidence

```json
{
  "callFlow": [
    { "step": 1, "state": "INVITE sent", "timestamp": "ISO-8601", "expected": "INVITE sent" },
    { "step": 2, "state": "100 Trying", "timestamp": "ISO-8601", "expected": "100 Trying" },
    { "step": 3, "state": "TIMEOUT", "timestamp": "ISO-8601", "expected": "180 Ringing" }
  ],
  "anomalies": [
    { "step": 3, "type": "timeout", "detail": "No 180 Ringing after 3000ms", "severity": "high" }
  ],
  "timingIssues": [
    { "event": "call_setup", "expectedMs": 1200, "actualMs": 3800, "delta": 2600 }
  ]
}
```

## Stop Conditions

- Call state divergence point identified
- Codec/signaling mismatch confirmed
- 3 evidence items collected
- Token budget exhausted
- Wall-clock limit (5 minutes)

## Escalation Conditions

- One-way audio with no signaling anomaly (may be network/NAT — needs infra investigator)
- Timing issue below measurement resolution (sub-millisecond race condition)
- Intermittent failure with no pattern in call metadata

## Common Patterns This Investigator Detects

| Pattern | Evidence Shape |
|---------|---------------|
| **SIP timeout** | INVITE sent, no 2xx received within configured timeout |
| **Event ordering bug** | State transitions arrive out of sequence in call router |
| **One-way audio (NAT)** | SDP ports open, but RTP packets dropped at NAT boundary |
| **Codec negotiation failure** | SDP offer/answer mismatch on cipher or codec |
| **Call state race condition** | Two events processed simultaneously, wrong one wins |
| **SRTP overhead** | Packet size increase from SRTP upgrade causes MTU/NAT issues |
