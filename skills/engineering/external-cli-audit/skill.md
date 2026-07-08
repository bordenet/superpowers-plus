---
name: external-cli-audit
source: superpowers-plus
augment_menu: true
triggers: ["/sp-external-cli-audit", "audit installer", "audit wrapper script", "review claude mcp add", "review gh pr create", "review kubectl", "review aws cli", "review npm publish", "default flags", "scope flag", "what does this CLI default to", "check CLI defaults"]
description: Use when reviewing, auditing, or fixing any script that invokes an external CLI (claude, gh, kubectl, aws, npm, terraform, helm, etc.). Forces behavioral grounding — enumerate the CLI's flags and defaults via `<cli> <subcommand> --help` BEFORE declaring the script correct. Catches silent defaults that bash syntax checks cannot.
summary: "Use when: any script wraps an external CLI — confirm scope/persistence/identity defaults are explicit, not assumed."
coordination:
  group: engineering
  order: 1
  requires: []
  enables: []
  escalates_to: [providing-code-review]
  internal: false
composition:
  produces: [audit-report]
  consumes: [user-intent]
  capabilities: [cli-help-introspection]
  priority: 60
  optional: false
  requires_all: false
---

# External CLI Audit

> **Purpose:** Catch the silent class of bugs where a wrapper script invokes an external CLI with defaults that don't match the deployment intent.
> **Origin:** Codified after a 2026-04-27 miss in `mcp-servers/install.sh` audit. The audit confirmed every per-server installer called `claude mcp add` correctly — but never inspected what `claude mcp add` *defaults to*. Result: registrations landed at project scope (visible only inside the install dir), not user scope (visible globally). The parallel audit did not catch it.

**Announce at start:** "I'm using the **external-cli-audit** skill to verify CLI defaults and scope flags."

---

## When to Use

**Use this skill when:**
- Reviewing or auditing any installer script (`install.sh`, `setup.sh`, `bootstrap.sh`)
- Reviewing any script that wraps a tool whose effect is **persisted somewhere** — registry, cluster, account, repo
- Diagnosing a bug whose symptom is "the script ran successfully but the result isn't where I expected it"
- Pre-fix gate before declaring a wrapper-script bug "fixed"

**Skip this skill when:**
- The script invokes only pure-output CLIs (`grep`, `jq`, `awk`) where state isn't persisted
- The CLI behavior is explicitly documented in version-pinned form AND a version-sensitive test exists that will fire if the CLI version changes. Documentation alone (without a version test) does not qualify — defaults change between releases without notice.

**Trigger CLIs (non-exhaustive):** `claude mcp add`, `claude mcp remove`, `gh pr create`, `gh release create`, `kubectl apply`, `kubectl create`, `aws s3 sync`, `aws iam create-*`, `npm publish`, `terraform apply`, `helm install`, `gcloud config set`, `git config`, `docker login`, `pip install`.

---

## The Failure Mode This Catches

Bash and shellcheck verify that a CLI **was called** with **syntactically valid arguments**. Neither tool can answer:

- *What scope/level/persistence layer does that subcommand default to?*
- *What identity does the call execute under?*
- *Is the default what we want for this deployment?*

A wrapper that does `claude mcp add NAME -- CMD` is *syntactically* fine. It is *behaviorally* wrong if the deployment intent is "register globally" and the default is project-local. Bash never warns. The script exits 0. The user sees "✓ Added X" and the registration is invisible everywhere except the install directory.

---

## The Audit Procedure (max 10 min)

### Step 1: Enumerate every external CLI call

```bash
# In the script(s) under audit:
grep -nE '(claude|gh|kubectl|aws|npm|terraform|helm|gcloud|docker|pip|az|git|ssh|scp|rsync) ' SCRIPT_PATH
```

Build a list. For each row, note the binary, subcommand, and any explicit flags.

