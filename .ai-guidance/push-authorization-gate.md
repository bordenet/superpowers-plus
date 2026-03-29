# Push Authorization Gate (NON-NEGOTIABLE)

**NEVER run `git push` to ANY remote without explicit human approval in the CURRENT conversation.**

- ❌ **NEVER** push a branch to `dev.azure.com` — branch pushes trigger CI/CD pipelines that auto-deploy
- ❌ **NEVER** assume "commit" means "push" — they are separate actions requiring separate approval
- ❌ **NEVER** push based on approval from a prior conversation/session
- ❌ **NEVER** promote staging → main without explicit, standalone approval — this is a RELEASE, not a sync
- ❌ **NEVER** bundle high-stakes actions (branch promotions, releases) into compound questions with low-stakes actions (cleanup, mirror sync)
- ❌ **NEVER** frame a deliberate branch gap (staging ahead of main) as a "problem to fix" — the gap is intentional workflow state
- ✅ **ALWAYS** confirm: "I'm about to push branch X to remote Y. This will trigger [pipelines]. Proceed?"
- ✅ **ALWAYS** verify `git config user.email` matches the remote's identity before pushing
- ✅ **ALWAYS** ask about staging→main promotion as its own separate question, never combined with other actions

**For Cari services (telephony-service, agent-api, etc.), the correct deployment path is:**
```powershell
.\scripts\build-and-push.ps1 -Environment dev [-UpdateECS]
```
This is a HUMAN action. Agents document deployment steps — they do NOT execute them.

| Date | Incident |
|------|----------|
| 2026-03-27 | Agent pushed 4 branches to ADO `telephony-service`, triggering 2 pipeline runs that progressed through 3/5 stages without human approval. Unsanctioned code deployed to Dev. PRs abandoned/restored, pipeline runs deleted, guardrails created (this section + `push-authorization-gate` skill + `security.md`/`deployment.md` workflow templates). |
| 2026-03-29 | Agent promoted staging → main (95 commits) in `superpowers-plus` without explicit approval. User asked "what's at risk of being left behind?" — agent misframed the staging/main gap as a deficiency, bundled the promotion into a compound question about GitLab mirror + branch cleanup, then executed it after a "yes" that only covered the other actions. Root cause: treating a deliberate workflow state as a problem, and hiding a release decision inside routine housekeeping. |
