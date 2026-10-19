#!/bin/bash

set -e

DIR="$1"
if [ -z "$DIR" ]; then
  echo "Usage: $0 <directory>"
  exit 1
fi

echo "Traitement des headers dans : $DIR"

for header_file in "$DIR"/*.h; do
  [ -e "$header_file" ] || continue

  echo "Traitement du header : $header_file"

  # Extraire toutes les déclarations static non commentées (une par ligne)
  mapfile -t static_lines < <(grep -P '^\s*static\s.*;\s*$' "$header_file" | grep -v '^\s*//')

  if [ ${#static_lines[@]} -eq 0 ]; then
    echo "  Aucune déclaration static trouvée."
    continue
  fi

  # Commenter toutes les déclarations static non commentées dans le header
  sed -i '/^\s*static.*;\s*$/ { /^[[:space:]]*\/\//! s/^/\/\// }' "$header_file"
  echo "  Déclarations static commentées dans $header_file"

  base_name=$(basename "$header_file" .h)
  c_file="$DIR/$base_name.c"
  if [ ! -f "$c_file" ]; then
    echo "  Fichier source $c_file non trouvé, saut."
    continue
  fi

  echo "  Ajout des déclarations dans $c_file"

  # Trouver la dernière ligne d'#include dans le fichier .c
  last_include_line=$(grep -n '^#include' "$c_file" | tail -1 | cut -d: -f1)
  if [ -z "$last_include_line" ]; then
    # Pas d'include : insérer en début
    insert_line=1
  else
    insert_line=$((last_include_line + 1))
  fi

  # Insertion ligne par ligne après la dernière include
  # On insère les lignes dans l'ordre inverse pour que ça reste dans l'ordre dans le fichier
  for (( idx=${#static_lines[@]}-1 ; idx>=0 ; idx-- )); do
    line="${static_lines[idx]}"
    # Échapper les '/' pour sed
    esc_line=$(printf '%s\n' "$line" | sed 's/\//\\\//g')
    sed -i "${insert_line}i ${esc_line}" "$c_file"
  done

  echo "  Déclarations static insérées après ligne $last_include_line."

done

echo "Terminé."
