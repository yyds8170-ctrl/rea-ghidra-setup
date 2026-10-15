// ExportReport.java — Ghidra headless：一次性生成完整静态分析产物与结构化报告。
// 脚本参数：1=输出目录 2=原始二进制绝对路径（用于 MD5/SHA256）。
// 产物：
//   meta.json / sections 在 meta 中；functions/strings/symbols/calls/decompiled（同 ExportAll）
//   xrefs.json（导入与字符串的交叉引用）；constants.json（按函数的关键立即数）
//   report.md（结构化 Markdown）；report.html（自包含单文件 HTML，内联 CSS，无 CDN/JS）
// analyzeHeadless 调用：... -postScript ExportReport.java <outDir> <binPath>
// 归本仓库 PolyForm Noncommercial 1.0.0（原创代码）。
// @category REA Export
import ghidra.app.script.GhidraScript;
import ghidra.app.decompiler.DecompInterface;
import ghidra.app.decompiler.DecompileOptions;
import ghidra.app.decompiler.DecompileResults;
import ghidra.program.model.listing.Data;
import ghidra.program.model.listing.DataIterator;
import ghidra.program.model.listing.Function;
import ghidra.program.model.listing.FunctionIterator;
import ghidra.program.model.listing.FunctionManager;
import ghidra.program.model.listing.Instruction;
import ghidra.program.model.listing.InstructionIterator;
import ghidra.program.model.mem.MemoryBlock;
import ghidra.program.model.symbol.ExternalLocation;
import ghidra.program.model.symbol.ExternalManager;
import ghidra.program.model.symbol.Reference;
import ghidra.program.model.symbol.ReferenceIterator;
import ghidra.program.model.symbol.RefType;
import ghidra.program.model.symbol.Symbol;
import ghidra.program.model.symbol.SymbolTable;
import ghidra.program.model.symbol.ExternalLocationIterator;
import ghidra.program.model.address.Address;
import ghidra.program.model.lang.OperandType;
import ghidra.program.model.scalar.Scalar;

import java.io.File;
import java.io.PrintWriter;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.security.MessageDigest;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.TreeMap;

public class ExportReport extends GhidraScript {

    // ------------------------------------------------------------- escaping
    static String esc(String s) {
        if (s == null) return "";
        StringBuilder sb = new StringBuilder();
        for (int i = 0; i < s.length(); i++) {
            char c = s.charAt(i);
            if (c == '"') sb.append("\\\"");
            else if (c == '\\') sb.append("\\\\");
            else if (c == '\n') sb.append("\\n");
            else if (c == '\r') sb.append("\\r");
            else if (c == '\t') sb.append("\\t");
            else if (c < 0x20) sb.append(String.format("\\u%04x", (int) c));
            else sb.append(c);
        }
        return sb.toString();
    }

    static String escHtml(String s) {
        if (s == null) return "";
        StringBuilder sb = new StringBuilder();
        for (int i = 0; i < s.length(); i++) {
            char c = s.charAt(i);
            if (c == '&') sb.append("&amp;");
            else if (c == '<') sb.append("&lt;");
            else if (c == '>') sb.append("&gt;");
            else if (c == '"') sb.append("&quot;");
            else sb.append(c);
        }
        return sb.toString();
    }

    static void writeText(File f, String content) throws Exception {
        Files.write(f.toPath(), content.getBytes(StandardCharsets.UTF_8));
    }

    static void writeArray(File outDir, String name, List<String> rows) throws Exception {
        StringBuilder sb = new StringBuilder("[\n");
        for (int i = 0; i < rows.size(); i++) {
            sb.append("  ").append(rows.get(i));
            if (i < rows.size() - 1) sb.append(",");
            sb.append("\n");
        }
        sb.append("]");
        writeText(new File(outDir, name), sb.toString());
    }

    static String hashFile(File f, String algo) throws Exception {
        MessageDigest md = MessageDigest.getInstance(algo);
        byte[] data = Files.readAllBytes(f.toPath());
        byte[] d = md.digest(data);
        StringBuilder sb = new StringBuilder();
        for (byte b : d) sb.append(String.format("%02x", b));
        return sb.toString();
    }

