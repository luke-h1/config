#!/bin/bash
#
# GitHub Actions Runner Setup Script for macOS
#
# This script sets up the macOS environment for GitHub Actions self-hosted runners.
# After running, you'll need to manually configure the runner for your repository.
#
# Usage:
#   ./setup-github-actions.sh
#   ./setup-github-actions.sh --debug
# --> ✅ Setup complete! Next steps:

# --> 1. Get your runner token:
# -->    - Go to your GitHub repository
# -->    - Navigate to Settings > Actions > Runners
# -->    - Click 'New self-hosted runner'
# -->    - Copy the token from the configuration command

# --> 2. Download and configure the runner (as the 'runner' user):
# -->    sudo su - runner
# -->    mkdir -p ~/actions-runner && cd ~/actions-runner
# -->    curl -O -L https://github.com/actions/runner/releases
# -->    tar xzf ./actions-runner.tar.gz
# -->    ./config.sh --url https://github.com/[owner]/[repo] --token [token]
# -->    exit

# --> 3. Load and start the LaunchDaemon:
# -->    sudo launchctl load -w /Library/LaunchDaemons/com.github.actions.runner.plist

# --> 4. Verify the runner is running:
# -->    sudo launchctl list | grep github.actions.runner
# -->    tail -f /Users/runner/actions-runner/runner.log

# --> Service Management Commands:
# -->    Start:   sudo launchctl load -w /Library/LaunchDaemons/com.github.actions.runner.plist
# -->    Stop:    sudo launchctl unload /Library/LaunchDaemons/com.github.actions.runner.plist
# -->    Status:  sudo launchctl list | grep github.actions.runner
# -->    Logs:    tail -f /Users/runner/actions-runner/runner.log

# --> For React Native iOS builds, use in your workflow:
# -->    runs-on: self-hosted


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

sudo --reset-timestamp

clear_debug() {
  set +x
}

reset_debug() {
  if [ -n "$DEBUG" ]; then
    set -x
  fi
}

