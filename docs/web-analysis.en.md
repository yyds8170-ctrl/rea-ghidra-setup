# Reverse-engineering a website from a URL

What people hand you is often not an `.exe` but **a URL**. This repo wraps REA's
CDP (Chrome DevTools Protocol) passive-observation capability into a standard,
reproducible Evidence workflow: open the page → understand how it works.

## Three modes, pick by what you have

| Mode | You have it | Best for | One-liner |
|---|---|---|---|
| Live browser observation | the URL, you can open a browser | which scripts loaded, what requests fired, what localStorage holds | `scripts/web-analyze.sh --cdp ... --deep` |
| Static JS bundle parse | an attached page | unpack chunks without running code, find route/endpoint candidates, vendor fingerprints, sourcemaps | `--bundle` |
| HAR/SAZ offline replay | a Chrome-exported HAR | batch review requests/responses, exposed payloads, source locations | `--har file.har` |

> REA **never launches, navigates, or closes your browser** — it passively attaches
> to a Chrome that already has the target page open. This is a deliberate safety
> boundary (not browser automation, not a sandbox).

## Prerequisite: start a debug-port browser (once)

```bash
google-chrome --remote-debugging-port=9222 \
  --user-data-dir=/tmp/rea-browser-profile \
  --password-store=basic "https://the-site-you-want-to-analyze"
```

- Chromium / Brave work the same; on macOS use the executable inside `.app/Contents/MacOS/`.
- Use a **dedicated profile** (`--user-data-dir`), not your daily browser.
- `--password-store=basic`: Linux desktop keyring can stall Chrome; this flag bypasses it.
- Bind the debug port to loopback only; never expose it.

Not sure your env is ready? Run:

```bash
scripts/web-analyze.sh --doctor
```

## One-liner observation

```bash
# basic (DOM structure, scripts/resources, console, WebSocket, storage keys)
scripts/web-analyze.sh --cdp http://127.0.0.1:9222

# deep + static bundle parse + screenshot, dump Evidence JSON
scripts/web-analyze.sh --cdp http://127.0.0.1:9222 \
  --origin https://example.com \
  --out /tmp/web-out --deep --bundle --screenshot

# HAR offline replay
scripts/web-analyze.sh --har ./capture.har
```

Outputs are standard Evidence JSON (`inspect.json` / `bundle.json` / `targets.json`),
each with provider, observation window, coverage (complete/filtered/truncated), and
limitations.

## What you actually get (inspect-web-page)

- DOM frames, accessibility tree (structure by default; text needs `--include-accessibility-text`)
- All script URLs and resources (incl. sourcemap metadata)
- Network requests within the window (method/status/MIME/size/URL — **not** response bodies, unless you opt into JSON body shapes)
- Console output (raw text needs `--include-console-text`), WebSocket frame shapes
- localStorage / Cookie / IndexedDB key names (**values always redacted**; fingerprints optional for cross-session diff)

Static bundle parse (`analyze-web-bundle`), without executing code:
chunk dependency edges, route/endpoint candidates, third-party vendor fingerprints,
WebMCP declarations.

## Deep deobfuscation (optional)

For heavy obfuscation (obfuscator.io, control-flow flattening, webpack bundles),
the industry-standard flow is to strip with [webcrack](https://github.com/j4k0xb/webcrack)
before manual reading:

```bash
npx webcrack page.bundle.js -o ./recovered/
```

If a sourcemap (`*.js.map`) is exposed, it can restore original source — look for `.map` first.

## Boundaries & compliance

- Only analyze sites you are **authorized** to analyze (your own product, authorized targets, public pages).
- Passive attach ≠ sandbox: the page still runs with your Chrome's privileges and makes real requests.
- Default window is 500ms; raise `--observation-ms` as needed. Historical network events before attach are never back-filled.
- CDP endpoint accepts only `http://127.0.0.1:PORT` (not localhost / paths / credentials).

## Local example

`examples/web-demo/` is a static page with an external script + fetch + localStorage key:

```bash
cd examples/web-demo && python3 -m http.server 8099 &
# open http://127.0.0.1:8099/ in your debug-port browser
../../scripts/web-analyze.sh --cdp http://127.0.0.1:9222 --out /tmp/web-out --bundle
```
