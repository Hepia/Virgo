#!/bin/bash

set -e

DIR="$1"
if [ -z "$DIR" ]; then
  echo "Usage: $0 <directory>"
  exit 1
fi

echo "Traitement des fichiers .c dans : $DIR"

# Fonction pour savoir si une position (offset) est dans un bloc commentaire /* ... */
is_offset_in_comment() {
  local text="$1"
  local offset="$2"

  # Compte le nombre d'occurrences /* avant offset
  local before=${text:0:offset}
  local open_count=$(grep -o "/\*" <<< "$before" | wc -l)
  local close_count=$(grep -o "\*/" <<< "$before" | wc -l)

  # Si plus de /* ouverts que fermés avant offset => dans commentaire
  if (( open_count > close_count )); then
    return 0
  else
    return 1
  fi
}

for c_file in "$DIR"/*.c; do
  [ -e "$c_file" ] || continue

  echo "Traitement de $c_file"

  # Trouve la dernière ligne #include
  last_include_line=$(grep -n '^#include' "$c_file" | tail -1 | cut -d: -f1)
  if [ -z "$last_include_line" ]; then
    echo "  Pas de #include trouvé, saut."
    continue
  fi

  # Extraction des déclarations static ou static inline après la dernière include
  mapfile -t static_decls < <(sed -n "$((last_include_line + 1)),\$p" "$c_file" | grep -P '^\s*static(\s+inline)?\s+[^(]+\([^;{]*\);\s*$')

  if [ ${#static_decls[@]} -eq 0 ]; then
    echo "  Aucune déclaration static inline après #include."
    continue
  fi

  # Charger le contenu complet du fichier en une seule ligne (sans retour chariot)
  full_text=$(tr '\n' ' ' < "$c_file")

  for decl in "${static_decls[@]}"; do
    # Extraire nom fonction
    func_name=$(echo "$decl" | sed -E 's/^\s*static(\s+inline)?\s+[^(]+\s+([a-zA-Z0-9_]+)\s*\(.*/\2/')
    if [ -z "$func_name" ]; then
      echo "  Impossible d'extraire nom fonction dans : $decl"
      continue
    fi

    # Trouver ligne déclaration dans le fichier original
    decl_line=$(grep -nF -- "$decl" "$c_file" | cut -d: -f1 | head -1)

    # Chercher déclaration dans full_text (on cherche la position)
    decl_pos=$(echo "$full_text" | grep -b -oF "$decl" | cut -d: -f1 | head -1)
    if [ -z "$decl_pos" ]; then
      echo "  Déclaration '$func_name' non trouvée dans texte complet ?"
      continue
    fi

    # Vérifier si déclaration est dans un commentaire
    if is_offset_in_comment "$full_text" "$decl_pos"; then
      echo "  La déclaration de '$func_name' est dans un bloc commentaire. On ne modifie pas."
      continue
    fi

    # Chercher définition static ou static inline de la fonction dans full_text
    def_regex="static(\s+inline)?[[:space:]]+[a-zA-Z0-9_]+[[:space:]]+${func_name}[[:space:]]*\([^)]*\)[[:space:]]*\{"
    def_pos=$(echo "$full_text" | grep -b -oP "$def_regex" | cut -d: -f1 | head -1)

    if [ -z "$def_pos" ]; then
      echo "  Fonction '$func_name' non définie. Commentaire de la déclaration."
      # Commenter dans le fichier source si pas déjà commentée
      if ! sed -n "${decl_line}p" "$c_file" | grep -q '^[[:space:]]*//'; then
        sed -i "${decl_line}s/^/\/\//" "$c_file"
      fi
      continue
    fi

    # Vérifier si définition est dans un commentaire
    if is_offset_in_comment "$full_text" "$def_pos"; then
      echo "  Fonction '$func_name' définie mais dans un bloc commentaire. Commentaire de la déclaration."
      if ! sed -n "${decl_line}p" "$c_file" | grep -q '^[[:space:]]*//'; then
        sed -i "${decl_line}s/^/\/\//" "$c_file"
      fi
      continue
    fi

    echo "  Fonction '$func_name' définie, déclaration conservée."
  done
done

echo "Traitement terminé."
