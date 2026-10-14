#!/usr/bin/env bash
# =============================================================================
# walkthrough.sh — 端到端实战引导（中文、幂等、只读/不做破坏性操作）
#
# 依次演示：① 环境检查 ② verify 9/9 ③ Ghidra 导出 demo ④ batch-analyze + 快照缓存
#           ⑤ mcp-setup --list/--dry-run（不写盘）。
# 任一步失败打印清晰中文提示并退出非 0；不会修改用户的 MCP 客户端配置。
#
# 用法：examples/walkthrough.sh
# =============================================================================
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_DIR" || exit 1

step() { echo; echo "============================================================"; echo "▶ $1"; echo "============================================================"; }
ok()   { echo "  [OK] $1"; }
note() { echo "  [..] $1"; }

step "① 环境检查（doctor：Node/JDK21/Ghidra/native/内存/磁盘）"
if bash scripts/doctor.sh; then ok "doctor 通过"; else echo "  [提示] doctor 有告警，可看上方输出；继续后续步骤。"; fi

step "② 端到端 verify（9 项分析/反编译断言）"
note "首次会启动 Ghidra headless，约 1-3 分钟…"
if bash verify.sh; then ok "verify 9/9"; else echo "  [失败] verify 未全过，请先按 README 完成 install.sh"; exit 1; fi

step "③ Ghidra 导出 examples/demo（functions/strings/伪代码）"
WD="$(mktemp -d)"
note "导出到 ${WD}（--kind all）…"
if bash scripts/ghidra-export.sh examples/demo --out "$WD" --kind all >/tmp/wt-export.log 2>&1; then
  ok "导出完成，产物："
  for f in functions strings symbols calls decompiled; do
    [ -f "$WD/$f.json" ] && printf "       %s.json（%s 字节）\n" "$f" "$(wc -c < "$WD/$f.json" | tr -d ' ')"
  done
else
  echo "  [失败] ghidra-export 出错，见 /tmp/wt-export.log"; exit 1
fi

step "④ batch-analyze + 快照缓存（2 个不同目标，演示并行与二次命中缓存）"
# 用两个 sha256 不同的目标（带符号 / strip），避免相同 sha 去重
B1="examples/demo"; B2="examples/demo_stripped"
SNAP="$WD/snap"
note "首次批量（functions）…"
bash scripts/batch-analyze.sh "$B1" "$B2" --out "$WD/bo" --kind functions --jobs 2 --snapshot "$SNAP" >/tmp/wt-b1.log 2>&1 && ok "首次批量完成" || echo "  [提示] 批量异常，见 /tmp/wt-b1.log"
note "第二次同 snapshot（应全部 cached、秒回）…"
bash scripts/batch-analyze.sh "$B1" "$B2" --out "$WD/bo2" --kind functions --jobs 2 --snapshot "$SNAP" >/tmp/wt-b2.log 2>&1 && ok "二次批量完成" || echo "  [提示] 见 /tmp/wt-b2.log"
grep -h "缓存命中" /tmp/wt-b2.log || true

step "⑤ MCP 客户端对接（--list 检测 / --dry-run 预览，不写盘）"
note "检测本机 MCP 客户端…"
bash scripts/mcp-setup.sh --list || echo "  [提示] --list 未发现客户端属正常（未装 Claude/Cursor 等）。"
note "预览将写入的 stdio JSON（--dry-run，不写盘）…"
bash scripts/mcp-setup.sh --dry-run --client claude-desktop || true

echo
echo "============================================================"
echo " 演示完成。本脚本只读/幂等，未修改任何 MCP 客户端配置。"
echo " 要真正注册 MCP 客户端，请确认上面 --dry-run 的 JSON 后再加 --yes。"
echo "============================================================"
