#!/bin/bash

set -euo pipefail

ENV_FILE="${3:-.env}"

trim() {
    local value="$1"
    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"
    printf '%s' "$value"
}

# 1. Validation: Check arguments
if [[ $# -lt 2 || $# -gt 3 ]]; then
    echo "Usage: $0 <source_template_file> <output_destination_file> [env_file]"
    echo "Example: $0 config_template.cfg config.cfg .env"
    exit 1
fi

SOURCE_FILE="$1"
OUTPUT_FILE="$2"

if [[ ! -f "$SOURCE_FILE" ]]; then
    echo "Error: Source file '$SOURCE_FILE' not found."
    exit 1
fi

if [[ "$SOURCE_FILE" == "$OUTPUT_FILE" ]]; then
    echo "Error: Source and output files must be different."
    exit 1
fi

# 2. Load .env safely
if [[ -f "$ENV_FILE" ]]; then
    while IFS= read -r raw_line || [[ -n "$raw_line" ]]; do
        line="${raw_line%$'\r'}"
        line="$(trim "$line")"

        # Skip comments and empty lines
        [[ -z "$line" || "$line" == \#* ]] && continue

        if [[ "$line" != *"="* ]]; then
            echo "Warning: Skipping invalid line in $ENV_FILE: $line"
            continue
        fi

        key="$(trim "${line%%=*}")"
        value="$(trim "${line#*=}")"
        key="${key#export }"
        key="$(trim "$key")"

        if [[ ! "$key" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
            echo "Warning: Skipping invalid variable name '$key' in $ENV_FILE"
            continue
        fi

        # Handle quoted values and optional inline comments.
        if [[ "$value" =~ ^\"(.*)\"[[:space:]]*(#.*)?$ ]]; then
            value="${BASH_REMATCH[1]}"
            value="${value//\\\"/\"}"
            value="${value//\\\\/\\}"
        elif [[ "$value" =~ ^\'(.*)\'[[:space:]]*(#.*)?$ ]]; then
            value="${BASH_REMATCH[1]}"
        else
            if [[ "$value" =~ ^(.*[^[:space:]])[[:space:]]+#.*$ ]]; then
                value="${BASH_REMATCH[1]}"
            fi
            value="$(trim "$value")"
        fi

        export "$key=$value"
    done <"$ENV_FILE"
else
    echo "Notice: $ENV_FILE not found; using system environment variables only."
fi

# 3. Process the template (handles {{VAR}} and {{VAR:-default}})
render_template() {
    local source="$1"
    local target="$2"
    local line full key default replacement has_default rest rendered before

    : >"$target"

    while IFS= read -r line || [[ -n "$line" ]]; do
        # In YAML templates, ignore full-line comments so commented placeholders
        # do not require env values.
        if [[ "$source" =~ \.ya?ml$ && "$line" =~ ^[[:space:]]*# ]]; then
            printf '%s\n' "$line" >>"$target"
            continue
        fi

        rest="$line"
        rendered=""
        while [[ "$rest" =~ \{\{([A-Za-z_][A-Za-z0-9_]*)(:-([^}]*))?\}\} ]]; do
            full="${BASH_REMATCH[0]}"
            key="${BASH_REMATCH[1]}"
            has_default="${BASH_REMATCH[2]-}"
            default="${BASH_REMATCH[3]-}"

            if [[ "${!key+x}" == "x" ]]; then
                replacement="${!key}"
            elif [[ -n "$has_default" ]]; then
                replacement="$default"
            else
                replacement="$full"
            fi

            before="${rest%%"$full"*}"
            rendered+="$before$replacement"
            rest="${rest#*"$full"}"
        done
        line="$rendered$rest"
        printf '%s\n' "$line" >>"$target"
    done <"$source"
}

TMP_OUTPUT="$(mktemp)"
trap 'rm -f "$TMP_OUTPUT"' EXIT
render_template "$SOURCE_FILE" "$TMP_OUTPUT"
mv "$TMP_OUTPUT" "$OUTPUT_FILE"
trap - EXIT

# 4. Final validation: check for unreplaced placeholders
if [[ "$SOURCE_FILE" =~ \.ya?ml$ ]]; then
    MISSING_VARS="$(awk '!/^[[:space:]]*#/' "$OUTPUT_FILE" | grep -oE '\{\{[A-Za-z_][A-Za-z0-9_]*(:-[^}]*)?\}\}' | sort -u || true)"
else
    MISSING_VARS="$(grep -oE '\{\{[A-Za-z_][A-Za-z0-9_]*(:-[^}]*)?\}\}' "$OUTPUT_FILE" | sort -u || true)"
fi

if [[ -n "$MISSING_VARS" ]]; then
    echo "--------------------------------------------------------"
    echo "WARNING: The following placeholders were not replaced:"
    echo "$MISSING_VARS"
    echo "Check if these are defined in $ENV_FILE or have defaults."
    echo "--------------------------------------------------------"
else
    echo "Success: All variables substituted in $OUTPUT_FILE"
fi
