# GitLab CLI (glab) — Reference

> Companion to `skill.md`. Install walkthrough, auth, and command reference.

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
glab config set host "<hostname>" --global
glab config get host
```

### 2. Create a personal access token (PAT) — or use OAuth device flow

**OAuth device flow (no PAT required):** For interactive setup, `glab auth login` can authenticate via browser-based OAuth if your GitLab instance has configured OAuth application support:

```bash
glab auth login --hostname "<hostname>"   # follow the device-code prompt in the browser
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
glab auth logout --hostname "<hostname>"
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

**Listing projects:** `glab repo list` shows the authenticated user's accessible repos. For faster, filterable results:

```bash
glab api "projects?membership=true&per_page=50"
```

---

## Merge requests

```bash
glab mr list [--state opened|closed|merged|all]
glab mr view "{<id> | <branch>}"
glab mr create [--fill]
glab mr create --title "T" --description "D" --label bugfix
glab mr create --draft
glab mr create --reviewer "<username>"
glab mr create --target-branch "<branch>"
glab mr approve "{<id> | <branch>}"
glab mr merge "{<id> | <branch>}" [--squash] [--rebase] [--remove-source-branch]
glab mr checkout "{<id> | <branch>}"
glab mr diff "{<id> | <branch>}"
glab mr update "{<id> | <branch>}" --title "new title"
glab mr close "{<id> | <branch>}"
glab mr note "<id>" -m "comment text"
```

---

## CI/CD pipelines

```bash
glab ci list
glab ci status
glab ci view [branch]
glab ci run
glab ci lint
glab ci trace "[<job-id>|<job-name>]"
glab ci retry "<job-id>"
glab ci cancel "<job-id>"
glab ci artifact "<refName>" "<jobName>"
# Trigger a manual job via raw API (glab ci trigger is not a valid subcommand):
glab api "projects/:id/jobs/<job-id>/play" -X POST
```

---

## CI/CD variables

> ⚠️ **`glab variable set` silently overwrites existing values with no confirmation.** Run `glab variable get <key>` first.

```bash
glab variable list
glab variable get "<key>"
glab variable set "<key>" "<value>"
glab variable set "<key>" "<value>" --masked --protected
glab variable delete "<key>"          # ⚠️ PERMANENT
# Group-level:
glab variable list --group "<group-path>"
glab variable set "<key>" "<value>" --group "<group-path>"
```

> ⚠️ `--masked` does NOT protect secrets at the API layer — masked only suppresses output in CI job logs.

---

## Repositories / projects

```bash
glab repo view [repo]
glab repo clone [group/repo] [dir]
glab repo list
glab repo create [path]
```

---

## Releases

```bash
glab release list
glab release create "<tag>" --name "Release name" --notes "description"
glab release create "<tag>" --ref "<branch-or-commit>"
glab release view "<tag>"
glab release upload "<tag>" "<file>"
glab release delete "<tag>"   # ⚠️ PERMANENT — does NOT delete the git tag
```

---

## Issues

```bash
glab issue list [--state opened|closed|all]
glab issue view "<id>"
glab issue create --title "T" --description "D"
glab issue close "<id>"
glab issue note "<id>" -m "comment"
glab issue update "<id>" --label bug
```

---

## API (raw)

```bash
glab api "<endpoint>"
glab api "projects?membership=true&per_page=50" --paginate
```

> ⚠️ `--paginate` issues synchronous page-by-page requests; may trigger rate limits on large instances. Add `sleep 1` between pages for large-scale automation.

**POST with JSON body:**

```bash
printf '%s' '{"key":"val"}' | glab api <endpoint> -X POST --input -
# Or write JSON to a temp file: glab api "<endpoint>" -X POST --input /path/to/body.json
```

---

## Useful flags

| Flag | Meaning |
|------|---------|
| `-R <repo>` | Target project (`namespace/project`, `group/subgroup/project`, or full GitLab URL) |
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
