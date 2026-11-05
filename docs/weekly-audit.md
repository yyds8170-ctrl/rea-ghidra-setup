[English](weekly-audit.en.md) | 简体中文

# 每周自动巡检与自动升级流水线（weekly-audit）

> 对应工作流：[`.github/workflows/weekly-audit.yml`](../.github/workflows/weekly-audit.yml)
> 单一事实源：[`config/versions.env`](../config/versions.env)
>
> 每周只读探测四路依赖的上游漂移；**绝不直推 main**。只对 patch 级漂移自动开升级 PR，
> 显式派发全套 CI 当门禁，CI 绿后**直接 squash 合并**；minor/major 或命令有删改则只开 PR
> 等人审；CI 红则开「受阻」issue。

## 1. 流水线总览

```
detect（只读）
  ├─ scripts/audit_collect_drift.py  → drift.json
  │     rea-agents(npm) / Ghidra(GitHub releases) / JDK21(Adoptium) / Node(同 major LTS)
  ├─ lychee 外链死链（continue-on-error，只报告）
  └─ rea --help 命令清单 vs config/command-baseline/ diff
        │
        ▼
report-issue（漂移/新命令/移除命令 → 去重 issue；dry_run 只打印）
        │
        ▼  （仅当存在 patch 级漂移 且 dry_run=false）
open-upgrade-pr
  ├─ scripts/audit_bump_and_branch.sh → 建分支/机械 bump/自检/push
  ├─ pulls.list 去重 → create PR（固定 label/分支名/标题）
  └─ actions.createWorkflowDispatch(ci.yml) 显式派到升级分支
        │
        ▼
ci-gate（轮询升级分支上 ci.yml 最新 run conclusion，每 20s，超时 60min）
        │
   ┌────┴─────────┐
 CI 绿           CI 红
   │               │
 patch → 直接 squash 合并    tiered-merge：评论失败链接
 minor/major → 评论 hold 等人工   + 开/去重 audit-blocked issue
```

## 2. 触发与兜底

| 触发 | 配置 | 语义 |
|---|---|---|
| `schedule` | cron `10 4 * * 1`（周一 04:10 UTC = 北京 12:10） | 错峰避开 `ci.yml` 的周一 03:20；真跑（自动开 patch PR） |
| `push` | branches:[main]，paths 过滤 | 仅 `config/versions.env` / 本 workflow / `config/command-baseline/**` 变动才跑；任何 push 都给 60 天静默时钟续命 |
| `workflow_dispatch` | inputs: `dry_run`（默认 `true`）、`force_upgrade` | 手动/子代理重跑；默认 dry-run 只探测不写 |

- **schedule 不可靠**：cron 用 UTC、最小粒度 5 分钟、高峰会排队延迟甚至丢 run；公开仓库连续 60 天无活动会被 GitHub 自动停用。靠 `push` + `workflow_dispatch` 双兜底续命。若巡检停摆，请在 Actions 页手动 **Enable workflow**。
- **dry_run 语义**：schedule / push 没有 `inputs.dry_run`，视为「真跑」；`workflow_dispatch` 默认 `dry_run=true`，只 `console.log`，不建 issue/PR/分支。

## 3. 漂移端点

| 依赖 | 锁定来源 | 上游端点 | 级别判定 | 自动合并 |
|---|---|---|---|---|
| rea-agents | `REA_VERSION` | `https://registry.npmjs.org/rea-agents/latest`（`.version` / `.engines.node`） | semver diff | 仅 patch |
| Ghidra | `GHIDRA_VERSION` | `https://api.github.com/repos/NationalSecurityAgency/ghidra/releases/latest`（`.tag_name` 正则取号，asset 名取 `GHIDRA_DATE`） | semver diff | 仅 patch |
| JDK 21 | `JDK_FEATURE=21` | `api.adoptium.net/v3/assets/feature_releases/21/ga` | 仅报告（major 固定 21，安装时拉最新 GA） | 否 |
| Node | `REA_NODE_VERSION` | `nodejs.org/dist/index.json` 筛**同 major 且 lts 非空**的最新补丁 | 同 major 内 patch | 仅 patch |

- 所有 GitHub 调用带 `GITHUB_TOKEN`（匿名 60 次/小时，极易 403）；lychee 扫 GitHub 外链也带 `--github-token`。
- Node **不**跟新 major（如 v24→v26）：跨 major 需人工评估 engines 门禁，只在 note 里提示。
- JDK 只锁 major 21（Ghidra 12.x 硬性要求），无 patch 字段可改，仅报告当前 GA。
- engines 变化：从 `versions.env` 注释里抽出基线 engines，与 npm latest 的 `engines.node` 比对，变化写进 drift.json 与 PR 正文。

