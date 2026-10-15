/*
 * 02-license-key —— 序列号校验（逐字节异或 + 求和）
 *
 * 算法：把输入 key 的每个字节先与 0x5A 异或，再累加求和，
 *       最终和与魔数 439（0x1B7）比较，相等即合法。
 *
 * 正确 key（已真实核算）："A6868"
 *   A(0x41)^0x5A = 0x1B = 27
 *   6(0x36)^0x5A = 0x6C = 108
 *   8(0x38)^0x5A = 0x62 = 98
 *   6(0x36)^0x5A = 0x6C = 108
 *   8(0x38)^0x5A = 0x62 = 98
 *   求和 = 27+108+98+108+98 = 439 = 0x1B7
 *
 * 逆向要点（与断言对应）：
 *   - 反编译文本（decompiled.json）应同时出现异或常量
 *     0x5a（十进制 90）与魔数 0x1b7（十进制 439）。
 *   - 即使 strip 掉符号，常量与字符串仍在反编译中可见。
 */
#include <stdio.h>
#include <string.h>

#define XOR_KEY   0x5A
#define EXPECTED  439   /* 0x1B7 */

/* 返回 1 表示序列号合法 */
int verify_key(const char *key) {
    if (key == NULL) {
        return 0;
    }
    long sum = 0;
    size_t n = strlen(key);
    for (size_t i = 0; i < n; i++) {
        sum += (long)(key[i] ^ XOR_KEY);
    }
    return (sum == EXPECTED) ? 1 : 0;
}

int main(int argc, char **argv) {
    const char *key = (argc > 1) ? argv[1] : "";

    if (verify_key(key)) {
        printf("LICENSE OK\n");
        return 0;
    }

    printf("LICENSE INVALID\n");
    printf("usage: %s <serial>\n", argv[0]);
    return 1;
}
