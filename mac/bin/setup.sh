#!/bin/bash

set -e

[[ "$1" = "--debug" || -o xtrace ]] && DEBUG="1"

SUCCESS=""

NAME='Luke Howsam'
EMAIL=''
GIT_NAME='luke-h1'
GIT_EMAIL=''
GITHUB_USER='luke-h1'
ISSUES_URL='https://github.com/luke-h1/config/issues'
WORK=false

mkdir -p ~/.config && touch ~/.config/starship.toml

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
  # shellcheck disable=SC2317
  clear_debug
  # shellcheck disable=SC2317
  if [ -n "$SUDO_ASKPASS" ]; then
    sudo --askpass --validate
  else
    sudo_init
  fi
  # shellcheck disable=SC2317
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
      echo "!!! If you're stuck: file an issue with debugging output at:" >&2
      echo "!!!   $ISSUES_URL" >&2
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
  # shellcheck disable=SC2317
  if [ -z "$INTERACTIVE" ]; then
    return
  fi

  # If TouchID for sudo is setup: use that instead.
  # shellcheck disable=SC2317
  if grep -q pam_tid /etc/pam.d/sudo; then
    return
  fi

  # shellcheck disable=SC2317
  local SUDO_PASSWORD SUDO_PASSWORD_SCRIPT

  # shellcheck disable=SC2317
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

sudo_refresh() {
  clear_debug
  if [ -n "$SUDO_ASKPASS" ]; then
    sudo --askpass --validate
  else
    sudo_init
  fi
  reset_debug
}

[ "$USER" = "root" ] && abort "Run Strap as yourself, not root."
# shellcheck disable=SC2086
groups | grep $Q -E "\b(admin)\b" || abort "Add $USER to the admin group."

# Prevent sleeping during script execution, as long as the machine is on AC power
caffeinate -s -w $$ &

if [ "$WORK" != true ]; then
  # Set some basic security settings.
  logn "Configuring security settings:"
  sudo_askpass defaults write com.apple.Safari \
    com.apple.Safari.ContentPageGroupIdentifier.WebKit2JavaEnabled \
    -bool false
  sudo_askpass defaults write com.apple.Safari \
    com.apple.Safari.ContentPageGroupIdentifier.WebKit2JavaEnabledForLocalFiles \
    -bool false
  sudo_askpass defaults write com.apple.screensaver askForPassword -int 1
  sudo_askpass defaults write com.apple.screensaver askForPasswordDelay -int 0
  sudo_askpass defaults write /Library/Preferences/com.apple.alf globalstate -int 1
  sudo_askpass launchctl load /System/Library/LaunchDaemons/com.apple.alf.agent.plist 2>/dev/null

  if [ -n "$NAME" ] && [ -n "$EMAIL" ]; then
    LOGIN_TEXT=$(escape "Found this computer? Please contact $NAME at $EMAIL.")
    echo "$LOGIN_TEXT" | grep -q '[()]' && LOGIN_TEXT="'$LOGIN_TEXT'"
    sudo_askpass defaults write /Library/Preferences/com.apple.loginwindow \
      LoginwindowText \
      "$LOGIN_TEXT"
  fi
  # Check and enable full-disk encryption.
  logn "Checking full-disk encryption status:"
  # shellcheck disable=SC2086
  if fdesetup status | grep $Q -E "FileVault is (On|Off, but will be enabled after the next restart)."; then
    logk
  elif [ -n "$CI" ]; then
    echo "SKIPPED (for CI)"
  elif [ -n "$INTERACTIVE" ]; then
    echo
    log "Enabling full-disk encryption on next reboot:"
    sudo_askpass fdesetup enable -user "$USER" |
      tee ~/Desktop/"FileVault Recovery Key.txt"
    logk
  else
    echo
    abort "Run 'sudo fdesetup enable -user \"$USER\"' to enable full-disk encryption."
  fi

  logk
else
  log "Security settings configuration is disabled for work."
fi