    // ------------------------------------------------------------- mini MD->HTML
    static String inlineHtml(String line) {
        StringBuilder sb = new StringBuilder();
        boolean code = false;
        StringBuilder token = new StringBuilder();
        for (int i = 0; i < line.length(); i++) {
            char c = line.charAt(i);
            if (c == '`') {
                if (code) { sb.append("<code>").append(escHtml(token.toString())).append("</code>"); token.setLength(0); code = false; }
                else { flushBold(sb, token); code = false; }
                continue;
            }
            if (!code) {
                if (c == '*' && i + 1 < line.length() && line.charAt(i + 1) == '*') {
                    if (token.length() > 0) { sb.append(escHtml(token.toString())); token.setLength(0); }
                    int end = line.indexOf("**", i + 2);
                    if (end >= 0) {
                        sb.append("<strong>").append(escHtml(line.substring(i + 2, end))).append("</strong>");
                        i = end + 1;
                        continue;
                    }
                }
                token.append(c);
            }
        }
        if (code) sb.append("`").append(escHtml(token.toString()));
        else if (token.length() > 0) sb.append(escHtml(token.toString()));
        return sb.toString();
    }

    private static void flushBold(StringBuilder sb, StringBuilder token) {
        if (token.length() > 0) { sb.append(escHtml(token.toString())); token.setLength(0); }
    }

    static String mdToHtml(String md) {
        String[] lines = md.split("\n", -1);
        StringBuilder out = new StringBuilder();
        int i = 0;
        while (i < lines.length) {
            String ln = lines[i];
            String t = ln.trim();
            if (t.isEmpty()) { i++; continue; }
            // fenced code
            if (t.startsWith("```")) {
                StringBuilder code = new StringBuilder();
                i++;
                while (i < lines.length && !lines[i].trim().startsWith("```")) {
                    code.append(escHtml(lines[i])).append("\n");
                    i++;
                }
                i++;
                out.append("<pre><code>").append(code.toString()).append("</code></pre>\n");
                continue;
            }
            // headings
            int h = 0;
            while (h < t.length() && t.charAt(h) == '#' && h < 6) h++;
            if (h > 0 && h < t.length() && t.charAt(h) == ' ') {
                out.append("<h").append(h).append(">").append(inlineHtml(t.substring(h + 1)))
                   .append("</h").append(h).append(">\n");
                i++;
                continue;
            }
            // table
            if (t.contains("|") && i + 1 < lines.length && lines[i + 1].matches("^[\\s\\|:\\-]+$")
                && lines[i + 1].contains("-")) {
                String[] header = splitRow(t);
                i += 2;
                List<String[]> body = new ArrayList<>();
                while (i < lines.length && lines[i].contains("|") && lines[i].trim().startsWith("|")) {
                    body.add(splitRow(lines[i].trim()));
                    i++;
                }
                out.append("<table>\n<thead><tr>");
                for (String c : header) out.append("<th>").append(inlineHtml(c.trim())).append("</th>");
                out.append("</tr></thead>\n<tbody>\n");
                for (String[] row : body) {
                    out.append("<tr>");
                    for (String c : row) out.append("<td>").append(inlineHtml(c.trim())).append("</td>");
                    out.append("</tr>\n");
                }
                out.append("</tbody>\n</table>\n");
                continue;
            }
            // bullet list
            if (t.startsWith("- ") || t.startsWith("* ")) {
                out.append("<ul>\n");
                while (i < lines.length && (lines[i].trim().startsWith("- ") || lines[i].trim().startsWith("* "))) {
                    out.append("<li>").append(inlineHtml(lines[i].trim().substring(2))).append("</li>\n");
                    i++;
                }
                out.append("</ul>\n");
                continue;
            }
            // paragraph
            out.append("<p>").append(inlineHtml(t)).append("</p>\n");
            i++;
        }
        return out.toString();
    }

    static String[] splitRow(String row) {
        String r = row.trim();
        if (r.startsWith("|")) r = r.substring(1);
        if (r.endsWith("|")) r = r.substring(0, r.length() - 1);
        // split on | not escaped
        List<String> cells = new ArrayList<>();
        StringBuilder cur = new StringBuilder();
        for (int i = 0; i < r.length(); i++) {
            char c = r.charAt(i);
            if (c == '\\' && i + 1 < r.length()) { cur.append(c).append(r.charAt(i + 1)); i++; }
            else if (c == '|') { cells.add(cur.toString()); cur.setLength(0); }
            else cur.append(c);
        }
        cells.add(cur.toString());
        return cells.toArray(new String[0]);
    }

