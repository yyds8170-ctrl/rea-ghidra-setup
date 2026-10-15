# =============================================================================
# examples/cases/Makefile —— 端到端逆向案例库的统一构建
#
# 目标：把 5 个案例分别编译为「带符号版」与「strip 版」，全部输出到 build/。
#   带符号版：保留函数名，用于验证 Ghidra 能恢复函数名 / 调用边。
#   strip 版：cp + strip，用于验证「无符号时关键常量 / 字符串仍可被识别」。
#
# 确定性编译参数（与研究结论一致）：
#   gcc -O0 -g -fno-builtin -Wall -Wextra
# =============================================================================

CC      ?= cc
CFLAGS  ?= -O0 -g -fno-builtin -Wall -Wextra

BUILD   := build

# 案例名 -> 源文件
CASES := 01-crackme-password 02-license-key 03-tiered-pricing 04-switch-dispatch 05-export-flow

SRC_01 := 01-crackme-password/crackme.c
SRC_02 := 02-license-key/license.c
SRC_03 := 03-tiered-pricing/pricing.c
SRC_04 := 04-switch-dispatch/dispatch.c
SRC_05 := 05-export-flow/flow.c

# 每个案例产出两个二进制：<name> 与 <name>-stripped
BINARIES := $(addprefix $(BUILD)/,$(CASES))
STRIPPED := $(addsuffix -stripped,$(BINARIES))

.PHONY: all clean
all: $(BUILD) $(BINARIES) $(STRIPPED)

$(BUILD):
	mkdir -p $(BUILD)

# 带符号版
$(BUILD)/01-crackme-password: $(SRC_01) | $(BUILD)
	$(CC) $(CFLAGS) -o $@ $<
$(BUILD)/02-license-key: $(SRC_02) | $(BUILD)
	$(CC) $(CFLAGS) -o $@ $<
$(BUILD)/03-tiered-pricing: $(SRC_03) | $(BUILD)
	$(CC) $(CFLAGS) -o $@ $<
$(BUILD)/04-switch-dispatch: $(SRC_04) | $(BUILD)
	$(CC) $(CFLAGS) -o $@ $<
$(BUILD)/05-export-flow: $(SRC_05) | $(BUILD)
	$(CC) $(CFLAGS) -o $@ $<

# strip 版：先复制再 strip
$(BUILD)/%-stripped: $(BUILD)/%
	cp $< $@
	strip $@

clean:
	rm -rf $(BUILD)
