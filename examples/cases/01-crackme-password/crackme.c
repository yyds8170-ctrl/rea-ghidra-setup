/*
 * 01-crackme-password —— 经典口令校验 crackme
 *
 * 目标：输入口令与硬编码串 "S3cr3t-2026" 用 strcmp 比较，
 *       匹配则打印 "ACCESS GRANTED"，否则打印 "ACCESS DENIED"。
 *
 * 逆向要点（与断言对应）：
 *   - 字符串表（strings.json）应能看到 "S3cr3t-2026" 与 "ACCESS GRANTED"。
 *   - 函数表（functions.json）应能看到 check_password。
 *   - 调用边（calls.json）应出现对 strcmp 的调用。
 *
 * 编译：gcc -O0 -g -fno-builtin -Wall -Wextra（见统一 Makefile）
 */
#include <stdio.h>
#include <string.h>

#define TRUE_PASSWORD "S3cr3t-2026"

/* 返回 1 表示口令正确，0 表示错误 */
int check_password(const char *input) {
    /* -fno-builtin 保证 strcmp 以真实库函数调用形式保留在调用图中 */
    if (input != NULL && strcmp(input, TRUE_PASSWORD) == 0) {
        return 1;
    }
    return 0;
}

int main(int argc, char **argv) {
    const char *input = (argc > 1) ? argv[1] : "";

    if (check_password(input)) {
        printf("ACCESS GRANTED\n");
        return 0;
    }

    printf("ACCESS DENIED\n");
    printf("usage: %s <password>\n", argv[0]);
    return 1;
}
