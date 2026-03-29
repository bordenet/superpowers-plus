# Core Boards Authoring Skill

Generate HTML announcements for [Company]'s Core Boards system.

## What It Does

Promotes Outline Wiki pages by generating clean, lightly styled HTML ready to paste into Core's HTML rich editor.

## Usage

Invoke the skill before creating a Core Board announcement:

```
superpowers:core-boards
```

The skill will ask:
1. Which wiki page to promote
2. The purpose of the announcement
3. Target audience
4. Confirm extracted key points

Then output copy-paste HTML.

## Example Output

```html
<div style="font-family: Segoe UI, Arial, sans-serif; font-size: 14px; line-height: 1.6; max-width: 600px;">
  <p style="margin-bottom: 16px;">
    Please note the following wiki page 
    "<a href="https://wiki.int.[company].net/doc/..." style="color: #0066cc;">AI & Interview Integrity Policy</a>" 
    has been created to establish clear expectations for candidate behavior during interviews.
  </p>
  <p style="margin-bottom: 12px; color: #333;"><strong>Key points:</strong></p>
  <ul style="margin-bottom: 16px; padding-left: 20px; color: #333;">
    <li style="margin-bottom: 8px;">AI tools are not permitted during any interview session</li>
    <li style="margin-bottom: 8px;">Candidates requiring accommodations must disclose during phone screen</li>
    <li style="margin-bottom: 8px;">No-shows without notice result in immediate disqualification</li>
  </ul>
  <p style="color: #666; font-size: 13px;">Target audience: HR, Senior Leadership, Engineering</p>
</div>
```

## Why Core Boards?

From [Company]'s [Modes of Communication](https://wiki.int.[company].net/doc/modes-of-communication-ko1N62U1wn):

- Good for announcements and reminders
- Messages don't scroll off screen like Teams/email
- Write-once / read-many
- Has Action-Feed feature for tracking

## Installation

Run from `superpowers-[company]/`:

```bash
./install.sh
```
