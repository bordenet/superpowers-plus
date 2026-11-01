# Lite state and next steps

Verified 2026-11-01. This is a planning status and source-only baseline, not a
Light release, native benchmark or execution-contract amendment.

## Released and locally available

Main is `c531624f94678b856d2803b658941cb992d4e8a2`; dev is
`18181149e549e14a7165af8342533c08430ab9f5`. Both have tree
`c891a5b9e4c96fd7d908286b0fede3459152d173`.
The [efficiency feature](https://github.com/bordenet/superpowers-plus/pull/1411),
[main promotion](https://github.com/bordenet/superpowers-plus/pull/1412) and
[history sync](https://github.com/bordenet/superpowers-plus/pull/1413) are merged.
Required release workflows succeeded. The normal installer completed from this
main, and the release recorded native Codex/Claude loader and callback acceptance.
A fresh comparison matched all 55 recorded installed runtime/hook/skill files
against released source; no duplicate install was performed during reconciliation.

These improvements reuse validation/review evidence and reduce repeated work.
They do not implement Light or prove smaller native startup listings. The old
staged strategy draft has a hardened released successor; it is preserved as WIP.
Codex and Claude are the required hosts for the next plan; Augment is optional.

## Progress

| Area | State |
|---|---|
| Historical baseline and discovery | Complete for their recorded revisions; retained |
| Core selection manifest/validator | Shipped; eight canonical core entries |
| Full source/installed-output protection | Shipped, with a later repository oracle |
| P2b mode flag and state | Uncommitted, unsealed, Full-only; selected Light is rejected |
| Ownership and per-host listing projections | Unfinished |
| Transitions, interruption recovery, diagnostics | Unfinished |
| On-demand catalog/load helpers | Absent |
| Complete native Light evaluation and dogfood | Outstanding |

The protected P2b worktree has two staged additions and seven unstaged modifications;
its head is `c9e7cf1079b4d20feb2d43ae58036ddbd8088472`, 27 commits behind the pinned
dev. Its prior background-sync attribution was acknowledged by the owner; that is
not an unanswered question. Preserve its bytes and staging while planning reuse.

## Fresh source-only baseline

The existing resident-cost reporter and manifest validator ran with scratch HOME
and TMPDIR at the pinned dev above. Both exited 0. Product source was unchanged.

| Metric | Result | Boundary |
|---|---:|---|
| Source skill inventory | 125 | Source packages, not installed selectors |
| Automatic/manual source skills | 25 / 100 | Reporter visibility classification |
| Projected Claude listing metadata | 7,119 bytes | Decoded name plus description, UTF-8 |
| Eight core entries' metadata | 2,318 bytes | Canonical metadata, not native visibility |
| Source parse failures | 0 | Reporter scope |

Core metadata excludes future helpers and host framing. Manual flags, aliases,
plugins, hooks, connectors and host-supplied instructions affect actual context.
No complete-Light cost or native listing result follows from this table. The old
7,345/2,390-byte values remain historical; their difference is not lite savings.

## Compatibility reconciliation

The historical private contract retains oracle
`45186ef62e2ac91f8ec173d92d36b5058380eff2`. Current repository source/output tests
and fixture use `09d0281da0ee33198937f6b8e54390d9b82ba3f3`. Keep both histories;
propose an execution-contract amendment rather than silently repinning old evidence.
The broad source freeze still covers skills, rules, lib, tools and installer/runtime
inputs. The historical B0 narrowing has not already happened.

Only three P2b paths changed upstream since its current head: the Full source test,
the Full install helper and the Augment baseline fixture. Review those overlaps
before reusing old exemptions or hashes. Old focused passes do not seal a current
standalone slice. No source freeze, oracle, interface or default changed here.

## First diagnostic prepared; approval pending

R2b preparation now has same-revision F/A/C source payloads, the released alias
mapping, frozen content fixtures and an executable native observation method.
The next proposed run is deliberately small: four Claude Code F/C skill-layer
sessions on Haiku 5.5, one push-authorization case and one arithmetic negative in
each arm, with separately observed startup. It schedules eight user turns and
at most sixteen provider inference requests, with a USD 2 pre-tax API inference
ceiling. No paid run is authorized or has executed.

Haiku 5.5 supersedes the older 4.5 proposal at the owner's direction. Its current
model limits/pricing were verified. Native CLI checks against a local fake provider
proved tool-event capture and real startup/task continuation; synthetic responses
are not evidence of model behavior, provider availability, billing or quality.

The guard reserves worst-case spend before forwarding and settles only complete
provider usage. Errors keep their reservation and stop. Paid and mock runs use
separate fresh roots; stale or symlink runtime trees refuse before mutation.
Denied, failed, truncated or unobservable task windows are INVALID, even if the
final answer succeeds. A separate native denial check proved this path.

This is a controlled source skill-layer diagnostic with read-only tools and a
fixture hook. It excludes live suite hooks, wrappers, synced skills and connectors
from both arms. It does not establish shipped-Full behavior, native Light cost,
complete acceptance or host support. A remains source/inventory-only; helper cost
is still unknown. Unknown live wrapper ownership is preserved without cleanup.

The full register retains 26 required skills, 78 positive cases, 10 negatives and
two repeats, with Codex and Claude required. Those requirements are not waived by
this pilot. The old 704-session draft is not launch authority. After the pilot,
present all observations before seeking a separate expanded budget or any product,
contract, oracle or default change.
