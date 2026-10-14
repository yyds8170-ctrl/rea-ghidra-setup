#include <stdio.h>
#include <string.h>

int secret_check(int code) {
    if (code == 1337) return 1;
    if (code > 9000) return 2;
    return 0;
}

int calc_discount(int total, int qty) {
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