> **Note:** This grep only catches literal binary names. Inspect the script manually for:
> - Dynamic dispatch (`$BIN`, `$(which claude)`, `exec "$TOOL"`)
> - Sourced helper scripts (`source helpers.sh` or `. helpers.sh`) that may also invoke CLIs
> - Child scripts invoked via `bash`, `sh`, or `exec` (non-sourced — these are separate processes)
> - **Shell function definitions** that wrap CLIs (`install_mcp() { claude mcp add ...; }`) — functions appear in the script but their CLI invocations won't be found by a name-only grep
> - Heredoc subshells (`$( ... )` blocks inside strings)
> - **Shell aliases** in the operator's environment (`alias aws='aws --profile prod'` silently changes which account is targeted). Check the environment before auditing: `type -a <cli>` reveals aliases, functions, and path resolution. `alias | grep -E '<cli>'` surfaces active aliases.

### Step 2: For each unique `<cli> <subcommand>`, run `--help`

```bash
# Do NOT truncate — scope/namespace flags often appear past line 80
<cli> <subcommand> --help 2>&1
```

If the output is long: `<cli> <subcommand> --help 2>&1 | less` or redirect to a temp file. Confirm you can see all flag descriptions before proceeding.

Record:
- **Defaults** for any flag the script does NOT pass (especially scope, namespace, profile, project, level, mode)
- **Required-but-omitted** flags
- **Deprecation warnings**

### Step 2b: Check for CWD-sensitivity

For each CLI, determine whether it uses the working directory to resolve scope, config, or context:

```bash
# Search the help output for CWD indicators (heuristic only — see caveat below):
<cli> <subcommand> --help 2>&1 | grep -iE "(current directory|project root|local|working dir|\.git)"
```

> ⚠️ **CWD grep caveat:** A negative result does NOT confirm the CLI is CWD-agnostic — a CLI can be CWD-sensitive without using any of these keywords in its `--help` output. (Example: `claude mcp add` is CWD-sensitive but `--help` does not mention the working directory.) Always cross-check the official documentation for each CLI's scope resolution behavior.

If the CLI is CWD-sensitive (e.g., `claude mcp add` defaults to project scope based on CWD):
1. Identify the working directory **from which the script will be invoked** in production (not your dev terminal).
2. Confirm the intended scope/context matches that CWD.
3. Document the CWD assumption in the script comment or make it explicit with an absolute path flag.

**Example (the founding incident):** `claude mcp add NAME -- CMD` silently registers at project scope when the CWD is a project directory. Global registration requires `--scope user`. The script returned exit 0 with "✓ Added X" but the registration was invisible outside the install directory.

### Step 3: For EACH default, ask "is this what we want?"

| Question | Why it matters |
|---|---|
| Where does the side effect persist? (file path, registry, cloud account) | Tells you which scope flag is relevant |
| Who is the implicit identity/principal? | Tells you whether `--profile`, `--user`, `--account` is needed |
| Is the default reversible? | Tells you whether you can change scope after the fact |
| Does the default differ between tool versions? | Pin the flag explicitly to immunize against upstream changes |
| What version is actually installed? | `<cli> --version 2>&1` — record this before starting the audit; confirm it matches the version the script was written against |
| Are there environment variables that silently override these flags? | `AWS_PROFILE`, `AWS_DEFAULT_REGION`, `KUBECONFIG`, `HELM_NAMESPACE`, `NPM_CONFIG_REGISTRY`, `DOCKER_HOST`, `GH_TOKEN`, etc. can override explicit flags — verify none are set unexpectedly in the deployment environment |
| Does the CLI prompt for confirmation in non-TTY/CI environments? | CLIs like `terraform apply`, `helm install`, `npm publish`, `gh release create` may hang on interactive prompts in CI. Pin the no-prompt flag (e.g., `--auto-approve`, `--yes`, `--no-interactive`). |
| Are there dotfiles that silently override? | `~/.npmrc`, `~/.aws/credentials`, `~/.kube/config`, `~/.claude.json`, `~/.config/gh/hosts.yml`, `~/.docker/config.json` — if the script's explicit flags conflict with these, the dotfile may win on the deploy host |

