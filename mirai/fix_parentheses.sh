#!/bin/bash

if [ -z "$1" ]; then
  echo "Usage: $0 <source_directory>"
  exit 1
fi

SRC_DIR="$1"
FILE="util.c"
LINE=121
TARGET="$SRC_DIR/$FILE"

if [ ! -f "$TARGET" ]; then
  echo "File $TARGET not found."
  exit 1
fi

echo "Before modification (line $LINE):"
sed -n "${LINE}p" "$TARGET"

# Define the original line (pattern) and replacement
ORIGINAL='if (any < 0 || acc > cutoff || acc == cutoff && c > cutlim)'
REPLACEMENT='if (any < 0 || acc > cutoff || (acc == cutoff && c > cutlim))'

# Use sed with a condition: only replace line 121 if it matches the original line pattern
sed -i "${LINE}{/$(echo "$ORIGINAL" | sed 's/[]\/$*.^[]/\\&/g')/c\\
$REPLACEMENT
}" "$TARGET"

echo "After modification (line $LINE):"
sed -n "${LINE}p" "$TARGET"
