#!/bin/bash

# Sync JetBrains IDE config from this repo to local machine
# Supports: IntelliJ IDEA, Rider (all versions)
# Matches Cursor settings: format on save, Prettier-style, terminal scrollback

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JETBRAINS_BASE_DIR="$HOME/Library/Application Support/JetBrains"

# Find all installed JetBrains IDEs (IntelliJ IDEA and Rider)
find_ide_configs() {
    local ide_dirs=()

    if [ -d "$JETBRAINS_BASE_DIR" ]; then
        # Find IntelliJ IDEA directories (any version)
        for dir in "$JETBRAINS_BASE_DIR"/IntelliJIdea*/; do
            [ -d "$dir" ] && ide_dirs+=("$dir")
        done

        # Find Rider directories (any version)
        for dir in "$JETBRAINS_BASE_DIR"/Rider*/; do
            [ -d "$dir" ] && ide_dirs+=("$dir")
        done
    fi

    printf '%s\n' "${ide_dirs[@]}"
}

sync_config_to_ide() {
    local ide_dir="$1"
    local ide_name=$(basename "$ide_dir")

    echo "----------------------------------------"
    echo "Syncing to: $ide_name"
    echo "----------------------------------------"

    # Create directories if they don't exist
    mkdir -p "$ide_dir/options"
    mkdir -p "$ide_dir/options/mac"
    mkdir -p "$ide_dir/codestyles"
    mkdir -p "$ide_dir/keymaps"

    # Backup existing config
    local backup_dir="$ide_dir/backup-$(date +%Y%m%d-%H%M%S)"
    echo "Creating backup at $backup_dir"
    mkdir -p "$backup_dir/options"
    mkdir -p "$backup_dir/options/mac"
    mkdir -p "$backup_dir/codestyles"
    mkdir -p "$backup_dir/keymaps"

    # Backup existing files (if they exist)
    [ -f "$ide_dir/options/editor.xml" ] && cp "$ide_dir/options/editor.xml" "$backup_dir/options/" 2>/dev/null || true
    [ -f "$ide_dir/options/editor-font.xml" ] && cp "$ide_dir/options/editor-font.xml" "$backup_dir/options/" 2>/dev/null || true
    [ -f "$ide_dir/options/ide.general.xml" ] && cp "$ide_dir/options/ide.general.xml" "$backup_dir/options/" 2>/dev/null || true
    [ -f "$ide_dir/options/terminal.xml" ] && cp "$ide_dir/options/terminal.xml" "$backup_dir/options/" 2>/dev/null || true
    [ -f "$ide_dir/options/other.xml" ] && cp "$ide_dir/options/other.xml" "$backup_dir/options/" 2>/dev/null || true
    [ -f "$ide_dir/options/code.style.schemes.xml" ] && cp "$ide_dir/options/code.style.schemes.xml" "$backup_dir/options/" 2>/dev/null || true
    [ -f "$ide_dir/options/keymap.xml" ] && cp "$ide_dir/options/keymap.xml" "$backup_dir/options/" 2>/dev/null || true
    [ -f "$ide_dir/options/mac/keymap.xml" ] && cp "$ide_dir/options/mac/keymap.xml" "$backup_dir/options/mac/" 2>/dev/null || true

    # Copy new config files
    echo "Copying options..."
    cp "$SCRIPT_DIR/options/editor.xml" "$ide_dir/options/"
    cp "$SCRIPT_DIR/options/editor-font.xml" "$ide_dir/options/"
    cp "$SCRIPT_DIR/options/ide.general.xml" "$ide_dir/options/"
    cp "$SCRIPT_DIR/options/terminal.xml" "$ide_dir/options/"
    cp "$SCRIPT_DIR/options/other.xml" "$ide_dir/options/"
    cp "$SCRIPT_DIR/options/code.style.schemes.xml" "$ide_dir/options/"
    cp "$SCRIPT_DIR/options/keymap.xml" "$ide_dir/options/"
    cp "$SCRIPT_DIR/options/mac/keymap.xml" "$ide_dir/options/mac/"

    echo "Copying code styles..."
    cp "$SCRIPT_DIR/codestyles/Prettier.xml" "$ide_dir/codestyles/"

    echo "Copying keymaps..."
    cp "$SCRIPT_DIR/keymaps/CursorLike.xml" "$ide_dir/keymaps/"

    echo "Done syncing $ide_name"
    echo ""
}

# Main execution
echo "========================================"
echo "JetBrains IDE Config Sync"
echo "========================================"
echo ""
echo "Source: $SCRIPT_DIR"
echo "Scanning for installed IDEs..."
echo ""

# Check if JetBrains directory exists
if [ ! -d "$JETBRAINS_BASE_DIR" ]; then
    echo "Error: JetBrains config directory not found at $JETBRAINS_BASE_DIR"
    echo "Please ensure at least one JetBrains IDE is installed and has been run at least once."
    exit 1
fi

# Find all IDE configs
IDE_CONFIGS=$(find_ide_configs)

if [ -z "$IDE_CONFIGS" ]; then
    echo "Error: No IntelliJ IDEA or Rider installations found."
    echo "Please ensure at least one IDE is installed and has been run at least once."
    exit 1
fi

# Count IDEs found
IDE_COUNT=$(echo "$IDE_CONFIGS" | grep -c .)
echo "Found $IDE_COUNT JetBrains IDE(s):"
echo "$IDE_CONFIGS" | while read -r dir; do
    [ -n "$dir" ] && echo "  - $(basename "$dir")"
done
echo ""

# Sync to each IDE
echo "$IDE_CONFIGS" | while read -r ide_dir; do
    [ -n "$ide_dir" ] && sync_config_to_ide "$ide_dir"
done

echo "========================================"
echo "Sync Complete!"
echo "========================================"
echo ""
echo "Settings applied to all IDEs:"
echo "  - Word wrap enabled (like Cursor)"
echo "  - Editor font size: 14px with 1.2 line spacing"
echo "  - UI scale: 110%"
echo "  - Terminal scrollback: 100000 lines"
echo "  - Prettier-style code formatting"
echo "  - CursorLike keymap:"
echo "      Cmd+B  - Toggle file tree"
echo "      Cmd+L  - Select line"
echo "      Cmd+I  - AI Assistant"
echo "      Cmd+P  - Go to file"
echo "      Cmd+Shift+P - Command palette"
echo "      Cmd+Shift+F - Find in files"
echo ""
echo "Note: Restart your IDE(s) for changes to take effect."
echo ""
echo "To enable format on save in each IDE:"
echo "  Settings > Tools > Actions on Save > Enable 'Reformat code'"
