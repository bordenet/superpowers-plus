# LLM Skill Review — Reference

Companion to `skill.md` (kept under the 250-line structural limit per `skill-health-check`). Load this file when actually dispatching the Specialist Personas or applying the Mandatory Checks in full detail — `skill.md` only summarizes them.

## Specialist Personas (full detail)

Run these in parallel if tooling allows (e.g. `Task()`-based parallel sub-agent dispatch, as `code-review-battery` already documents for its own reviewer roster). If not, emulate them sequentially while keeping their scoring separate.

### 1) Runtime Determinist

Focus: instruction ordering, trigger precision, hidden branching, stop conditions, ambiguous language, state preconditions.

Start from:
- skill triggers and anti-triggers
- ordered steps in `skill.md`
- any routing logic or command dispatch
- any text that tells the model to infer, decide, or continue

Questions:
- Would two strong models do the same thing here?
- Is precedence explicit when rules conflict?
- Are refusal/escalation paths defined?
- Are outputs constrained enough to be machine-usable?

### 2) Shell Portability Auditor

Focus: shell scripts, installers, hooks, path logic, process control, quoting, environment assumptions.

Start from:
- install/setup/uninstall scripts
- helper shell libraries
- hook scripts
- path-resolution and filesystem mutations

Questions:
- Is this explicitly bash, POSIX sh, or zsh, and is the code consistent with that?
- Are GNU/BSD differences accounted for?
- Are quoting, globbing, and word splitting safe?
- Does rerunning preserve a clean state?
- Does the script fail loudly and locally, not later and elsewhere?

**Be extremely picky.** Shell is part of the product surface.

### 3) Tool Contract Guardian

Focus: MCP/tool wiring, argument discipline, validation before side effects, parseability, fallback rules.

Start from:
- tool invocation instructions
- MCP config
- wrappers around tool-calling behavior
- prompt text that maps user intent to tools

Questions:
- Could a model choose the wrong tool and believe it succeeded?
- Are required arguments always explicit?
- Are destructive operations gated by validation?
- Does tool output have a structure the next model step can reliably consume?
- Are unavailable tools handled by safe degradation rather than unsafe improvisation?

### 4) Cross-Agent Compatibility Critic

Focus: Claude/Augment/Cursor differences, hook semantics, file placement, plugin assumptions, context windows, slash-command assumptions.

Start from:
- agent-specific docs and manifests
- routing/install destinations
- feature flags or platform conditionals
- any vendor-specific prompting assumptions

Questions:
- Is any agent-specific behavior incorrectly presented as universal?
- Are supported platforms materially equivalent, or only nominally supported?
- Are install paths and config conventions consistent across agents?
- Does the prompt style rely on one vendor's reasoning behavior?

### 5) Context Efficiency Examiner

Focus: token pressure, duplication, buried constraints, prompt sprawl, compaction resilience.

Start from:
- long skill files
- repeated guidance blocks
- nested checklists and examples
- required output formats

Questions:
- Are the most important invariants front-loaded?
- Could this survive summarization without losing safety?
- Is any prose ornamental when it should be algorithmic?
- Are there repeated instructions that should become a short rubric?

### 6) Prose/Design Critic ensemble (from progressive-harsh-review)

Run as PHR's actual three-persona ensemble, not a single pass -- a round-2 self-review found that collapsing this into one persona silently dropped PHR's ensemble/averaging/correlated-failure design, the exact "silent fallback" failure class this skill exists to catch in others. Each sub-persona scores all five Prose/Design Quality Axes (`skill.md`) using its OWN weights below; average the three weighted scores with equal weight afterward (PHR's Step 2 rule). Dimension definitions and weights are copied verbatim from `progressive-harsh-review`'s "The Three Personas" section to avoid re-deriving them out of sync with the source.

**6a) JuniorDevNitpicker (Surface Quality)** -- weights: Correctness 35%, Simplicity 25%, Blind Spots 20%, Verifiability 15%, Operational Risk 5%. Start from: line-by-line reading of the skill.md -- every heading, trigger, table entry, undefined term.

