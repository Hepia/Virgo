CC ?= gcc
CFLAGS ?= -Wall -Wextra -O2
TARGET = vm_daemon

all: $(TARGET)

$(TARGET): vm_daemon.c
	$(CC) $(CFLAGS) -o $(TARGET) vm_daemon.c

clean:
	rm -f $(TARGET)
