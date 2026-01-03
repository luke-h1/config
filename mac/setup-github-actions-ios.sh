#!/bin/bash

set -e

[[ "$1" = "--debug" || -o xtrace ]] && DEBUG="1"

SUCCESS=""

sudo_askpass() {
  if [ -n "$SUDO_ASKPASS" ]; then
    sudo --askpass "$@"
  else
    sudo "$@"
  fi
}

abort() {
  STEP=""
  echo "!!! $*" >&2
  exit 1
}
log() {
  STEP="$*"
  sudo_refresh
  echo "--> $*"
}
logn() {
  STEP="$*"
  sudo_refresh
  printf -- "--> %s " "$*"
}
logk() {
  STEP=""
  echo "OK"
}
escape() {
  printf '%s' "${1//\'/\'}"
}

sudo_refresh() {
  clear_debug
  if [ -n "$SUDO_ASKPASS" ]; then
    sudo --askpass --validate
  else
    sudo_init
  fi
  reset_debug
}

trap "cleanup" EXIT

if [ -n "$DEBUG" ]; then
  set -x
else
  QUIET_FLAG="-q"
  Q="$QUIET_FLAG"
fi

STDIN_FILE_DESCRIPTOR="0"
[ -t "$STDIN_FILE_DESCRIPTOR" ] && INTERACTIVE="1"

cleanup() {
  set +e
  sudo_askpass rm -rf "$CLT_PLACEHOLDER" "$SUDO_ASKPASS" "$SUDO_ASKPASS_DIR"
  sudo --reset-timestamp
  if [ -z "$SUCCESS" ]; then
    if [ -n "$STEP" ]; then
      echo "!!! $STEP FAILED" >&2
    else
      echo "!!! FAILED" >&2
    fi
    if [ -z "$DEBUG" ]; then
      echo "!!! Run '$0 --debug' for debugging output." >&2
    fi
  fi
}

# We want to always prompt for sudo password at least once rather than doing
# root stuff unexpectedly.
sudo --reset-timestamp

# functions for turning off debug for use when handling the user password
clear_debug() {
  set +x
}

reset_debug() {
  if [ -n "$DEBUG" ]; then
    set -x
  fi
}

# Initialise (or reinitialise) sudo to save unhelpful prompts later.
sudo_init() {
  if [ -z "$INTERACTIVE" ]; then
    return
  fi

  # If TouchID for sudo is setup: use that instead.
  if grep -q pam_tid /etc/pam.d/sudo; then
    return
  fi

  local SUDO_PASSWORD SUDO_PASSWORD_SCRIPT

  if ! sudo --validate --non-interactive &>/dev/null; then
    while true; do
      read -rsp "--> Enter your password (for sudo access):" SUDO_PASSWORD
      echo
      if sudo --validate --stdin 2>/dev/null <<<"$SUDO_PASSWORD"; then
        break
      fi

      unset SUDO_PASSWORD
      echo "!!! Wrong password!" >&2
    done

    clear_debug
    SUDO_PASSWORD_SCRIPT="$(
      cat <<BASH
#!/bin/bash
echo "$SUDO_PASSWORD"
BASH
    )"
    unset SUDO_PASSWORD
    SUDO_ASKPASS_DIR="$(mktemp -d)"
    SUDO_ASKPASS="$(mktemp "$SUDO_ASKPASS_DIR"/strap-askpass-XXXXXXXX)"
    chmod 700 "$SUDO_ASKPASS_DIR" "$SUDO_ASKPASS"
    bash -c "cat > '$SUDO_ASKPASS'" <<<"$SUDO_PASSWORD_SCRIPT"
    unset SUDO_PASSWORD_SCRIPT
    reset_debug

    export SUDO_ASKPASS
  fi
}

[ "$USER" = "root" ] && abort "Run this script as yourself, not root."
# shellcheck disable=SC2086
groups | grep $Q -E "\b(admin)\b" || abort "Add $USER to the admin group."

# Prevent sleeping during script execution, as long as the machine is on AC power
caffeinate -s -w $$ &

log "🚀 Setting up M4 Mac for GitHub Actions iOS React Native builds"

