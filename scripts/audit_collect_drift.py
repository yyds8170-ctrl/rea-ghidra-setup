#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# =============================================================================
# scripts/audit_collect_drift.py — 每周巡检：采集「四路依赖上游漂移 + engines 变化
#                                  + 命令清单 diff」，结构化输出 drift.json。
#
# 只读探测，唯一写盘动作是 --out 指定的 drift.json。任何一路探测失败（离线 / GitHub
# 匿名限流 403 / npx 不可用）都不会让脚本崩溃，而是把该项标成 level=unknown 并写 note。
#
# 漂移判定（与 research/C_weekly_audit_design.md §3.5 对齐；以 config/versions.env 为
# 单一事实源）：
#   rea-agents | REA_VERSION        | npm /latest .version
#   Ghidra     | GHIDRA_VERSION    | GitHub releases/latest .tag_name（连带取出
#              |                   GHIDRA_BUILD / GHIDRA_DATE 供 bump）
#   JDK 21     | JDK_FEATURE=21    | Adoptium feature_releases/21/ga（仅报告，不 bump）
#   Node       | REA_NODE_VERSION  | nodejs.org/dist/index.json 同 major 最新 LTS
#
# 用法：
#   python3 scripts/audit_collect_drift.py \
#       --versions config/versions.env --out drift.json \
#       [--help-dump /tmp/help-new.txt] [--baseline-dir config/command-baseline]
#
# 退出码：0 = 探测完成（漂移 / 探测失败都写进 JSON，不因此失败）；2 = 参数/版本文件错。
# =============================================================================
import argparse
import datetime
import json
import os
import re
import sys
import urllib.error
import urllib.request

GITHUB = "https://api.github.com/repos/NationalSecurityAgency/ghidra/releases/latest"
NPM_LATEST = "https://registry.npmjs.org/rea-agents/latest"
ADOPTIUM_21_GA = (
    "https://api.adoptium.net/v3/assets/feature_releases/21/ga"
    "?image_type=jdk&architecture=x64&os=linux&heap_size=normal&page=0&page_size=1"
)
NODE_INDEX = "https://nodejs.org/dist/index.json"
HTTP_TIMEOUT = 30


def http_get_json(url, token=None, timeout=HTTP_TIMEOUT):
    """GET JSON。返回 (obj, None) 或 (None, errmsg)。
    GitHub 调用才带 vnd.github Accept 与 token（Adoptium/npm 对该 Accept 头会 406）。"""
    req = urllib.request.Request(url)
    req.add_header("User-Agent", "weekly-audit")
    if "api.github.com" in url:
        req.add_header("Accept", "application/vnd.github+json")
        if token:
            req.add_header("Authorization", "Bearer " + token)
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            return json.load(resp), None
    except urllib.error.HTTPError as e:
        return None, "HTTP %s（%s）" % (e.code, url)
    except Exception as e:  # noqa: BLE001 —— 容错：任何网络异常都降级为 unknown
        return None, "%s: %s" % (type(e).__name__, e)


def load_versions(path):
    """解析 config/versions.env 的 KEY=VALUE；顺带从注释里抽出 baseline engines。"""
    vals = {}
    baseline_engines = None
    with open(path, encoding="utf-8") as fh:
        for line in fh:
            s = line.strip()
            if not s or s.startswith("#"):
                # 形如：# Node：REA 6.8.0 engines = ^22.23.4 || ^24.22.1 || >=26.12.1（…
                m = re.search(r"engines\s*=\s*([^（]+)", s)
                if m:
                    baseline_engines = m.group(1).strip()
                continue
            if "=" in s:
                k, v = s.split("=", 1)
                vals[k.strip()] = v.strip()
    return vals, baseline_engines


def parse_ver_tuple(text):
    """'6.8.0' / 'v24.22.2' / '21.0.13+9' -> (6,8,0)。非数字段取其前缀数字。"""
    t = (text or "").strip().lstrip("v")
    t = t.split("+", 1)[0]          # 去掉 build metadata（21.0.13+9 -> 21.0.13）
    nums = []
    for part in re.split(r"[.\-]", t):
        m = re.match(r"(\d+)", part)
        nums.append(int(m.group(1)) if m else 0)
    while len(nums) < 3:
        nums.append(0)
    return tuple(nums[:3])


def semver_level(locked, upstream):
    a = parse_ver_tuple(locked)
    b = parse_ver_tuple(upstream)
    if b[0] > a[0]:
        return "major"
    if b[1] > a[1]:
        return "minor"
    if b[2] > a[2]:
        return "patch"
    return "none"


