#!/bin/bash

if [ -z "$1" ]; then
  echo "Usage: $0 <repo_directory>"
  exit 1
fi

REPO_DIR="$1"

cd "$REPO_DIR" || { echo "Directory $REPO_DIR not found"; exit 1; }

declare -A vars_to_fix

# Format: filename:linenumber="var1 var2 var3"
vars_to_fix["table.c:82"]="val"
vars_to_fix["table.c:97"]="val"
vars_to_fix["killer.c:262"]="pid"
vars_to_fix["attack.c:26"]="i"
vars_to_fix["attack_app.c:28"]="rfd"
vars_to_fix["attack_app.c:862"]="generic_memes"
vars_to_fix["attack_app.c:857"]="rfd"
vars_to_fix["attack_udp.c:405"]="data"
vars_to_fix["attack_udp.c:404"]="udph"
vars_to_fix["attack_udp.c:403"]="iph"
vars_to_fix["attack_gre.c:201"]="ent1 ent2 ent3"
vars_to_fix["checksum.c:30"]="length"
vars_to_fix["resolv.c:158"]="dnsa"

echo "Processing unused variable warnings..."

# Group variables by file for efficiency
declare -A file_vars_lines

for key in "${!vars_to_fix[@]}"; do
  filename="${key%%:*}"
  lineno="${key#*:}"
  lineno="${lineno%%:*}"
  varnames="${vars_to_fix[$key]}"

  for varname in $varnames; do
    file_vars_lines["$filename"]+="$lineno:$varname "
  done
done

for file in "${!file_vars_lines[@]}"; do
  if [ ! -f "$file" ]; then
    echo "File $file not found, skipping."
    continue
  fi

  echo "Fixing $file..."

  IFS=' ' read -r -a entries <<< "${file_vars_lines[$file]}"

  # Build array of line/variable pairs
  declare -a line_vars=()
  for entry in "${entries[@]}"; do
    line="${entry%%:*}"
    var="${entry#*:}"
    line_vars+=("$line:$var")
  done

  # Sort lines descending to avoid messing line numbers
  IFS=$'\n' sorted=($(sort -r -n <<<"${line_vars[*]}"))
  unset IFS

  for lv in "${sorted[@]}"; do
    lineno="${lv%%:*}"
    varname="${lv#*:}"

    insert_line=$((lineno + 1))

    # Check if already inserted to avoid duplicates
    next_line=$(sed -n "${insert_line}p" "$file" | tr -d '[:space:]')
    void_line="(void)$varname;"

    if [[ "$next_line" != "$void_line" ]]; then
      sed -i "${insert_line}i \    (void)${varname};" "$file"
      echo "  Inserted '(void)${varname};' after line $lineno"
    else
      echo "  '(void)${varname};' already present after line $lineno"
    fi
  done

done

echo "Done fixing unused variables."


# #!/bin/bash

# if [ -z "$1" ]; then
#   echo "Usage: $0 <repo_directory>"
#   exit 1
# fi

# REPO_DIR="$1"

# cd "$REPO_DIR" || { echo "Directory $REPO_DIR not found"; exit 1; }

# declare -A vars_to_fix

# # Add unused variable warnings here:
# # Format: filename:linenumber:variable_name
# # (Extraits directement de tes warnings)

# vars_to_fix["table.c:82"]="val"
# vars_to_fix["table.c:97"]="val"
# vars_to_fix["killer.c:262"]="pid"
# vars_to_fix["attack.c:26"]="i"
# vars_to_fix["attack_app.c:28"]="rfd"
# vars_to_fix["attack_app.c:862"]="generic_memes"
# vars_to_fix["attack_app.c:857"]="rfd"
# vars_to_fix["attack_udp.c:405"]="data"
# vars_to_fix["attack_udp.c:404"]="udph"
# vars_to_fix["attack_udp.c:403"]="iph"
# vars_to_fix["attack_gre.c:201"]="ent1"
# vars_to_fix["attack_gre.c:201"]="ent2"
# vars_to_fix["attack_gre.c:201"]="ent3"
# vars_to_fix["checksum.c:30"]="length"
# vars_to_fix["resolv.c:158"]="dnsa"

# echo "Processing unused variable warnings..."

# # We will group by file for efficiency
# declare -A file_vars_lines

# for key in "${!vars_to_fix[@]}"; do
#   filename="${key%%:*}"
#   lineno="${key#*:}"
#   lineno="${lineno%%:*}"
#   varname="${vars_to_fix[$key]}"
#   file_vars_lines["$filename"]+="$lineno:$varname "
# done

# for file in "${!file_vars_lines[@]}"; do
#   if [ ! -f "$file" ]; then
#     echo "File $file not found, skipping."
#     continue
#   fi

#   echo "Fixing $file..."

#   # Read lines to insert in array for sorting by line descending
#   IFS=' ' read -r -a entries <<< "${file_vars_lines[$file]}"

#   # Build array of line/variable pairs
#   declare -a line_vars=()
#   for entry in "${entries[@]}"; do
#     line="${entry%%:*}"
#     var="${entry#*:}"
#     line_vars+=("$line:$var")
#   done

#   # Sort lines descending (to insert from bottom to top to keep line numbers consistent)
#   IFS=$'\n' sorted=($(sort -r -n <<<"${line_vars[*]}"))
#   unset IFS

#   for lv in "${sorted[@]}"; do
#     lineno="${lv%%:*}"
#     varname="${lv#*:}"

#     insert_line=$((lineno + 1))

#     # Check if already `(void)variable;` exists just after declaration (avoid double insert)
#     next_line=$(sed -n "${insert_line}p" "$file" | tr -d '[:space:]')
#     void_line="(void)$varname;"

#     if [[ "$next_line" != "$void_line" ]]; then
#       # Insert the line
#       sed -i "${insert_line}i \    (void)${varname};" "$file"
#       echo "  Inserted '(void)${varname};' after line $lineno"
#     else
#       echo "  '(void)${varname};' already present after line $lineno"
#     fi
#   done

# done

# echo "Done fixing unused variables."
