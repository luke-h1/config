#!/bin/bash

# Sync JetBrains IDE config from this repo to local machine
# Supports: IntelliJ IDEA, Rider, Android Studio (all versions)
# Matches Cursor settings: format on save, Prettier-style, terminal scrollback
#
# Usage: ./sync.sh [--skip-plugins]
#   --skip-plugins  Skip plugin installation (useful if IDEs are running)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKIP_PLUGINS=false

# Parse arguments
for arg in "$@"; do
    case $arg in
        --skip-plugins)
            SKIP_PLUGINS=true
            shift
            ;;
    esac
done
JETBRAINS_BASE_DIR="$HOME/Library/Application Support/JetBrains"
GOOGLE_BASE_DIR="$HOME/Library/Application Support/Google"

# Plugins to install (plugin IDs from JetBrains Marketplace)
# Find plugin IDs at: https://plugins.jetbrains.com > Plugin page > Additional Information > Plugin ID
PLUGINS=(
    "com.mallowigi.idea"        # Atom Material Icons
    "aws.toolkit"               # AWS Toolkit
    "org.jetbrains.kotlin"      # Kotlin
    "io.flutter"                # Flutter
    "Dart"                      # Dart
    "com.anthropic.code.plugin" # Claude Code
)

# Map IDE config directory prefixes to their application executables
get_ide_executable() {
    local ide_name="$1"
    
    case "$ide_name" in
        IntelliJIdea*)
            echo "/Applications/IntelliJ IDEA.app/Contents/MacOS/idea"
            ;;
        Rider*)
            echo "/Applications/Rider.app/Contents/MacOS/rider"
            ;;
        WebStorm*)
            echo "/Applications/WebStorm.app/Contents/MacOS/webstorm"
            ;;
        PyCharm*)
            echo "/Applications/PyCharm.app/Contents/MacOS/pycharm"
            ;;
        GoLand*)
            echo "/Applications/GoLand.app/Contents/MacOS/goland"
            ;;
        CLion*)
            echo "/Applications/CLion.app/Contents/MacOS/clion"
            ;;
        RubyMine*)
            echo "/Applications/RubyMine.app/Contents/MacOS/rubymine"
            ;;
        PhpStorm*)
            echo "/Applications/PhpStorm.app/Contents/MacOS/phpstorm"
            ;;
        DataGrip*)
            echo "/Applications/DataGrip.app/Contents/MacOS/datagrip"
            ;;
        AndroidStudio*)
            echo "/Applications/Android Studio.app/Contents/MacOS/studio"
            ;;
        *)
            echo ""
            ;;
    esac
}

# Find all installed JetBrains IDEs
find_ide_configs() {
    local ide_dirs=()

    # JetBrains IDEs (IntelliJ, Rider, etc.)
    if [ -d "$JETBRAINS_BASE_DIR" ]; then
        for dir in "$JETBRAINS_BASE_DIR"/IntelliJIdea*/; do
            [ -d "$dir" ] && ide_dirs+=("$dir")
        done
        for dir in "$JETBRAINS_BASE_DIR"/Rider*/; do
            [ -d "$dir" ] && ide_dirs+=("$dir")
        done
        for dir in "$JETBRAINS_BASE_DIR"/WebStorm*/; do
            [ -d "$dir" ] && ide_dirs+=("$dir")
        done
        for dir in "$JETBRAINS_BASE_DIR"/PyCharm*/; do
            [ -d "$dir" ] && ide_dirs+=("$dir")
        done
        for dir in "$JETBRAINS_BASE_DIR"/GoLand*/; do
            [ -d "$dir" ] && ide_dirs+=("$dir")
        done
        for dir in "$JETBRAINS_BASE_DIR"/CLion*/; do
            [ -d "$dir" ] && ide_dirs+=("$dir")
        done
        for dir in "$JETBRAINS_BASE_DIR"/RubyMine*/; do
            [ -d "$dir" ] && ide_dirs+=("$dir")
        done
        for dir in "$JETBRAINS_BASE_DIR"/PhpStorm*/; do
            [ -d "$dir" ] && ide_dirs+=("$dir")
        done
        for dir in "$JETBRAINS_BASE_DIR"/DataGrip*/; do
            [ -d "$dir" ] && ide_dirs+=("$dir")
        done
    fi

    # Android Studio (stored under Google)
    if [ -d "$GOOGLE_BASE_DIR" ]; then
        for dir in "$GOOGLE_BASE_DIR"/AndroidStudio*/; do
            [ -d "$dir" ] && ide_dirs+=("$dir")
        done
    fi

    printf '%s\n' "${ide_dirs[@]}"
}

