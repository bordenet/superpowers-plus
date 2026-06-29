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

For install, auth, MR, CI, variables, issues, API, and repo command reference, see **[reference.md](reference.md)**.

---

## Failure Modes

| Failure | Fix |
|---------|-----|
| `403` after valid `glab auth status` | SAML SSO: authorize the PAT at `https://<host>/-/user_settings/personal_access_tokens` then retry |
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