    // ------------------------------------------------------------- main
    @Override
    public void run() throws Exception {
        String[] a = getScriptArgs();
        if (a.length < 1) { println("ExportReport: 缺少输出目录"); return; }
        File outDir = new File(a[0]);
        outDir.mkdirs();
        File binFile = a.length >= 2 ? new File(a[1]) : null;

        FunctionManager fm = currentProgram.getFunctionManager();
        SymbolTable st = currentProgram.getSymbolTable();

        // ---- gather functions (preserve order, but de-dupe in report later)
        List<Function> allFuncs = new ArrayList<>();
        FunctionIterator fit = fm.getFunctions(true);
        while (fit.hasNext()) {
            if (monitor.isCancelled()) break;
            allFuncs.add(fit.next());
        }
        List<String> funcRows = new ArrayList<>();
        for (Function f : allFuncs) {
            String sig;
            try { sig = f.getSignature().getPrototypeString(); }
            catch (Exception e) { sig = f.getName(); }
            funcRows.add("{\"address\":\"" + f.getEntryPoint() + "\",\"name\":\"" + esc(f.getName())
                    + "\",\"signature\":\"" + esc(sig) + "\",\"thunk\":" + f.isThunk()
                    + ",\"external\":" + f.isExternal() + ",\"global\":" + f.isGlobal() + "}");
        }
        writeArray(outDir, "functions.json", funcRows);

        // ---- strings
        DataIterator dit = currentProgram.getListing().getDefinedData(true);
        List<String> strRows = new ArrayList<>();
        List<Data> strData = new ArrayList<>();
        while (dit.hasNext()) {
            if (monitor.isCancelled()) break;
            Data d = dit.next();
            try {
                if (d.hasStringValue() && d.getValue() instanceof String) {
                    String str = (String) d.getValue();
                    strData.add(d);
                    strRows.add("{\"address\":\"" + d.getAddress() + "\",\"value\":\"" + esc(str)
                            + "\",\"length\":" + str.length() + "}");
                }
            } catch (Exception e) { /* skip */ }
        }
        writeArray(outDir, "strings.json", strRows);

        // ---- symbols
        java.util.Iterator<Symbol> sit = st.getAllSymbols(true);
        List<String> symRows = new ArrayList<>();
        while (sit.hasNext()) {
            if (monitor.isCancelled()) break;
            Symbol sy = sit.next();
            String ns;
            try { ns = sy.getParentNamespace() != null ? sy.getParentNamespace().getName() : ""; }
            catch (Exception e) { ns = ""; }
            String type;
            try { type = sy.getSymbolType().toString(); }
            catch (Exception e) { type = "UNKNOWN"; }
            symRows.add("{\"address\":\"" + sy.getAddress() + "\",\"name\":\"" + esc(sy.getName())
                    + "\",\"type\":\"" + esc(type) + "\",\"namespace\":\"" + esc(ns) + "\"}");
        }
        writeArray(outDir, "symbols.json", symRows);

        // ---- calls
        List<String> callRows = new ArrayList<>();
        for (Function caller : allFuncs) {
            Set<Function> callees;
            try { callees = caller.getCalledFunctions(monitor); }
            catch (Exception e) { continue; }
            if (callees == null) continue;
            for (Function c : callees) {
                callRows.add("{\"caller_address\":\"" + caller.getEntryPoint() + "\",\"caller\":\"" + esc(caller.getName())
                        + "\",\"callee_address\":\"" + c.getEntryPoint() + "\",\"callee\":\"" + esc(c.getName()) + "\"}");
            }
        }
        writeArray(outDir, "calls.json", callRows);

        // ---- meta: sections / format / entry
        List<MemoryBlock> blocks = new ArrayList<>();
        for (MemoryBlock b : currentProgram.getMemory().getBlocks()) blocks.add(b);
        List<String> secRows = new ArrayList<>();
        for (MemoryBlock b : blocks) {
            secRows.add("{\"name\":\"" + esc(b.getName()) + "\",\"start\":\"" + b.getStart() + "\",\"end\":\"" + b.getEnd()
                    + "\",\"size\":" + b.getSize() + ",\"read\":" + b.isRead() + ",\"write\":" + b.isWrite()
                    + ",\"execute\":" + b.isExecute() + ",\"initialized\":" + b.isInitialized() + "}");
        }

        // entry point：优先名为 "entry" 的符号，其次 _start 函数，再回退首个外部入口
        List<String> entries = new ArrayList<>();
        String entryAddr = "";
        ghidra.program.model.symbol.SymbolIterator enSym = st.getSymbols("entry");
        if (enSym.hasNext()) {
            entryAddr = enSym.next().getAddress().toString();
        } else {
            for (Function f : allFuncs) {
                if (f.getName().equals("_start")) { entryAddr = f.getEntryPoint().toString(); break; }
            }
        }
        if (entryAddr.isEmpty()) {
            ghidra.program.model.address.AddressIterator eit = st.getExternalEntryPointIterator();
            if (eit.hasNext()) entryAddr = eit.next().toString();
        }
        if (!entryAddr.isEmpty()) entries.add(entryAddr);

        // ---- imports / exports
        ExternalManager em = currentProgram.getExternalManager();
        List<String> libNames = new ArrayList<>();
        for (String lib : em.getExternalLibraryNames()) libNames.add(lib);
        List<String> impRows = new ArrayList<>();
        for (String lib : libNames) {
            ExternalLocationIterator elit = em.getExternalLocations(lib);
            while (elit.hasNext()) {
                ExternalLocation loc = elit.next();
                String label;
                try { label = loc.getLabel(); } catch (Exception e) { label = null; }
                Address ea = null;
                try { ea = loc.getAddress(); } catch (Exception e) { ea = null; }
                impRows.add("{\"library\":\"" + esc(lib) + "\",\"name\":\"" + esc(label == null ? "" : label)
                        + "\",\"address\":\"" + (ea == null ? "" : ea.toString()) + "\"}");
            }
        }
        writeArray(outDir, "imports.json", impRows);

        List<String> expRows = new ArrayList<>();
        for (Function f : allFuncs) {
            try {
                if (!f.isExternal() && f.isGlobal()) {
                    String sig;
                    try { sig = f.getSignature().getPrototypeString(); }
                    catch (Exception e) { sig = f.getName(); }
                    expRows.add("{\"name\":\"" + esc(f.getName()) + "\",\"address\":\"" + f.getEntryPoint()
                            + "\",\"signature\":\"" + esc(sig) + "\"}");
                }
            } catch (Exception e) { /* skip */ }
        }
        writeArray(outDir, "exports.json", expRows);

        // ---- constants (per function scalars)
        List<String> constRows = new ArrayList<>();
        Map<String, List<Long>> constByFunc = new LinkedHashMap<>();
        for (Function f : allFuncs) {
            if (f.isExternal()) continue;
            List<Long> vals = new ArrayList<>();
            InstructionIterator ii = currentProgram.getListing().getInstructions(f.getBody(), true);
            while (ii.hasNext()) {
                if (monitor.isCancelled()) break;
                Instruction ins = ii.next();
                for (int op = 0; op < ins.getNumOperands(); op++) {
                    try {
                        int otype = ins.getOperandType(op);
                        if (OperandType.isScalar(otype)) {
                            Scalar sc = ins.getScalar(op);
                            if (sc == null) continue;
                            long v = sc.getValue();
                            if (!vals.contains(v)) vals.add(v);
                        }
                    } catch (Exception e) { /* skip */ }
                }
            }
            constByFunc.put(f.getName(), vals);
            for (long v : vals) {
                constRows.add("{\"function\":\"" + esc(f.getName()) + "\",\"value\":" + v
                        + ",\"hex\":\"0x" + Long.toHexString(v) + "\"}");
            }
        }
        writeArray(outDir, "constants.json", constRows);

        // ---- xrefs: references TO imports and TO strings
        List<String> xrefRows = new ArrayList<>();
        addXrefsToImportAddresses(em, libNames, xrefRows, fm);
        for (Data d : strData) {
            addXrefsToAddress(d.getAddress(), d.getValue() instanceof String ? (String) d.getValue() : null,
                    xrefRows, fm, "string");
        }
        if (xrefRows.size() > 6000) {
            xrefRows = xrefRows.subList(0, 6000);
        }
        writeArray(outDir, "xrefs.json", xrefRows);

        // ---- meta.json
        String md5 = "", sha = "";
        long fsize = 0;
        if (binFile != null && binFile.isFile()) {
            md5 = hashFile(binFile, "MD5");
            sha = hashFile(binFile, "SHA-256");
            fsize = binFile.length();
        }
        String format = currentProgram.getExecutableFormat();
        String langId = currentProgram.getLanguageID().toString();
        String compiler = currentProgram.getCompiler();
        Address imageBase = currentProgram.getImageBase();
        StringBuilder meta = new StringBuilder();
        meta.append("{\n");
        meta.append("  \"file\": \"").append(esc(binFile != null ? binFile.getName() : "")).append("\",\n");
        meta.append("  \"path\": \"").append(esc(binFile != null ? binFile.getAbsolutePath() : "")).append("\",\n");
        meta.append("  \"size\": ").append(fsize).append(",\n");
        meta.append("  \"md5\": \"").append(md5).append("\",\n");
        meta.append("  \"sha256\": \"").append(sha).append("\",\n");
        meta.append("  \"format\": \"").append(esc(format)).append("\",\n");
        meta.append("  \"language_id\": \"").append(esc(langId)).append("\",\n");
        meta.append("  \"compiler\": \"").append(esc(compiler)).append("\",\n");
        meta.append("  \"image_base\": \"").append(imageBase == null ? "" : imageBase.toString()).append("\",\n");
        meta.append("  \"entry_points\": [");
        for (int k = 0; k < entries.size(); k++) meta.append(k > 0 ? "," : "").append("\"").append(entries.get(k)).append("\"");
        meta.append("],\n");
        meta.append("  \"sections\": [\n");
        for (int k = 0; k < secRows.size(); k++) meta.append("    ").append(secRows.get(k)).append(k < secRows.size() - 1 ? ",\n" : "\n");
        meta.append("  ]\n");
        meta.append("}\n");
        writeText(new File(outDir, "meta.json"), meta.toString());

        // ---- decompiled
        DecompInterface decomp = new DecompInterface();
        DecompileOptions dopt = new DecompileOptions();
        decomp.setOptions(dopt);
        decomp.openProgram(currentProgram);
        Map<String, String> decompMap = new LinkedHashMap<>();
        List<String> decRows = new ArrayList<>();
        for (Function f : allFuncs) {
            if (f.isExternal()) continue;
            DecompileResults res = decomp.decompileFunction(f, 60, monitor);
            if (res != null && res.decompileCompleted() && res.getDecompiledFunction() != null) {
                String c = res.getDecompiledFunction().getC();
                decompMap.put(f.getName(), c);
                decRows.add("  \"" + esc(f.getName()) + "\": \"" + esc(c) + "\"");
            }
        }
        decomp.dispose();
        StringBuilder dec = new StringBuilder("{\n");
        for (int k = 0; k < decRows.size(); k++) {
            dec.append(decRows.get(k));
            if (k < decRows.size() - 1) dec.append(",");
            dec.append("\n");
        }
        dec.append("}");
        writeText(new File(outDir, "decompiled.json"), dec.toString());

        // ---- security heuristics
        boolean canary = containsImportName(impRows, "__stack_chk_fail") || containsImportName(impRows, "__stack_chk_guard");
        boolean dynamicBlock = blockNamed(blocks, ".dynamic") || blockNamed(blocks, "DYNAMIC");
        boolean stripped = looksStripped(allFuncs);

        // ---- build report.md
        StringBuilder rmd = new StringBuilder();
        String binName = binFile != null ? binFile.getName() : currentProgram.getName();
        rmd.append("# 二进制静态分析报告 / Static Analysis Report\n\n");
        rmd.append("**目标 / Target:** ").append(esc(binName)).append("  \n");
        rmd.append("**生成时间 / Generated:** ").append(new java.util.Date().toString()).append("  \n");
        rmd.append("**工具 / Tool:** Ghidra headless（via rea-ghidra-setup）\n\n");

        rmd.append("## 1. 元信息 / Overview\n\n");
        rmd.append("| 项目 Item | 值 Value |\n|---|---|\n");
        rmd.append("| 文件大小 Size | ").append(fsize).append(" bytes |\n");
        rmd.append("| 格式 Format | ").append(esc(format)).append(" |\n");
        rmd.append("| 架构语言 Language | ").append(esc(langId)).append(" |\n");
        rmd.append("| 编译器 Compiler | ").append(esc(compiler)).append(" |\n");
        rmd.append("| 镜像基址 Image base | ").append(imageBase == null ? "" : imageBase.toString()).append(" |\n");
        rmd.append("| 入口点 Entry | ").append(String.join(", ", entries)).append(" |\n");
        rmd.append("| MD5 | `").append(md5).append("` |\n");
        rmd.append("| SHA256 | `").append(sha).append("` |\n\n");

        rmd.append("## 2. 段表 / Sections\n\n");
        rmd.append("| 段名 Name | 起始 Start | 结束 End | 大小 Size | R | W | X |\n");
        rmd.append("|---|---|---|---|---|---|---|\n");
        for (MemoryBlock b : blocks) {
            rmd.append("| ").append(esc(b.getName())).append(" | ").append(b.getStart()).append(" | ").append(b.getEnd())
               .append(" | ").append(b.getSize()).append(" | ").append(b.isRead() ? "✓" : "·")
               .append(" | ").append(b.isWrite() ? "✓" : "·").append(" | ").append(b.isExecute() ? "✓" : "·").append(" |\n");
        }
        rmd.append("\n");

        rmd.append("## 3. 安全特征 / Security Features（启发式 Heuristic）\n\n");
        rmd.append("- **Stack Canary（栈保护）:** ").append(canary ? "检测到 `__stack_chk_fail`（是）" : "未检测到").append("\n");
        rmd.append("- **PIE / 动态基址:** ").append(dynamicBlock && format.contains("ELF") ? "存在动态段（疑似 PIE）" : "未能确认").append("\n");
        rmd.append("- **Stripped（已剥离符号）:** ").append(stripped ? "看起来已剥离（自定义函数名为 FUN_xx）" : "保留符号").append("\n");
        rmd.append("- **NX / RELRO:** Ghidra headless 不解析 GNU_STACK/RELRO，建议用 `readelf -l` / `readelf -d` 复核。\n\n");

        rmd.append("## 4. 导入函数 / Imports\n\n");
        rmd.append("| 库 Library | 函数 Name | 地址 Address |\n|---|---|---|\n");
        for (String lib : libNames) {
            ExternalLocationIterator elit = em.getExternalLocations(lib);
            while (elit.hasNext()) {
                ExternalLocation loc = elit.next();
                String label;
                try { label = loc.getLabel(); } catch (Exception e) { label = ""; }
                Address ea = null;
                try { ea = loc.getAddress(); } catch (Exception e) { ea = null; }
                rmd.append("| ").append(esc(lib)).append(" | ").append(esc(label == null ? "" : label))
                   .append(" | ").append(ea == null ? "" : ea.toString()).append(" |\n");
            }
        }
        rmd.append("\n");

        rmd.append("## 5. 导出函数 / Exports\n\n");
        rmd.append("| 函数 Name | 地址 Address | 原型 Signature |\n|---|---|---|\n");
        boolean anyExport = false;
        for (Function f : allFuncs) {
            try {
                if (!f.isExternal() && f.isGlobal()) {
                    String sig;
                    try { sig = f.getSignature().getPrototypeString(); }
                    catch (Exception e) { sig = f.getName(); }
                    rmd.append("| ").append(esc(f.getName())).append(" | ").append(f.getEntryPoint())
                       .append(" | ").append(esc(sig)).append(" |\n");
                    anyExport = true;
                }
            } catch (Exception e) { /* skip */ }
        }
        if (!anyExport) {
            rmd.append("| （无动态导出） | — | 普通可执行文件通常没有动态导出表；自定义函数见函数清单、常量与反编译摘要 |\n");
        }
        rmd.append("\n");

        rmd.append("## 6. 字符串 / Strings（共 ").append(strData.size()).append(" 条）\n\n");
        int shown = 0;
        for (Data d : strData) {
            if (shown++ >= 200) { rmd.append("- …（其余见 strings.json）\n"); break; }
            String val = (String) d.getValue();
            rmd.append("- `").append(d.getAddress()).append("` ").append(esc(val)).append("\n");
        }
        rmd.append("\n");

        rmd.append("## 7. 关键常量 / Key Constants\n\n");
        rmd.append("| 函数 Function | 常量 Constants（十进制 / 十六进制） |\n|---|---|\n");
        for (Map.Entry<String, List<Long>> e2 : constByFunc.entrySet()) {
            if (e2.getValue().isEmpty()) continue;
            List<String> cells = new ArrayList<>();
            for (long v : e2.getValue()) {
                if (v == 0) continue;
                cells.add(v + " / 0x" + Long.toHexString(v));
            }
            if (cells.isEmpty()) continue;
            rmd.append("| ").append(esc(e2.getKey())).append(" | ").append(String.join(", ", cells)).append(" |\n");
        }
        rmd.append("\n");

        rmd.append("## 8. 交叉引用 / Cross References（代码→导入/字符串；完整原始见 xrefs.json）\n\n");
        int nx = 0;
        for (String x : xrefRows) {
            // parse the JSON row minimally for display
            String from = jsonField(x, "from_function"), target = jsonField(x, "target"), type = jsonField(x, "type");
            if (from.isEmpty()) continue;   // 只显示来自真实函数的代码引用，过滤元数据块噪声
            if (nx++ >= 120) { rmd.append("- …（其余见 xrefs.json）\n"); break; }
            rmd.append("- ").append(esc(from)).append(" → ").append(esc(target)).append(" (").append(esc(type)).append(")\n");
        }
        if (nx == 0) {
            rmd.append("- （无代码侧数据引用；对导入函数的调用关系见第 9 节调用图）\n");
        }
        rmd.append("\n");

        rmd.append("## 9. 调用关系 / Call Graph（详见 calls.json）\n\n");
        Map<String, List<String>> adj = new TreeMap<>();
        for (String c : callRows) {
            String caller = jsonField(c, "caller"), callee = jsonField(c, "callee");
            adj.computeIfAbsent(caller, k -> new ArrayList<>());
            if (!adj.get(caller).contains(callee)) adj.get(caller).add(callee);
        }
        for (Map.Entry<String, List<String>> e2 : adj.entrySet()) {
            rmd.append("- **").append(esc(e2.getKey())).append("** → ").append(esc(String.join(", ", e2.getValue()))).append("\n");
        }
        rmd.append("\n");

        rmd.append("## 10. 反编译摘要 / Decompiled Highlights\n\n");
        String[] focus = pickFocus(allFuncs);
        for (String fn : focus) {
            String c = decompMap.get(fn);
            if (c == null) continue;
            rmd.append("### ").append(esc(fn)).append("\n\n```c\n").append(c).append("\n```\n\n");
        }
        rmd.append("---\n\n");
        rmd.append("本报告由 rea-ghidra-setup 的 Ghidra headless 报告生成器自动产出。\n");
        rmd.append("本项目是独立第三方工具，与 NSA/Ghidra、REA 无隶属或背书关系；详见 NOTICE / TRADEMARKS。\n");

        writeText(new File(outDir, "report.md"), rmd.toString());

        // ---- HTML
        String css = "body{font-family:system-ui,-apple-system,'Segoe UI',sans-serif;max-width:1000px;margin:2rem auto;"
                + "padding:0 1.2rem;line-height:1.55;color:#1c1c1e}"
                + "table{border-collapse:collapse;width:100%;margin:.6rem 0;font-size:.92rem}"
                + "th,td{border:1px solid #c7c7cc;padding:4px 8px;text-align:left;vertical-align:top}"
                + "th{background:#f2f2f7}h1,h2,h3{line-height:1.25}"
                + "h2{border-bottom:2px solid #4b4a9b;padding-bottom:3px;margin-top:2.2rem}"
                + "code{background:#f2f2f7;padding:1px 5px;border-radius:3px;font-family:ui-monospace,Menlo,monospace}"
                + "pre{background:#f6f6fa;border:1px solid #e2e2ea;border-radius:6px;padding:10px 12px;overflow:auto}"
                + "pre code{background:none;padding:0}blockquote{color:#555;border-left:3px solid #bbb;margin:0;padding-left:1rem}";
        String html = "<!doctype html>\n<html lang=\"zh\">\n<head>\n<meta charset=\"utf-8\">\n"
                + "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">\n"
                + "<title>" + escHtml(binName) + " - 静态分析报告</title>\n<style>\n" + css + "\n</style>\n</head>\n<body>\n"
                + mdToHtml(rmd.toString())
                + "\n</body>\n</html>\n";
        writeText(new File(outDir, "report.html"), html.toString());

        println("ExportReport: functions=" + allFuncs.size() + " strings=" + strData.size()
                + " imports=" + impRows.size() + " exports=" + expRows.size() + " xrefs=" + xrefRows.size()
                + " constants-funcs=" + constByFunc.size() + " -> report.md / report.html in " + outDir.getAbsolutePath());
    }