# Check if an IDE is currently running
is_ide_running() {
    local ide_name="$1"
    
    case "$ide_name" in
        IntelliJIdea*)
            pgrep -f "IntelliJ IDEA" > /dev/null 2>&1
            ;;
        AndroidStudio*)
            pgrep -f "Android Studio" > /dev/null 2>&1
            ;;
        Rider*)
            pgrep -f "Rider" > /dev/null 2>&1
            ;;
        WebStorm*)
            pgrep -f "WebStorm" > /dev/null 2>&1
            ;;
        PyCharm*)
            pgrep -f "PyCharm" > /dev/null 2>&1
            ;;
        GoLand*)
            pgrep -f "GoLand" > /dev/null 2>&1
            ;;
        *)
            return 1
            ;;
    esac
}

# Install plugins using the IDE's command-line installer
# Reference: https://www.jetbrains.com/help/idea/install-plugins-from-the-command-line.html
install_plugins_via_cli() {
    local ide_name="$1"
    local ide_executable=$(get_ide_executable "$ide_name")
    
    if [ -z "$ide_executable" ]; then
        echo "  Warning: Unknown IDE type for $ide_name"
        return 1
    fi
    
    if [ ! -x "$ide_executable" ]; then
        echo "  Warning: IDE executable not found at $ide_executable"
        echo "  Plugins will need to be installed manually from Settings > Plugins"
        return 1
    fi
    
    # Check if IDE is running
    if is_ide_running "$ide_name"; then
        echo "  Warning: $ide_name is currently running."
        echo "  The command-line plugin installer requires the IDE to be closed."
        echo ""
        echo "  To install plugins, either:"
        echo "    1. Close the IDE and run this script again, OR"
        echo "    2. Install manually: Settings > Plugins > Marketplace"
        echo ""
        echo "  Plugins to install:"
        for plugin in "${PLUGINS[@]}"; do
            echo "    - $plugin"
        done
        return 1
    fi
    
    echo "  Installing plugins via command line..."
    echo "  Executable: $ide_executable"
    
    # Install all plugins in one command (more efficient)
    # The IDE will download plugins from JetBrains Marketplace automatically
    if "$ide_executable" installPlugins "${PLUGINS[@]}" 2>&1; then
        echo "  Plugins installed successfully!"
        return 0
    else
        echo "  Warning: Some plugins may have failed to install"
        echo "  You can install them manually from Settings > Plugins"
        return 1
    fi
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
    [ -f "$ide_dir/options/laf.xml" ] && cp "$ide_dir/options/laf.xml" "$backup_dir/options/" 2>/dev/null || true
    [ -f "$ide_dir/options/ui.lnf.xml" ] && cp "$ide_dir/options/ui.lnf.xml" "$backup_dir/options/" 2>/dev/null || true

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
    cp "$SCRIPT_DIR/options/laf.xml" "$ide_dir/options/"
    cp "$SCRIPT_DIR/options/ui.lnf.xml" "$ide_dir/options/"

    echo "Copying code styles..."
    cp "$SCRIPT_DIR/codestyles/Prettier.xml" "$ide_dir/codestyles/"

    echo "Copying keymaps..."
    cp "$SCRIPT_DIR/keymaps/CursorLike.xml" "$ide_dir/keymaps/"

    # Install plugins using command-line installer
    if [ "$SKIP_PLUGINS" = true ]; then
        echo "Skipping plugin installation (--skip-plugins flag)"
    else
        echo "Installing plugins..."
        install_plugins_via_cli "$ide_name" || true  # Don't fail if plugins can't install
    fi

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

# Check if any config directories exist
if [ ! -d "$JETBRAINS_BASE_DIR" ] && [ ! -d "$GOOGLE_BASE_DIR" ]; then
    echo "Error: No JetBrains or Android Studio config directories found."
    echo "Please ensure at least one IDE is installed and has been run at least once."
    exit 1
fi

# Find all IDE configs
IDE_CONFIGS=$(find_ide_configs)

if [ -z "$IDE_CONFIGS" ]; then
    echo "Error: No JetBrains IDE or Android Studio installations found."
    echo "Please ensure at least one IDE is installed and has been run at least once."
    exit 1
fi

# Count IDEs found
IDE_COUNT=$(echo "$IDE_CONFIGS" | grep -c . || echo "0")
echo "Found $IDE_COUNT IDE(s):"
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
echo "  - Editor font size: 11px with 1.2 line spacing"
echo "  - UI scale: 100%"
echo "  - Terminal scrollback: 100000 lines"
echo "  - Prettier-style code formatting"
echo "  - Dark theme (Darcula/ExperimentalDark)"
echo "  - Minimal UI: compact mode, no breadcrumbs, smooth scrolling"
echo "  - Plugins: Atom Material Icons, AWS Toolkit, Kotlin, Flutter, Dart, Claude Code"
echo "  - CursorLike keymap:"
echo "      Cmd+B  - Toggle file tree"
echo "      Cmd+J  - Toggle terminal"
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
