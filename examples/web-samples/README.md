# examples/web-samples/ — MCP / HAR 小型文本样本

本目录是**可提交**的小型文本样本，用于离线复跑 MCP 端到端握手与 HAR 离线复盘，
不依赖真机、Ghidra 或外部网络。

> 安全：所有凭证都是明显占位假值（`PLACEHOLDER_FAKE_*`），禁止换成真实 token / cookie。

## 文件

| 文件 | 说明 |
|---|---|
| `good.har` | 标准 HAR 1.2 样本：1 个 POST（带 postData/Authorization/Cookie）+ 1 个 GET（JS 响应），共 2 条 entry |
| `broken-missing-fields.har` | 异常样本：合法 JSON 但缺 HAR 必填字段（entry 缺 `time`/`request.method`/`response.status`），用于验证报错 |
| `not-json.har` | 异常样本：根本不是 JSON，用于验证解析报错 |
| `redaction-probe.har` | 打码覆盖探针：含 Authorization/Proxy-Authorization/X-Api-Key/X-Auth-Token/X-Custom-Session/query token/Set-Cookie，全部 PLACEHOLDER 假值 |
| `sample.saz` | Fiddler SAZ（ZIP+raw 会话），1 条 POST→200 |
| `sample.qlog` | aioquic 0.3 profile qlog（用 aioquic 自带 trace 编码器生成） |
| `sample.mitm` | mitmproxy 12.x 二进制 flow（用 mitmproxy 库 FlowWriter 生成）；复盘需 `REA_MITMDUMP_COMMAND=<绝对路径 mitmdump 12.2.3>` |
| `mcp-client-config.example.json` | MCP 客户端配置文件里 `mcpServers.rea` 条目的形状（路径占位，勿直接用） |
| `run-mcp-e2e.sh` | 可复跑的 MCP stdio JSON-RPC 端到端脚本（见下） |

## 跑一遍 MCP 端到端（initialize → initialized → tools/list → tools/call）

```bash
bash examples/web-samples/run-mcp-e2e.sh                 # 全部校验应打印 ALL CHECKS PASSED
bash examples/web-samples/run-mcp-e2e.sh --out /tmp/mcp-transcript.log   # 同时落盘收发报文
```

它真的启动 `npx -y rea-agents@<REA_VERSION> --mcp`（版本取自 `config/versions.env`，
不硬编码），走完整一轮 JSON-RPC，并逐条校验信封：`jsonrpc=="2.0"`、`id` 对齐、
`result`/无 `error`、`result.content[].type=="text"`。

已真实跑通的离线 `tools/call`（均无需 Ghidra/真机/网络）：
`inspect_byte_entropy`（临时小文件 Shannon 熵）、`inspect_analysis_settings`、
`list_unknowns`、`binary_session`。错误信封断言：调用未声明工具 → 顶层 JSON-RPC
`error`（code `-32602`）；缺必填参数 → `result.isError==true`。
Ghidra/设备类工具需真机，未在本脚本实跑。

## 跑一遍 HAR 离线复盘

```bash
scripts/web-analyze.sh --har examples/web-samples/good.har                # 应退出 0，逐条复盘 2 个请求
scripts/web-analyze.sh --har examples/web-samples/broken-missing-fields.har  # 应退出 1，结构化报缺字段
scripts/web-analyze.sh --har examples/web-samples/not-json.har             # 应退出 1，报 HAR is malformed JSON
```

> 注意：`--har` 底层调的是
> `rea inspect-web-network-capture <文件> har --format json`（离线、不联网重放）；
> 不是 `rea analyze <文件>`——后者会把 HAR 当二进制 artifact 打开并报 unsupported binary format。