If any default does NOT match deployment intent → **the script is wrong**, even if it runs cleanly.

### Step 4: Verify behaviorally, not syntactically

**Step 4 is DIAGNOSTIC** — run it to confirm the bug exists (or confirm the default is correct before any fix). A separate Step 6 (post-fix) verifies the fix worked. Do NOT combine the two.

```bash
# Run the wrapped CLI in a sandbox/dev account if possible.
# Run in the SAME ENVIRONMENT as the production deploy (CI runner, not your local terminal)
# to produce a valid result — local identity and config may differ from the deploy host.
# If sandbox execution is not possible: read the CLI source or changelog to confirm the
# default value for the pinned version, and document the assumption explicitly in a PR comment.
# Examples by CLI family:

# claude — registry location
claude mcp list                               # local/project scope
claude mcp list --scope user                  # user scope (~/.claude.json)

# gh — confirm the default base branch for the CURRENT PR
gh pr view --json baseRefName,headRefName
# or, to see all open PRs' base branches:
gh pr list --json number,baseRefName,headRefName

# kubectl — namespace/context
kubectl config view --minify | grep namespace

# aws — account (does NOT include region)
aws sts get-caller-identity
# aws — region
aws configure get region   # or: echo "${AWS_DEFAULT_REGION:-<not set>}"

# npm — registry & tag
npm config get registry
```

Confirm the side effect landed where the deployment intent says it should.

### Step 5: Lock in explicit flags

Once the right defaults are identified, **make them explicit in the script** rather than relying on the implicit default. Future readers (and future versions of the CLI) won't have your context.

```bash
# Bad — relies on default scope (which may change between CLI versions)
claude mcp add NAME -- node "$SCRIPT_DIR/build/stdio.js"

# Good — scope is explicit, annotated with WHY it was chosen
# --scope user: required for global visibility; project scope (default) is invisible outside install dir
claude mcp add --scope user NAME -- node "$SCRIPT_DIR/build/stdio.js"
```

**Always add a WHY comment alongside the explicit flag.** Without context, future contributors may silently revert "mysterious" flags. Also audit for unset-variable risk in flag construction: `--scope $MY_VAR` where `MY_VAR` is unset silently passes an empty value — check that every variable used in flag positions is guaranteed to be set.

### Step 6: Post-fix re-verification (REQUIRED)

After applying the explicit flags, re-run the behavioral verification commands from Step 4 in the same production-equivalent environment to confirm the fix produced the intended state. The audit is not complete until post-fix verification passes.

```bash
# Example: confirm user-scope registration after adding --scope user
claude mcp list --scope user    # should now show the registered server
claude mcp list                 # project scope — should NOT show server if intended as user-only
```

> ⚠️ **Pre-existing stale registrations:** If the script previously ran with the wrong scope, stale entries may persist alongside the new correct-scope entry. Identify and clean up stale registrations before declaring the fix complete.

---

## Common CLI Default Hazards

*Defaults verified at time of authoring; always run `<cli> <subcommand> --help` for your installed version. Defaults can change between CLI releases without notice.*

