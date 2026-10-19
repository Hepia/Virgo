# Compiler and flags can be overridden from environment
CC ?= gcc
CROSS_COMPILE ?=

# Default flags
CFLAGS ?= -Wall -O2
CFLAGS += -I../include
LDFLAGS ?= -ljson-c -lcrypto

# Target binary
TARGET = mmc-vm-daemon
OBJS = mmc-vm-daemon.o ../utils/mmc_common.o ../utils/mmc_config.o

# Prefix all compiler tools with cross-compile prefix if set
CC := $(CROSS_COMPILE)$(CC)

all: $(TARGET)

../utils/mmc_common.o: ../utils/mmc_common.c
	$(CC) $(CFLAGS) -c $< -o $@

../utils/mmc_config.o: ../utils/mmc_config.c
	$(CC) $(CFLAGS) -c $< -o $@

$(TARGET): $(OBJS)
	$(CC) $(OBJS) -o $@ $(LDFLAGS)

clean:
	rm -f $(TARGET) *.o ../utils/*.o

.PHONY: all clean 