# Install the Xcode Command Line Tools.
if ! [ -f "/Library/Developer/CommandLineTools/usr/bin/git" ]; then
  log "Installing the Xcode Command Line Tools:"
  CLT_PLACEHOLDER="/tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress"
  sudo_askpass touch "$CLT_PLACEHOLDER"

  CLT_PACKAGE=$(softwareupdate -l |
    grep -B 1 "Command Line Tools" |
    awk -F"*" '/^ *\*/ {print $2}' |
    sed -e 's/^ *Label: //' -e 's/^ *//' |
    sort -V |
    tail -n1)
  sudo_askpass softwareupdate -i "$CLT_PACKAGE"
  sudo_askpass rm -f "$CLT_PLACEHOLDER"
  if ! [ -f "/Library/Developer/CommandLineTools/usr/bin/git" ]; then
    if [ -n "$INTERACTIVE" ]; then
      echo
      logn "Requesting user install of Xcode Command Line Tools:"
      xcode-select --install
    else
      echo
      abort "Run 'xcode-select --install' to install the Xcode Command Line Tools."
    fi
  fi
  logk
fi

# Check if the Xcode license is agreed to and agree if not.
xcode_license() {
  if /usr/bin/xcrun clang 2>&1 | grep "$Q" license; then
    if [ -n "$INTERACTIVE" ]; then
      logn "Asking for Xcode license confirmation:"
      sudo_askpass xcodebuild -license
      logk
    else
      abort "Run 'sudo xcodebuild -license' to agree to the Xcode license."
    fi
  fi
}
xcode_license

# Setup Git configuration.
logn "Configuring Git:"
if [ -n "$GIT_NAME" ] && ! git config user.name >/dev/null; then
  git config --global user.name "$GIT_NAME"
fi

if [ -n "$GIT_EMAIL" ] && ! git config user.email >/dev/null; then
  git config --global user.email "$GIT_EMAIL"
fi

if [ -n "$GITHUB_USER" ] && [ "$(git config github.user)" != "$GITHUB_USER" ]; then
  git config --global github.user "$GITHUB_USER"
fi

# Setup Homebrew directory and permissions.
logn "Installing Homebrew:"
HOMEBREW_PREFIX="$(brew --prefix 2>/dev/null || true)"
HOMEBREW_REPOSITORY="$(brew --repository 2>/dev/null || true)"
if [ -z "$HOMEBREW_PREFIX" ] || [ -z "$HOMEBREW_REPOSITORY" ]; then
  UNAME_MACHINE="$(/usr/bin/uname -m)"
  if [[ "$UNAME_MACHINE" == "arm64" ]]; then
    HOMEBREW_PREFIX="/opt/homebrew"
    HOMEBREW_REPOSITORY="${HOMEBREW_PREFIX}"
  else
    HOMEBREW_PREFIX="/usr/local"
    HOMEBREW_REPOSITORY="${HOMEBREW_PREFIX}/Homebrew"
  fi
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

# Update Homebrew.
export PATH="$HOMEBREW_PREFIX/bin:$PATH"
logn "Updating Homebrew:"
brew update --quiet
logk

# Install Homebrew Bundle, Cask and Services tap.
log "Installing Homebrew taps and extensions:"
brew bundle --quiet --file=- <<RUBY
tap "homebrew/cask"
tap "homebrew/core"
tap "homebrew/services"
RUBY
logk

# Check and install any remaining software updates.
if [ "$WORK" != true ]; then
  logn "Checking for software updates:"
  if softwareupdate -l 2>&1 | grep "$Q" "No new software available."; then
    logk
  else
    echo
    log "Installing software updates:"
    if [ -z "$CI" ]; then
      sudo_askpass softwareupdate --install --all
      xcode_license
      logk
    else
      echo "SKIPPED (for CI)"
    fi
  fi
else
  log "Software update check is disabled for work."
fi

# Avoid creating .DS_Store files on network or USB volumes
defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true

# Save to disk (not to iCloud) by default
defaults write NSGlobalDomain NSDocumentSaveNewDocumentsToCloud -bool false
defaults write com.apple.screensaver askForPassword -int 1
defaults write com.apple.screensaver askForPasswordDelay -int 0

# Disable shadow in screenshots
defaults write com.apple.screencapture disable-shadow -bool true

# Enable the automatic update check
defaults write com.apple.SoftwareUpdate AutomaticCheckEnabled -bool true

# Download newly available updates in background
defaults write com.apple.SoftwareUpdate AutomaticDownload -int 1

# Install System data files & security updates
defaults write com.apple.SoftwareUpdate CriticalUpdateInstall -int 1

