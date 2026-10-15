[English](https://yyds8170-ctrl.github.io/rea-ghidra-setup/en/) | 简体中文

# rea-ghidra-setup

在云电脑 / Linux 服务器 / Windows / macOS 上，**一条命令**把 **REA（Reverse Engineer Anything）+ Ghidra 12.1.4 + JDK 21 + 便携 Node 24** 装好并通过 9 项端到端验证。本仓库只分发安装/编排脚本，**不内置、不修改、不分发** Ghidra 或 REA 二进制——运行时从官方源下载。

??? info "独立第三方声明"
    本项目是独立的第三方部署/编排工具，与 NSA、Ghidra、morluto、REA 及各自权利人**无隶属、无背书、无赞助关系**。"Ghidra""REA"等名称归各自权利人所有，本项目仅作指示性说明。第三方版权与许可证始终保留，详见
    [NOTICE](https://github.com/yyds8170-ctrl/rea-ghidra-setup/blob/main/NOTICE) 与
    [TRADEMARKS](https://github.com/yyds8170-ctrl/rea-ghidra-setup/blob/main/TRADEMARKS.md)。
    维护者：**洋洋（[yyds8170-ctrl](https://github.com/yyds8170-ctrl)）**。

## 30 秒安装

=== "Linux / macOS (bash)"
    ```bash
    git clone https://github.com/yyds8170-ctrl/rea-ghidra-setup.git
    cd rea-ghidra-setup
    ./rea-ghidra install && ./rea-ghidra verify
    ```

=== "Windows (PowerShell)"
    ```powershell
    git clone https://github.com/yyds8170-ctrl/rea-ghidra-setup.git
    cd rea-ghidra-setup
    .\rea-ghidra.ps1 install
    .\rea-ghidra.ps1 verify
    ```

=== "Docker（任意宿主）"
    ```bash
    docker build -t rea-ghidra .
    docker run --rm --entrypoint bash rea-ghidra /opt/rea-ghidra-setup/verify.sh
    ```

## 特性

- **统一入口**：`rea-ghidra` / `rea-ghidra.ps1` 一条命令收敛 install / doctor / verify / mcp / export / batch / self-update / current / rollback。
- **三平台一等公民**：Linux（x86_64/arm64）、Windows 10/11 x64（用户态免管理员）、macOS（Intel / Apple Silicon，自动构建 native）。
- **Docker / ChromeOS**：提供多架构镜像构建与 Crostini 指引。
- **离线兜底**：`prepare-offline` 把 Ghidra/JDK/Node 预先拉到 `offline/`，内网/air-gapped 环境直接装。
- **校验和强校验**：下载产物全部比对 sha256；self-update 只接受带 `.checksums.txt` 的 release 包。
- **批量缓存**：`batch` 子命令并行分析多个二进制，按内容 sha12 做快照缓存，可断点续跑。
- **静态导出**：`export` 用 Ghidra 原生 `analyzeHeadless` 导出 functions/strings/symbols/calls/decompiled JSON，不依赖 REA/Node。
- **真实案例库**：5 个 crackme / license key / 阶梯计价 / switch 分派 / 导出流程示例，断言只依赖字符串与常量，不依赖绝对地址。
- **结构化报告生成器**：Markdown + 内联 CSS HTML 双产物，含元信息/段表/安全项/导入导出/字符串/交叉引用/反编译摘要。
- **国内镜像**：自动探测与切换 Ghidra/JDK 国内镜像源，可通过环境变量锁定。

## 下一步

- 平台专属安装细节：[安装指南](install.md)
- 子命令全表：[使用手册](usage.md)
- 案例库：[真实案例导览](cases.md)
- 报告生成器：[结构化报告](report.md)
- 常见问题：[FAQ](faq.md)
- 平台×环境支持矩阵：[支持矩阵](support-matrix.md)

源码与 issue 反馈见 [GitHub 仓库](https://github.com/yyds8170-ctrl/rea-ghidra-setup)；完整根 README（含实测截图、版本历史、目录树）见
[README.md](https://github.com/yyds8170-ctrl/rea-ghidra-setup/blob/main/README.md)。
