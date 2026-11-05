# 全量覆盖矩阵 / Coverage Matrix — rea-agents 6.8.0

> 175 个命令逐行列出：命令 | 领域 | 可测性 | 前置摘要。可测性图例见 [README](README.md#可测性图例--testability-legend)。
> 本文件由 `research/B_commands_176.json` 确定性生成，命令名与 `config/command-baseline/rea-6.8.0.txt` 一致。

| # | 命令 / Command | 领域 / Domain | 可测性 / Testability | 前置摘要 / Prerequisites (summary) |
|---|---|---|---|---|
| 1 | `address-to-file-offset` | ① 核心/Ghidra 原生 | 🔧 needs-tool | a native analysis provider: Ghidra (>=12.1) / Hopper / IDA / Kuna configured; a target bi… |
| 2 | `analyze` | ① 核心/Ghidra 原生 | 🔧 needs-tool | a native analysis provider: Ghidra (>=12.1) / Hopper / IDA / Kuna configured; a target bi… |
| 3 | `annotate-native-function` | ① 核心/Ghidra 原生 | 🔧 needs-tool | a native analysis provider: Ghidra (>=12.1) / Hopper / IDA / Kuna configured; a target bi… |
| 4 | `decompile` | ① 核心/Ghidra 原生 | 🔧 needs-tool | a native analysis provider: Ghidra (>=12.1) / Hopper / IDA / Kuna configured; a target bi… |
| 5 | `decompile-all` | ① 核心/Ghidra 原生 | 🔧 needs-tool | a native analysis provider: Ghidra (>=12.1) / Hopper / IDA / Kuna configured; a target bi… |
| 6 | `function` | ① 核心/Ghidra 原生 | 🔧 needs-tool | a native analysis provider: Ghidra (>=12.1) / Hopper / IDA / Kuna configured; a target bi… |
| 7 | `inspect` | ① 核心/Ghidra 原生 | 🔧 needs-tool | a native analysis provider: Ghidra (>=12.1) / Hopper / IDA / Kuna configured; a target bi… |
| 8 | `inspect-native-api` | ① 核心/Ghidra 原生 | 🔧 needs-tool | a native analysis provider: Ghidra (>=12.1) / Hopper / IDA / Kuna configured; a target bi… |
| 9 | `inspect-native-data-type` | ① 核心/Ghidra 原生 | 🔧 needs-tool | a native analysis provider: Ghidra (>=12.1) / Hopper / IDA / Kuna configured; a target bi… |
| 10 | `inspect-native-instruction` | ① 核心/Ghidra 原生 | 🔧 needs-tool | a native analysis provider: Ghidra (>=12.1) / Hopper / IDA / Kuna configured; a target bi… |
| 11 | `inspect-native-load-image` | ① 核心/Ghidra 原生 | 🔧 needs-tool | a native analysis provider: Ghidra (>=12.1) / Hopper / IDA / Kuna configured; a target bi… |
| 12 | `instructions` | ① 核心/Ghidra 原生 | 🔧 needs-tool | a native analysis provider: Ghidra (>=12.1) / Hopper / IDA / Kuna configured; a target bi… |
| 13 | `match-native-functions` | ① 核心/Ghidra 原生 | 🔧 needs-tool | a native analysis provider: Ghidra (>=12.1) / Hopper / IDA / Kuna configured; a target bi… |
| 14 | `read-bytes` | ① 核心/Ghidra 原生 | 🔧 needs-tool | a native analysis provider: Ghidra (>=12.1) / Hopper / IDA / Kuna configured; a target bi… |
| 15 | `resolve-native-call-targets` | ① 核心/Ghidra 原生 | 🔧 needs-tool | a native analysis provider: Ghidra (>=12.1) / Hopper / IDA / Kuna configured; a target bi… |
| 16 | `search` | ① 核心/Ghidra 原生 | 🔧 needs-tool | a native analysis provider: Ghidra (>=12.1) / Hopper / IDA / Kuna configured; a target bi… |
| 17 | `search-bytes` | ① 核心/Ghidra 原生 | 🔧 needs-tool | a native analysis provider: Ghidra (>=12.1) / Hopper / IDA / Kuna configured; a target bi… |
| 18 | `trace` | ① 核心/Ghidra 原生 | 🔧 needs-tool | a native analysis provider: Ghidra (>=12.1) / Hopper / IDA / Kuna configured; a target bi… |
| 19 | `trace-native-values` | ① 核心/Ghidra 原生 | 🔧 needs-tool | a native analysis provider: Ghidra (>=12.1) / Hopper / IDA / Kuna configured; a target bi… |
| 20 | `xrefs` | ① 核心/Ghidra 原生 | 🔧 needs-tool | a native analysis provider: Ghidra (>=12.1) / Hopper / IDA / Kuna configured; a target bi… |
| 21 | `compare-managed-members` | ② 离线二进制 | ✅ linux-testable | 无，内置纯解析 / none, built-in |
| 22 | `inspect-artifact` | ② 离线二进制 | ✅ linux-testable | 无，内置纯解析 / none, built-in |
| 23 | `inspect-binary-layout` | ② 离线二进制 | 🔧 needs-tool | caller-supplied pwntools on Linux x64 |
| 24 | `inspect-byte-entropy` | ② 离线二进制 | ✅ linux-testable | 无，内置纯解析 / none, built-in |
| 25 | `inspect-elf-notes` | ② 离线二进制 | ✅ linux-testable | 无，内置纯解析 / none, built-in |
| 26 | `inspect-go-binary` | ② 离线二进制 | ✅ linux-testable | 无，内置纯解析 / none, built-in |
| 27 | `inspect-macho` | ② 离线二进制 | ✅ linux-testable | a Mach-O / Swift / ObjC artifact (static parse; Hopper NOT required) |
| 28 | `inspect-managed-artifact` | ② 离线二进制 | ✅ linux-testable | 无，内置纯解析 / none, built-in |
| 29 | `inspect-managed-members` | ② 离线二进制 | ✅ linux-testable | 无，内置纯解析 / none, built-in |
| 30 | `inspect-managed-native-boundaries` | ② 离线二进制 | ✅ linux-testable | 无，内置纯解析 / none, built-in |
| 31 | `inspect-native-exports` | ② 离线二进制 | ✅ linux-testable | 无，内置纯解析 / none, built-in |
| 32 | `inspect-pe-certificates` | ② 离线二进制 | ✅ linux-testable | 无，内置纯解析 / none, built-in |
| 33 | `inspect-pe-imports` | ② 离线二进制 | ✅ linux-testable | 无，内置纯解析 / none, built-in |
| 34 | `inspect-pe-load-config` | ② 离线二进制 | ✅ linux-testable | 无，内置纯解析 / none, built-in |
| 35 | `inspect-pe-resources` | ② 离线二进制 | ✅ linux-testable | 无，内置纯解析 / none, built-in |
| 36 | `inspect-rust-binary` | ② 离线二进制 | ✅ linux-testable | 无，内置纯解析 / none, built-in |
| 37 | `inspect-signature` | ② 离线二进制 | ✅ linux-testable | a Mach-O / Swift / ObjC artifact (static parse; Hopper NOT required) |
| 38 | `inspect-with-objdump` | ② 离线二进制 | 🔧 needs-tool | GNU objdump (binutils) installed |
| 39 | `list-architectures` | ② 离线二进制 | ✅ linux-testable | 无，内置纯解析 / none, built-in |
| 40 | `list-objdump-architectures` | ② 离线二进制 | 🔧 needs-tool | GNU objdump (binutils) installed |
| 41 | `capture-native-ui-scenario` | ③ 动态调试 | 📱 needs-device | a live process / UI session |
| 42 | `capture-process` | ③ 动态调试 | 📱 needs-device | a live process / UI session |
| 43 | `compare-process-captures` | ③ 动态调试 | 📱 needs-device | a live process / UI session |
| 44 | `cutter-command` | ③ 动态调试 | 🔧 needs-tool | a live Cutter instance + REA Python plugin bridge |
| 45 | `debug-with-gdb` | ③ 动态调试 | 🔧 needs-tool | GDB installed; a live target inferior |
| 46 | `debug-with-rizin` | ③ 动态调试 | 🔧 needs-tool | Rizin (rizin) installed |
| 47 | `execute-rizin-command` | ③ 动态调试 | 🔧 needs-tool | Rizin (rizin) installed |
| 48 | `inspect-recorded-crash` | ③ 动态调试 | 📱 needs-device | a live process / UI session |
| 49 | `instrument-with-frida` | ③ 动态调试 | 📱 needs-device | frida / frida-tools installed; a live target process or device |
| 50 | `list-cutter-sessions` | ③ 动态调试 | 🔧 needs-tool | a live Cutter instance + REA Python plugin bridge |
| 51 | `list-frida-devices` | ③ 动态调试 | 📱 needs-device | frida / frida-tools installed; a live target process or device |
| 52 | `list-frida-processes` | ③ 动态调试 | 📱 needs-device | frida / frida-tools installed; a live target process or device |
| 53 | `observe-native-calls` | ③ 动态调试 | 🍎 needs-macos | macOS host; LLDB; a Mach-O target |
| 54 | `observe-native-ui` | ③ 动态调试 | 📱 needs-device | a live process / UI session |
| 55 | `trace-native-ui-action` | ③ 动态调试 | 📱 needs-device | a live process / UI session |
| 56 | `analyze-javascript-application` | ④ Web/JS/Electron | ✅ linux-testable | 无，内置纯解析 / none, built-in |
| 57 | `analyze-web-bundle` | ④ Web/JS/Electron | 📱 needs-device | a running Chromium/Electron/Node target exposing a CDP/Inspector endpoint (Playwright for… |
| 58 | `capture-browser-scenario` | ④ Web/JS/Electron | 📱 needs-device | a running Chromium/Electron/Node target exposing a CDP/Inspector endpoint (Playwright for… |
| 59 | `capture-electron-scenario` | ④ Web/JS/Electron | 📱 needs-device | a running Chromium/Electron/Node target exposing a CDP/Inspector endpoint (Playwright for… |
| 60 | `capture-web-screenshot` | ④ Web/JS/Electron | 📱 needs-device | a running Chromium/Electron/Node target exposing a CDP/Inspector endpoint (Playwright for… |
| 61 | `compare-application-versions` | ④ Web/JS/Electron | ✅ linux-testable | 无，内置纯解析 / none, built-in |
| 62 | `compare-javascript-export-shapes` | ④ Web/JS/Electron | ✅ linux-testable | 无，内置纯解析 / none, built-in |
| 63 | `compare-source-to-bundle` | ④ Web/JS/Electron | ✅ linux-testable | 无，内置纯解析 / none, built-in |
| 64 | `compare-web-captures` | ④ Web/JS/Electron | 📱 needs-device | a running Chromium/Electron/Node target exposing a CDP/Inspector endpoint (Playwright for… |
| 65 | `compare-web-screenshots` | ④ Web/JS/Electron | 📱 needs-device | a running Chromium/Electron/Node target exposing a CDP/Inspector endpoint (Playwright for… |
| 66 | `discover-webmcp-tools` | ④ Web/JS/Electron | 📱 needs-device | a running Chromium/Electron/Node target exposing a CDP/Inspector endpoint (Playwright for… |
| 67 | `export-web-scripts` | ④ Web/JS/Electron | ✅ linux-testable | 无，内置纯解析 / none, built-in |
| 68 | `inspect-electron-fuses` | ④ Web/JS/Electron | ✅ linux-testable | 无，内置纯解析 / none, built-in |
| 69 | `inspect-electron-page` | ④ Web/JS/Electron | 📱 needs-device | a running Chromium/Electron/Node target exposing a CDP/Inspector endpoint (Playwright for… |
| 70 | `inspect-web-event-listeners` | ④ Web/JS/Electron | 📱 needs-device | a running Chromium/Electron/Node target exposing a CDP/Inspector endpoint (Playwright for… |
| 71 | `inspect-web-network-capture` | ④ Web/JS/Electron | ✅ linux-testable | 无，内置纯解析 / none, built-in |
| 72 | `inspect-web-page` | ④ Web/JS/Electron | 📱 needs-device | a running Chromium/Electron/Node target exposing a CDP/Inspector endpoint (Playwright for… |
| 73 | `list-browser-targets` | ④ Web/JS/Electron | 📱 needs-device | a running Chromium/Electron/Node target exposing a CDP/Inspector endpoint (Playwright for… |
| 74 | `list-electron-targets` | ④ Web/JS/Electron | 📱 needs-device | a running Chromium/Electron/Node target exposing a CDP/Inspector endpoint (Playwright for… |
| 75 | `list-javascript-runtime-targets` | ④ Web/JS/Electron | 📱 needs-device | a running Chromium/Electron/Node target exposing a CDP/Inspector endpoint (Playwright for… |
| 76 | `observe-javascript-runtime` | ④ Web/JS/Electron | 📱 needs-device | a running Chromium/Electron/Node target exposing a CDP/Inspector endpoint (Playwright for… |
| 77 | `observe-web-execution` | ④ Web/JS/Electron | 📱 needs-device | a running Chromium/Electron/Node target exposing a CDP/Inspector endpoint (Playwright for… |
| 78 | `observe-web-session` | ④ Web/JS/Electron | 📱 needs-device | a running Chromium/Electron/Node target exposing a CDP/Inspector endpoint (Playwright for… |
| 79 | `reconcile-javascript-runtime` | ④ Web/JS/Electron | ✅ linux-testable | 无，内置纯解析 / none, built-in |
| 80 | `recover-javascript-sources` | ④ Web/JS/Electron | ✅ linux-testable | 无，内置纯解析 / none, built-in |
| 81 | `trace-javascript-semantics` | ④ Web/JS/Electron | ✅ linux-testable | 无，内置纯解析 / none, built-in |
| 82 | `trace-web-module-imports` | ④ Web/JS/Electron | 📱 needs-device | a running Chromium/Electron/Node target exposing a CDP/Inspector endpoint (Playwright for… |
| 83 | `trace-web-source-location` | ④ Web/JS/Electron | ✅ linux-testable | 无，内置纯解析 / none, built-in |
| 84 | `capture-adb-screen` | ⑤ Android/ADB | 📱 needs-device | adb (Android Debug Bridge) on PATH; an attached/connected Android device or emulator |
| 85 | `collect-adb-bugreport` | ⑤ Android/ADB | 📱 needs-device | adb (Android Debug Bridge) on PATH; an attached/connected Android device or emulator |
| 86 | `decode-android-resources` | ⑤ Android/ADB | ✅ linux-testable | 无，内置纯解析 / none, built-in |
| 87 | `inspect-adb-client` | ⑤ Android/ADB | 📱 needs-device | adb (Android Debug Bridge) on PATH; an attached/connected Android device or emulator |
| 88 | `inspect-adb-device` | ⑤ Android/ADB | 📱 needs-device | adb (Android Debug Bridge) on PATH; an attached/connected Android device or emulator |
| 89 | `inspect-adb-display` | ⑤ Android/ADB | 📱 needs-device | adb (Android Debug Bridge) on PATH; an attached/connected Android device or emulator |
| 90 | `inspect-adb-package` | ⑤ Android/ADB | 📱 needs-device | adb (Android Debug Bridge) on PATH; an attached/connected Android device or emulator |
| 91 | `inspect-adb-window` | ⑤ Android/ADB | 📱 needs-device | adb (Android Debug Bridge) on PATH; an attached/connected Android device or emulator |
| 92 | `inspect-android-class` | ⑤ Android/ADB | ✅ linux-testable | 无，内置纯解析 / none, built-in |
| 93 | `inspect-android-method` | ⑤ Android/ADB | ✅ linux-testable | 无，内置纯解析 / none, built-in |
| 94 | `inspect-android-package` | ⑤ Android/ADB | ✅ linux-testable | 无，内置纯解析 / none, built-in |
| 95 | `inspect-apk-signature` | ⑤ Android/ADB | ✅ linux-testable | 无，内置纯解析 / none, built-in |
| 96 | `inspect-apktool-client` | ⑤ Android/ADB | ✅ linux-testable | the corresponding launcher binary (adb/apktool/tshark) on PATH |
| 97 | `install-adb-package` | ⑤ Android/ADB | 📱 needs-device | adb (Android Debug Bridge) on PATH; an attached/connected Android device or emulator |
| 98 | `list-adb-devices` | ⑤ Android/ADB | 📱 needs-device | adb (Android Debug Bridge) on PATH; an attached/connected Android device or emulator |
| 99 | `list-adb-directory` | ⑤ Android/ADB | 📱 needs-device | adb (Android Debug Bridge) on PATH; an attached/connected Android device or emulator |
| 100 | `list-adb-features` | ⑤ Android/ADB | 📱 needs-device | adb (Android Debug Bridge) on PATH; an attached/connected Android device or emulator |
| 101 | `list-adb-packages` | ⑤ Android/ADB | 📱 needs-device | adb (Android Debug Bridge) on PATH; an attached/connected Android device or emulator |
| 102 | `list-adb-processes` | ⑤ Android/ADB | 📱 needs-device | adb (Android Debug Bridge) on PATH; an attached/connected Android device or emulator |
| 103 | `list-adb-services` | ⑤ Android/ADB | 📱 needs-device | adb (Android Debug Bridge) on PATH; an attached/connected Android device or emulator |
| 104 | `project-android-application-graph` | ⑤ Android/ADB | ✅ linux-testable | 无，内置纯解析 / none, built-in |
| 105 | `pull-adb-file` | ⑤ Android/ADB | 📱 needs-device | adb (Android Debug Bridge) on PATH; an attached/connected Android device or emulator |
| 106 | `pull-adb-package` | ⑤ Android/ADB | 📱 needs-device | adb (Android Debug Bridge) on PATH; an attached/connected Android device or emulator |
| 107 | `push-adb-file` | ⑤ Android/ADB | 📱 needs-device | adb (Android Debug Bridge) on PATH; an attached/connected Android device or emulator |
| 108 | `read-adb-logcat` | ⑤ Android/ADB | 📱 needs-device | adb (Android Debug Bridge) on PATH; an attached/connected Android device or emulator |
| 109 | `read-adb-setting` | ⑤ Android/ADB | 📱 needs-device | adb (Android Debug Bridge) on PATH; an attached/connected Android device or emulator |
| 110 | `resolve-adb-packages` | ⑤ Android/ADB | 📱 needs-device | adb (Android Debug Bridge) on PATH; an attached/connected Android device or emulator |
| 111 | `search-android-classes` | ⑤ Android/ADB | ✅ linux-testable | 无，内置纯解析 / none, built-in |
| 112 | `start-adb-activity` | ⑤ Android/ADB | 📱 needs-device | adb (Android Debug Bridge) on PATH; an attached/connected Android device or emulator |
| 113 | `start-adb-app` | ⑤ Android/ADB | 📱 needs-device | adb (Android Debug Bridge) on PATH; an attached/connected Android device or emulator |
| 114 | `stop-adb-app` | ⑤ Android/ADB | 📱 needs-device | adb (Android Debug Bridge) on PATH; an attached/connected Android device or emulator |
| 115 | `trace-android-references` | ⑤ Android/ADB | ✅ linux-testable | 无，内置纯解析 / none, built-in |
| 116 | `uninstall-adb-package` | ⑤ Android/ADB | 📱 needs-device | adb (Android Debug Bridge) on PATH; an attached/connected Android device or emulator |
| 117 | `decode-interface-builder` | ⑥ Apple | 🍎 needs-macos | Apple/macOS or iOS artifact (.app/.ipa/storyboard/plist) |
| 118 | `demangle-swift` | ⑥ Apple | ✅ linux-testable | a Mach-O / Swift / ObjC artifact (static parse; Hopper NOT required) |
| 119 | `inspect-apple-ips` | ⑥ Apple | 🍎 needs-macos | Apple/macOS or iOS artifact (.app/.ipa/storyboard/plist) |
| 120 | `inspect-asset-catalog` | ⑥ Apple | 🍎 needs-macos | Apple/macOS or iOS artifact (.app/.ipa/storyboard/plist) |
| 121 | `inspect-keyed-archive` | ⑥ Apple | 🍎 needs-macos | Apple/macOS or iOS artifact (.app/.ipa/storyboard/plist) |
| 122 | `inspect-native-dispatch-metadata` | ⑥ Apple | ✅ linux-testable | a Mach-O / Swift / ObjC artifact (static parse; Hopper NOT required) |
| 123 | `inspect-plist` | ⑥ Apple | 🍎 needs-macos | Apple/macOS or iOS artifact (.app/.ipa/storyboard/plist) |
| 124 | `project-apple-application-graph` | ⑥ Apple | 🍎 needs-macos | Apple/macOS or iOS artifact (.app/.ipa/storyboard/plist) |
| 125 | `trace-dylib-resolution` | ⑥ Apple | 🍎 needs-macos | Apple/macOS or iOS artifact (.app/.ipa/storyboard/plist) |
| 126 | `compare-wasm-interfaces` | ⑦ 多格式 | 🔧 needs-tool | WABT (wasm-objdump / wasm2wat) installed |
| 127 | `decode-signal-recording` | ⑦ 多格式 | 🔧 needs-tool | caller-supplied sigrok + sigrok-decoders; (for decode) a sigrok recording |
| 128 | `inspect-erlang-beam` | ⑦ 多格式 | ✅ linux-testable | 无，内置纯解析 / none, built-in |
| 129 | `inspect-evm-interface` | ⑦ 多格式 | ✅ linux-testable | 无，内置纯解析 / none, built-in |
| 130 | `inspect-gpu-code-objects` | ⑦ 多格式 | ✅ linux-testable | 无，内置纯解析 / none, built-in |
| 131 | `inspect-il2cpp-metadata` | ⑦ 多格式 | ✅ linux-testable | 无，内置纯解析 / none, built-in |
| 132 | `inspect-model-artifact` | ⑦ 多格式 | ✅ linux-testable | 无，内置纯解析 / none, built-in |
| 133 | `inspect-packet-capture` | ⑦ 多格式 | 🔧 needs-tool | tshark + capinfos (Wireshark) installed |
| 134 | `inspect-packet-fields` | ⑦ 多格式 | 🔧 needs-tool | tshark + capinfos (Wireshark) installed |
| 135 | `inspect-pcap-capture` | ⑦ 多格式 | 🔧 needs-tool | tshark + capinfos (Wireshark) installed |
| 136 | `inspect-pcap-client` | ⑦ 多格式 | ✅ linux-testable | the corresponding launcher binary (adb/apktool/tshark) on PATH |
| 137 | `inspect-python-pyc` | ⑦ 多格式 | ✅ linux-testable | 无，内置纯解析 / none, built-in |
| 138 | `inspect-signal-decoders` | ⑦ 多格式 | 🔧 needs-tool | caller-supplied sigrok + sigrok-decoders; (for decode) a sigrok recording |
| 139 | `inspect-sqlite-database` | ⑦ 多格式 | ✅ linux-testable | 无，内置纯解析 / none, built-in |
| 140 | `inspect-wasm-artifact` | ⑦ 多格式 | 🔧 needs-tool | WABT (wasm-objdump / wasm2wat) installed |
| 141 | `extract-artifact` | ⑧ 固件/嵌入式 | ✅ linux-testable | a firmware/embedded artifact (static parse); some extractors need installed unpack tools |
| 142 | `extract-firmware` | ⑧ 固件/嵌入式 | ✅ linux-testable | a firmware/embedded artifact (static parse); some extractors need installed unpack tools |
| 143 | `identify-flutter-build` | ⑧ 固件/嵌入式 | ✅ linux-testable | a firmware/embedded artifact (static parse); some extractors need installed unpack tools |
| 144 | `inspect-dart-aot` | ⑧ 固件/嵌入式 | ✅ linux-testable | a firmware/embedded artifact (static parse); some extractors need installed unpack tools |
| 145 | `inspect-desktop-application` | ⑧ 固件/嵌入式 | ✅ linux-testable | a firmware/embedded artifact (static parse); some extractors need installed unpack tools |
| 146 | `inspect-devicetree` | ⑧ 固件/嵌入式 | ✅ linux-testable | a firmware/embedded artifact (static parse); some extractors need installed unpack tools |
| 147 | `inspect-firmware-regions` | ⑧ 固件/嵌入式 | ✅ linux-testable | a firmware/embedded artifact (static parse); some extractors need installed unpack tools |
| 148 | `inspect-kernel-module` | ⑧ 固件/嵌入式 | ✅ linux-testable | a firmware/embedded artifact (static parse); some extractors need installed unpack tools |
| 149 | `project-harmony-application-graph` | ⑧ 固件/嵌入式 | ✅ linux-testable | a firmware/embedded artifact (static parse); some extractors need installed unpack tools |
| 150 | `build-reconstruction-obligation-ledger` | ⑨ Evidence/工程化 | ✅ linux-testable | 无，内置纯解析 / none, built-in |
| 151 | `compare` | ⑨ Evidence/工程化 | ✅ linux-testable | 无，内置纯解析 / none, built-in |
| 152 | `environment-build` | ⑨ Evidence/工程化 | ✅ linux-testable | 无，内置纯解析 / none, built-in |
| 153 | `environment-compare` | ⑨ Evidence/工程化 | ✅ linux-testable | 无，内置纯解析 / none, built-in |
| 154 | `environment-export` | ⑨ Evidence/工程化 | ✅ linux-testable | 无，内置纯解析 / none, built-in |
| 155 | `environment-serve` | ⑨ Evidence/工程化 | ✅ linux-testable | 无，内置纯解析 / none, built-in |
| 156 | `evaluate-reconstruction-coverage` | ⑨ Evidence/工程化 | ✅ linux-testable | 无，内置纯解析 / none, built-in |
| 157 | `evidence-export` | ⑨ Evidence/工程化 | ✅ linux-testable | 无，内置纯解析 / none, built-in |
| 158 | `evidence-import` | ⑨ Evidence/工程化 | ✅ linux-testable | 无，内置纯解析 / none, built-in |
| 159 | `import-managed-reconstruction` | ⑨ Evidence/工程化 | ✅ linux-testable | 无，内置纯解析 / none, built-in |
| 160 | `import-reference-source` | ⑨ Evidence/工程化 | ✅ linux-testable | 无，内置纯解析 / none, built-in |
| 161 | `inspect-analysis-view` | ⑨ Evidence/工程化 | ✅ linux-testable | 无，内置纯解析 / none, built-in |
| 162 | `inspect-evidence-bundle` | ⑨ Evidence/工程化 | ✅ linux-testable | 无，内置纯解析 / none, built-in |
| 163 | `project-managed-application-graph` | ⑨ Evidence/工程化 | ✅ linux-testable | 无，内置纯解析 / none, built-in |
| 164 | `trace-application-feature` | ⑨ Evidence/工程化 | ✅ linux-testable | 无，内置纯解析 / none, built-in |
| 165 | `verify-managed-native-boundaries` | ⑨ Evidence/工程化 | ✅ linux-testable | 无，内置纯解析 / none, built-in |
| 166 | `capabilities` | ⑩ JEB/平台 | ✅ linux-testable | 无，内置纯解析 / none, built-in |
| 167 | `decompile-jeb-item` | ⑩ JEB/平台 | 💼 needs-jeb | JEB (commercial reverse-engineering suite) running / licensed |
| 168 | `doctor` | ⑩ JEB/平台 | ✅ linux-testable | 无，内置纯解析 / none, built-in |
| 169 | `inspect-jeb-client` | ⑩ JEB/平台 | 💼 needs-jeb | JEB (commercial reverse-engineering suite) running / licensed |
| 170 | `list-jeb-units` | ⑩ JEB/平台 | 💼 needs-jeb | JEB (commercial reverse-engineering suite) running / licensed |
| 171 | `open-jeb-project` | ⑩ JEB/平台 | 💼 needs-jeb | JEB (commercial reverse-engineering suite) running / licensed |
| 172 | `providers` | ⑩ JEB/平台 | ✅ linux-testable | 无，内置纯解析 / none, built-in |
| 173 | `setup` | ⑩ JEB/平台 | ✅ linux-testable | 无，内置纯解析 / none, built-in |
| 174 | `uninstall` | ⑩ JEB/平台 | ✅ linux-testable | 无，内置纯解析 / none, built-in |
| 175 | `update` | ⑩ JEB/平台 | ✅ linux-testable | 无，内置纯解析 / none, built-in |

**合计 / Total：175 个命令。**
