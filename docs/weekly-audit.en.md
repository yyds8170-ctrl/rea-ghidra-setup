[English](weekly-audit.en.md) | [简体中文](weekly-audit.md)

# Weekly auto-audit & auto-upgrade pipeline (weekly-audit)

> Workflow: [`.github/workflows/weekly-audit.yml`](../.github/workflows/weekly-audit.yml)
> Single source of truth: [`config/versions.env`](../config/versions.env)
>
> Read-only probe of four upstream dep drifts every week. **Never pushes directly to main.**
> Only patch-level drift auto-opens an upgrade PR, dispatches the full CI as a gate, then
> **directly squash-merges when CI is green**; minor/major or any command removal opens a PR
> and waits for human review; a red CI opens a "blocked" issue.

## 1. Overview

```
detect (read-only)
  ├─ scripts/audit_collect_drift.py  → drift.json
  │     rea-agents(npm) / Ghidra(GitHub releases) / JDK21(Adoptium) / Node(same-major LTS)
  ├─ lychee external-link check (continue-on-error, report only)
  └─ rea --help command list vs config/command-baseline/ diff
        │
        ▼
report-issue (drift / new / removed cmds → deduped issue; dry_run prints only)
        │
        ▼  (only when a patch-level drift exists AND dry_run=false)
open-upgrade-pr
  ├─ scripts/audit_bump_and_branch.sh → branch / mechanical bump / self-check / push
  ├─ pulls.list dedup → create PR (fixed label/branch/title)
  └─ actions.createWorkflowDispatch(ci.yml) explicitly onto the upgrade branch
        │
        ▼
ci-gate (poll latest ci.yml run conclusion on the branch, every 20s, 60min timeout)
        │
   ┌────┴─────────┐
 CI green          CI red
   │                 │
 patch → direct squash-merge   tiered-merge: comment failing link
 minor/major → comment hold    + open/dedup audit-blocked issue
```

## 2. Triggers & fallbacks

| Trigger | Config | Meaning |
|---|---|---|
| `schedule` | cron `10 4 * * 1` (Mon 04:10 UTC) | Off-peak vs ci.yml's Mon 03:20; runs for real (auto patch PRs) |
| `push` | branches:[main], paths filtered | Only on `config/versions.env` / this workflow / `config/command-baseline/**`; any push resets the 60-day idle clock |
| `workflow_dispatch` | inputs `dry_run` (default `true`), `force_upgrade` | Manual/agent re-run; dry-run by default |

- **Schedules are unreliable**: cron is UTC, 5-min granularity, queued/dropped under load; a public repo's scheduled workflow auto-disables after 60 days of no activity. `push` + `workflow_dispatch` keep it alive. If it stops, click **Enable workflow** on the Actions tab.
- **dry_run semantics**: schedule / push have no `inputs.dry_run` → treated as a real run; `workflow_dispatch` defaults to `dry_run=true` (console.log only, no issue/PR/branch).

## 3. Drift endpoints

| Dep | Locked in | Upstream endpoint | Level | Auto-merge |
|---|---|---|---|---|
| rea-agents | `REA_VERSION` | `registry.npmjs.org/rea-agents/latest` (`.version` / `.engines.node`) | semver diff | patch only |
| Ghidra | `GHIDRA_VERSION` | `api.github.com/repos/NationalSecurityAgency/ghidra/releases/latest` (`.tag_name`; asset name → `GHIDRA_DATE`) | semver diff | patch only |
| JDK 21 | `JDK_FEATURE=21` | `api.adoptium.net/v3/assets/feature_releases/21/ga` | report only (major fixed at 21; install pulls latest GA) | no |
| Node | `REA_NODE_VERSION` | `nodejs.org/dist/index.json` filtered to **same major, lts truthy**, newest patch | same-major patch | patch only |

- All GitHub calls carry `GITHUB_TOKEN` (anonymous = 60/hr, easily 403); lychee also passes `--github-token`.
- Node does **not** follow a new major (v24→v26); cross-major needs human engine-gate review (noted only).
- JDK is locked to major 21 only (Ghidra 12.x requires it); no patch field to bump, reported for visibility.
- engines change: baseline engines are read from the `versions.env` comment and compared to npm's `engines.node`; a mismatch is recorded in drift.json and the PR body.

