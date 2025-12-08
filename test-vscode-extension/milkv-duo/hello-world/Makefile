TARGET=helloworld

ifeq (,$(TOOLCHAIN_PREFIX))
TOOLCHAIN_PREFIX = ~/work/ruyi-litester/test-vscode-extension/myhone-venv/bin/riscv64-unknown-linux-musl-
endif

ifeq (,$(CFLAGS))
# 如果设置了QEMU=1，使用QEMU兼容的架构选项（去掉xthead扩展）
ifeq ($(QEMU),1)
CFLAGS = -march=rv64gc -mabi=lp64d -mcmodel=medany -O2 -g
else
# 默认使用Milkv Duo优化的架构选项
CFLAGS = -mcpu=c906fdv -march=rv64imafdcv0p7xthead -mcmodel=medany -mabi=lp64d -O2 -g
endif
endif

ifeq (,$(LDFLAGS))
LDFLAGS = -D_LARGEFILE_SOURCE -D_LARGEFILE64_SOURCE -D_FILE_OFFSET_BITS=64 -static
endif

CC = $(TOOLCHAIN_PREFIX)gcc

SOURCE = $(wildcard *.c)
OBJS = $(patsubst %.c,%.o,$(SOURCE))

$(TARGET): $(OBJS)
	$(CC) $(CFLAGS) -o $@ $(OBJS) $(LDFLAGS)

%.o: %.c
	$(CC) $(CFLAGS) -o $@ -c $<

.PHONY: clean
clean:
	@rm *.o -rf
	@rm $(OBJS) -rf
	@rm $(TARGET)
