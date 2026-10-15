/*
 * 04-switch-dispatch —— 命令分派（switch/case 跳转表）
 *
 * dispatch(cmd) 按 cmd 值分派到四个子命令函数：
 *   1 -> do_login   打印 "login-menu"
 *   2 -> do_buy     打印 "buy-menu"
 *   3 -> do_about   打印 "about-menu"
 *   4 -> do_exit    打印 "exit-menu"
 *
 * 逆向要点（与断言对应）：
 *   - 字符串表应包含 "login-menu"/"buy-menu"/"about-menu"/"exit-menu"。
 *   - 调用边应出现 dispatch -> do_login / do_buy / do_exit。
 *   - -O0 下 switch 通常被编译为 if-else 链或跳转表，
 *     这里只断言调用边，不强求一定看到 switch 语法。
 */
#include <stdio.h>
#include <stdlib.h>

int do_login(void) {
    printf("login-menu\n");
    return 0;
}

int do_buy(void) {
    printf("buy-menu\n");
    return 0;
}

int do_about(void) {
    printf("about-menu\n");
    return 0;
}

int do_exit(void) {
    printf("exit-menu\n");
    return 0;
}

int dispatch(int cmd) {
    switch (cmd) {
        case 1:  return do_login();
        case 2:  return do_buy();
        case 3:  return do_about();
        case 4:  return do_exit();
        default: printf("unknown-cmd\n"); return -1;
    }
}

int main(int argc, char **argv) {
    int cmd = (argc > 1) ? atoi(argv[1]) : 0;
    return dispatch(cmd);
}
