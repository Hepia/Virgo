CC ?= gcc
CFLAGS ?= -Wall -Wextra -O2
TARGET = host_daemon

all: $(TARGET)

$(TARGET): host_daemon.c
	$(CC) $(CFLAGS) -o $(TARGET) host_daemon.c

clean:
	rm -f $(TARGET)