sudo_init() {
  if [ -z "$INTERACTIVE" ]; then
    return
  fi

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

caffeinate -s -w $$ &

log "🚀 Setting up M4 Mac for GitHub Actions React Native builds"

UNAME_MACHINE="$(/usr/bin/uname -m)"
if [[ "$UNAME_MACHINE" == "arm64" ]]; then
  log "Detected Apple Silicon (ARM64) architecture"
  
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

log "Setting up 'runner' service account:"
if dscl . -read /Users/runner &>/dev/null; then
  log "Runner user already exists"
else
  log "Creating runner service account..."
  
  RUNNER_PASSWORD=$(openssl rand -base64 32)
  
  sudo_askpass dscl . -create /Users/runner
  sudo_askpass dscl . -create /Users/runner UserShell /bin/bash
  sudo_askpass dscl . -create /Users/runner RealName "GitHub Actions Runner"
  sudo_askpass dscl . -create /Users/runner UniqueID "510"
  sudo_askpass dscl . -create /Users/runner PrimaryGroupID 20
  sudo_askpass dscl . -create /Users/runner NFSHomeDirectory /Users/runner
  sudo_askpass dscl . -passwd /Users/runner "$RUNNER_PASSWORD"
  
  sudo_askpass dscl . -append /Groups/admin GroupMembership runner
  
  sudo_askpass mkdir -p /Users/runner
  sudo_askpass chown -R runner:staff /Users/runner
  
  RUNNER_CREDS_FILE="$HOME/.github-runner-credentials"
  echo "runner:$RUNNER_PASSWORD" > "$RUNNER_CREDS_FILE"
  chmod 600 "$RUNNER_CREDS_FILE"
  
  log "Runner account created. Password saved to: $RUNNER_CREDS_FILE"
  unset RUNNER_PASSWORD
  logk
fi

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

logn "Running Xcode first launch setup:"
sudo_askpass xcodebuild -runFirstLaunch
logk

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

export PATH="$HOMEBREW_PREFIX/bin:$PATH"
logn "Updating Homebrew:"
brew update --quiet
logk

log "Installing essential tools:"
brew install git node
logk

logn "Installing Watchman:"
if command -v watchman &> /dev/null; then
  logk
else
  brew install watchman
  logk
fi

logn "Installing CocoaPods:"
if command -v pod &> /dev/null; then
  logk
else
  sudo_askpass gem install cocoapods
  logk
fi

logn "Installing Fastlane:"
if command -v fastlane &> /dev/null; then
  logk
else
  brew install fastlane
  logk
fi

logn "Installing React Native tooling:"
if command -v react-native &> /dev/null; then
  logk
else
  npm install -g react-native-cli
  npm install -g eas-cli
  logk
fi

log "Setting up environment variables:"
RUNNER_ENV_FILE="/Users/runner/.github-actions-runner.env"
sudo_askpass tee "$RUNNER_ENV_FILE" > /dev/null <<EOF
# GitHub Actions Runner Environment Variables

export XCODE_DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
export ImageOS=macos15
export PATH="$HOMEBREW_PREFIX/bin:\$PATH"
export PATH="\$HOME/.gem/ruby/*/bin:\$PATH"
EOF
sudo_askpass chown runner:staff "$RUNNER_ENV_FILE"

sudo_askpass tee /Users/runner/.bash_profile > /dev/null <<EOF
if [ -f ~/.github-actions-runner.env ]; then
  source ~/.github-actions-runner.env
fi
EOF
sudo_askpass chown runner:staff /Users/runner/.bash_profile
logk

log "Setting up LaunchDaemon for automatic runner startup:"
LAUNCH_DAEMON_PLIST="/Library/LaunchDaemons/com.github.actions.runner.plist"
RUNNER_DIR="/Users/runner/actions-runner"

RUNNER_START_SCRIPT="/Users/runner/start-runner.sh"
sudo_askpass tee "$RUNNER_START_SCRIPT" > /dev/null <<'EOF'
#!/bin/bash

RUNNER_DIR="/Users/runner/actions-runner"
LOG_FILE="/Users/runner/actions-runner/runner.log"

if [ -f /Users/runner/.github-actions-runner.env ]; then
  source /Users/runner/.github-actions-runner.env
fi

sleep 10

cd "$RUNNER_DIR"

if [ ! -f "$RUNNER_DIR/.runner" ]; then
  echo "$(date): Runner not configured yet. Please run config.sh first." >> "$LOG_FILE"
  exit 1
fi

exec ./run.sh >> "$LOG_FILE" 2>&1
EOF
sudo_askpass chmod +x "$RUNNER_START_SCRIPT"
sudo_askpass chown runner:staff "$RUNNER_START_SCRIPT"

sudo_askpass tee "$LAUNCH_DAEMON_PLIST" > /dev/null <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.github.actions.runner</string>
    <key>ProgramArguments</key>
    <array>
        <string>/Users/runner/start-runner.sh</string>
    </array>
    <key>UserName</key>
    <string>runner</string>
    <key>GroupName</key>
    <string>staff</string>
    <key>WorkingDirectory</key>
    <string>/Users/runner/actions-runner</string>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <dict>
        <key>SuccessfulExit</key>
        <false/>
    </dict>
    <key>StandardOutPath</key>
    <string>/Users/runner/actions-runner/runner-stdout.log</string>
    <key>StandardErrorPath</key>
    <string>/Users/runner/actions-runner/runner-stderr.log</string>
    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>$HOMEBREW_PREFIX/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
        <key>XCODE_DEVELOPER_DIR</key>
        <string>/Applications/Xcode.app/Contents/Developer</string>
    </dict>
</dict>
</plist>
EOF

sudo_askpass chown root:wheel "$LAUNCH_DAEMON_PLIST"
sudo_askpass chmod 644 "$LAUNCH_DAEMON_PLIST"
logk

echo
log "✅ Setup complete! Next steps:"
echo
log "1. Get your runner token:"
log "   - Go to your GitHub repository"
log "   - Navigate to Settings > Actions > Runners"
log "   - Click 'New self-hosted runner'"
log "   - Copy the token from the configuration command"
echo
log "2. Download and configure the runner (as the 'runner' user):"
log "   sudo su - runner"
log "   mkdir -p ~/actions-runner && cd ~/actions-runner"
if [[ "$UNAME_MACHINE" == "arm64" ]]; then
  log "   curl -O -L https://github.com/actions/runner/releases"
  log "   tar xzf ./actions-runner.tar.gz"
else
  log "   curl -O -L https://github.com/actions/runner/releases/latest/download/actions-runner"
  log "   tar xzf ./actions-runner.tar.gz"
fi
log "   ./config.sh --url https://github.com/[owner]/[repo] --token [token]"
log "   exit"
echo
log "3. Load and start the LaunchDaemon:"
log "   sudo launchctl load -w $LAUNCH_DAEMON_PLIST"
echo
log "4. Verify the runner is running:"
log "   sudo launchctl list | grep github.actions.runner"
log "   tail -f /Users/runner/actions-runner/runner.log"
echo
log "Service Management Commands:"
log "   Start:   sudo launchctl load -w $LAUNCH_DAEMON_PLIST"
log "   Stop:    sudo launchctl unload $LAUNCH_DAEMON_PLIST"
log "   Status:  sudo launchctl list | grep github.actions.runner"
log "   Logs:    tail -f /Users/runner/actions-runner/runner.log"
echo
log "For React Native iOS builds, use in your workflow:"
log "   runs-on: self-hosted"
echo
log "Note: Runner credentials saved in: $HOME/.github-runner-credentials"
echo

SUCCESS="1"
log "✅ M4 Mac is now ready for GitHub Actions iOS React Native builds! ✅"
