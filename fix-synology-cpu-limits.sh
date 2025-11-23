#!/bin/bash
# fix-synology-cpu-limits.sh
# Removes CPU resource limits from generated Docker Compose files
# Run this after substitute_env.sh for Synology compatibility

echo "Synology CPU Limit Fix"
echo "======================"
echo ""

if [ $# -eq 0 ]; then
    echo "Usage: $0 <docker-compose-file>"
    echo "Example: $0 docker-compose.arr-stack.yml"
    exit 1
fi

FILE="$1"

if [ ! -f "$FILE" ]; then
    echo "Error: File '$FILE' not found"
    exit 1
fi

echo "Removing CPU limits from: $FILE"

# Create backup
cp "$FILE" "$FILE.bak"
echo "✓ Created backup: $FILE.bak"

# Remove entire deploy section
sed -i '/^[[:space:]]*deploy:/,/^[[:space:]]*[a-z_-]*:/{ /^[[:space:]]*deploy:/d; /^[[:space:]]*resources:/d; /^[[:space:]]*limits:/d; /^[[:space:]]*cpus:/d; /^[[:space:]]*memory:/d; /^[[:space:]]*reservations:/d; }' "$FILE"

echo "✓ Removed deploy sections"
echo ""
echo "Done! You can now run:"
echo "  docker-compose -f $FILE up -d"
echo ""
echo "To restore: cp $FILE.bak $FILE"