def extract_commands_from_help(text):
    """从 `rea --help` 输出里抽命令名：命令段是「两空格起头 <cmd>  <desc>」。"""
    cmds = set()
    for line in text.splitlines():
        m = re.match(r"^  ([a-z][a-z0-9-]+)\s", line)
        if m:
            cmds.add(m.group(1))
    return cmds


def find_baseline(baseline_dir, rea_version):
    """在 config/command-baseline/ 里找 rea-<ver>.txt 基线。优先匹配锁定版本，
    否则取版本号最高的那份。返回 (version, abs_path, set(commands)) 或 (None,None,set())。"""
    if not os.path.isdir(baseline_dir):
        return None, None, set()
    candidates = {}
    for name in os.listdir(baseline_dir):
        m = re.match(r"^rea-(\d+\.\d+\.\d+)\.txt$", name)
        if m:
            candidates[m.group(1)] = os.path.join(baseline_dir, name)
    if not candidates:
        return None, None, set()
    # 优先锁定版本，否则按 tuple 排序取最高
    pick = None
    if rea_version in candidates:
        pick = rea_version
    else:
        pick = sorted(candidates, key=parse_ver_tuple)[-1]
    path = candidates[pick]
    cmds = set()
    with open(path, encoding="utf-8") as fh:
        for line in fh:
            c = line.strip()
            if c:
                cmds.add(c)
    return pick, path, cmds


def probe_rea(token):
    data, err = http_get_json(NPM_LATEST, token=None)
    if err or not data:
        return {"upstream": None, "engines_node": None,
                "note": "npm 探测失败：%s" % err}
    return {"upstream": data.get("version"),
            "engines_node": (data.get("engines") or {}).get("node"),
            "note": ""}


def probe_ghidra(token):
    data, err = http_get_json(GITHUB, token=token)
    if err or not data:
        return {"upstream": None, "build": None, "date": None,
                "note": "GitHub releases 探测失败（匿名限流 403？未带 GITHUB_TOKEN）：%s" % err}
    tag = data.get("tag_name", "")            # e.g. Ghidra_12.1.4_build
    m = re.search(r"Ghidra_(\d+\.\d+\.\d+)_build", tag)
    ver = m.group(1) if m else None
    date = None
    for asset in data.get("assets", []) or []:
        am = re.search(r"ghidra_\d+\.\d+\.\d+_PUBLIC_(\d+)\.zip", asset.get("name", ""))
        if am:
            date = am.group(1)
            break
    return {"upstream": ver, "build": tag or None, "date": date,
            "note": ""}


def probe_jdk():
    data, err = http_get_json(ADOPTIUM_21_GA)
    if err or not data:
        return {"upstream": None, "note": "Adoptium 探测失败：%s" % err}
    rel = data[0] if isinstance(data, list) and data else {}
    vd = rel.get("version_data", {}) or {}
    name = vd.get("openjdk_version") or rel.get("release_name")
    return {"upstream": name, "note": ""}


def probe_node(locked):
    data, err = http_get_json(NODE_INDEX)
    if err or not data:
        return {"upstream": None, "note": "nodejs.org dist 探测失败：%s" % err}
    major = parse_ver_tuple(locked)[0]
    same_major_lts = [r for r in data
                      if r.get("version", "").startswith("v%d." % major) and r.get("lts")]
    if not same_major_lts:
        return {"upstream": None, "note": "index.json 未找到 v%d.x LTS" % major}
    latest = same_major_lts[0]["version"].lstrip("v")
    newest_major = next((r["version"] for r in data if r.get("lts")), None)
    note = "同 major v%d 最新 LTS=%s" % (major, latest)
    if newest_major and not newest_major.startswith("v%d." % major):
        note += "；另有更新 major %s 不自动跟（需人工评估 engines 门禁）" % newest_major
    return {"upstream": latest, "note": note}


