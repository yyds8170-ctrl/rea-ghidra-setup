// ExportCalls.java — Ghidra headless：导出函数调用关系 caller->callee 边（calls.json）。
// 脚本参数 1：输出目录。字段：caller_address、caller、callee_address、callee。
// 归本仓库 PolyForm Noncommercial 1.0.0 许可（原创代码）。
// @category REA Export
import ghidra.app.script.GhidraScript;
import ghidra.program.model.listing.Function;
import ghidra.program.model.listing.FunctionIterator;
import ghidra.program.model.listing.FunctionManager;

import java.io.File;
import java.io.PrintWriter;
import java.util.ArrayList;
import java.util.List;
import java.util.Set;

public class ExportCalls extends GhidraScript {
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
        if (a.length < 1) { println("ExportCalls: 缺少输出目录"); return; }
        File outDir = new File(a[0]); outDir.mkdirs();
        FunctionManager fm = currentProgram.getFunctionManager();
        FunctionIterator it = fm.getFunctions(true);
        List<String> rows = new ArrayList<>();
        int n = 0;
        while (it.hasNext()) {
            if (monitor.isCancelled()) break;
            Function caller = it.next();
            Set<Function> callees;
            try { callees = caller.getCalledFunctions(monitor); }
            catch (Exception e) { continue; }
            if (callees == null) continue;
            for (Function c : callees) {
                rows.add("{\"caller_address\":\"" + caller.getEntryPoint() + "\",\"caller\":\"" + esc(caller.getName())
                        + "\",\"callee_address\":\"" + c.getEntryPoint() + "\",\"callee\":\"" + esc(c.getName()) + "\"}");
                n++;
            }
        }
        PrintWriter w = new PrintWriter(new File(outDir, "calls.json"), "UTF-8");
        w.println("[");
        for (int i = 0; i < rows.size(); i++) {
            w.print("  " + rows.get(i));
            if (i < rows.size() - 1) w.print(",");
            w.println();
        }
        w.println("]"); w.close();
        println("ExportCalls: " + n + " call edges -> " + new File(outDir, "calls.json").getAbsolutePath());
    }
}
