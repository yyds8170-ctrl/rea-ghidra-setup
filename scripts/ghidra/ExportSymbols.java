// ExportSymbols.java — Ghidra headless：导出符号表（含导入/导出）为 JSON（symbols.json）。
// 脚本参数 1：输出目录。字段：address、name、type、namespace。
// 归本仓库 PolyForm Noncommercial 1.0.0 许可（原创代码）。
// @category REA Export
import ghidra.app.script.GhidraScript;
import ghidra.program.model.symbol.Symbol;
import ghidra.program.model.symbol.SymbolTable;

import java.io.File;
import java.io.PrintWriter;
import java.util.ArrayList;
import java.util.List;

public class ExportSymbols extends GhidraScript {
    static String esc(String s) {
        if (s == null) return "";
        StringBuilder sb = new StringBuilder();
        for (int i = 0; i < s.length(); i++) {
            char c = s.charAt(i);
            if (c == '"') sb.append("\\\"");
            else if (c == '\\') sb.append("\\\\");
            else if (c < 0x20) sb.append(String.format("\\u%04x", (int) c));
            else sb.append(c);
        }
        return sb.toString();
    }

    @Override
    public void run() throws Exception {
        String[] a = getScriptArgs();
        if (a.length < 1) { println("ExportSymbols: 缺少输出目录"); return; }
        File outDir = new File(a[0]); outDir.mkdirs();
        SymbolTable st = currentProgram.getSymbolTable();
        java.util.Iterator<Symbol> it = st.getAllSymbols(true);
        List<String> rows = new ArrayList<>();
        int n = 0;
        while (it.hasNext()) {
            if (monitor.isCancelled()) break;
            Symbol sy = it.next();
            String ns;
            try { ns = sy.getParentNamespace() != null ? sy.getParentNamespace().getName() : ""; }
            catch (Exception e) { ns = ""; }
            String type;
            try { type = sy.getSymbolType().toString(); }
            catch (Exception e) { type = "UNKNOWN"; }
            rows.add("{\"address\":\"" + sy.getAddress() + "\",\"name\":\"" + esc(sy.getName())
                    + "\",\"type\":\"" + esc(type) + "\",\"namespace\":\"" + esc(ns) + "\"}");
            n++;
        }
        PrintWriter w = new PrintWriter(new File(outDir, "symbols.json"), "UTF-8");
        w.println("[");
        for (int i = 0; i < rows.size(); i++) {
            w.print("  " + rows.get(i));
            if (i < rows.size() - 1) w.print(",");
            w.println();
        }
        w.println("]"); w.close();
        println("ExportSymbols: " + n + " symbols -> " + new File(outDir, "symbols.json").getAbsolutePath());
    }
}