def main():
    ap = argparse.ArgumentParser(description="采集上游漂移，输出 drift.json")
    ap.add_argument("--versions", default="config/versions.env")
    ap.add_argument("--out", default="drift.json")
    ap.add_argument("--baseline-dir", default="config/command-baseline")
    ap.add_argument("--help-dump", default=None,
                    help="`rea-agents@latest --help` 原始输出；提供则做命令清单 diff")
    args = ap.parse_args()

    if not os.path.isfile(args.versions):
        print("ERROR: 找不到版本文件 %s" % args.versions, file=sys.stderr)
        return 2

    versions, baseline_engines = load_versions(args.versions)
    need = ["GHIDRA_VERSION", "JDK_FEATURE", "REA_NODE_VERSION", "REA_VERSION"]
    missing = [k for k in need if not versions.get(k)]
    if missing:
        print("ERROR: versions.env 缺字段 %s" % ",".join(missing), file=sys.stderr)
        return 2

    token = os.environ.get("GITHUB_TOKEN") or None
    items = []

    # --- rea-agents（npm）---
    r = probe_rea(token)
    rea_up = r["upstream"]
    if rea_up:
        lvl = semver_level(versions["REA_VERSION"], rea_up)
        note = "npm /latest"
        if lvl == "none":
            note += "；与锁定一致"
    else:
        lvl = "unknown"
        note = r["note"]
    engines_changed = bool(baseline_engines and r["engines_node"]
                           and baseline_engines != r["engines_node"])
    items.append({
        "dep": "rea",
        "locked": versions["REA_VERSION"],
        "upstream": rea_up,
        "level": lvl,
        "auto_bump": True,
        "engines_node": r["engines_node"],
        "baseline_engines_node": baseline_engines,
        "engines_changed": engines_changed,
        "source": NPM_LATEST,
        "note": note,
    })

    # --- Ghidra（GitHub releases）---
    g = probe_ghidra(token)
    if g["upstream"]:
        lvl = semver_level(versions["GHIDRA_VERSION"], g["upstream"])
        note = "releases/latest；需人工核对 GHIDRA_BUILD/DATE"
    else:
        lvl = "unknown"
        note = g["note"]
    items.append({
        "dep": "ghidra",
        "locked": versions["GHIDRA_VERSION"],
        "upstream": g["upstream"],
        "level": lvl,
        "auto_bump": True,
        "ghidra_build": g["build"],
        "ghidra_date": g["date"],
        "source": GITHUB,
        "note": note,
    })

    # --- JDK 21（Adoptium GA，仅报告不 bump）---
    j = probe_jdk()
    items.append({
        "dep": "jdk21",
        "locked": versions["JDK_FEATURE"],
        "upstream": j["upstream"],
        "level": "none",
        "auto_bump": False,
        "source": ADOPTIUM_21_GA,
        "note": ("仅锁 major=%s；安装时拉最新 GA（当前 %s），无 patch 字段可改。%s"
                 % (versions["JDK_FEATURE"], j["upstream"], j["note"])).strip(),
    })

    # --- Node（同 major 最新 LTS）---
    n = probe_node(versions["REA_NODE_VERSION"])
    if n["upstream"]:
        lvl = semver_level(versions["REA_NODE_VERSION"], n["upstream"])
        note = n["note"]
    else:
        lvl = "unknown"
        note = n["note"]
    items.append({
        "dep": "node",
        "locked": versions["REA_NODE_VERSION"],
        "upstream": n["upstream"],
        "level": lvl,
        "auto_bump": True,
        "source": NODE_INDEX,
        "note": note,
    })

    # --- 命令清单 diff（基线在 config/command-baseline/）---
    base_ver, base_path, base_cmds = find_baseline(args.baseline_dir, versions["REA_VERSION"])
    new_cmds, gone_cmds = [], []
    diff_note = ""
    if args.help_dump and os.path.isfile(args.help_dump):
        with open(args.help_dump, encoding="utf-8") as fh:
            fresh = extract_commands_from_help(fh.read())
        if base_cmds:
            new_cmds = sorted(fresh - base_cmds)
            gone_cmds = sorted(base_cmds - fresh)
            diff_note = ("基线 %s 命令 %d 个；新快照命令 %d 个。"
                         % (base_ver, len(base_cmds), len(fresh)))
        else:
            diff_note = "未找到基线快照，跳过 diff。"
    else:
        diff_note = "未提供 --help-dump（CI 里由 npx rea-agents@latest --help 生成），跳过命令 diff。"

    result = {
        "generated_at": datetime.datetime.now(datetime.timezone.utc).strftime(
            "%Y-%m-%dT%H:%M:%SZ"),
        "versions_env": args.versions,
        "items": items,
        "command_diff": {
            "baseline_version": base_ver,
            "baseline_file": base_path,
            "new_commands": new_cmds,
            "gone_commands": gone_cmds,
            "note": diff_note,
        },
    }

    with open(args.out, "w", encoding="utf-8") as fh:
        json.dump(result, fh, ensure_ascii=False, indent=2)
        fh.write("\n")

    # 控制台摘要（dry_run 下也能看见）
    print("== drift 采集完成 -> %s ==" % args.out)
    for it in items:
        print("  %-8s locked=%-12s upstream=%-12s level=%-7s %s"
              % (it["dep"], it["locked"], str(it["upstream"]), it["level"], it["note"]))
    cd = result["command_diff"]
    print("  命令 diff（基线 %s）: +%d new / -%d gone"
          % (cd["baseline_version"], len(cd["new_commands"]), len(cd["gone_commands"])))
    return 0


if __name__ == "__main__":
    sys.exit(main())
