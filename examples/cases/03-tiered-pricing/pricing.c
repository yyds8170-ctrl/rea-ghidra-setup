/*
 * 03-tiered-pricing —— 阶梯计价（比 demo 更完整）
 *
 * 规则（qty=数量，total=未折前总价）：
 *   数量 >= 100(0x64) ：折扣 = total * 20 / 100（八折，常量 20=0x14）
 *   数量 >= 10 (0x0a) ：折扣 = total * 10 / 100（九折，常量 10=0x0a）
 *   否则             ：折扣 = 0
 *   若 total >= 1000(0x3E8) ：再立减 50（0x32）
 *   应付 = total - 折扣
 *
 * 逆向要点（与断言对应）：
 *   - 反编译文本应能看到阈值常量 10(0xa)、100(0x64) 与满减常量 50(0x32)。
 *   - 这些常量在 -O0 下以立即数形式保留，strip 后仍可被识别。
 */
#include <stdio.h>
#include <stdlib.h>

/* 返回应付金额（元，整数） */
long compute_price(long total, long qty) {
    long discount = 0;

    if (qty >= 100) {            /* 0x64 */
        discount = total * 20 / 100;   /* 0x14 */
    } else if (qty >= 10) {      /* 0xa */
        discount = total * 10 / 100;   /* 0xa */
    }

    if (total >= 1000) {         /* 0x3E8 */
        discount += 50;          /* 0x32 立减 */
    }

    long payable = total - discount;
    if (payable < 0) {
        payable = 0;
    }
    return payable;
}

int main(int argc, char **argv) {
    long total = (argc > 1) ? atol(argv[1]) : 1200;
    long qty   = (argc > 2) ? atol(argv[2]) : 7;

    printf("total=%ld qty=%ld payable=%ld\n", total, qty, compute_price(total, qty));
    return 0;
}