| CLI | Subcommand | Default | Often-wanted | Flag / note |
|---|---|---|---|---|
| `claude` | `mcp add` | project scope | user scope | `--scope user` |
| `gh` | `pr create` | repo's default branch as base | release branch | `--base BRANCH` |
| `gh` | `pr edit` | `--body` replaces the entire body | append/preserve existing content | Fetch current body first — `gh pr view --json body -q .body` — then re-supply the full text, or use `--body-file` with the merged content |
| `gh` | `release create` | published (non-draft) release visible to all users | draft | `--draft` |
| `kubectl` | `apply` | current context's default namespace | explicit ns | `-n NAMESPACE` |
| `aws` | most commands | `default` profile; region from `~/.aws/config` or `AWS_DEFAULT_REGION` (errors if neither set — no built-in default) | env-specific | `--profile`, `--region` |
| `npm` | `publish` (unscoped) | `latest` tag, public registry | tag/private | `--tag`, `--registry` |
| `npm` | `publish` (`@scope/pkg`) | **restricted (private)** | public | `--access public` |
| `git` | `config` | repo-local | user-global or system | `--global`, `--system` |
| `docker` | `login` | DockerHub | private registry | positional arg: `<registry-url>` |
| `pip` | `install` | active venv if activated, else global site-packages | explicitly activated venv | N/A — activate venv (`source venv/bin/activate`) before invoking pip |
| `helm` | `install` | current k8s context, default namespace | explicit context/ns | `--kube-context`, `-n NAMESPACE` |
| `terraform` | `apply` | `default` workspace; no var-file loaded | explicit workspace + var-file | Pre-step: `terraform workspace select ENV`; then `-var-file=<path>` (single-dash equals, not double-dash space) |
| `gcloud` | most commands | project and zone from `gcloud config list` | explicit project/zone | `--project`, `--zone` |
| `az` | most commands | subscription from `az account show` | explicit subscription/group | `--subscription`, `--resource-group` |

---

## Anti-Patterns

| Anti-Pattern | Why It Fails |
|---|---|
| "The script ran with exit 0, so it's correct" | Exit code reflects *invocation success*, not *deployment intent satisfaction* |
| "Bash syntax check passes" | Bash cannot audit external CLI semantics |
| "The CLI is documented elsewhere" | Defaults change between versions; pin them in-script |
| "We'll catch it in CI" | CI typically runs in a clean environment that masks scope/identity defaults |
| "The other 8 installers do it the same way" | Copy-paste propagates the default-flag bug across the whole repo |
| "I confirmed one hypothesis with a test" | Confirming Mechanism A doesn't exclude Mechanism B producing the same symptom — re-audit defaults independently |

## Self-Check Before Declaring "Audit Complete"

- [ ] Listed every external CLI invocation in the script(s), including dynamic dispatch, sourced scripts, child scripts (non-sourced), and shell function definitions
- [ ] Ran `<cli> <subcommand> --help` (full output, not truncated) for each unique subcommand
- [ ] Checked each CLI for CWD-sensitivity; confirmed the correct working directory for production invocation
- [ ] Recorded the default for every flag the script does NOT pass
- [ ] Checked for environment variable overrides and dotfile overrides that could silently override explicit flags
- [ ] Confirmed that any `--flag $VAR` usage guards against unset variables
- [ ] **Step 4 (diagnostic):** Verified broken/correct state BEFORE any fix, in the production-equivalent environment (not just local terminal)
- [ ] Confirmed each default matches deployment intent
- [ ] Made the right flags explicit in the script, with a WHY comment explaining why the default was wrong
- [ ] **Step 6 (post-fix):** Re-verified behavioral state AFTER the fix in the same production-equivalent environment; cleaned up stale pre-existing registrations if present
- [ ] Checked idempotency: if the script re-runs, stale prior-run state is cleaned up first

If any box is unchecked, the audit is incomplete.

## Failure Modes

| Failure | Fix |
|---------|-----|
| Audit passes a script using a deprecated flag | `--help` doesn't always document deprecated flags; cross-check vendor release notes for the CLI version pinned in the repo |
| False positive on intentional shell expansion | If a `$VAR` is intentionally unquoted (e.g., word-splitting), document it in a comment so the auditor exempts it |
| CWD-mismatch — script exits 0 but state lands in wrong scope | Add Step 2b CWD-sensitivity check; use absolute path flags or `cd` with an explicit scope flag |
| Env var override silences explicit flag | Enumerate relevant env vars (e.g., `AWS_PROFILE`) for each CLI family; verify they are not set unexpectedly in CI/prod |
| `--help` unavailable or misleading for the subcommand | Consult the CLI's vendor changelog for the pinned version; do NOT guess or rely solely on `--help` output |