echo "Would you like to set your hostname / computer (as done via System Preferences >> Sharing)?  (y/n)"
read -r response
if [[ $response =~ ^([yY][eE][sS]|[yY])$ ]]; then
  echo "What would you like it to be?"
  # shellcheck disable=SC2162
  read HOSTNAME
  sudo scutil --set ComputerName "$HOSTNAME"
  sudo scutil --set HostName "$HOSTNAME"
  sudo scutil --set LocalHostName "$HOSTNAME"
  sudo defaults write /Library/Preferences/SystemConfiguration/com.apple.smb.server NetBIOSName -string "$HOSTNAME"
fi

echo "Turn off keyboard illumination when computer is not used for 5 minutes"
defaults write com.apple.BezelServices kDimTime -int 300

echo "Disable display from automatically adjusting brightness? (y/n)"
read -r response
if [[ $response =~ ^([yY][eE][sS]|[yY])$ ]]; then
  sudo defaults write /Library/Preferences/com.apple.iokit.AmbientLightSensor "Automatic Display Enabled" -bool false
fi
echo "Where do you want screenshots to be stored? (hit ENTER if you want ~/Desktop as default)"
# Thanks https://github.com/omgmog
# shellcheck disable=SC2162
read screenshot_location
if [ -z "${screenshot_location}" ]; then
  # If nothing specified, we default to ~/Desktop
  screenshot_location="${HOME}/Desktop"
else
  # Otherwise we use input
  if [[ "${screenshot_location:0:1}" != "/" ]]; then
    # If input doesn't start with /, assume it's relative to home
    screenshot_location="${HOME}/${screenshot_location}"
  fi
fi
echo "Setting location to ${screenshot_location}"
defaults write com.apple.screencapture location -string "${screenshot_location}"

echo "Show hidden files in Finder by default? (y/n)"
read -r response
if [[ $response =~ ^([yY][eE][sS]|[yY])$ ]]; then
  defaults write com.apple.Finder AppleShowAllFiles -bool true
fi

# Disable the sound effects on boot
# thanks github.com/kentcdodds
sudo nvram SystemAudioVolume=" "

# SHOW MOUNTED VOLUMES ON DESKTOP
defaults write com.apple.finder ShowExternalHardDrivesOnDesktop -bool false
defaults write com.apple.finder ShowHardDrivesOnDesktop -bool false
defaults write com.apple.finder ShowMountedServersOnDesktop -bool false
defaults write com.apple.finder ShowRemovableMediaOnDesktop -bool false

echo "Safari section"
# Warn about fraudulent websites
defaults write com.apple.Safari WarnAboutFraudulentWebsites -bool true

echo "Privacy: Don't send search queries to Apple"
defaults write com.apple.Safari UniversalSearchEnabled -bool false
defaults write com.apple.Safari SuppressSearchSuggestions -bool true

echo "Hiding Safari's bookmarks bar by default"
defaults write com.apple.Safari ShowFavoritesBar -bool false

echo "Hiding Safari's sidebar in Top Sites"
defaults write com.apple.Safari ShowSidebarInTopSites -bool false

echo "Disabling Safari's thumbnail cache for History and Top Sites"
defaults write com.apple.Safari DebugSnapshotsUpdatePolicy -int 2

echo "Enabling Safari's debug menu"
defaults write com.apple.Safari IncludeInternalDebugMenu -bool true

echo "Making Safari's search banners default to Contains instead of Starts With"
defaults write com.apple.Safari FindOnPageMatchesWordStartsOnly -bool false

echo "Removing useless icons from Safari's bookmarks bar"
defaults write com.apple.Safari ProxiesInBookmarksBar "()"

defaults -currentHost write com.apple.ImageCapture disableHotPlug -bool true

# UI CONFIG
echo "Speed up various animations"
defaults write -g NSAutomaticWindowAnimationsEnabled -bool false
defaults write -g QLPanelAnimationDuration -float 0
defaults write -g NSWindowResizeTime -float 0.001
defaults write com.apple.finder DisableAllAnimations -bool true
defaults write com.apple.dock launchanim -bool false
defaults write com.apple.dock expose-animation-duration -float 0.1
defaults write -g NSDocumentRevisionsWindowTransformAnimation -bool false
defaults write -g NSBrowserColumnAnimationSpeedMultiplier -float 0.001

echo "disable bouncing icons in dock"
defaults write com.apple.dock no-bouncing -bool false

echo "speed up launchpad animations"
defaults write com.apple.dock springboard-show-duration -float 0.1
defaults write com.apple.dock springboard-hide-duration -float 0.11
defaults write com.apple.dock springboard-page-duration -float 0.1

