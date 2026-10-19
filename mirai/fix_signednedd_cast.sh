#!/bin/bash

if [ -z "$1" ]; then
  echo "Usage: $0 <source_directory>"
  exit 1
fi

SRC_DIR="$1"

# Helper function to add cast for rand_alphastr calls in attack_app.c
fix_rand_alphastr() {
  local file="$SRC_DIR/attack_app.c"
  if [ ! -f "$file" ]; then
    echo "File attack_app.c not found in $SRC_DIR"
    return
  fi

  # Use sed to add (uint8_t *) cast to first argument of rand_alphastr calls on lines 993 and 1054
  sed -i -e '993s/rand_alphastr(\([^,]*\)/rand_alphastr((uint8_t *)\1/' \
         -e '1054s/rand_alphastr(\([^,]*\)/rand_alphastr((uint8_t *)\1/' "$file"
  echo "Fixed rand_alphastr casts in attack_app.c at lines 993 and 1054"
}

# Helper function to add cast for resolv_skip_name calls in resolv.c
fix_resolv_skip_name() {
  local file="$SRC_DIR/resolv.c"
  if [ ! -f "$file" ]; then
    echo "File resolv.c not found in $SRC_DIR"
    return
  fi

  # Lines with calls: 181 and 207 (and also 206 sometimes).
  # We'll add cast on first two arguments: (uint8_t *)arg1, (uint8_t *)arg2

  # sed to add casts on line 181
  sed -i -e '181s/resolv_skip_name(\([^,]*\), \([^,)]*\)/resolv_skip_name((uint8_t *)\1, (uint8_t *)\2/' \
         -e '206,207s/resolv_skip_name(\([^,]*\), \([^,)]*\)/resolv_skip_name((uint8_t *)\1, (uint8_t *)\2/' "$file"

  echo "Fixed resolv_skip_name casts in resolv.c at lines 181, 206, and 207"
}

fix_rand_alphastr
fix_resolv_skip_name