## 4. PR / issue dedup naming

Idempotency anchor = **branch name + label + title** trio:

| Object | Name | Labels |
|---|---|---|
| Upgrade branch | `chore/upgrade-<dep>-<newver>` | `dependencies` `automated` `upgrade:<dep>` |
| Upgrade PR | `chore(deps): bump <dep> <old> -> <new>` | same |
| Drift report issue | `[weekly-audit] 上游漂移巡检（<date>）` / drift audit | `dependencies` `automated` `audit-drift` |
| Blocked issue | `[weekly-audit] 升级受阻：<dep> <old> -> <new>` / upgrade blocked | `dependencies` `automated` `audit-blocked` |

- Dedup uses `pulls.list` / `issues.listForRepo` (core quota, 1000/hr) + local match — not the search API (separate 10/min limit).
- Dedup only against **open** PRs/issues; closed ones count as resolved.

## 5. CI gate (anti-recursion: explicit dispatch)

A PR opened by `GITHUB_TOKEN` does **not** trigger `ci.yml`'s `pull_request` (GitHub anti-recursion). Therefore:

1. After opening the PR, `open-upgrade-pr` calls `actions.createWorkflowDispatch({ workflow_id:'ci.yml', ref: <branch> })`;
2. `ci-gate` polls `actions.listWorkflowRuns({ workflow_id:'ci.yml', branch, per_page:1 })` every 20s until `status==='completed'`, reads `conclusion`, 60-min timeout.

One dispatch runs the full `ci.yml` gate (lint suite + the `schedule||workflow_dispatch`-gated e2e/docker/checksum/multiarch legs).

## 6. Tiered merge (note: direct squash, not auto-merge)

The repo's "Protect main" ruleset has only **deletion** and **non_fast_forward**; there are no required status checks and repo-level `allow_auto_merge=false`. Therefore:

| Level | CI green | CI red |
|---|---|---|
| **patch** | **Directly call the merge API** `PUT /repos/{owner}/{repo}/pulls/{n}/merge`, `merge_method=squash` | blocked |
| **minor / major** | Comment summary/risk, mark `hold for human review`, **no merge** | blocked |
| any | — | Comment failing run link + open/dedup `audit-blocked`; **never force-merge** |

> This is "**the pipeline directly squash-merges after CI is green**", distinct from GitHub's official
> `enable-auto-merge` (which requires allow-auto-merge + required status checks — neither is set here).
> A patch merge into main does **not** tag/release; to release, manually push a `v*` tag to trigger `release.yml`.

## 7. Blocked issues

A blocked issue is opened instead of merging when:

- `check-versions.sh` self-check fails after the bump;
- `git push` fails;
- CI `conclusion != success` (failure/timeout).

## 8. Command-evolution diff

- Baseline snapshots live in `config/command-baseline/rea-<ver>.txt` (one command per line, sorted), with `command-domain.tsv` (command⇥domain⇥testability). **`research/` is gitignored and is not the runtime baseline.**
- Weekly `npx rea-agents@latest --help` is diffed against the baseline with `comm -13/-23`:
  - `new_commands` (capabilities to cover) go into the drift report and PR;
  - `gone_commands` (removed/renamed = potentially breaking) downgrade even a patch to human review.
- A rea upgrade PR commits the fresh snapshot as `config/command-baseline/rea-<newver>.txt`; domain annotations for new commands are left for humans to add in `command-domain.tsv`.

## 9. Scripts

| Script | Role |
|---|---|
| `scripts/audit_collect_drift.py` | Read-only probe of the four drifts + engines compare + command diff → `drift.json`; probe failure degrades to `level=unknown` instead of crashing |
| `scripts/audit_bump_and_branch.sh` | Only for `level=patch`: mechanically edit `config/versions.env` (ghidra also edits hardcoded points in `ci.yml`), branch, run `check-versions.sh`, write `/tmp/upgrade-manifest.tsv`; default dry-run, `--apply` touches local files, `AUDIT_PUSH=1` pushes |
