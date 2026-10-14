#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/*
 * Windows PE 不像 ELF 那样在默认符号表里保留函数名（名字在独立的 PDB 中）。
 * 为了让跨平台的 verify 都能按函数名反编译，在 Windows 上把两个目标函数
 * 放进 PE 导出表（Ghidra 会据此命名）；ELF 上该宏为空，行为不变。
 */
#if defined(_WIN32) || defined(__CYGWIN__)
#define REA_EXPORT __declspec(dllexport)
#else
#define REA_EXPORT
#endif

REA_EXPORT int secret_check(int code) {
    if (code == 1337) return 1;
    if (code > 9000) return 2;
    return 0;
}

REA_EXPORT int calc_discount(int total, int qty) {
    int d = 0;
    if (qty >= 10) d = total * 15 / 100;
    else if (qty >= 5) d = total * 10 / 100;
    if (total > 1000) d += 50;
    return d;
}

int main(int argc, char **argv) {
    int code = argc > 1 ? atoi(argv[1]) : 0;
    printf("check=%d discount=%d\n", secret_check(code), calc_discount(1200, 7));
    return 0;
}
