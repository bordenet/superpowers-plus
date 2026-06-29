---
name: gitlab-cli
source: superpowers-plus
augment_menu: true
auto_invoke: false
description: Use glab for GitLab merge requests, CI/CD, variables, issues, and raw API calls on gitlab.com or any self-hosted GitLab instance. Includes macOS/Windows install and auth walkthrough. Triggers on glab, GitLab CLI, GitLab MR, pipeline status, install/setup glab, or GitLab-specific repo operations.
summary: "Use when: operating on GitLab via glab (MRs, CI, variables, issues, API), or helping someone install and authenticate glab on macOS or Windows."
triggers:
  - "glab"
  - "gitlab cli"
  - "gitlab mr"
  - "gitlab pipeline"
  - "gitlab ci"
  - "gitlab api"
  - "gitlab variable"
  - "gitlab issue"
  - "gitlab auth"
  - "gitlab.com"
  - "self-hosted gitlab"
  - "install glab"
  - "setup glab"
  - "configure glab"
  - "glab not found"
  - "glab auth login"
  - "glab mr list"
  - "glab mr view"
anti_triggers:
  - "gh pr"
  - "github cli"
  - "github pull request"
  - "azure devops"
  - "bitbucket"
coordination:
  group: engineering
  order: 1
  requires: []
  enables: []
  escalates_to: []
  internal: false
composition:
  produces: []
  consumes: [user-intent]
  capabilities: [gitlab-http-api]
  priority: 50
  optional: false
  requires_all: false
---

# GitLab CLI (glab)

> **Announce at start:** "I'm using the **gitlab-cli** skill for GitLab / glab operations."

**Do not use for:** GitHub (`gh`), Azure DevOps, or Bitbucket workflows.

---

## Agent setup walkthrough

When `glab` is missing or auth fails, walk the user through these steps **in order**. Ask which OS they use (macOS vs Windows) before giving install commands. Run checks yourself when you have shell access (with **network enabled**).

