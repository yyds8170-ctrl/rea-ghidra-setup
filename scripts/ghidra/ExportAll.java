// ExportAll.java — Ghidra headless：一次导出全部 5 类产物（总入口，自包含，不依赖兄弟类）。
// 脚本参数 1：输出目录。产物：functions/strings/symbols/calls/decompiled 的 JSON。
// analyzeHeadless 调用：analyzeHeadless <proj> Proj -import <bin> -scriptPath scripts/ghidra \
//   -postScript ExportAll.java <outDir> -deleteProject
// 归本仓库 PolyForm Noncommercial 1.0.0 许可（原创代码）。
// @category REA Export
import ghidra.app.script.GhidraScript;
import ghidra.app.decompiler.DecompInterface;
import ghidra.app.decompiler.DecompileResults;
import ghidra.program.model.listing.Data;
import ghidra.program.model.listing.DataIterator;
import ghidra.program.model.listing.Function;
import ghidra.program.model.listing.FunctionIterator;
import ghidra.program.model.listing.FunctionManager;
import ghidra.program.model.symbol.Symbol;
import ghidra.program.model.symbol.SymbolTable;

import java.io.File;
import java.io.PrintWriter;
import java.util.ArrayList;
import java.util.List;
import java.util.Set;

public class ExportAll extends GhidraScript {
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

    static void writeArray(File outDir, String name, List<String> rows) throws Exception {
        PrintWriter w = new PrintWriter(new File(outDir, name), "UTF-8");
        w.println("[");
        for (int i = 0; i < rows.size(); i++) {
            w.print("  " + rows.get(i));
            if (i < rows.size() - 1) w.print(",");
            w.println();
        }
        w.println("]"); w.close();
    }

    @Override
    public void run() throws Exception {
        String[] a = getScriptArgs();
        if (a.length < 1) { println("ExportAll: 缺少输出目录"); return; }
        File outDir = new File(a[0]); outDir.mkdirs();
        FunctionManager fm = currentProgram.getFunctionManager();

        // functions
        FunctionIterator fit = fm.getFunctions(true);
        List<String> funcs = new ArrayList<>();
        while (fit.hasNext()) {
            if (monitor.isCancelled()) break;
            Function f = fit.next();
            String sig;
            try { sig = f.getSignature().getPrototypeString(); }
            catch (Exception e) { sig = f.getName(); }
            funcs.add("{\"address\":\"" + f.getEntryPoint() + "\",\"name\":\"" + esc(f.getName())
                    + "\",\"signature\":\"" + esc(sig) + "\",\"thunk\":" + f.isThunk() + "}");
        }
        writeArray(outDir, "functions.json", funcs);

        // strings
        DataIterator dit = currentProgram.getListing().getDefinedData(true);
        List<String> strs = new ArrayList<>();
        while (dit.hasNext()) {
            if (monitor.isCancelled()) break;
            Data d = dit.next();
            try {
                if (d.hasStringValue() && d.getValue() instanceof String) {
                    String str = (String) d.getValue();
                    strs.add("{\"address\":\"" + d.getAddress() + "\",\"value\":\"" + esc(str) + "\",\"length\":" + str.length() + "}");
                }
            } catch (Exception e) { /* skip */ }
        }
        writeArray(outDir, "strings.json", strs);

        // symbols
        SymbolTable st = currentProgram.getSymbolTable();
        java.util.Iterator<Symbol> sit = st.getAllSymbols(true);
        List<String> syms = new ArrayList<>();
        while (sit.hasNext()) {
            if (monitor.isCancelled()) break;
            Symbol sy = sit.next();
            String ns;
            try { ns = sy.getParentNamespace() != null ? sy.getParentNamespace().getName() : ""; }
            catch (Exception e) { ns = ""; }
            String type;
            try { type = sy.getSymbolType().toString(); }
            catch (Exception e) { type = "UNKNOWN"; }
            syms.add("{\"address\":\"" + sy.getAddress() + "\",\"name\":\"" + esc(sy.getName())
                    + "\",\"type\":\"" + esc(type) + "\",\"namespace\":\"" + esc(ns) + "\"}");
        }
        writeArray(outDir, "symbols.json", syms);

        // calls
        FunctionIterator cit = fm.getFunctions(true);
        List<String> calls = new ArrayList<>();
        while (cit.hasNext()) {
            if (monitor.isCancelled()) break;
            Function caller = cit.next();
            Set<Function> callees;
            try { callees = caller.getCalledFunctions(monitor); }
            catch (Exception e) { continue; }
            if (callees == null) continue;
            for (Function c : callees) {
                calls.add("{\"caller_address\":\"" + caller.getEntryPoint() + "\",\"caller\":\"" + esc(caller.getName())
                        + "\",\"callee_address\":\"" + c.getEntryPoint() + "\",\"callee\":\"" + esc(c.getName()) + "\"}");
            }
        }
        writeArray(outDir, "calls.json", calls);

        // decompiled
        DecompInterface decomp = new DecompInterface();
        decomp.openProgram(currentProgram);
        FunctionIterator dit2 = fm.getFunctions(true);
        List<String> decs = new ArrayList<>();
        while (dit2.hasNext()) {
            if (monitor.isCancelled()) break;
            Function f = dit2.next();
            DecompileResults res = decomp.decompileFunction(f, 60, monitor);
            if (res != null && res.decompileCompleted() && res.getDecompiledFunction() != null) {
                decs.add("  \"" + esc(f.getName()) + "\": \"" + esc(res.getDecompiledFunction().getC()) + "\"");
            }
        }
        decomp.dispose();
        PrintWriter w = new PrintWriter(new File(outDir, "decompiled.json"), "UTF-8");
        w.println("{");
        for (int i = 0; i < decs.size(); i++) {
            w.print(decs.get(i));
            if (i < decs.size() - 1) w.print(",");
            w.println();
        }
        w.println("}"); w.close();

        println("ExportAll: functions=" + funcs.size() + " strings=" + strs.size() + " symbols=" + syms.size()
                + " calls=" + calls.size() + " decompiled=" + decs.size() + " -> " + outDir.getAbsolutePath());
    }
}
