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

if ! command -v perl >/dev/null 2>&1; then
    echo "Error: perl is required but was not found."
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
TMP_OUTPUT="$(mktemp)"
trap 'rm -f "$TMP_OUTPUT"' EXIT
perl -pe 's/\{\{(\w+)(?::-(.*?))?\}\}/exists $ENV{$1} ? $ENV{$1} : (defined $2 ? $2 : $&)/ge' "$SOURCE_FILE" >"$TMP_OUTPUT"
mv "$TMP_OUTPUT" "$OUTPUT_FILE"
trap - EXIT

# 4. Final validation: check for unreplaced placeholders
MISSING_VARS="$(perl -lne 'print for /\{\{\w+.*?\}\}/g' "$OUTPUT_FILE" | sort -u || true)"

if [[ -n "$MISSING_VARS" ]]; then
    echo "--------------------------------------------------------"
    echo "WARNING: The following placeholders were not replaced:"
    echo "$MISSING_VARS"
    echo "Check if these are defined in $ENV_FILE or have defaults."
    echo "--------------------------------------------------------"
else
    echo "Success: All variables substituted in $OUTPUT_FILE"
fi
