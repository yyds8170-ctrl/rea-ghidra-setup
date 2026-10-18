# 给一个链接/网站怎么做逆向分析（URL 分析）

很多人拿到的"软件"不是 exe，而是**一个网址**。本仓库基于 REA 的 CDP
（Chrome DevTools Protocol）被动观察能力，把"打开网页 → 看懂它怎么干活"
变成一套标准化、可复现的 Evidence 流程。

## 三种模式，按你手里的材料选

| 模式 | 你有什么 | 适合 | 一键入口 |
|---|---|---|---|
| 实时浏览器观察 | 目标 URL，自己能开浏览器 | 想知道页面加载了哪些脚本、发了哪些请求、localStorage 写了什么 | `scripts/web-analyze.sh --cdp ... --deep` |
| JS bundle 静态解析 | 已 attach 的页面 | 不跑代码地拆 chunk、找路由/API 端点候选、看 vendor 指纹、sourcemap | `--bundle` |
| HAR/SAZ 离线复盘 | 一份 Chrome 导出的 HAR 抓包 | 已经抓过包，要批量看请求/响应、暴露的 payload 和源码位置 | `--har 文件.har` |

> REA **不替你启动、导航、关闭浏览器**——它被动 attach 一个已经打开目标页的
> Chrome 系浏览器。这是设计上的安全边界（不是浏览器自动化，也不是沙箱）。

## 前置：用调试端口起浏览器（一次）

```bash
google-chrome --remote-debugging-port=9222 \
  --user-data-dir=/tmp/rea-browser-profile \
  --password-store=basic "https://你要分析的网站"
```

- Chromium / Brave 同理；macOS 用 `.app/Contents/MacOS/` 下的可执行文件。
- `--user-data-dir` 用**专用 profile**，不要拿你日常浏览器。
- `--password-store=basic`：Linux 桌面 keyring 会卡住 Chrome，这个 flag 绕开。
- 调试端口只绑 loopback，不要暴露到外网。

不确定环境是否就绪？跑：

```bash
scripts/web-analyze.sh --doctor
```

## 一键观察

```bash
# 1) 基础观察（DOM 结构、脚本/资源清单、控制台、WebSocket、存储键名）
scripts/web-analyze.sh --cdp http://127.0.0.1:9222

# 2) 深度观察 + bundle 静态解析 + 视口截图，产物落盘
scripts/web-analyze.sh --cdp http://127.0.0.1:9222 \
  --origin https://example.com \
  --out /tmp/web-out --deep --bundle --screenshot

# 3) HAR 离线复盘
scripts/web-analyze.sh --har ./抓包.har
```

产物都是标准 Evidence JSON（`inspect.json` / `bundle.json` / `targets.json`），
每个结论带 provider、时间窗、coverage（complete/filtered/truncated）和局限说明。

## 它具体能拿到什么（inspect-web-page）

- DOM 帧结构、可访问性树（默认只留结构，文字要 `--include-accessibility-text`）
- 页面加载的全部脚本 URL 与资源清单（含 sourcemap 元数据）
- 观察窗口内的网络请求（方法/状态/MIME/大小/URL，**不含**响应体——除非你显式开 JSON body shape）
- 控制台输出（原始文本要 `--include-console-text`）、WebSocket 帧形状
- localStorage / Cookie / IndexedDB 的键名（**值永远打码**，可加指纹做跨次对比）

bundle 静态解析（`analyze-web-bundle`）在**不执行代码**的前提下给你：
chunk 依赖边、路由与 API 端点候选、第三方库指纹、WebMCP 声明。

## 深度反混淆（可选增强）

如果遇到重度混淆（obfuscator.io / 控制流平坦化 / webpack 包），业界标准做法是先用
[webcrack](https://github.com/j4k0xb/webcrack) 剥壳再人工读：

```bash
npx webcrack page.bundle.js -o ./recovered/
```

sourcemap（`*.js.map`）若暴露，直接能还原源码，优先找 `.map`。

## 边界与合规

- 只分析你**有权分析**的站点（自己的产品、授权的目标、公开页面）。
- 被动 attach 不等于沙箱：页面仍以你 Chrome 的权限跑，会真实发请求。
- 观察窗口默认 500ms，按需 `--observation-ms` 调大；窗口外的历史网络事件不会补抓。
- CDP endpoint 只认 `http://127.0.0.1:PORT`（localhost/带路径/带凭证都不接受）。

## 本地示例

`examples/web-demo/` 是一个带外部脚本 + fetch + localStorage 键的静态页：

```bash
cd examples/web-demo && python3 -m http.server 8099 &
# 然后在调试端口浏览器里打开 http://127.0.0.1:8099/
../../scripts/web-analyze.sh --cdp http://127.0.0.1:9222 --out /tmp/web-out --bundle
```