    // ------------------------------------------------------------- helpers
    private void addXrefsToImportAddresses(ExternalManager em, List<String> libs, List<String> out, FunctionManager fm) {
        for (String lib : libs) {
            ExternalLocationIterator elit = em.getExternalLocations(lib);
            while (elit.hasNext()) {
                ExternalLocation loc = elit.next();
                Address addr = null;
                String label = "";
                try { addr = loc.getAddress(); label = loc.getLabel(); } catch (Exception e) { continue; }
                if (addr == null) continue;
                addXrefsToAddress(addr, label, out, fm, "import");
            }
        }
    }

    private void addXrefsToAddress(Address target, String targetLabel, List<String> out, FunctionManager fm, String kind) {
        ReferenceIterator ri = currentProgram.getReferenceManager().getReferencesTo(target);
        while (ri.hasNext()) {
            if (monitor.isCancelled()) break;
            Reference r = ri.next();
            Address from = r.getFromAddress();
            RefType rt = r.getReferenceType();
            Function containing = fm.getFunctionContaining(from);
            String fn = containing != null ? containing.getName() : "";
            out.add("{\"from\":\"" + from + "\",\"from_function\":\"" + esc(fn) + "\",\"target\":\""
                    + esc(targetLabel == null ? target.toString() : targetLabel)
                    + "\",\"target_address\":\"" + target + "\",\"type\":\"" + esc(rt.toString())
                    + "\",\"kind\":\"" + kind + "\"}");
        }
    }

