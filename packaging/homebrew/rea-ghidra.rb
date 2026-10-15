# Homebrew formula for rea-ghidra-setup (personal third-party tap).
#
# PolyForm Noncommercial 不能进入 homebrew/core（core 要求 DFSG 兼容许可），
# 但第三方 tap 不限制许可。把本文件放到独立 tap 仓库的 Formula/ 下即可：
#   仓库:  yyds8170-ctrl/homebrew-rea-ghidra
#   路径:  Formula/rea-ghidra.rb
#
# 发版时务必把 url 的 tag 与 sha256 更新为真实值：
#   curl -sL https://github.com/yyds8170-ctrl/rea-ghidra-setup/archive/refs/tags/v4.0.1.tar.gz | shasum -a 256
#
# 用户安装：
#   brew tap yyds8170-ctrl/rea-ghidra && brew install rea-ghidra
class ReaGhidra < Formula
  desc "Cross-platform installer/orchestrator for Ghidra + rea-agents (noncommercial)"
  homepage "https://github.com/yyds8170-ctrl/rea-ghidra-setup"
  url "https://github.com/yyds8170-ctrl/rea-ghidra-setup/archive/refs/tags/v4.0.1.tar.gz"
  sha256 "REPLACE_WITH_REAL_SHA256_OF_TARBALL"
  license "PolyForm-Noncommercial-1.0.0"
  head "https://github.com/yyds8170-ctrl/rea-ghidra-setup.git", branch: "main"

  # 安装器与脚本本体放进 libexec，不污染 bin 根目录；bin 只放薄包装。
  # 不令 brew 下载 Ghidra 本体——首次运行时由脚本自己去官方源拉取。
  def install
    libexec.install Dir["*"]
    bin.install_symlink libexec/"rea-ghidra"
  end

  test do
    system "#{bin}/rea-ghidra", "--help"
  end
end
