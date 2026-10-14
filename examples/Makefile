# 编译反编译测试程序：demo（含调试符号）+ demo_stripped（剥离符号）
CC      ?= cc
CFLAGS  ?= -O0 -Wall -Wextra

.PHONY: all clean
all: demo demo_stripped

demo: demo.c
	$(CC) $(CFLAGS) -g -o demo demo.c

# 剥离符号版本，用于验证无符号二进制（REA 仍能恢复函数与常量）
demo_stripped: demo
	cp demo demo_stripped
	strip demo_stripped

clean:
	rm -f demo demo_stripped
