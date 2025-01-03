#!/bin/bash

# Hardcoded path to the .env file
ENV_FILE=".env"

# Check if enough arguments are provided
if [[ $# -ne 2 ]]; then
    echo "Usage: $0 <yml_file> <output_file>"
    exit 1
fi

# Get the input YAML file and the output file from arguments
YML_FILE="$1"
OUTPUT_FILE="$2"

# Check if the YAML file exists
if [[ ! -f "$YML_FILE" ]]; then
    echo "Error: Input file '$YML_FILE' does not exist."
    exit 1
fi

# Check if the .env file exists
if [[ ! -f "$ENV_FILE" ]]; then
    echo "Error: .env file '$ENV_FILE' does not exist."
    exit 1
fi

# Initialize a temporary sed script
SED_SCRIPT=$(mktemp)

# Read the .env file and generate a sed script, ensuring the last line is processed
while IFS='=' read -r key value || [[ -n "$key" ]]; do
    # Skip comments and empty lines
    if [[ $key != \#* ]] && [[ -n $key ]]; then
        # Escape special characters in the key and value
        escaped_key=$(printf '%s' "$key" | sed 's/[]\/$*.^[]/\\&/g')
        escaped_value=$(printf '%s' "$value" | sed 's/[&/]/\\&/g')
        # Add substitution to the sed script
        echo "s|{{${escaped_key}}}|${escaped_value}|g" >> "$SED_SCRIPT"
    fi
done < "$ENV_FILE"

# Debugging: Print generated sed script for verification
echo "Generated sed script:"
cat "$SED_SCRIPT"

# Apply the generated sed script to the YAML file
sed -f "$SED_SCRIPT" "$YML_FILE" > "$OUTPUT_FILE"

# Remove the temporary sed script
rm -f "$SED_SCRIPT"

echo "Substituted file saved to $OUTPUT_FILE"
