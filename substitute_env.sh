#!/bin/bash

# Configuration
ENV_FILE=".env"

# 1. Validation: Check arguments
if [[ $# -ne 2 ]]; then
    echo "Usage: $0 <source_template_file> <output_destination_file>"
    echo "Example: $0 config_template.cfg config.cfg"
    exit 1
fi

SOURCE_FILE="$1"
OUTPUT_FILE="$2"

if [[ ! -f "$SOURCE_FILE" ]]; then
    echo "Error: Source file '$SOURCE_FILE' not found."
    exit 1
fi

# 2. Load .env safely (handles special characters and wildcards like */6)
if [[ -f "$ENV_FILE" ]]; then
    while IFS='=' read -r key value || [[ -n "$key" ]]; do
        # Skip comments and empty lines
        [[ $key =~ ^#.* ]] || [[ -z $key ]] && continue

        # Trim carriage returns (CRLF) and whitespace
        key=$(echo "$key" | tr -d '\r' | xargs)
        value=$(echo "$value" | tr -d '\r' | xargs)

        # Export for Perl to access via %ENV
        export "$key"="$value"
    done <"$ENV_FILE"
else
    echo "Notice: $ENV_FILE not found; using system environment variables only."
fi

# 3. Process the template (Handles {{VAR}} and {{VAR:-default}})
# Works on any file type (cfg, yml, json, txt, etc.)
perl -pe 's/\{\{(\w+)(?::-(.*?))?\}\}/exists $ENV{$1} ? $ENV{$1} : (defined $2 ? $2 : $&)/ge' "$SOURCE_FILE" >"$OUTPUT_FILE"

# 4. Final Validation: Check for unreplaced placeholders (macOS & Linux compatible)
MISSING_VARS=$(perl -lne 'print for /\{\{\w+.*?\}\}/g' "$OUTPUT_FILE" | sort -u)

if [[ -n "$MISSING_VARS" ]]; then
    echo "--------------------------------------------------------"
    echo "⚠️  WARNING: The following placeholders were not replaced:"
    echo "$MISSING_VARS"
    echo "Check if these are defined in $ENV_FILE or have defaults."
    echo "--------------------------------------------------------"
else
    echo "✅ Success: All variables substituted in $OUTPUT_FILE"
fi
