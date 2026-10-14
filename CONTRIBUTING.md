# 贡献指南

感谢关注本项目。它是一个精简的 **REA + Ghidra 部署 / 技能仓库**，目标是让任何人在云电脑或服务器上一键装好、一键验证。

## 仓库结构

| 路径 | 作用 |
| --- | --- |
| `install.sh` | 安装 JDK21 + Ghidra + 环境变量（幂等） |
| `uninstall.sh` | 卸载本项目安装内容 |
| `verify.sh` | 端到端自检（编译 demo + 真实分析 + 断言） |
| `skill/SKILL.md` | 逆向工程智能体技能 |
| `scripts/DecompileAll.java` | Ghidra 原生批量反编译脚本 |
| `scripts/ghidra-decompile.sh` | 不依赖 REA 的批量反编译包装 |
| `examples/` | 测试程序 demo.c 与 Makefile |
| `Dockerfile` | 容器化构建 |

## 本地验证（提交前必做）

```bash
# 1. 静态检查所有脚本（需安装 shellcheck）
shellcheck -x install.sh verify.sh uninstall.sh scripts/ghidra-decompile.sh

# 2. 编译测试程序
make -C examples

# 3. 完整端到端自检（需已安装 JDK/Ghidra；首次约 1-3 分钟）
bash verify.sh
```

`verify.sh` 必须全部通过（退出码 0）。新增或修改功能时，请同步补充对应的断言。

## 代码风格

- Bash：遵循 ShellCheck；引号包裹变量，`set -euo pipefail`；保持幂等、可重复运行
- 安装路径统一在 `~/tools`，不污染系统目录，不要求 root
- 脚本应自动从环境变量或 `~/tools` 定位 JDK / Ghidra，不硬编码用户目录
- 只下载/安装**必要**依赖，不内置第三方二进制

## 新增 Ghidra 脚本

- 文件名与类名一致（如 `Foo.java`），放在 `scripts/`
- 通过 `analyzeHeadless -postScript` 可运行，并在真实二进制上验证
- 为其提供文档说明（参数、用法）

## 提交信息

建议使用清晰的类型前缀，例如 `feat:` / `fix:` / `docs:` / `ci:` / `chore:`，并在正文说明动机与验证方式。

## 合规

所有贡献必须符合本项目的合规要求：仅用于合法研究与授权分析，禁止用于绕过授权、外挂、未授权入侵等。详见 [README 合规红线](README.md#合规红线务必阅读)。

## 许可

提交即表示你同意你的贡献以本仓库的 [PolyForm Noncommercial 1.0.0](LICENSE) 许可发布。