## 4. PR / issue 去重命名约定

一切幂等锚点 = **分支名 + label + 标题** 三件套：

| 对象 | 命名 | label |
|---|---|---|
| 升级分支 | `chore/upgrade-<dep>-<newver>` | `dependencies` `automated` `upgrade:<dep>` |
| 升级 PR | `chore(deps): bump <dep> <old> -> <new>` | 同上 |
| 漂移报告 issue | `[weekly-audit] 上游漂移巡检（<日期>）` | `dependencies` `automated` `audit-drift` |
| 升级受阻 issue | `[weekly-audit] 升级受阻：<dep> <old> -> <new>` | `dependencies` `automated` `audit-blocked` |

- 用 `pulls.list` / `issues.listForRepo`（core 限流，1000 次/小时）+ 本地匹配去重，不用 search API（单独 10 次/分钟限流）。
- 只对 **open** 的 PR/issue 去重；已关闭视为已处理，下次真漂移再新开。

## 5. CI 门禁（防递归：必须显式派发）

`GITHUB_TOKEN` 开的 PR **不会触发** `ci.yml` 的 `pull_request`（GitHub 防递归）。因此：

1. `open-upgrade-pr` 开 PR 后立即 `actions.createWorkflowDispatch({ workflow_id:'ci.yml', ref: <升级分支> })`；
2. `ci-gate` 每 20s 调 `actions.listWorkflowRuns({ workflow_id:'ci.yml', branch, per_page:1 })` 等 `status==='completed'`，取 `conclusion`，超时 60 分钟。

一次 workflow_dispatch 会跑齐 `ci.yml` 的全部门禁腿（lint 套件 + 按 `schedule||workflow_dispatch` 守卫的 e2e/docker/checksum/multiarch）。

## 6. 分级合并（重点：直接 squash，不用 auto-merge）

本仓库规则集「Protect main」只含两条规则：**禁删分支** 与 **禁 force-push**；没有 required status checks，仓库级 `allow_auto_merge=false`。因此：

| 级别（semver） | CI 绿 | CI 红 |
|---|---|---|
| **patch** | **直接调合并 API** `PUT /repos/{owner}/{repo}/pulls/{n}/merge`，`merge_method=squash` | 走 blocked |
| **minor / major** | 只评论变更摘要/风险，标注 `hold for human review`，**不合并** | 走 blocked |
| 任何级别 | — | 评论失败 run 链接 + 开/去重 `audit-blocked` issue，**绝不强制合并** |

> 这是「**CI 绿后由流水线直接 squash 合并**」，区别于 GitHub 官方的 `enable-auto-merge`
> （后者依赖仓库开启 allow auto-merge + required status checks，本仓库都没有）。
> patch 升级后合进 main **不会自动打 tag / 发版**；如需发版请手动打 `v*` tag 触发 `release.yml`。

## 7. 受阻 issue

以下情况不开合并、改开 `audit-blocked` issue：

- bump 后 `check-versions.sh` 自检不过；
- `git push` 失败；
- CI `conclusion != success`（failure/timeout）。

## 8. 命令演进 diff

- 基线快照入库在 `config/command-baseline/rea-<ver>.txt`（每行一个命令、字典序），配套 `command-domain.tsv`（命令⇥领域⇥可测性）。**不用 `research/`（已 gitignore）当运行时基线。**
- 每周 `npx rea-agents@latest --help` 抽命令清单，与基线 `comm -13/-23` diff：
  - `new_commands`（新增能力待覆盖）写进 drift 报告与 PR；
  - `gone_commands`（被删/改名 = 潜在破坏性）即使是 patch 也降级为人工。
- rea 升级 PR 会把新命令快照写成 `config/command-baseline/rea-<newver>.txt` 一并提交；新命令的领域标注留给人工补 `command-domain.tsv`。

## 9. 脚本

| 脚本 | 职责 |
|---|---|
| `scripts/audit_collect_drift.py` | 只读探测四路漂移 + engines 比对 + 命令 diff，输出 `drift.json`（探测失败降级为 `level=unknown`，不崩溃） |
| `scripts/audit_bump_and_branch.sh` | 仅对 `level=patch` 机械改 `config/versions.env`（ghidra 连带改 `ci.yml` 硬编码点），建分支、跑 `check-versions.sh` 自检、写 `/tmp/upgrade-manifest.tsv`；默认 dry-run，`--apply` 才改本地，`AUDIT_PUSH=1` 才 push |