**6b) SeniorArchCritic (Structural Quality)** -- weights: Correctness 25%, Simplicity 15%, Verifiability 25%, Blind Spots 15%, Operational Risk 20%. Start from: promises made vs. evidence provided -- do coordination/escalation claims and companion-skill references hold when traced against the actual sibling skills on disk?

**6c) OpsRealist (Operational Quality)** -- weights: Correctness 25%, Simplicity 10%, Blind Spots 25%, Verifiability 10%, Operational Risk 30%. Start from: failure scenarios -- what happens if a trigger never fires, a step is skipped, or the skill collides with a sibling?

**Drift risk (design-critic dogfood finding, 2026-07-17):** the three weight sets above are hand-copied from `progressive-harsh-review`'s "The Three Personas" section, not read from it live -- if that section is ever renamed, restructured, or reweighted, these copies silently go stale. `coordination.requires` in `skill.md` names the dependency for the skill-router's dependency graph, but nothing mechanically re-verifies the numbers match. Before trusting a review that leans on this ensemble, diff these three lines against PHR's current "The Three Personas" section by hand; a durable fix would be a CI check comparing them automatically.

Skill-file-specific questions (all three sub-personas ask these, moved here from `progressive-harsh-review` -- that skill no longer reviews skill files): are triggers unique across the installed skill set, is the YAML frontmatter valid, are there broken cross-references, are coordination fields correct with no overlap with peer skills, do anti-triggers actually prevent false positives, is the Failure Modes table populated?

## Mandatory Checks (full flag lists)

`skill.md` lists these six categories; the concrete flags for each are here.

### A. Instruction Determinism

Flag any of the following:
- vague verbs like "handle", "manage", "appropriate", "careful", "robust", "ensure" without exact operational meaning
- multiple interpretations of trigger or routing behavior
- missing precedence between triggers, anti-triggers, and overrides
- instructions requiring common-sense inference instead of explicit rules
- scoring systems without pass/fail thresholds or merge thresholds
- prompts that say "review thoroughly" without enumerated dimensions

### B. Shell and Runtime Portability

Flag any of the following:
- bashisms without a guaranteed bash runtime
- zsh-only features in supposedly portable code
- GNU/BSD incompatibilities in `sed`, `grep`, `find`, `date`, `stat`, `readlink`, `xargs`, `mktemp`
- unsafe quoting, unquoted expansions, command substitution hazards
- reliance on current working directory or fragile relative paths
- hidden env vars or mutable PATH assumptions
- interactive behavior inside automation paths
- weak cleanup of temporary files or partially written state
- error handling that masks failures in pipelines or subshells

### C. Tool Contract Safety

Flag any of the following:
- tools selected by implication rather than explicit criteria
- under-specified required parameters
- output contracts that are hard for models to parse reliably
- dangerous side effects before validation
- fallback instructions that keep going after ambiguous failure
- mismatches between tool docs and prompt expectations

### D. Failure-Mode Resilience

Flag any of the following:
- missing stop-and-report rules
- retries that can loop or amplify damage
- state mutation before confirming prerequisites
- dependence on prior conversation state that compaction may erase
- success conditions that are asserted, not verified
- partial failure paths with no operator-visible remediation

### E. Cross-Agent Interoperability

Flag any of the following:
- Claude-only hooks or semantics assumed to apply everywhere
- Cursor or Augment support claimed without equivalent implementation detail
- undocumented differences in plugin/config destinations
- slash commands or invocation behavior that only one platform supports
- tool-calling assumptions that vary by vendor/model tier

### F. Test Realism

Flag any of the following:
- tests that only grep for strings instead of validating runtime behavior
- no tests for reruns and idempotency
- no tests for absent tools or partial installs
- no adversarial tests for ambiguous instructions
- no regression coverage for install/setup scripts
- no fixtures for cross-platform shell differences
