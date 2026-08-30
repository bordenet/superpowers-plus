# Module: wiki placement

Load before Phase 5 (publish).

## Pre-publish checks

1. **Secret scan** — run the wiki secret audit over the draft. Zero findings
   required.
2. **Duplicate detection** — search the wiki for pages covering the same topic.
   If a near-duplicate exists, stop and ask the interviewee: update it, make
   this a companion page, or supersede it.

## Placement algorithm

1. Identify the wiki's top-level sections (spaces / collections / root pages).
2. Find the most specific existing parent page whose scope contains this topic.
   Prefer a parent 1-2 levels deep over a top-level section.
3. If no parent fits, propose the closest top-level section and flag that a new
   sub-area may be needed.
4. Present the proposed path to the interviewee as `Section / Parent / <new page>`.

## Publish

1. Confirm the location with the interviewee.
2. Ask for explicit publish approval ("publish to <path>?").
3. Publish via the wiki adapter. Capture the returned page ID and URL.
4. Verify the page renders and the URL resolves.
5. Update the state file: `Phase: published`, record page ID and URL.

**HARD GATE:** No publish without explicit interviewee approval of both the
content and the location.
