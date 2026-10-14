// ExportDecompiled.java — Ghidra headless：导出逐函数伪代码为 JSON（decompiled.json：名->C 文本）。
// 脚本参数 1：输出目录。
// 归本仓库 PolyForm Noncommercial 1.0.0 许可（原创代码）。
// @category REA Export
import ghidra.app.script.GhidraScript;
import ghidra.app.decompiler.DecompInterface;
import ghidra.app.decompiler.DecompileResults;
import ghidra.program.model.listing.Function;
import ghidra.program.model.listing.FunctionIterator;
import ghidra.program.model.listing.FunctionManager;

import java.io.File;
import java.io.PrintWriter;
import java.util.ArrayList;
import java.util.List;

public class ExportDecompiled extends GhidraScript {
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

    @Override
    public void run() throws Exception {
        String[] a = getScriptArgs();
        if (a.length < 1) { println("ExportDecompiled: 缺少输出目录"); return; }
        File outDir = new File(a[0]); outDir.mkdirs();
        DecompInterface decomp = new DecompInterface();
        decomp.openProgram(currentProgram);
        FunctionManager fm = currentProgram.getFunctionManager();
        FunctionIterator it = fm.getFunctions(true);
        List<String> entries = new ArrayList<>();
        int n = 0;
        for (Function f : it) {
            if (monitor.isCancelled()) break;
            DecompileResults res = decomp.decompileFunction(f, 60, monitor);
            if (res != null && res.decompileCompleted() && res.getDecompiledFunction() != null) {
                String code = res.getDecompiledFunction().getC();
                entries.add("  \"" + esc(f.getName()) + "\": \"" + esc(code) + "\"");
                n++;
            }
        }
        decomp.dispose();
        PrintWriter w = new PrintWriter(new File(outDir, "decompiled.json"), "UTF-8");
        w.println("{");
        for (int i = 0; i < entries.size(); i++) {
            w.print(entries.get(i));
            if (i < entries.size() - 1) w.print(",");
            w.println();
        }
        w.println("}"); w.close();
        println("ExportDecompiled: " + n + " functions -> " + new File(outDir, "decompiled.json").getAbsolutePath());
    }
}
