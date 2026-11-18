# 全量覆盖矩阵 / Coverage Matrix — rea-agents 6.9.0

> 196 个命令逐行列出：命令 | 领域 | 可测性 | 前置摘要。可测性图例见 [README](README.md#可测性图例--testability-legend)。
> 命令名与 `config/command-baseline/rea-6.9.0.txt` 一致；另有 `completions`、`mcp` 两个集成入口单列，不计入本表。

| # | 命令 / Command | 领域 / Domain | 可测性 / Testability | 前置摘要 / Prerequisites (summary) |
|---|---|---|---|---|
| 1 | `address-to-file-offset` | ① 核心/Ghidra 原生 | 🔧 needs-tool | a native analysis provider: Ghidra (>=12.1) / Hopper / IDA / Kuna configured; a target bi… |
| 2 | `analyze` | ① 核心/Ghidra 原生 | 🔧 needs-tool | a native analysis provider: Ghidra (>=12.1) / Hopper / IDA / Kuna configured; a target bi… |
| 3 | `analyze-javascript-application` | ④ Web/JS/Electron | ✅ linux-testable | 无，内置纯解析 / none, built-in |
| 4 | `analyze-web-bundle` | ④ Web/JS/Electron | 📱 needs-device | a running Chromium/Electron/Node target exposing a CDP/Inspector endpoint (Playwright for… |
| 5 | `annotate-native-function` | ① 核心/Ghidra 原生 | 🔧 needs-tool | a native analysis provider: Ghidra (>=12.1) / Hopper / IDA / Kuna configured; a target bi… |
| 6 | `audit-release-exposure` | ⑨ Evidence/工程化 | ✅ linux-testable | static analysis of a shipped artifact and sibling debug companions (.pdb/.dSYM/.debug/.map) |
| 7 | `build-reconstruction-obligation-ledger` | ⑨ Evidence/工程化 | ✅ linux-testable | 无，内置纯解析 / none, built-in |
| 8 | `capabilities` | ⑩ JEB/平台 | ✅ linux-testable | 无，内置纯解析 / none, built-in |
| 9 | `capture-adb-screen` | ⑤ Android/ADB | 📱 needs-device | adb (Android Debug Bridge) on PATH; an attached/connected Android device or emulator |
| 10 | `capture-browser-scenario` | ④ Web/JS/Electron | 📱 needs-device | a running Chromium/Electron/Node target exposing a CDP/Inspector endpoint (Playwright for… |
| 11 | `capture-desktop-application` | ③ 动态调试 | 📱 needs-device | Linux desktop session; target app launched and captured at stdin checkpoints |
| 12 | `capture-electron-scenario` | ④ Web/JS/Electron | 📱 needs-device | a running Chromium/Electron/Node target exposing a CDP/Inspector endpoint (Playwright for… |
| 13 | `capture-native-ui-scenario` | ③ 动态调试 | 📱 needs-device | a live process / UI session |
| 14 | `capture-process` | ③ 动态调试 | 📱 needs-device | a live process / UI session |
| 15 | `capture-web-screenshot` | ④ Web/JS/Electron | 📱 needs-device | a running Chromium/Electron/Node target exposing a CDP/Inspector endpoint (Playwright for… |
| 16 | `collect-adb-bugreport` | ⑤ Android/ADB | 📱 needs-device | adb (Android Debug Bridge) on PATH; an attached/connected Android device or emulator |
| 17 | `compare` | ⑨ Evidence/工程化 | ✅ linux-testable | 无，内置纯解析 / none, built-in |
| 18 | `compare-application-versions` | ④ Web/JS/Electron | ✅ linux-testable | 无，内置纯解析 / none, built-in |
| 19 | `compare-artifacts` | ⑨ Evidence/工程化 | ✅ linux-testable | compare two Evidence/artifact inventories, incl. FIT/uImage firmware components; offline |
| 20 | `compare-javascript-export-shapes` | ④ Web/JS/Electron | ✅ linux-testable | 无，内置纯解析 / none, built-in |
| 21 | `compare-managed-members` | ② 离线二进制 | ✅ linux-testable | 无，内置纯解析 / none, built-in |
| 22 | `compare-process-captures` | ③ 动态调试 | 📱 needs-device | a live process / UI session |
| 23 | `compare-source-to-bundle` | ④ Web/JS/Electron | ✅ linux-testable | 无，内置纯解析 / none, built-in |
| 24 | `compare-static-and-observed-endpoints` | ④ Web/JS/Electron | ✅ linux-testable | offline compare of static JS endpoints and HAR Evidence JSON; no browser |
| 25 | `compare-wasm-interfaces` | ⑦ 多格式 | 🔧 needs-tool | WABT (wasm-objdump / wasm2wat) installed |
| 26 | `compare-web-captures` | ④ Web/JS/Electron | 📱 needs-device | a running Chromium/Electron/Node target exposing a CDP/Inspector endpoint (Playwright for… |
| 27 | `compare-web-screenshots` | ④ Web/JS/Electron | 📱 needs-device | a running Chromium/Electron/Node target exposing a CDP/Inspector endpoint (Playwright for… |
| 28 | `cutter-command` | ③ 动态调试 | 🔧 needs-tool | a live Cutter instance + REA Python plugin bridge |
| 29 | `debug-with-gdb` | ③ 动态调试 | 🔧 needs-tool | GDB installed; a live target inferior |
| 30 | `debug-with-rizin` | ③ 动态调试 | 🔧 needs-tool | Rizin (rizin) installed |
| 31 | `decode-android-resources` | ⑤ Android/ADB | ✅ linux-testable | 无，内置纯解析 / none, built-in |
| 32 | `decode-interface-builder` | ⑥ Apple | 🍎 needs-macos | Apple/macOS or iOS artifact (.app/.ipa/storyboard/plist) |
| 33 | `decode-signal-recording` | ⑦ 多格式 | 🔧 needs-tool | caller-supplied sigrok + sigrok-decoders; (for decode) a sigrok recording |
| 34 | `decompile` | ① 核心/Ghidra 原生 | 🔧 needs-tool | a native analysis provider: Ghidra (>=12.1) / Hopper / IDA / Kuna configured; a target bi… |
| 35 | `decompile-all` | ① 核心/Ghidra 原生 | 🔧 needs-tool | a native analysis provider: Ghidra (>=12.1) / Hopper / IDA / Kuna configured; a target bi… |
| 36 | `decompile-jeb-item` | ⑩ JEB/平台 | 💼 needs-jeb | JEB (commercial reverse-engineering suite) running / licensed |
| 37 | `demangle-swift` | ⑥ Apple | ✅ linux-testable | a Mach-O / Swift / ObjC artifact (static parse; Hopper NOT required) |
| 38 | `describe-desktop-application-task` | ③ 动态调试 | 📱 needs-device | a desktop application capture folder produced by capture-desktop-application |
| 39 | `discover-webmcp-tools` | ④ Web/JS/Electron | 📱 needs-device | a running Chromium/Electron/Node target exposing a CDP/Inspector endpoint (Playwright for… |
| 40 | `doctor` | ⑩ JEB/平台 | ✅ linux-testable | 无，内置纯解析 / none, built-in |
| 41 | `environment-build` | ⑨ Evidence/工程化 | ✅ linux-testable | 无，内置纯解析 / none, built-in |
| 42 | `environment-compare` | ⑨ Evidence/工程化 | ✅ linux-testable | 无，内置纯解析 / none, built-in |
| 43 | `environment-export` | ⑨ Evidence/工程化 | ✅ linux-testable | 无，内置纯解析 / none, built-in |
| 44 | `environment-serve` | ⑨ Evidence/工程化 | ✅ linux-testable | 无，内置纯解析 / none, built-in |
| 45 | `evaluate-reconstruction-coverage` | ⑨ Evidence/工程化 | ✅ linux-testable | 无，内置纯解析 / none, built-in |
| 46 | `evidence-export` | ⑨ Evidence/工程化 | ✅ linux-testable | 无，内置纯解析 / none, built-in |
| 47 | `evidence-import` | ⑨ Evidence/工程化 | ✅ linux-testable | 无，内置纯解析 / none, built-in |
| 48 | `execute-rizin-command` | ③ 动态调试 | 🔧 needs-tool | Rizin (rizin) installed |
| 49 | `export-desktop-application` | ③ 动态调试 | 📱 needs-device | a desktop application capture folder; exports an agentenv computer app bundle |
| 50 | `export-web-scripts` | ④ Web/JS/Electron | ✅ linux-testable | 无，内置纯解析 / none, built-in |
| 51 | `extract-artifact` | ⑧ 固件/嵌入式 | ✅ linux-testable | a firmware/embedded artifact (static parse); some extractors need installed unpack tools |
| 52 | `extract-firmware` | ⑧ 固件/嵌入式 | ✅ linux-testable | a firmware/embedded artifact (static parse); some extractors need installed unpack tools |
| 53 | `function` | ① 核心/Ghidra 原生 | 🔧 needs-tool | a native analysis provider: Ghidra (>=12.1) / Hopper / IDA / Kuna configured; a target bi… |
| 54 | `guidance` | ⑩ JEB/平台 | ✅ linux-testable | none, built-in; searches/installed REA workflow guidance |
| 55 | `guided-workflows` | ⑩ JEB/平台 | ✅ linux-testable | none, built-in; lists or renders REA guided workflows |
| 56 | `identify-flutter-build` | ⑧ 固件/嵌入式 | ✅ linux-testable | a firmware/embedded artifact (static parse); some extractors need installed unpack tools |
| 57 | `import-managed-reconstruction` | ⑨ Evidence/工程化 | ✅ linux-testable | 无，内置纯解析 / none, built-in |
| 58 | `import-reference-source` | ⑨ Evidence/工程化 | ✅ linux-testable | 无，内置纯解析 / none, built-in |
| 59 | `inspect` | ① 核心/Ghidra 原生 | 🔧 needs-tool | a native analysis provider: Ghidra (>=12.1) / Hopper / IDA / Kuna configured; a target bi… |
| 60 | `inspect-adb-client` | ⑤ Android/ADB | 📱 needs-device | adb (Android Debug Bridge) on PATH; an attached/connected Android device or emulator |
| 61 | `inspect-adb-device` | ⑤ Android/ADB | 📱 needs-device | adb (Android Debug Bridge) on PATH; an attached/connected Android device or emulator |
| 62 | `inspect-adb-display` | ⑤ Android/ADB | 📱 needs-device | adb (Android Debug Bridge) on PATH; an attached/connected Android device or emulator |
| 63 | `inspect-adb-package` | ⑤ Android/ADB | 📱 needs-device | adb (Android Debug Bridge) on PATH; an attached/connected Android device or emulator |
| 64 | `inspect-adb-window` | ⑤ Android/ADB | 📱 needs-device | adb (Android Debug Bridge) on PATH; an attached/connected Android device or emulator |
| 65 | `inspect-analysis-view` | ⑨ Evidence/工程化 | ✅ linux-testable | 无，内置纯解析 / none, built-in |
| 66 | `inspect-android-class` | ⑤ Android/ADB | ✅ linux-testable | 无，内置纯解析 / none, built-in |
| 67 | `inspect-android-jni-bindings` | ⑤ Android/ADB | ✅ linux-testable | offline static parse linking DEX native declarations to JNI candidates; no APK execution |
| 68 | `inspect-android-method` | ⑤ Android/ADB | ✅ linux-testable | 无，内置纯解析 / none, built-in |
| 69 | `inspect-android-package` | ⑤ Android/ADB | ✅ linux-testable | 无，内置纯解析 / none, built-in |
| 70 | `inspect-api-contract` | ④ Web/JS/Electron | ✅ linux-testable | offline parse of local OpenAPI JSON or GraphQL SDL declarations; built-in |
| 71 | `inspect-apk-signature` | ⑤ Android/ADB | ✅ linux-testable | 无，内置纯解析 / none, built-in |
| 72 | `inspect-apktool-client` | ⑤ Android/ADB | ✅ linux-testable | the corresponding launcher binary (adb/apktool/tshark) on PATH |
| 73 | `inspect-apple-ips` | ⑥ Apple | 🍎 needs-macos | Apple/macOS or iOS artifact (.app/.ipa/storyboard/plist) |
| 74 | `inspect-artifact` | ② 离线二进制 | ✅ linux-testable | 无，内置纯解析 / none, built-in |
| 75 | `inspect-asset-catalog` | ⑥ Apple | 🍎 needs-macos | Apple/macOS or iOS artifact (.app/.ipa/storyboard/plist) |
| 76 | `inspect-binary-hardening` | ② 离线二进制 | ✅ linux-testable | offline static parse of ELF/PE/Mach-O hardening; no execution; built-in |
| 77 | `inspect-binary-layout` | ② 离线二进制 | 🔧 needs-tool | caller-supplied pwntools on Linux x64 |
| 78 | `inspect-byte-entropy` | ② 离线二进制 | ✅ linux-testable | 无，内置纯解析 / none, built-in |
| 79 | `inspect-dart-aot` | ⑧ 固件/嵌入式 | ✅ linux-testable | a firmware/embedded artifact (static parse); some extractors need installed unpack tools |
| 80 | `inspect-desktop-application` | ⑧ 固件/嵌入式 | ✅ linux-testable | a firmware/embedded artifact (static parse); some extractors need installed unpack tools |
| 81 | `inspect-desktop-application-state` | ③ 动态调试 | 📱 needs-device | a desktop application capture folder; reads roles/typed views/change kinds |
| 82 | `inspect-devicetree` | ⑧ 固件/嵌入式 | ✅ linux-testable | a firmware/embedded artifact (static parse); some extractors need installed unpack tools |
| 83 | `inspect-electron-fuses` | ④ Web/JS/Electron | ✅ linux-testable | 无，内置纯解析 / none, built-in |
| 84 | `inspect-electron-page` | ④ Web/JS/Electron | 📱 needs-device | a running Chromium/Electron/Node target exposing a CDP/Inspector endpoint (Playwright for… |
| 85 | `inspect-elf-notes` | ② 离线二进制 | ✅ linux-testable | 无，内置纯解析 / none, built-in |
| 86 | `inspect-elf-unwind-ranges` | ② 离线二进制 | ✅ linux-testable | offline static parse of ELF unwind ranges; no execution; built-in |
| 87 | `inspect-erlang-beam` | ⑦ 多格式 | ✅ linux-testable | 无，内置纯解析 / none, built-in |
| 88 | `inspect-evidence-bundle` | ⑨ Evidence/工程化 | ✅ linux-testable | 无，内置纯解析 / none, built-in |
| 89 | `inspect-evm-interface` | ⑦ 多格式 | ✅ linux-testable | 无，内置纯解析 / none, built-in |
| 90 | `inspect-firmware-regions` | ⑧ 固件/嵌入式 | ✅ linux-testable | a firmware/embedded artifact (static parse); some extractors need installed unpack tools |
| 91 | `inspect-go-binary` | ② 离线二进制 | ✅ linux-testable | 无，内置纯解析 / none, built-in |
| 92 | `inspect-gpu-code-objects` | ⑦ 多格式 | ✅ linux-testable | 无，内置纯解析 / none, built-in |
| 93 | `inspect-il2cpp-metadata` | ⑦ 多格式 | ✅ linux-testable | 无，内置纯解析 / none, built-in |
| 94 | `inspect-jeb-client` | ⑩ JEB/平台 | 💼 needs-jeb | JEB (commercial reverse-engineering suite) running / licensed |
| 95 | `inspect-kernel-build-config` | ⑧ 固件/嵌入式 | ✅ linux-testable | offline parse of a Linux kernel image banner and embedded build config; no execution |
| 96 | `inspect-kernel-module` | ⑧ 固件/嵌入式 | ✅ linux-testable | a firmware/embedded artifact (static parse); some extractors need installed unpack tools |
| 97 | `inspect-keyed-archive` | ⑥ Apple | 🍎 needs-macos | Apple/macOS or iOS artifact (.app/.ipa/storyboard/plist) |
| 98 | `inspect-macho` | ② 离线二进制 | ✅ linux-testable | a Mach-O / Swift / ObjC artifact (static parse; Hopper NOT required) |
| 99 | `inspect-managed-artifact` | ② 离线二进制 | ✅ linux-testable | 无，内置纯解析 / none, built-in |
| 100 | `inspect-managed-members` | ② 离线二进制 | ✅ linux-testable | 无，内置纯解析 / none, built-in |
| 101 | `inspect-managed-native-boundaries` | ② 离线二进制 | ✅ linux-testable | 无，内置纯解析 / none, built-in |
| 102 | `inspect-model-artifact` | ⑦ 多格式 | ✅ linux-testable | 无，内置纯解析 / none, built-in |
| 103 | `inspect-native-api` | ① 核心/Ghidra 原生 | 🔧 needs-tool | a native analysis provider: Ghidra (>=12.1) / Hopper / IDA / Kuna configured; a target bi… |
| 104 | `inspect-native-data-type` | ① 核心/Ghidra 原生 | 🔧 needs-tool | a native analysis provider: Ghidra (>=12.1) / Hopper / IDA / Kuna configured; a target bi… |
| 105 | `inspect-native-dispatch-metadata` | ⑥ Apple | ✅ linux-testable | a Mach-O / Swift / ObjC artifact (static parse; Hopper NOT required) |
| 106 | `inspect-native-exports` | ② 离线二进制 | ✅ linux-testable | 无，内置纯解析 / none, built-in |
| 107 | `inspect-native-initializers` | ② 离线二进制 | ✅ linux-testable | offline static parse of ELF/Mach-O initializer/finalizer functions; no execution |
| 108 | `inspect-native-instruction` | ① 核心/Ghidra 原生 | 🔧 needs-tool | a native analysis provider: Ghidra (>=12.1) / Hopper / IDA / Kuna configured; a target bi… |
| 109 | `inspect-native-load-image` | ① 核心/Ghidra 原生 | 🔧 needs-tool | a native analysis provider: Ghidra (>=12.1) / Hopper / IDA / Kuna configured; a target bi… |
| 110 | `inspect-ntfs-journal` | ⑦ 多格式 | ✅ linux-testable | offline parse of paired NTFS MFT and USN journal acquisitions; built-in |
| 111 | `inspect-packet-capture` | ⑦ 多格式 | 🔧 needs-tool | tshark + capinfos (Wireshark) installed |
| 112 | `inspect-packet-fields` | ⑦ 多格式 | 🔧 needs-tool | tshark + capinfos (Wireshark) installed |
| 113 | `inspect-pcap-capture` | ⑦ 多格式 | 🔧 needs-tool | tshark + capinfos (Wireshark) installed |
| 114 | `inspect-pcap-client` | ⑦ 多格式 | ✅ linux-testable | the corresponding launcher binary (adb/apktool/tshark) on PATH |
| 115 | `inspect-pe-certificates` | ② 离线二进制 | ✅ linux-testable | 无，内置纯解析 / none, built-in |
| 116 | `inspect-pe-imports` | ② 离线二进制 | ✅ linux-testable | 无，内置纯解析 / none, built-in |
| 117 | `inspect-pe-load-config` | ② 离线二进制 | ✅ linux-testable | 无，内置纯解析 / none, built-in |
| 118 | `inspect-pe-resources` | ② 离线二进制 | ✅ linux-testable | 无，内置纯解析 / none, built-in |
| 119 | `inspect-playwright-trace` | ④ Web/JS/Electron | ✅ linux-testable | offline inventory of a saved Playwright v10 trace ZIP; no browser launch |
| 120 | `inspect-plist` | ⑥ Apple | 🍎 needs-macos | Apple/macOS or iOS artifact (.app/.ipa/storyboard/plist) |
| 121 | `inspect-python-pyc` | ⑦ 多格式 | ✅ linux-testable | 无，内置纯解析 / none, built-in |
| 122 | `inspect-recorded-crash` | ③ 动态调试 | 📱 needs-device | a live process / UI session |
| 123 | `inspect-rust-binary` | ② 离线二进制 | ✅ linux-testable | 无，内置纯解析 / none, built-in |
| 124 | `inspect-signal-decoders` | ⑦ 多格式 | 🔧 needs-tool | caller-supplied sigrok + sigrok-decoders; (for decode) a sigrok recording |
| 125 | `inspect-signature` | ② 离线二进制 | ✅ linux-testable | a Mach-O / Swift / ObjC artifact (static parse; Hopper NOT required) |
| 126 | `inspect-sqlite-database` | ⑦ 多格式 | ✅ linux-testable | 无，内置纯解析 / none, built-in |
| 127 | `inspect-v8-code-cache` | ④ Web/JS/Electron | ✅ linux-testable | offline parse of a V8 code-cache header and byte patterns; no execution |
| 128 | `inspect-wasm-artifact` | ⑦ 多格式 | 🔧 needs-tool | WABT (wasm-objdump / wasm2wat) installed |
| 129 | `inspect-web-event-listeners` | ④ Web/JS/Electron | 📱 needs-device | a running Chromium/Electron/Node target exposing a CDP/Inspector endpoint (Playwright for… |
| 130 | `inspect-web-network-capture` | ④ Web/JS/Electron | ✅ linux-testable | 无，内置纯解析 / none, built-in |
| 131 | `inspect-web-page` | ④ Web/JS/Electron | 📱 needs-device | a running Chromium/Electron/Node target exposing a CDP/Inspector endpoint (Playwright for… |
| 132 | `inspect-windows-shortcut` | ② 离线二进制 | ✅ linux-testable | offline parse of a Windows .lnk shell link; target not resolved or executed |
| 133 | `inspect-with-objdump` | ② 离线二进制 | 🔧 needs-tool | GNU objdump (binutils) installed |
| 134 | `install-adb-package` | ⑤ Android/ADB | 📱 needs-device | adb (Android Debug Bridge) on PATH; an attached/connected Android device or emulator |
| 135 | `instructions` | ① 核心/Ghidra 原生 | 🔧 needs-tool | a native analysis provider: Ghidra (>=12.1) / Hopper / IDA / Kuna configured; a target bi… |
| 136 | `instrument-with-frida` | ③ 动态调试 | 📱 needs-device | frida / frida-tools installed; a live target process or device |
| 137 | `list-adb-devices` | ⑤ Android/ADB | 📱 needs-device | adb (Android Debug Bridge) on PATH; an attached/connected Android device or emulator |
| 138 | `list-adb-directory` | ⑤ Android/ADB | 📱 needs-device | adb (Android Debug Bridge) on PATH; an attached/connected Android device or emulator |
| 139 | `list-adb-features` | ⑤ Android/ADB | 📱 needs-device | adb (Android Debug Bridge) on PATH; an attached/connected Android device or emulator |
| 140 | `list-adb-packages` | ⑤ Android/ADB | 📱 needs-device | adb (Android Debug Bridge) on PATH; an attached/connected Android device or emulator |
| 141 | `list-adb-processes` | ⑤ Android/ADB | 📱 needs-device | adb (Android Debug Bridge) on PATH; an attached/connected Android device or emulator |
| 142 | `list-adb-services` | ⑤ Android/ADB | 📱 needs-device | adb (Android Debug Bridge) on PATH; an attached/connected Android device or emulator |
| 143 | `list-architectures` | ② 离线二进制 | ✅ linux-testable | 无，内置纯解析 / none, built-in |
| 144 | `list-browser-targets` | ④ Web/JS/Electron | 📱 needs-device | a running Chromium/Electron/Node target exposing a CDP/Inspector endpoint (Playwright for… |
| 145 | `list-cutter-sessions` | ③ 动态调试 | 🔧 needs-tool | a live Cutter instance + REA Python plugin bridge |
| 146 | `list-electron-targets` | ④ Web/JS/Electron | 📱 needs-device | a running Chromium/Electron/Node target exposing a CDP/Inspector endpoint (Playwright for… |
| 147 | `list-frida-devices` | ③ 动态调试 | 📱 needs-device | frida / frida-tools installed; a live target process or device |
| 148 | `list-frida-processes` | ③ 动态调试 | 📱 needs-device | frida / frida-tools installed; a live target process or device |
| 149 | `list-javascript-runtime-targets` | ④ Web/JS/Electron | 📱 needs-device | a running Chromium/Electron/Node target exposing a CDP/Inspector endpoint (Playwright for… |
| 150 | `list-jeb-units` | ⑩ JEB/平台 | 💼 needs-jeb | JEB (commercial reverse-engineering suite) running / licensed |
| 151 | `list-objdump-architectures` | ② 离线二进制 | 🔧 needs-tool | GNU objdump (binutils) installed |
| 152 | `match-native-functions` | ① 核心/Ghidra 原生 | 🔧 needs-tool | a native analysis provider: Ghidra (>=12.1) / Hopper / IDA / Kuna configured; a target bi… |
| 153 | `observe-javascript-runtime` | ④ Web/JS/Electron | 📱 needs-device | a running Chromium/Electron/Node target exposing a CDP/Inspector endpoint (Playwright for… |
| 154 | `observe-native-calls` | ③ 动态调试 | 🍎 needs-macos | macOS host; LLDB; a Mach-O target |
| 155 | `observe-native-ui` | ③ 动态调试 | 📱 needs-device | a live process / UI session |
| 156 | `observe-web-execution` | ④ Web/JS/Electron | 📱 needs-device | a running Chromium/Electron/Node target exposing a CDP/Inspector endpoint (Playwright for… |
| 157 | `observe-web-session` | ④ Web/JS/Electron | 📱 needs-device | a running Chromium/Electron/Node target exposing a CDP/Inspector endpoint (Playwright for… |
| 158 | `open-jeb-project` | ⑩ JEB/平台 | 💼 needs-jeb | JEB (commercial reverse-engineering suite) running / licensed |
| 159 | `procedure-references` | ① 核心/Ghidra 原生 | 🔧 needs-tool | a native analysis provider: Ghidra (>=12.1) / Hopper / IDA / Kuna configured; a loaded procedure |
| 160 | `project-android-application-graph` | ⑤ Android/ADB | ✅ linux-testable | 无，内置纯解析 / none, built-in |
| 161 | `project-apple-application-graph` | ⑥ Apple | 🍎 needs-macos | Apple/macOS or iOS artifact (.app/.ipa/storyboard/plist) |
| 162 | `project-harmony-application-graph` | ⑧ 固件/嵌入式 | ✅ linux-testable | a firmware/embedded artifact (static parse); some extractors need installed unpack tools |
| 163 | `project-managed-application-graph` | ⑨ Evidence/工程化 | ✅ linux-testable | 无，内置纯解析 / none, built-in |
| 164 | `providers` | ⑩ JEB/平台 | ✅ linux-testable | 无，内置纯解析 / none, built-in |
| 165 | `pull-adb-file` | ⑤ Android/ADB | 📱 needs-device | adb (Android Debug Bridge) on PATH; an attached/connected Android device or emulator |
| 166 | `pull-adb-package` | ⑤ Android/ADB | 📱 needs-device | adb (Android Debug Bridge) on PATH; an attached/connected Android device or emulator |
| 167 | `push-adb-file` | ⑤ Android/ADB | 📱 needs-device | adb (Android Debug Bridge) on PATH; an attached/connected Android device or emulator |
| 168 | `read-adb-logcat` | ⑤ Android/ADB | 📱 needs-device | adb (Android Debug Bridge) on PATH; an attached/connected Android device or emulator |
| 169 | `read-adb-setting` | ⑤ Android/ADB | 📱 needs-device | adb (Android Debug Bridge) on PATH; an attached/connected Android device or emulator |
| 170 | `read-bytes` | ① 核心/Ghidra 原生 | 🔧 needs-tool | a native analysis provider: Ghidra (>=12.1) / Hopper / IDA / Kuna configured; a target bi… |
| 171 | `reconcile-javascript-runtime` | ④ Web/JS/Electron | ✅ linux-testable | 无，内置纯解析 / none, built-in |
| 172 | `recover-javascript-sources` | ④ Web/JS/Electron | ✅ linux-testable | 无，内置纯解析 / none, built-in |
| 173 | `resolve-adb-packages` | ⑤ Android/ADB | 📱 needs-device | adb (Android Debug Bridge) on PATH; an attached/connected Android device or emulator |
| 174 | `resolve-native-call-targets` | ① 核心/Ghidra 原生 | 🔧 needs-tool | a native analysis provider: Ghidra (>=12.1) / Hopper / IDA / Kuna configured; a target bi… |
| 175 | `search` | ① 核心/Ghidra 原生 | 🔧 needs-tool | a native analysis provider: Ghidra (>=12.1) / Hopper / IDA / Kuna configured; a target bi… |
| 176 | `search-android-classes` | ⑤ Android/ADB | ✅ linux-testable | 无，内置纯解析 / none, built-in |
| 177 | `search-bytes` | ① 核心/Ghidra 原生 | 🔧 needs-tool | a native analysis provider: Ghidra (>=12.1) / Hopper / IDA / Kuna configured; a target bi… |
| 178 | `setup` | ⑩ JEB/平台 | ✅ linux-testable | 无，内置纯解析 / none, built-in |
| 179 | `start-adb-activity` | ⑤ Android/ADB | 📱 needs-device | adb (Android Debug Bridge) on PATH; an attached/connected Android device or emulator |
| 180 | `start-adb-app` | ⑤ Android/ADB | 📱 needs-device | adb (Android Debug Bridge) on PATH; an attached/connected Android device or emulator |
| 181 | `stop-adb-app` | ⑤ Android/ADB | 📱 needs-device | adb (Android Debug Bridge) on PATH; an attached/connected Android device or emulator |
| 182 | `trace` | ① 核心/Ghidra 原生 | 🔧 needs-tool | a native analysis provider: Ghidra (>=12.1) / Hopper / IDA / Kuna configured; a target bi… |
| 183 | `trace-android-references` | ⑤ Android/ADB | ✅ linux-testable | 无，内置纯解析 / none, built-in |
| 184 | `trace-application-feature` | ⑨ Evidence/工程化 | ✅ linux-testable | 无，内置纯解析 / none, built-in |
| 185 | `trace-dylib-resolution` | ⑥ Apple | 🍎 needs-macos | Apple/macOS or iOS artifact (.app/.ipa/storyboard/plist) |
| 186 | `trace-javascript-semantics` | ④ Web/JS/Electron | ✅ linux-testable | 无，内置纯解析 / none, built-in |
| 187 | `trace-native-ui-action` | ③ 动态调试 | 📱 needs-device | a live process / UI session |
| 188 | `trace-native-values` | ① 核心/Ghidra 原生 | 🔧 needs-tool | a native analysis provider: Ghidra (>=12.1) / Hopper / IDA / Kuna configured; a target bi… |
| 189 | `trace-web-module-imports` | ④ Web/JS/Electron | 📱 needs-device | a running Chromium/Electron/Node target exposing a CDP/Inspector endpoint (Playwright for… |
| 190 | `trace-web-source-location` | ④ Web/JS/Electron | ✅ linux-testable | 无，内置纯解析 / none, built-in |
| 191 | `uninstall` | ⑩ JEB/平台 | ✅ linux-testable | 无，内置纯解析 / none, built-in |
| 192 | `uninstall-adb-package` | ⑤ Android/ADB | 📱 needs-device | adb (Android Debug Bridge) on PATH; an attached/connected Android device or emulator |
| 193 | `update` | ⑩ JEB/平台 | ✅ linux-testable | 无，内置纯解析 / none, built-in |
| 194 | `validate-browser-scenario` | ④ Web/JS/Electron | ✅ linux-testable | offline validation of one browser scenario; no browser launched or attached |
| 195 | `verify-managed-native-boundaries` | ⑨ Evidence/工程化 | ✅ linux-testable | 无，内置纯解析 / none, built-in |
| 196 | `xrefs` | ① 核心/Ghidra 原生 | 🔧 needs-tool | a native analysis provider: Ghidra (>=12.1) / Hopper / IDA / Kuna configured; a target bi… |

**合计 / Total：196 个命令。**