# Check if running on Apple Silicon
UNAME_MACHINE="$(/usr/bin/uname -m)"
if [[ "$UNAME_MACHINE" == "arm64" ]]; then
  log "Detected Apple Silicon (ARM64) architecture"
  
  # Install Rosetta 2 for Intel compatibility
  logn "Checking for Rosetta 2:"
  if pgrep -q oahd; then
    logk
  else
    log "Installing Rosetta 2:"
    softwareupdate --install-rosetta --agree-to-license
    logk
  fi
else
  log "Detected Intel architecture"
fi

# Install the Xcode Command Line Tools.
if ! [ -f "/Library/Developer/CommandLineTools/usr/bin/git" ]; then
  log "Installing the Xcode Command Line Tools:"
  CLT_PLACEHOLDER="/tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress"
  sudo_askpass touch "$CLT_PLACEHOLDER"
  sudo_askpass rm -f "$CLT_PLACEHOLDER"
  if ! [ -f "/Library/Developer/CommandLineTools/usr/bin/git" ]; then
    if [ -n "$INTERACTIVE" ]; then
      echo
      logn "Requesting user install of Xcode Command Line Tools:"
      xcode-select --install
      echo "Please complete the Xcode Command Line Tools installation, then press Enter to continue..."
      read -r
    else
      echo
      abort "Run 'xcode-select --install' to install the Xcode Command Line Tools."
    fi
  fi
  logk
fi

# Check if Xcode is installed
logn "Checking for Xcode installation:"
if [ -d "/Applications/Xcode.app" ]; then
  logk
  XCODE_VERSION=$(xcodebuild -version | head -n 1)
  log "Found $XCODE_VERSION"
else
  echo "NOT FOUND"
  log "⚠️  Xcode is not installed. Please install Xcode from the App Store:"
  log "   1. Open the App Store"
  log "   2. Search for 'Xcode'"
  log "   3. Install Xcode (this may take a while)"
  log "   4. Run this script again after installation"
  
  if [ -n "$INTERACTIVE" ]; then
    echo
    read -p "Press Enter after you've installed Xcode, or Ctrl+C to exit..."
  else
    abort "Xcode must be installed. Install from App Store and run this script again."
  fi
fi

# Check if the Xcode license is agreed to and agree if not.
logn "Checking Xcode license agreement:"
if /usr/bin/xcrun clang 2>&1 | grep "$Q" license; then
  if [ -n "$INTERACTIVE" ]; then
    log "Accepting Xcode license:"
    sudo_askpass xcodebuild -license accept
    logk
  else
    abort "Run 'sudo xcodebuild -license accept' to agree to the Xcode license."
  fi
else
  logk
fi

# Run Xcode first launch
logn "Running Xcode first launch setup:"
sudo_askpass xcodebuild -runFirstLaunch
logk

# Setup Homebrew directory and permissions.
logn "Checking Homebrew installation:"
HOMEBREW_PREFIX="$(brew --prefix 2>/dev/null || true)"
HOMEBREW_REPOSITORY="$(brew --repository 2>/dev/null || true)"
if [ -z "$HOMEBREW_PREFIX" ] || [ -z "$HOMEBREW_REPOSITORY" ]; then
  echo "NOT FOUND"
  log "Installing Homebrew:"
  if [[ "$UNAME_MACHINE" == "arm64" ]]; then
    HOMEBREW_PREFIX="/opt/homebrew"
    HOMEBREW_REPOSITORY="${HOMEBREW_PREFIX}"
  else
    HOMEBREW_PREFIX="/usr/local"
    HOMEBREW_REPOSITORY="${HOMEBREW_PREFIX}/Homebrew"
  fi
  
  [ -d "$HOMEBREW_PREFIX" ] || sudo_askpass mkdir -p "$HOMEBREW_PREFIX"
  if [ "$HOMEBREW_PREFIX" = "/usr/local" ]; then
    sudo_askpass chown "root:wheel" "$HOMEBREW_PREFIX" 2>/dev/null || true
  fi
  (
    cd "$HOMEBREW_PREFIX"
    sudo_askpass mkdir -p Cellar Caskroom Frameworks bin etc include lib opt sbin share var
    sudo_askpass chown "$USER:admin" Cellar Caskroom Frameworks bin etc include lib opt sbin share var
  )

  [ -d "$HOMEBREW_REPOSITORY" ] || sudo_askpass mkdir -p "$HOMEBREW_REPOSITORY"
  sudo_askpass chown -R "$USER:admin" "$HOMEBREW_REPOSITORY"

  if [ "$HOMEBREW_PREFIX" != "$HOMEBREW_REPOSITORY" ]; then
    ln -sf "$HOMEBREW_REPOSITORY/bin/brew" "$HOMEBREW_PREFIX/bin/brew"
  fi

  # Download Homebrew.
  export GIT_DIR="$HOMEBREW_REPOSITORY/.git" GIT_WORK_TREE="$HOMEBREW_REPOSITORY"
  git init "$Q"
  git config remote.origin.url "https://github.com/Homebrew/brew"
  git config remote.origin.fetch "+refs/heads/*:refs/remotes/origin/*"
  git fetch "$Q" --tags --force
  git reset "$Q" --hard origin/master
  unset GIT_DIR GIT_WORK_TREE
  logk
