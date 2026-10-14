# 配置与 MCP 接入指南

> 本文覆盖三部分：① 环境变量调优（内存/超时/路径）；② 把 REA 注册为 MCP server
> 接入 Claude Code / Cursor / Claude Desktop 等；③ 代理与 npm 镜像。
> 前置安装见各平台文档，先跑 `bash scripts/detect-env.sh` 与 `scripts/doctor.sh`（Windows 用 `scripts/doctor.ps1`）。

## 一、关键环境变量

| 变量 | 作用 | 默认 / 取值 |
| --- | --- | --- |
| `GHIDRA_INSTALL_DIR` | Ghidra 解压目录（含 `support/analyzeHeadless`） | 安装脚本写入；未设置时 REA 也会在常见目录搜索 |
| `JAVA_HOME` | JDK 21 目录（含 `bin/java`） | 安装脚本写入；Ghidra 12.x 要求**恰好 21** |
| `GHIDRA_HEADLESS_MAXMEM` | **仅 headless** 的 JVM 最大堆（`-Xmx`） | 优先级最高；未设置看 `GHIDRA_MAXMEM`，再回退 `2G` |
| `GHIDRA_MAXMEM` | 所有 Ghidra 实例（含 GUI）的最大堆 | 默认 `2G` |
| `REA_GHIDRA_STARTUP_TIMEOUT_MS` | Ghidra provider 启动/导入/分析的等待毫秒 | 默认 `330000`（330s）；大二进制可加大到 `600000` |
| `REA_GHIDRA_LANGUAGE_ID` | 强制 Ghidra 语言 ID（如 `x86:LE:32:default`） | 一般不用；自动识别失败时才设 |
| `PATH` | 需含 JDK 的 `bin`、Node 的 `bin`、（Windows）`%APPDATA%\npm` | 安装脚本自动追加 |

### 内存怎么设

低内存机器（4GB 内存 / 云电脑 / Crostini）建议把 headless 堆降到 512M：

```bash
# Linux / macOS（写进 ~/.bashrc 或 ~/.zshrc）
export GHIDRA_HEADLESS_MAXMEM=512M
export REA_GHIDRA_STARTUP_TIMEOUT_MS=600000
```

```powershell
# Windows（用户级持久化）
[Environment]::SetEnvironmentVariable('GHIDRA_HEADLESS_MAXMEM','512M','User')
[Environment]::SetEnvironmentVariable('REA_GHIDRA_STARTUP_TIMEOUT_MS','600000','User')
```

> 注意：`GHIDRA_HEADLESS_MAXMEM` 只限制 JVM 堆，不限制 JVM 常驻 RSS、Node 堆或整个进程家族的总内存。
> 512M 用小样本（examples/demo）验证可行，大目标仍需更大堆。

### 让设置生效

- bash/zsh：写进 `~/.bashrc` / `~/.zshrc` 后 `source` 或重开终端。
- macOS：脚本会同时写 `~/.zshrc` 与 `~/.bash_profile`。
- Windows：用户级变量写入后**重开终端**才在新会话生效；脚本会同时设置当前进程。
- Docker：`docker run -e GHIDRA_HEADLESS_MAXMEM=512M ...` 或在 Compose 的 `environment` 中覆盖。

## 二、把 REA 注册为 MCP server

REA 提供两种接入方式：自动注册（推荐）与手动配置。

### 1. 自动注册（`rea mcp add`）

```bash
# 列出/为检测到的客户端配置；指定某一个：
rea mcp add --agent claude-code
rea mcp add --agent cursor
# 覆盖客户端实际启动命令（例如用 pnpm 包一层）：
rea mcp add -c "pnpm rea-agents --mcp"
# 默认写到全局；--no-global 只写当前项目：
rea mcp add --agent claude-code --no-global
```

注册后自检 MCP server 能否启动、能否列出工具：

```bash
rea mcp doctor --json
```

### 2. 交互式配置（`rea setup`）

```bash
rea setup --all-detected --yes          # 为所有检测到的客户端配置
rea setup --client claude-code --yes    # 只配置某一个
rea setup --dry-run                     # 只打印将要做什么，不落地
```

- `rea setup` 同时负责可选分析 provider 的配置；`rea uninstall` 可移除 REA 写入的客户端配置与技能文件。
- 在豆包等**不直接注册 MCP** 的环境中，无需注册，直接通过命令行 CLI（与 MCP 共享同一套工作流）即可，
  见 [`skill/SKILL.md`](../skill/SKILL.md)。

### 3. 手动配置（以 Claude Desktop 为例）

编辑 `claude_desktop_config.json`（macOS 在 `~/Library/Application Support/Claude/`，
Windows 在 `%APPDATA%\Claude\`），加入：

```json
{
  "mcpServers": {
    "rea": {
      "command": "npx",
      "args": ["-y", "rea-agents@6.4.0", "--mcp"]
    }
  }
}
```

- 已全局安装时可直接用 `command: "rea"`、`args: ["--mcp"]`，免去每次 npx 解析。
- 若 Ghidra 安装在非标准路径，给该 server 加 `env`：
  ```json
  "env": {
    "GHIDRA_INSTALL_DIR": "C:\\tools\\ghidra_12.1.4_PUBLIC",
    "JAVA_HOME": "C:\\tools\\jdk-21",
    "GHIDRA_HEADLESS_MAXMEM": "512M"
  }
  ```
- 改完重启客户端；`rea --mcp` 是 stdio server，本身不常驻。
- 注意 MCP 客户端自身的请求超时也要够长（否则即使 Ghidra 能在 330s 内完成，客户端也可能更早超时）。

### 4. 验证接入

```bash
rea doctor            # provider 自检（含 Ghidra 版本、analyzeHeadless、native decompiler）
rea mcp doctor --json # MCP server 启动 + 工具列表
bash scripts/doctor.sh         # 本项目的跨平台环境预检（Linux/macOS）
.\scripts\doctor.ps1           # Windows
```

## 三、代理与镜像

- **下载走代理**（Ghidra 在 GitHub、JDK 在 Adoptium/CDN、Node 在 nodejs.org）：
  ```bash
  export HTTPS_PROXY=http://127.0.0.1:7890
  export HTTP_PROXY=http://127.0.0.1:7890
  ```
  PowerShell：
  ```powershell
  $env:HTTPS_PROXY='http://127.0.0.1:7890'; $env:HTTP_PROXY='http://127.0.0.1:7890'
  ```
- **npm 镜像**（仅影响 `rea-agents` 安装，不影响 Ghidra/JDK）：
  ```bash
  npm config set registry https://registry.npmmirror.com
  ```
- **Docker 镜像**：在内网/受限环境给 Docker daemon 配置 registry mirror；构建时构建容器内的
  `apt`/`curl` 代理用 `--build-arg HTTPS_PROXY=...`（多架构 buildx 时用 `docker buildx build --build-arg`）。
- 完全离线 / 内网（air-gapped）安装见 [offline.md](offline.md)；常见报错见 [troubleshooting.md](troubleshooting.md)。