echo "Always show scrollbars"
defaults write NSGlobalDomain AppleShowScrollBars -string "Always"

echo "Quit printer app once print jobs have finished"
defaults write com.apple.print.PrintingPrefs "Quit When Finished" -bool true

echo "require password immediately after sleep or screen saver"
defaults write com.apple.screensaver askForPassword -int 1
defaults write com.apple.screensaver askForPasswordDelay -int 0

echo "disable window animations"
defaults write com.apple.finder DisableAllAnimations -bool true

echo "Use list view in finder windows"
defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"

echo "Speed up Mission control animation"
defaults write com.apple.dock expose-animation-duration -float 0.1

echo "Auto hide dock"
defaults write com.apple.dock autohide -bool true

echo "Change Menu bar clock format"
defaults write com.apple.menuextra.clock DateFormat -string "EEE MMM d  H:mm"

# Disable the sound effects on boot
sudo nvram SystemAudioVolume=" "

echo "Wipe all default icons from Dock"
defaults write com.apple.dock persistent-apps -array

log "Move Dock to right"
defaults write com.apple.dock orientation right

mkdir -p ~/Downloads/Incomplete

if [ "$WORK" != true ]; then
  log "Setting up an incomplete downloads folder in Downloads"
  defaults write org.m0k.transmission UseIncompleteDownloadFolder -bool true
  defaults write org.m0k.transmission IncompleteDownloadFolder -string "${HOME}/Downloads/Incomplete"

  log "Setting auto-add folder to be Downloads"
  defaults write org.m0k.transmission AutoImportDirectory -string "${HOME}/Downloads"

  log "Don't prompt for confirmation before downloading"
  defaults write org.m0k.transmission DownloadAsk -bool false

  log "Trash original torrent files after adding them"
  defaults write org.m0k.transmission DeleteOriginalTorrent -bool true

  log "Hiding the donate message"
  defaults write org.m0k.transmission WarningDonate -bool false

  log "Hiding the legal disclaimer"
  defaults write org.m0k.transmission WarningLegal -bool false

  log "Auto-resizing the window to fit transfers"
  defaults write org.m0k.transmission AutoSize -bool true

  log "Auto updating to betas"
  defaults write org.m0k.transmission AutoUpdateBeta -bool true

  log "Setting up the best block list"
  defaults write org.m0k.transmission EncryptionRequire -bool true
  defaults write org.m0k.transmission BlocklistAutoUpdate -bool true
  defaults write org.m0k.transmission BlocklistNew -bool true
  defaults write org.m0k.transmission BlocklistURL -string "http://john.bitsurge.net/public/biglist.p2p.gz"
else
  log "Transmission setup is disabled for work."
fi

sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
brew update
brew upgrade
# brew bundle
curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py
python3 get-pip.py
pip3 install pipenv
pip install --upgrade pip
brew install pyenv
pyenv install 3.10.0
pyenv global 3.10.0
brew update
brew upgrade
brew install node
brew link node
brew update && brew install nvm
mkdir /Users/lukehowsam/.nvm

brew tap homebrew/cask-fonts && brew install --cask font-fira-code-nerd-font

curl -fsSL https://get.pnpm.io/install.sh | sh -
# shellcheck disable=SC2046
sudo chown -R "$USER":$(id -gn "$USER") /Users/"$USER"/.config
npm i -g vercel lite-server expo-cli typescript
sudo gem install cocoapods
sudo xcodebuild -license accept

find ~/Library/Application\ Support/Dock -name "*.db" -maxdepth 1 -delete
for app in "Activity Monitor" "Address Book" "Calendar" "Contacts" "cfprefsd" \
  "Dock" "Finder" "Mail" "Messages" "Safari" "SystemUIServer" \
  "Transmission"; do
  killall "${app}" >/dev/null 2>&1
done
SUCCESS="1"
log "✅ System is now Bootstrapped! ✅"

log "❌---------------------------------------❌"
log "remember to setup manually:"
log "macs fan control"
log "stealth-mode mac setting"
log "PIA client"
log "Amphetamine"
log "Android studio"
log "Docker"
log "vscode extensions"
log "libmagic"
log "❌---------------------------------------❌"

cat <<EOF >>~/.zprofile
# Add Visual Studio Code (code)
export PATH="\$PATH:/Applications/Visual Studio Code.app/Contents/Resources/app/bin"
EOF
log "asking for sudo permission to reboot"
sudo reboot now
