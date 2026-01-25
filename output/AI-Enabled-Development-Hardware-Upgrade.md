# AI-Enabled Development Hardware Upgrade

> **🚨 ACTION REQUIRED — CTO APPROVAL**
>
> **Request:** Approve one-time hardware purchase (<$2,000) to replace 5-year-old Surface 4 for Team Delta engineer.
>
> **Why Now:** Current hardware cannot run multiple AI agents concurrently. Single-agent limitation costs 10 hours/month in lost velocity and blocks parallel development practices the rest of the industry has adopted.
>
> **Decision Needed By:** End of Week 1 to meet 1-month delivery target.

---

## Problem Statement

Current development hardware (5-year-old Surface 4 with i7-11185G7, 16GB RAM) cannot run multiple AI agents simultaneously. A single Cursor instance consumes 2-4GB RAM during active use; adding a second agent triggers swap thrashing and thermal throttling within 20 minutes. This forces a linear, one-agent-at-a-time workflow instead of parallel execution across coding, testing, and review agents.

**Measured impact:** 30 minutes of daily system wait time from context switching and thermal recovery.

## Cost of Doing Nothing

* **Productivity Loss:** 10 hours per month (120 hours/year) in lost velocity
* **Workflow Constraint:** Single-agent limitation prevents parallel work across multiple repositories or tasks—work that could run concurrently must run sequentially
* **Worsening Gap:** AI agent memory footprints have grown 20-50% since 2023 as context windows expanded to 200K tokens and multi-agent features (e.g., Cursor's 8-agent parallel mode) became standard. 2023 single-agent workflows ran on 8GB; 2025 multi-agent workflows require 32-64GB.

## Proposed Solution

Replace current Surface 4 with one of the following, based on OS preference:

| Option | Spec | Price | Notes |
|--------|------|-------|-------|
| **MacBook Pro 14" M4 Pro** | 36GB unified RAM, 1TB SSD | ~$2,499 | Apple's recommended config for developers running multi-agent AI tooling |
| **Framework Laptop 13 (Ryzen AI 9 HX 370)** | 32GB DDR5 (upgradable to 96GB), 1TB SSD | ~$1,500 | Best Windows option under $2,000; modular design, strong thermals (115°F keyboard under sustained load) |

This upgrade enables running 3-4 concurrent AI agents without performance degradation and eliminates the thermal throttling that currently degrades performance after 20 minutes of heavy use.

## Key Goals/Benefits

| Goal | Current State | Target State |
|------|---------------|--------------|
| Concurrent agents | 1 | 3-4 |
| Daily wait time | 30 min | <5 min |
| Thermal throttling | After 20 min | None |
| Hardware runway | End of life | 4-5 years |

## Scope

**In Scope:**
* Laptop workstation procurement (one of the two options above)
* Setup and migration of development environment

**Out of Scope:**
* Cloud infrastructure changes
* Additional software licensing
* Desktop workstation peripherals

## Success Metrics

* **Agent Capacity:** Increase from 1 active agent to 3-4 concurrent agents without swap or throttling
* **Wait-Time Reduction:** Achieve >80% reduction in daily system-related idle time (30 min → <5 min)
* **Workflow Enablement:** Successful parallel agent workflow (e.g., coding + testing + review) within first month

## Key Stakeholders

* **Owner:** Thomas Smith
* **Approver:** Matt Bordenet (Direct Manager)
* **Executive Approver:** Matt Andrus (CTO)

## Timeline

| Phase | Timing |
|-------|--------|
| Request Approval | Week 1 |
| Procurement | Weeks 2-3 |
| Setup & Migration | Week 4 |
| **Target Delivery** | Within 1 month |

## Budget Impact

| Option | One-Time Cost |
|--------|---------------|
| Framework Laptop 13 (Windows) | ~$1,500 |
| MacBook Pro 14" M4 Pro (macOS) | ~$2,499 |

**Note:** MacBook Pro exceeds original $2,000 target but provides 36GB unified RAM vs. 32GB, better sustained performance for AI workloads, and aligns with existing macOS toolchain if applicable.

---

## Appendix: AI Agent Memory Requirements (2023-2025)

| Tool | Idle RAM (2023) | Active RAM (2025) | Multi-Agent Recommendation |
|------|-----------------|-------------------|----------------------------|
| GitHub Copilot | ~200 MB | 1-2 GB | 16-32 GB |
| Cursor | ~1 GB | 2-4 GB | 32-64 GB |
| Claude Code | <500 MB | <1 GB | N/A (API-driven) |

**Sources:** GitHub Community discussions, Reddit r/cursor hardware threads, Tom's Hardware Framework review, CDW MacBook business buyer guide. Full citations available on request.