else
  logk
fi

# Update Homebrew.
export PATH="$HOMEBREW_PREFIX/bin:$PATH"
logn "Updating Homebrew:"
brew update --quiet
logk

# Install essential tools
log "Installing essential tools:"
brew install git node
logk

# Install Watchman (required for React Native)
logn "Installing Watchman:"
if command -v watchman &> /dev/null; then
  logk
else
  brew install watchman
  logk
fi

# Install CocoaPods
logn "Installing CocoaPods:"
if command -v pod &> /dev/null; then
  logk
else
  sudo_askpass gem install cocoapods
  logk
fi

# Install Fastlane
logn "Installing Fastlane:"
if command -v fastlane &> /dev/null; then
  logk
else
  brew install fastlane
  logk
fi

# Install React Native CLI globally
logn "Installing React Native CLI:"
if command -v react-native &> /dev/null; then
  logk
else
  npm install -g react-native-cli
  logk
fi

# Set up environment variables for GitHub Actions runner
log "Setting up environment variables:"
RUNNER_ENV_FILE="$HOME/.github-actions-runner.env"
cat > "$RUNNER_ENV_FILE" <<EOF
# GitHub Actions Runner Environment Variables
# Source this file in your shell profile or runner service

# Xcode Developer Directory
export XCODE_DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer

# ImageOS (adjust based on your macOS version)
# macOS 12 = macos12, macOS 13 = macos13, macOS 14 = macos14, macOS 15 = macos15
export ImageOS=macos15

# Node.js path
export PATH="$HOMEBREW_PREFIX/bin:\$PATH"

# CocoaPods path
export PATH="\$HOME/.gem/ruby/*/bin:\$PATH"
EOF
logk

# Display next steps
echo
log "✅ Setup complete! Next steps:"
echo
log "1. Set up the GitHub Actions runner:"
log "   - Go to your GitHub repository"
log "   - Navigate to Settings > Actions > Runners"
log "   - Click 'New self-hosted runner'"
log "   - Select macOS and follow the instructions"
echo
log "2. Download and configure the runner:"
log "   mkdir -p ~/actions-runner && cd ~/actions-runner"
if [[ "$UNAME_MACHINE" == "arm64" ]]; then
  log "   curl -O -L https://github.com/actions/runner/releases/latest/download/actions-runner-osx-arm64-\$(curl -s https://api.github.com/repos/actions/runner/releases/latest | grep 'tag_name' | cut -d '\"' -f 4 | sed 's/v//').tar.gz"
else
  log "   curl -O -L https://github.com/actions/runner/releases/latest/download/actions-runner-osx-x64-\$(curl -s https://api.github.com/repos/actions/runner/releases/latest | grep 'tag_name' | cut -d '\"' -f 4 | sed 's/v//').tar.gz"
fi
log "   tar xzf ./actions-runner-*.tar.gz"
log "   ./config.sh --url https://github.com/[owner]/[repo] --token [token]"
echo
log "3. Install and start the runner as a service:"
log "   ./svc.sh install"
log "   ./svc.sh start"
echo
log "4. Source the environment variables (add to ~/.zshrc or ~/.bash_profile):"
log "   source $RUNNER_ENV_FILE"
echo
log "5. For React Native iOS builds, ensure your workflow uses:"
log "   runs-on: self-hosted"
log "   and installs pods: cd ios && pod install"
echo

SUCCESS="1"
log "✅ M4 Mac is now ready for GitHub Actions iOS React Native builds! ✅"

