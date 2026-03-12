# Scripts Directory

Utility scripts for managing the AI slop detection system.

## Scripts

| Script | Purpose |
|--------|---------|
| `slop-dictionary.js` | CLI for managing the slop dictionary (add/remove phrases) |
| `slop-metrics.js` | Analyze slop detection metrics and patterns |
| `slop-infrastructure.sh` | Infrastructure setup for slop tracking |
| `perplexity-stats.sh` | Track Perplexity API usage and costs |

## Usage

### slop-dictionary.js

Manage the dictionary of AI-like phrases detected by the `detecting-ai-slop` skill:

```bash
# Add a phrase to detect
node scripts/slop-dictionary.js add "leverage synergies" buzzword

# Add an exception (allowed phrase)
node scripts/slop-dictionary.js except "deep dive" technical-docs

# List all phrases in a category
node scripts/slop-dictionary.js list hedge-pattern

# Show top detected patterns
node scripts/slop-dictionary.js top 20
```

### slop-metrics.js

Analyze detection patterns:

```bash
node scripts/slop-metrics.js
```

### perplexity-stats.sh

Track API usage:

```bash
./scripts/perplexity-stats.sh
```

## Categories

The slop dictionary organizes phrases into categories:

- `generic-booster` — "incredibly", "extremely", "absolutely"
- `buzzword` — "leverage", "synergize", "game-changing"
- `filler-phrase` — "it's worth noting", "in essence"
- `hedge-pattern` — "might want to consider", "could potentially"
- `sycophantic-phrase` — "Great question!", "Excellent point!"
- `transitional-filler` — "As we move forward", "Going forward"
- `profanity` — Blocked words for professional content

## Related Skills

- `skills/writing/detecting-ai-slop/` — Uses this dictionary
- `skills/writing/eliminating-ai-slop/` — Rewrites detected patterns
- `skills/writing/professional-language-audit/` — Hard gate for profanity