    private static boolean containsImportName(List<String> impRows, String name) {
        for (String r : impRows) {
            if (r.contains("\"name\":\"" + name + "\"")) return true;
        }
        return false;
    }

    private static boolean blockNamed(List<MemoryBlock> blocks, String name) {
        for (MemoryBlock b : blocks) if (b.getName().equalsIgnoreCase(name)) return true;
        return false;
    }

    private static boolean looksStripped(List<Function> funcs) {
        int userNamed = 0;
        for (Function f : funcs) {
            try {
                if (f.isExternal() || f.isThunk()) continue;
                String n = f.getName();
                if (n.startsWith("FUN_") || n.startsWith("LAB_")) continue;
                if (n.equals("_start") || n.equals("_init") || n.equals("_fini") || n.equals("entry")) continue;
                userNamed++;
            } catch (Exception e) { /* skip */ }
        }
        return userNamed == 0;
    }

    private static String[] pickFocus(List<Function> funcs) {
        List<String> out = new ArrayList<>();
        for (String prefer : new String[]{"main", "check_password", "verify_key", "secret_check", "dispatch", "calc"}) {
            for (Function f : funcs) {
                if (f.getName().equals(prefer) && !out.contains(prefer)) out.add(prefer);
            }
        }
        if (out.isEmpty()) {
            for (Function f : funcs) {
                try { if (!f.isExternal() && !f.isThunk()) out.add(f.getName()); } catch (Exception e) { /* skip */ }
                if (out.size() >= 3) break;
            }
        }
        return out.toArray(new String[0]);
    }

    private static String jsonField(String row, String field) {
        // expects "field":"value"
        java.util.regex.Matcher m = java.util.regex.Pattern
                .compile("\"" + field + "\"\\s*:\\s*\"((?:[^\"\\\\]|\\\\.)*)\"").matcher(row);
        if (m.find()) return m.group(1);
        return "";
    }
}
