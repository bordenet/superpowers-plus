---
name: core-boards
source: superpowers-callbox
description: Use when creating internal announcements, promoting wiki pages, or publishing persistent messages to CallBox employees. Triggers on "create Core Board", "announce this wiki page", "post to Core", "promote this document", "internal announcement", "publish to core boards".
summary: "Use when: creating internal announcements or promoting wiki pages to Core Boards."
triggers: ["create Core Board", "announce this wiki page", "post to Core", "promote this document", "internal announcement", "publish to core boards"]
coordination:
  group: productivity
  order: 1
  requires: []
  enables: []
  escalates_to: []
  internal: false
anti_triggers: ['read boards', 'check my boards', 'unread boards']
---

# Core Boards Authoring

## Purpose

Core Boards are CallBox's internal announcement system — ideal for reaching large audiences with messages that won't scroll off screen like Teams or email.

This skill generates clean, lightly styled HTML for promoting Outline Wiki pages via Core Boards. The output is ready to paste into Core's HTML rich editor.

## When to Use This Skill

- You've created or updated an important wiki page
- The content needs to reach a specific audience (HR, engineering, leadership, etc.)
- You want a write-once/read-many announcement that persists

## The Workflow

**Step 1: Ask which wiki page**
> "Which wiki page are we promoting? (Paste the URL)"

**Step 2: Ask the purpose**
> "What's the purpose of this announcement? (One sentence)"

**Step 3: Ask the target audience**
> "Who's the target audience? (e.g., HR, senior leadership, engineering)"

**Step 4: Generate draft summary**
- Fetch the wiki page content via Outline API
- Extract 3-5 key points
- Present for user review:
> "Based on the wiki page, here are the key points I'd include:
> - Point 1
> - Point 2
> - Point 3
> 
> Does this capture the right points, or should I adjust?"

**Step 5: User confirms or edits**

**Step 6: Output final HTML**

## HTML Template

```html
<div style="font-family: Segoe UI, Arial, sans-serif; font-size: 14px; line-height: 1.6; max-width: 600px;">
  
  <p style="margin-bottom: 16px;">
    Please note the following wiki page 
    "<a href="[WIKI_URL]" style="color: #0066cc;">[FRIENDLY_PAGE_NAME]</a>" 
    has been created to [PURPOSE].
  </p>
  
  <p style="margin-bottom: 12px; color: #333;">
    <strong>Key points:</strong>
  </p>
  
  <ul style="margin-bottom: 16px; padding-left: 20px; color: #333;">
    <li style="margin-bottom: 8px;">[KEY_POINT_1]</li>
    <li style="margin-bottom: 8px;">[KEY_POINT_2]</li>
    <li style="margin-bottom: 8px;">[KEY_POINT_3]</li>
  </ul>
  
  <p style="color: #666; font-size: 13px;">
    Target audience: [AUDIENCE]
  </p>
  
</div>
```

## Styling Rules

- Inline styles only (Core may strip `<style>` blocks)
- System fonts: Segoe UI → Arial fallback
- Colors: #333 body, #666 secondary, #0066cc links
- Max-width 600px for readability
- Adequate spacing between list items

## Checklist

Before generating output, confirm:

- [ ] Wiki URL provided
- [ ] Purpose statement provided  
- [ ] Target audience specified
- [ ] Key points extracted and confirmed by user
- [ ] Wiki content fetched fresh (not from memory)

## What This Skill Does NOT Do

- Post to Core directly (you copy HTML to Core's editor)
- Handle images (wiki images won't render in Core)
- Track which announcements have been sent


## Common Failure Modes

- **Stale board data:** Querying cached board state instead of fetching fresh from API
- **Wrong board ID:** Using a board ID that doesn't exist or has been deleted
- **Permission errors:** Expired session cookies or insufficient Core Boards access

## Failure Modes

| Mode | Symptom | Recovery |
|------|---------|----------|
| Vague board title | Post unclear | Use descriptive title with summary |
| Skip duplicate check | Duplicate post | Search existing posts first |
