# AI Guidance Consolidation

> **Purpose**: Modular AI guidance extracted from all Agents.md files across the workspace.  
> **Goal**: Seed new projects without context window bloat.

## Structure

```
guidance/
├── README.md                    # This file
├── core/                        # ALWAYS loaded (essential rules)
│   ├── superpowers.md          # Bootstrap, skill invocation, "The Rule"
│   ├── communication.md        # No flattery, status updates, evidence-based
│   └── anti-slop.md            # Banned phrases, writing quality
├── workflows/                   # Load based on project needs
│   ├── deployment.md           # CI gates, manual deploy after green
│   ├── testing.md              # Coverage requirements, pre-commit
│   ├── security.md             # Pre-commit hooks, IP protection
│   └── session-resumption.md   # .resumption_state.md pattern
├── languages/                   # Load based on project language
│   ├── go.md                   # golangci-lint, 80% coverage, error wrapping
│   ├── python.md               # pylint, mypy, 50-85% coverage
│   ├── javascript.md           # ESLint, style guides, quote conventions
│   └── shell.md                # SC2155, BSD vs GNU, validation checklists
├── project-types/              # Load based on project type
│   ├── genesis-tools.md        # Reference implementations, setup scripts
│   ├── cli-tools.md            # Integration testing, shell conventions
│   └── web-apps.md             # Dark mode, event handlers, clipboard ops
└── seed.sh                     # Script to generate project-specific Agents.md
```

## Usage

### For New Projects

Run the seeding script:
```bash
./guidance/seed.sh --language=javascript --type=genesis-tools --path=/path/to/new/project
```

### For Existing Projects

Reference specific modules in your Agents.md:
```markdown
<!-- Load core guidance -->
See: superpowers-plus/guidance/core/*.md

<!-- Load language-specific -->
See: superpowers-plus/guidance/languages/javascript.md
```

## Extraction Source

Guidance extracted from:
- `/Users/matt/GitHub/Personal/Agents.md` (workspace root)
- `scripts/Agents.md` (shell conventions, pre-commit checklists)
- `bloginator/Agents.md` (corpus synthesis, anti-slop, LLM mode)
- `genesis-tools/strategic-proposal/Agents.md` (CI gates, reference implementations)
- `genesis-tools/architecture-decision-record/Agents.md` (deployment workflows)
- `genesis-tools/genesis/Agents.md` (quality gates, adversarial workflow, UI principles)
- `pr-faq-validator/Agents.md` (Go/Python conventions)
- `superpowers-plus/Agents.md` (anti-slop rules, skill development)
- `codebase-reviewer/docs/CLAUDE.md` (session resumption, IP protection)