| Step | Check / action | Success signal |
|------|----------------|----------------|
| 1 | `glab version` | Prints a version (e.g. `glab 1.x.x`) |
| 2 | Install glab if step 1 fails | See [Install glab](#install-glab) for their OS |
| 3 | `git --version` | Git installed (needed for clone context and `glab auth login` remote detection) |
| 4 | Ask **GitLab hostname** | `gitlab.com` or their self-hosted host (no `https://`) |
| 5 | `glab config set host <hostname> --global` | Only if not `gitlab.com` or host not already set |
| 6 | Create PAT or OAuth | See [Authenticate](#authenticate) |
| 7 | `glab auth status` (add `--hostname <host>` if self-managed) | Shows logged in as their user |
| 8 | `cd` into a GitLab clone; `glab repo view` | Resolves project from `origin` |
| 9 | Smoke test: `glab mr list` or `glab api user` | API works end-to-end |

---

## Install glab

Official docs: https://gitlab.com/gitlab-org/cli#installation

After install, open a **new** terminal (or reload the shell) so `PATH` picks up `glab`, then run `glab version`.

### Linux

**Debian / Ubuntu (via official repo):**

```bash
curl -fsSL https://packages.gitlab.com/install/repositories/gitlab/gitlab-cli/script.deb.sh | sudo bash
sudo apt install glab
glab version
```

**RPM-based (Fedora, RHEL, CentOS):**

```bash
curl -fsSL https://packages.gitlab.com/install/repositories/gitlab/gitlab-cli/script.rpm.sh | sudo bash
sudo dnf install glab
glab version
```

**Snap:**

```bash
sudo snap install glab
glab version
```

**Binary (all distros):** download from [GitLab CLI releases](https://gitlab.com/gitlab-org/cli/-/releases), place on `PATH`, `chmod +x`.

### macOS

**Recommended (Homebrew):**

```bash
brew install glab
glab version
```

Update later: `brew upgrade glab`

**No Homebrew:** download a macOS binary from [GitLab CLI releases](https://gitlab.com/gitlab-org/cli/-/releases), put it on your `PATH`, and run `glab version`.

**Apple Silicon vs Intel:** Homebrew and release binaries handle both; use the arch that matches the machine if downloading manually.

### Windows

Pick **one** shell context and stick to it (PowerShell, Git Bash, or WSL). Install `glab` into that environment's `PATH`.

**Option A — winget (PowerShell, native Windows):**

```powershell
winget install -e --id GLab.GLab
```

Open a **new** terminal, then `glab version`. If `glab` is not recognized, the installer may not have updated `PATH` — add the install directory to the user Path (or use Scoop/binary). Do not use bare `winget install glab` (wrong package).

**Option B — Scoop (PowerShell):**

```powershell
scoop install glab
glab version
```

**Git Bash:** install via winget/scoop on the Windows side; Git Bash inherits `PATH` if the installer updated it (restart Git Bash after install).

> ⚠️ **Supply-chain note (Linux curl installs):** The Debian and RPM install scripts use `curl | sudo bash` — remote code executed as root with no checksum verification. In security-sensitive environments: download the script, inspect it, then run it. Alternatively, install from a pre-built binary with a verified checksum from the [releases page](https://gitlab.com/gitlab-org/cli/-/releases).

---

## Authenticate

Default SaaS host is **gitlab.com**. Self-managed: user provides hostname only (e.g. `gitlab.example.com`).

### 1. Set default host (self-managed only)

```bash
glab config set host <hostname> --global
glab config get host
```

### 2. Create a personal access token (PAT) — or use OAuth device flow

**OAuth device flow (no PAT required):** For interactive setup, `glab auth login` can authenticate via browser-based OAuth if your GitLab instance has configured OAuth application support:

```bash
glab auth login --hostname <hostname>   # follow the device-code prompt in the browser
glab auth status
```

Use PAT if: you need non-interactive (CI) auth, the instance doesn't support OAuth, or you need fine-grained scope control. Use OAuth device flow if: you prefer not to manage a PAT or the instance supports it.

**PAT (non-interactive / CI):**

User creates a token in the GitLab UI (scopes depend on org policy; common minimum: **`api`**, **`read_api`**, **`write_repository`** for MR/CI work).

| Instance | Where to create a PAT |
|----------|------------------------|
| GitLab.com | https://gitlab.com/-/user_settings/personal_access_tokens |
| Self-managed | `https://<hostname>/-/user_settings/personal_access_tokens` |

**Minimum required scopes:** `api` for write operations (MR creation, CI triggers, variable writes); `read_api` for read-only work. Do **not** list both — `api` is a superset of `read_api`. Granting both is redundant and misleads users toward over-privileged tokens.

User copies the token once (starts with `glpat-` on many instances). **Never paste tokens into chat logs** if avoidable; prefer interactive login on their machine.

**⚠️ SAML SSO:** On instances with SAML enforcement, a valid PAT will still return 403 until the user explicitly authorizes it at `https://<host>/-/user_settings/personal_access_tokens`. Auth status will show green; API calls will fail. Fix: open that URL and authorize the token for SAML. (Legacy path on older self-managed instances: `/-/profile/personal_access_tokens` — both redirect correctly on current GitLab.)

### 3. Log in

**Interactive (easiest in a GitLab clone):** `glab` can suggest hosts from `git remote`.

```bash
cd /path/to/gitlab/clone
glab auth login
```

**Non-interactive (self-managed example):**

```bash
# ⚠️ --token "$GITLAB_TOKEN" exposes the token in shell history.
# Prefer stdin (below) or GITLAB_TOKEN env var for non-interactive use.
glab auth login --hostname gitlab.example.com --token "$GITLAB_TOKEN"
```

**Token from stdin (avoids token in shell history):**

```bash
# macOS / Linux / Git Bash / WSL
glab auth login --hostname gitlab.example.com --stdin < /path/to/token.txt

# PowerShell (GitLab.com example)
Get-Content token.txt | glab auth login --hostname gitlab.com --stdin
```

**macOS keyring (optional):** add `--use-keyring` to `glab auth login` to store the token in the OS keychain.

### 4. Verify

```bash
glab auth status
glab auth status --hostname gitlab.example.com
glab api user
```

For all configured hosts: `glab auth status --all`

### 5. Environment variables (CI / automation)

If set, these override stored credentials:

- `GITLAB_TOKEN` or `GITLAB_ACCESS_TOKEN`
- `GITLAB_HOST` — target instance hostname for commands

Do not commit tokens. Use the platform's secret store in CI.

### Re-auth / logout

```bash
glab auth logout --hostname <hostname>
glab auth login
```

### Troubleshooting auth

| Symptom | What to try |
|---------|-------------|
| `glab: command not found` | Reinstall; open new terminal; confirm `PATH` (Windows winget: often need new terminal or manual Path entry) |
| `401` / `403` / invalid token | New PAT with correct scopes; `glab auth login` again |
| `403` after valid `glab auth status` (SAML instances) | Authorize the PAT for SAML at `https://<host>/-/user_settings/personal_access_tokens` then retry — this is separate from auth login |
| SSL/TLS errors on self-hosted instance | The instance may use an internal CA. Options: (a) add the CA cert to your system trust store (recommended); (b) set `GITLAB_SSL_VERIFY=false` (dev/testing only — never in production). `--insecure` is not a valid flag for `glab auth login`; GITLAB_SSL_VERIFY is the correct escape hatch |
| Wrong instance | `glab config get host`; set with `glab config set host <host> --global` |
| Works in terminal, fails in AI agent | Agent sandbox blocked network — rerun with network enabled |
| `glab repo view` fails outside clone | Use `-R group/subgroup/repo` or `cd` into a clone with GitLab `origin` |

---

## AI agent / restricted shell environments

Many IDE agents run shell commands in a **network-restricted sandbox**. `glab` uses HTTPS for almost everything (`auth status`, `mr`, `ci`, `api`, etc.). Sandbox failures often look like **403 Forbidden**, timeouts, or connection errors even when the user's PAT and config are valid.

**When running `glab` from an agent:**

1. Use a shell with **outbound network** enabled when the host supports it.
2. If auth or API calls fail only inside the agent, **re-run `glab auth status` with network enabled** before telling the user to log in again.
3. Do not assume auth is broken based on a single sandboxed attempt.

Interactive terminals (user's own shell) are unaffected.

---

## Targeting a repository

Inside a clone, glab infers the project from **`git remote`** (usually `origin`). From any directory, target explicitly:

```bash
glab mr list -R group/subgroup/repo-name
glab ci status -R group/repo-name

# Self-hosted: full HTTPS project URL also works
glab mr list -R https://gitlab.example.com/group/repo-name
```

**Listing projects:** `glab repo list` shows the authenticated user's accessible repos — it does not require a repo context. On large instances with many repos, the output may be slow or paginated. For faster, filterable results:

```bash
glab api "projects?membership=true&per_page=50"
```

---

## Merge requests

```bash
glab mr list [--state opened|closed|merged|all]
glab mr view {<id> | <branch>}
glab mr view --web
glab mr create [--fill]
glab mr create --title "T" --description "D" --label bugfix
glab mr create --draft                             # open as draft / WIP
glab mr create --reviewer <username>               # request review on create
glab mr create --target-branch <branch>            # explicit target base
glab mr approve {<id> | <branch>}
glab mr revoke-approval {<id> | <branch>}
glab mr merge {<id> | <branch>}
glab mr merge {<id> | <branch>} --squash           # squash commits on merge (only if project allows squash strategy)
glab mr merge {<id> | <branch>} --rebase           # rebase strategy (only if project allows rebase strategy)
glab mr merge {<id> | <branch>} --remove-source-branch
glab mr checkout {<id> | <branch>}
glab mr diff {<id> | <branch>}
glab mr update {<id> | <branch>} --title "new title"
glab mr close {<id> | <branch>}
glab mr reopen <id>
glab mr note <id> -m "comment text"
```

---

## CI/CD pipelines

```bash
glab ci list
glab ci status
glab ci view [branch]
glab ci run
glab ci lint
glab ci trace [<job-id>|<job-name>]
glab ci retry <job-id>
glab ci cancel <job-id>
glab ci artifact <refName> <jobName>
# Trigger a manual job via raw API (glab ci trigger is not a valid subcommand):
glab api projects/:id/jobs/<job-id>/play -X POST
```

---

## CI/CD variables

> ⚠️ **`glab variable set` silently overwrites existing values with no confirmation.** Run `glab variable get <key>` first to verify the current value before overwriting.

```bash
# Project-level (default)
glab variable list
glab variable get <key>
glab variable set <key> <value>
glab variable set <key> <value> --masked --protected
glab variable update <key> <value>  # may be a strict update (requires pre-existing key); behavior varies by version
glab variable delete <key>          # ⚠️ PERMANENT — no confirmation prompt

# Group-level — use --group for multi-project orgs
glab variable list --group <group-path>
glab variable set <key> <value> --group <group-path>
glab variable delete <key> --group <group-path>
```

> ⚠️ **`--masked` does NOT protect secrets at the API layer.** `glab variable get <key>` and `glab api projects/:id/variables` return the plaintext value to any caller with API scope. Masked only suppresses output in CI job logs. Do not assume masked = secret at the API layer.

---

## Repositories / projects

```bash
glab repo view [repo]
glab repo view --web
glab repo clone [group/repo] [dir]
glab repo list
glab repo create [path]
```

---

## Releases

```bash
glab release list
glab release create <tag> --name "Release name" --notes "description"
glab release create <tag> --ref <branch-or-commit>   # create tag if not exists
glab release view <tag>
glab release upload <tag> <file>                      # upload release asset
glab release delete <tag>   # ⚠️ PERMANENT — deletes the release and release assets; does NOT delete the git tag
```

---

## Issues

```bash
glab issue list [--state opened|closed|all]
glab issue view <id>
glab issue view --web
glab issue create --title "T" --description "D"
glab issue close <id>
glab issue reopen <id>
glab issue note <id> -m "comment"
glab issue update <id> --label bug
```

---

## API (raw)

```bash
glab api <endpoint>
glab api projects/:id/variables

# Paginate large result sets (e.g., listing all projects in a large org)
glab api "projects?membership=true&per_page=50" --paginate
```

> ⚠️ **Rate limits and `--paginate`:** `--paginate` issues synchronous page-by-page requests. On large instances with thousands of items, this can trigger GitLab's rate limit (10 requests/second or 600 requests/minute for the REST API; exact limits vary by instance tier and configuration — check `X-RateLimit-*` response headers on your instance). `glab api` does not auto-throttle. For large-scale automation against private instances: use `glab api` in a loop with a deliberate `sleep 1` between pages, or prefer the `/graphql` endpoint with cursor-based pagination for bulk queries.

**PowerShell JSON pipe note:** Single-quoted strings in PowerShell are literal — no variable expansion. For dynamic JSON payloads, build the JSON in a variable first:

```powershell
$body = @{ key = "val"; other = $myVar } | ConvertTo-Json
Write-Output $body | glab api <endpoint> -X POST --input -
```

**POST with JSON body** (use a form that works on the user's shell):

```bash
# POSIX / Git Bash / WSL / macOS / Linux
printf '%s' '{"key":"val"}' | glab api <endpoint> -X POST --input -

# Alternative: write JSON to a temp file, then:
glab api <endpoint> -X POST --input /path/to/body.json
```

Avoid bash-only `<<<` heredocs in shared docs unless you know the agent runs bash. On **PowerShell**, piping JSON works: `'{"key":"val"}' | glab api <endpoint> -X POST --input -`

---

## Useful flags

| Flag | Meaning |
|------|---------|
| `-R <repo>` | Target project (`namespace/project` or `group/subgroup/project` or full GitLab URL). GitLab paths can be 2–3 segments — not GitHub-style `OWNER/REPO`. |
| `--web` | Open in browser |
| `--fill` | MR title/description from branch and commits |
| `--masked` | Mask a CI variable |
| `--protected` | Protect a CI variable |

---

## Confirm GitLab remote

```bash
git remote -v
glab repo view
```

If `glab repo view` succeeds, the current directory is linked to a GitLab project glab understands.

---

## Failure Modes

| Failure | Fix |
|---------|-----|
| `403` after valid `glab auth status` | SAML SSO: authorize the PAT at `https://<host>/-/profile/personal_access_tokens` |
| SSL/TLS error on self-hosted instance | Install internal CA cert, or use `GITLAB_SSL_VERIFY=false` for dev only |
| `glab variable set` overwrites a live secret | Always `glab variable get <key>` first; `set` has no confirmation prompt |
| API returns partial results from large org | Add `--paginate` to `glab api` calls; default `per_page=20` silently truncates |
| `glab ci trace` hangs on long-running job | Use Ctrl-C to interrupt; trace resumes from the current position on next run |
| `CI_JOB_TOKEN` in GitLab CI pipeline returns 403 | `CI_JOB_TOKEN` has restricted scope — cannot manage variables or most project API endpoints; use a PAT stored as a masked CI variable instead |
| Project access token vs. PAT confusion | Project access tokens are scoped to one project, created under `Settings > Access Tokens` (not user settings); PATs work across projects. `glab auth login` supports both, but project access tokens cannot be used for user-level API calls like `glab api user`. |

## Reference

- Upstream docs: https://gitlab.com/gitlab-org/cli
- Per-command help: `glab <command> --help`
- Releases: https://gitlab.com/gitlab-org/cli/-/releases

> **Version notice:** This reference was verified against glab 1.105.0. Flags such as `--device` (auth), `--use-keyring`, and pipeline input flags (`-i`) were added in recent releases. On older glab versions, run `glab <command> --help` to confirm flag availability before use. `glab version` shows your installed version.
