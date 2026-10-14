// ExportStrings.java — Ghidra headless：导出已定义字符串为 JSON（strings.json）。
// 脚本参数 1：输出目录。字段：address、value、length。
// 归本仓库 PolyForm Noncommercial 1.0.0 许可（原创代码）。
// @category REA Export
import ghidra.app.script.GhidraScript;
import ghidra.program.model.listing.Data;
import ghidra.program.model.listing.DataIterator;

import java.io.File;
import java.io.PrintWriter;
import java.util.ArrayList;
import java.util.List;

public class ExportStrings extends GhidraScript {
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
        if (a.length < 1) { println("ExportStrings: 缺少输出目录"); return; }
        File outDir = new File(a[0]); outDir.mkdirs();
        DataIterator it = currentProgram.getListing().getDefinedData(true);
        List<String> rows = new ArrayList<>();
        int n = 0;
        while (it.hasNext()) {
            if (monitor.isCancelled()) break;
            Data d = it.next();
            try {
                if (d.hasStringValue()) {
                    Object v = d.getValue();
                    if (v instanceof String) {
                        String str = (String) v;
                        rows.add("{\"address\":\"" + d.getAddress() + "\",\"value\":\"" + esc(str)
                                + "\",\"length\":" + str.length() + "}");
                        n++;
                    }
                }
            } catch (Exception e) { /* skip */ }
        }
        PrintWriter w = new PrintWriter(new File(outDir, "strings.json"), "UTF-8");
        w.println("[");
        for (int i = 0; i < rows.size(); i++) {
            w.print("  " + rows.get(i));
            if (i < rows.size() - 1) w.print(",");
            w.println();
        }
        w.println("]"); w.close();
        println("ExportStrings: " + n + " strings -> " + new File(outDir, "strings.json").getAbsolutePath());
    }
}
