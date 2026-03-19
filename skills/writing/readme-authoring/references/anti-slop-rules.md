# README Authoring — Anti-Slop Rules

> Reference material for the `readme-authoring` skill.
> See `skill.md` for core agent guidance.

## Delete These Words

| Word/Phrase | Replacement |
|-------------|-------------|
| comprehensive | list what's covered |
| cutting-edge | name the technology |
| world-class | delete entirely |
| seamless/seamlessly | describe the mechanism |
| robust | specify failure handling |
| powerful | quantify capability |
| innovative | describe what's new |
| state-of-the-art | cite the paper/version |
| elegant | delete entirely |
| intuitive | show a 3-second example |

## Delete These Phrases

- "In today's fast-paced world"
- "It's important to note that"
- "Let's dive into"
- "This project aims to"
- "We believe that"

## Replace Vague Claims

| Vague | Concrete |
|-------|----------|
| "Fast" | "Responds in <50ms" |
| "Scalable" | "Tested to 10K concurrent users" |
| "Easy to use" | Show a 3-line example |
| "Flexible" | List the configuration options |
| "Secure" | Name the security measures |

## Example: Rewriting a Bad Opening

**Before (slop score: 67):**
> "SuperTool is a comprehensive, cutting-edge solution that seamlessly integrates into your workflow to provide powerful capabilities for modern development teams."

**After (slop score: 12):**
> "SuperTool runs your tests in parallel across 8 cores. Install in 10 seconds: `npm i -g supertool`"

