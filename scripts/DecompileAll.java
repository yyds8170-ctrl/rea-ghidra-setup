// DecompileAll.java
//
// Ghidra headless 脚本：反编译程序中的所有函数。
//   脚本参数 1：输出目录（必填）
//   脚本参数 2：模式，separate（每个函数一个 .c，默认）或 combined（合并为一个 decompiled.c）
//
// 经 analyzeHeadless -postScript 调用，不依赖 REA / Node / npm。
// @category Reverse Engineering

import ghidra.app.script.GhidraScript;
import ghidra.app.decompiler.DecompInterface;
import ghidra.app.decompiler.DecompileResults;
import ghidra.program.model.listing.Function;
import ghidra.program.model.listing.FunctionIterator;
import ghidra.program.model.listing.FunctionManager;

import java.io.File;
import java.io.PrintWriter;

public class DecompileAll extends GhidraScript {

    @Override
    public void run() throws Exception {
        String[] args = getScriptArgs();
        if (args.length < 1) {
            println("DecompileAll: 缺少输出目录参数");
            return;
        }
        File outDir = new File(args[0]);
        boolean combined = args.length > 1 && args[1].equals("combined");
        outDir.mkdirs();

        DecompInterface decomp = new DecompInterface();
        decomp.openProgram(currentProgram);

        FunctionManager fm = currentProgram.getFunctionManager();
        FunctionIterator funcs = fm.getFunctions(true);

        PrintWriter combinedWriter = combined
                ? new PrintWriter(new File(outDir, "decompiled.c")) : null;

        int count = 0;
        for (Function f : funcs) {
            if (monitor.isCancelled()) {
                break;
            }
            DecompileResults res = decomp.decompileFunction(f, 60, monitor);
            if (res != null && res.decompileCompleted() && res.getDecompiledFunction() != null) {
                String code = res.getDecompiledFunction().getC();
                if (combined) {
                    combinedWriter.println(code);
                    combinedWriter.println();
                } else {
                    String safe = f.getName().replaceAll("[^A-Za-z0-9_]", "_");
                    File outFile = new File(outDir, safe + ".c");
                    try (PrintWriter w = new PrintWriter(outFile)) {
                        w.print(code);
                    }
                }
                count++;
            }
        }

        if (combinedWriter != null) {
            combinedWriter.close();
        }
        decomp.dispose();
        println("DecompileAll: wrote " + count + " functions to " + outDir.getAbsolutePath()
                + (combined ? " (combined)" : " (separate)"));
    }
}
