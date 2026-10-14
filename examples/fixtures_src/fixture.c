/* fixture.c — 多架构 fixture 回归用最小 C 样例（源码入库，编译产物进 examples/fixtures/ 并 gitignore）。
   含已知函数名/字符串，供 Ghidra 跨架构导出断言。 */
int secret_check(int x) { return x * 1337; }
int calc_discount(int p) { return p * 8 / 10; }
const char *greeting(void) { return "hello-fixture-2026"; }
int main(int c, char **a) { return secret_check(c) + calc_discount(c); }
