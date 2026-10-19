# Nom de l'exécutable
TARGET = encoder

# Fichiers source
SRCS = encoder.c

# Fichiers objets
OBJS = $(SRCS:.c=.o)

# Flags de compilation
CFLAGS = -Wall -Wextra -O2
LDFLAGS = -lcjson

# Cible par défaut
all: $(TARGET)

# Compilation de l'exécutable
$(TARGET): $(OBJS)
	$(CC) $(CFLAGS) -o $@ $^ $(LDFLAGS)

# Compilation des .o
%.o: %.c
	$(CC) $(CFLAGS) -c $< -o $@

# Nettoyage des fichiers générés
clean:
	rm -f $(TARGET) $(OBJS)

.PHONY: all clean
