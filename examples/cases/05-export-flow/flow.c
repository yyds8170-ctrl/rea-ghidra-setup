/*
 * 05-export-flow —— 演示“函数/字符串/导入/调用图”四类导出齐全
 *
 * 这是一个含多个 libc 导入（printf/strlen/strcmp）的小程序，
 * 用来跑 ghidra-export --kind all，验证：
 *   functions.json 非空
 *   strings.json   非空
 *   calls.json     非空
 *   symbols.json   非空（且能识别出 printf/strlen/strcmp 等导入名）
 */
#include <stdio.h>
#include <string.h>

int greet(const char *name) {
    char buf[64];
    size_t n = strlen(name);
    snprintf(buf, sizeof(buf), "hello:%s", name);
    if (strcmp(name, "admin") == 0) {
        printf("admin-greet len=%zu\n", n);
    } else {
        printf("greet: %s\n", buf);
    }
    return 0;
}

int main(int argc, char **argv) {
    const char *name = (argc > 1) ? argv[1] : "world";
    greet(name);
    return 0;
}
