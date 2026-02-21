#!/bin/bash

# =============================================================================
# Zsh Configuration Script
# Sets up Zsh with Oh My Zsh, Powerlevel10k, and useful plugins/tools
# =============================================================================

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Summary tracking arrays
INSTALLED=()
SKIPPED=()
CONFIGURED=()
FAILED=()

# Logging functions
log_info() {
  echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
  echo -e "${GREEN}[DONE]${NC} $1"
}

log_skip() {
  echo -e "${YELLOW}[SKIP]${NC} $1"
}

log_error() {
  echo -e "${RED}[FAIL]${NC} $1"
}

log_section() {
  echo ""
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BLUE}  $1${NC}"
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# Function to detect the operating system
detect_os() {
  if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    if [ -f /etc/os-release ]; then
      . /etc/os-release
      OS=$ID
    fi
  elif [[ "$OSTYPE" == "darwin"* ]]; then
    OS="macos"
  else
    log_error "Unsupported operating system"
    exit 1
  fi
}

# Function to install packages based on the OS
install_package() {
  package_name=$1
  case $OS in
    "fedora")
      sudo dnf install -y "$package_name"
      ;;
    "ubuntu")
      sudo apt-get update
      sudo apt-get install -y "$package_name"
      ;;
    "macos")
      brew install "$package_name"
      ;;
  esac
}

# Function to install Meslo fonts
install_fonts() {
  local font_url="https://github.com/romkatv/powerlevel10k-media/raw/master"
  local font_names=("MesloLGS%20NF%20Regular.ttf" "MesloLGS%20NF%20Bold.ttf" "MesloLGS%20NF%20Italic.ttf" "MesloLGS%20NF%20Bold%20Italic.ttf")
  local font_local_names=("MesloLGS NF Regular.ttf" "MesloLGS NF Bold.ttf" "MesloLGS NF Italic.ttf" "MesloLGS NF Bold Italic.ttf")
  local fonts_installed=0
  local fonts_skipped=0

  case $OS in
    "fedora"|"ubuntu")
      local font_dir="$HOME/.local/share/fonts"
      ;;
    "macos")
      local font_dir="$HOME/Library/Fonts"
      ;;
    *)
      log_error "Unsupported OS for font installation: $OS"
      FAILED+=("Meslo fonts")
      return 1
      ;;
  esac

  mkdir -p "$font_dir"

  for i in "${!font_names[@]}"; do
    if [ ! -f "$font_dir/${font_local_names[$i]}" ]; then
      if curl -sL "$font_url/${font_names[$i]}" --output "$font_dir/${font_local_names[$i]}"; then
        ((fonts_installed++))
      else
        log_error "Failed to download ${font_local_names[$i]}"
        FAILED+=("${font_local_names[$i]}")
      fi
    else
      ((fonts_skipped++))
    fi
  done

  # Only chmod the Meslo fonts we installed
  for font in "${font_local_names[@]}"; do
    [ -f "$font_dir/$font" ] && chmod 644 "$font_dir/$font"
  done

  if [ "$OS" != "macos" ]; then
    fc-cache -f -v > /dev/null 2>&1
  fi

  if [ $fonts_installed -gt 0 ]; then
    log_success "Installed $fonts_installed Meslo font(s)"
    INSTALLED+=("Meslo fonts ($fonts_installed)")
  fi
  if [ $fonts_skipped -gt 0 ]; then
    log_skip "Meslo fonts already installed ($fonts_skipped)"
    [ $fonts_installed -eq 0 ] && SKIPPED+=("Meslo fonts")
  fi
}

# =============================================================================
# Main Script
# =============================================================================

echo ""
echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║           Zsh Configuration Script                            ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════╝${NC}"

log_section "Detecting Environment"
detect_os
log_info "Detected OS: $OS"

# -----------------------------------------------------------------------------
log_section "Checking Network Connectivity"
# -----------------------------------------------------------------------------

check_network() {
  log_info "Checking internet connectivity..."
  if ! curl -s --head --connect-timeout 5 https://github.com > /dev/null; then
    log_error "No internet connection detected"
    log_error "This script requires internet access to download packages"
    exit 1
  fi
  log_success "Internet connectivity confirmed"
}

check_network

# -----------------------------------------------------------------------------
log_section "Installing Xcode Command Line Tools (macOS)"
# -----------------------------------------------------------------------------

install_xcode_clt() {
  if [ "$OS" != "macos" ]; then
    return 0
  fi

  # Check if CLT is already installed
  if xcode-select -p &> /dev/null; then
    log_skip "Xcode Command Line Tools already installed"
    SKIPPED+=("Xcode CLT")
    return 0
  fi

  log_info "Installing Xcode Command Line Tools..."
  log_info "This may take several minutes..."

  # Touch the file that triggers the softwareupdate mechanism
  touch /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress

  # Find the CLT package name
  CLT_PACKAGE=$(softwareupdate -l 2>/dev/null | grep -o "Command Line Tools for Xcode-[0-9.]*" | head -n 1)

  if [ -z "$CLT_PACKAGE" ]; then
    # Fallback: try alternative pattern
    CLT_PACKAGE=$(softwareupdate -l 2>/dev/null | grep "\*.*Command Line" | head -n 1 | awk -F"*" '{print $2}' | sed -e 's/^ *//' | tr -d '\n')
  fi

  if [ -z "$CLT_PACKAGE" ]; then
    log_error "Could not find Command Line Tools package"
    log_info "Please install manually: xcode-select --install"
    rm -f /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress
    FAILED+=("Xcode CLT")
    return 1
  fi

  # Install the CLT package
  if softwareupdate -i "$CLT_PACKAGE" --verbose; then
    log_success "Xcode Command Line Tools installed"
    INSTALLED+=("Xcode CLT")
  else
    log_error "Failed to install Xcode Command Line Tools"
    log_info "Please install manually: xcode-select --install"
    FAILED+=("Xcode CLT")
    rm -f /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress
    return 1
  fi

  rm -f /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress
}

install_xcode_clt

# -----------------------------------------------------------------------------
log_section "Installing Core Packages"
# -----------------------------------------------------------------------------

# Homebrew (macOS only - required for other package installations)
if [ "$OS" = "macos" ]; then
  if ! command -v brew &> /dev/null; then
    log_info "Installing Homebrew..."
    log_info "This may take several minutes..."

    # Use NONINTERACTIVE to avoid prompts
    if NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; then
      # Add Homebrew to PATH for this session
      if [[ -f "/opt/homebrew/bin/brew" ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
      elif [[ -f "/usr/local/bin/brew" ]]; then
        eval "$(/usr/local/bin/brew shellenv)"
      fi

      # Verify Homebrew is now available
      if command -v brew &> /dev/null; then
        log_success "Homebrew installed successfully"
        INSTALLED+=("Homebrew")
      else
        log_error "Homebrew installed but not found in PATH"
        log_error "Cannot continue without Homebrew on macOS"
        exit 1
      fi
    else
      log_error "Homebrew installation failed"
      log_error "Cannot continue without Homebrew on macOS"
      exit 1
    fi
  else
    log_skip "Homebrew already installed"
    SKIPPED+=("Homebrew")
    # Ensure brew is in PATH for this session
    if [[ -f "/opt/homebrew/bin/brew" ]]; then
      eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [[ -f "/usr/local/bin/brew" ]]; then
      eval "$(/usr/local/bin/brew shellenv)"
    fi
  fi
fi

# Git
if ! command -v git &> /dev/null; then
  log_info "Installing Git..."
  install_package git
  INSTALLED+=("Git")
else
  log_skip "Git already installed"
  SKIPPED+=("Git")
fi

# Zsh
if ! command -v zsh &> /dev/null; then
  log_info "Installing Zsh..."
  install_package zsh
  INSTALLED+=("Zsh")
else
  log_skip "Zsh already installed"
  SKIPPED+=("Zsh")
fi

# Default shell check
if [ "$SHELL" != "$(which zsh)" ]; then
  case $OS in
    "fedora"|"ubuntu")
      log_info "Setting Zsh as default shell..."
      chsh -s "$(which zsh)"
      CONFIGURED+=("Default shell → Zsh")
      ;;
    "macos")
      log_info "Default shell is not Zsh. Run: chsh -s $(which zsh)"
      ;;
  esac
else
  log_skip "Zsh is already the default shell"
fi

# -----------------------------------------------------------------------------
log_section "Installing Oh My Zsh"
# -----------------------------------------------------------------------------

if [ -d "$HOME/.oh-my-zsh" ]; then
  log_skip "Oh My Zsh already installed"
  SKIPPED+=("Oh My Zsh")
else
  log_info "Installing Oh My Zsh..."
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
  INSTALLED+=("Oh My Zsh")
fi

# -----------------------------------------------------------------------------
log_section "Installing Fonts"
# -----------------------------------------------------------------------------

install_fonts

# -----------------------------------------------------------------------------
log_section "Configuring macOS Terminal Font"
# -----------------------------------------------------------------------------

configure_macos_terminal_font() {
  if [ "$OS" != "macos" ]; then
    return 0
  fi

  log_info "Configuring Terminal.app to use MesloLGS NF font..."

  # Use osascript to configure Terminal.app default profile font
  # This sets the font for the "Basic" profile which is the default
  if osascript <<'APPLESCRIPT'
tell application "Terminal"
    set defaultSettings to default settings
    set font name of defaultSettings to "MesloLGS NF"
    set font size of defaultSettings to 12
end tell
APPLESCRIPT
  then
    log_success "Terminal.app font configured to MesloLGS NF"
    CONFIGURED+=("Terminal.app font → MesloLGS NF")
  else
    log_error "Failed to configure Terminal.app font"
    log_info "You can manually set the font in Terminal > Preferences > Profiles > Font"
    FAILED+=("Terminal.app font configuration")
  fi
}

configure_macos_terminal_font

# -----------------------------------------------------------------------------
log_section "Installing Powerlevel10k Theme"
# -----------------------------------------------------------------------------

if [ ! -d "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k" ]; then
  log_info "Installing Powerlevel10k..."
  if git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"/themes/powerlevel10k; then
    INSTALLED+=("Powerlevel10k theme")
  else
    log_error "Failed to clone Powerlevel10k"
    FAILED+=("Powerlevel10k theme")
  fi
else
  log_skip "Powerlevel10k already installed"
  SKIPPED+=("Powerlevel10k theme")
fi

# Configure theme in .zshrc
if ! grep -q 'ZSH_THEME="powerlevel10k/powerlevel10k"' ~/.zshrc; then
  sed -i.bak 's/ZSH_THEME="robbyrussell"/ZSH_THEME="powerlevel10k\/powerlevel10k"/g' ~/.zshrc
  CONFIGURED+=("ZSH_THEME → powerlevel10k")
fi

# -----------------------------------------------------------------------------
log_section "Installing Zsh Plugins"
# -----------------------------------------------------------------------------

# zsh-autosuggestions
if [ ! -d "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions" ]; then
  log_info "Installing zsh-autosuggestions..."
  if git clone https://github.com/zsh-users/zsh-autosuggestions.git "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"/plugins/zsh-autosuggestions; then
    INSTALLED+=("zsh-autosuggestions")
  else
    log_error "Failed to clone zsh-autosuggestions"
    FAILED+=("zsh-autosuggestions")
  fi
else
  log_skip "zsh-autosuggestions already installed"
  SKIPPED+=("zsh-autosuggestions")
fi

# zsh-syntax-highlighting
if [ ! -d "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting" ]; then
  log_info "Installing zsh-syntax-highlighting..."
  if git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"/plugins/zsh-syntax-highlighting; then
    INSTALLED+=("zsh-syntax-highlighting")
  else
    log_error "Failed to clone zsh-syntax-highlighting"
    FAILED+=("zsh-syntax-highlighting")
  fi
else
  log_skip "zsh-syntax-highlighting already installed"
  SKIPPED+=("zsh-syntax-highlighting")
fi

# Enable plugins in .zshrc
if ! grep -q 'plugins=(git zsh-autosuggestions zsh-syntax-highlighting)' ~/.zshrc; then
  sed -i.bak 's/plugins=(git)/plugins=(git zsh-autosuggestions zsh-syntax-highlighting)/g' ~/.zshrc
  CONFIGURED+=("Plugins → git, autosuggestions, syntax-highlighting")
fi

# -----------------------------------------------------------------------------
log_section "Installing CLI Tools"
# -----------------------------------------------------------------------------

# zoxide
if ! command -v zoxide &> /dev/null; then
  log_info "Installing zoxide..."
  install_package zoxide
  INSTALLED+=("zoxide")
else
  log_skip "zoxide already installed"
  SKIPPED+=("zoxide")
fi

# thefuck
if ! command -v thefuck &> /dev/null; then
  log_info "Installing thefuck..."
  install_package thefuck
  INSTALLED+=("thefuck")
else
  log_skip "thefuck already installed"
  SKIPPED+=("thefuck")
fi

# fd (find replacement)
# Note: package name varies by OS
if ! command -v fd &> /dev/null && ! command -v fdfind &> /dev/null; then
  log_info "Installing fd..."
  case $OS in
    "ubuntu"|"debian")
      install_package fd-find
      ;;
    *)
      install_package fd
      ;;
  esac
  INSTALLED+=("fd")
else
  log_skip "fd already installed"
  SKIPPED+=("fd")
fi

# bat (cat replacement)
# Note: package name varies by OS
if ! command -v bat &> /dev/null && ! command -v batcat &> /dev/null; then
  log_info "Installing bat..."
  case $OS in
    "ubuntu"|"debian")
      install_package bat
      ;;
    *)
      install_package bat
      ;;
  esac
  INSTALLED+=("bat")
else
  log_skip "bat already installed"
  SKIPPED+=("bat")
fi

# fzf (fuzzy finder)
if ! command -v fzf &> /dev/null; then
  log_info "Installing fzf..."
  install_package fzf
  INSTALLED+=("fzf")
else
  log_skip "fzf already installed"
  SKIPPED+=("fzf")
fi

# jq (JSON processor)
if ! command -v jq &> /dev/null; then
  log_info "Installing jq..."
  install_package jq
  INSTALLED+=("jq")
else
  log_skip "jq already installed"
  SKIPPED+=("jq")
fi

# tree (directory tree viewer)
if ! command -v tree &> /dev/null; then
  log_info "Installing tree..."
  install_package tree
  INSTALLED+=("tree")
else
  log_skip "tree already installed"
  SKIPPED+=("tree")
fi

# ShellCheck (shell script linter)
if ! command -v shellcheck &> /dev/null; then
  log_info "Installing shellcheck..."
  install_package shellcheck
  INSTALLED+=("shellcheck")
else
  log_skip "shellcheck already installed"
  SKIPPED+=("shellcheck")
fi

# -----------------------------------------------------------------------------
log_section "Installing Ghostty Terminal"
# -----------------------------------------------------------------------------

install_ghostty() {
  case $OS in
    "macos")
      if ! command -v ghostty &> /dev/null && [ ! -d "/Applications/Ghostty.app" ]; then
        log_info "Installing Ghostty via Homebrew..."
        brew install --cask ghostty
        INSTALLED+=("Ghostty")
      else
        log_skip "Ghostty already installed"
        SKIPPED+=("Ghostty")
      fi
      ;;
    "ubuntu"|"debian")
      if ! command -v ghostty &> /dev/null; then
        log_info "Installing Ghostty (Ubuntu/Debian)..."
        # Use the community-maintained deb package installer
        # https://github.com/mkasberg/ghostty-ubuntu
        if curl -fsSL https://raw.githubusercontent.com/mkasberg/ghostty-ubuntu/HEAD/install.sh | /bin/bash; then
          INSTALLED+=("Ghostty")
        else
          log_error "Ghostty installation failed"
          FAILED+=("Ghostty")
        fi
      else
        log_skip "Ghostty already installed"
        SKIPPED+=("Ghostty")
      fi
      ;;
    "fedora")
      if ! command -v ghostty &> /dev/null; then
        log_info "Installing Ghostty (Fedora)..."
        # https://copr.fedorainfracloud.org/coprs/pgdev/ghostty
        if sudo dnf copr enable -y pgdev/ghostty && sudo dnf install -y ghostty; then
          INSTALLED+=("Ghostty")
        else
          log_error "Ghostty installation failed"
          FAILED+=("Ghostty")
        fi
      else
        log_skip "Ghostty already installed"
        SKIPPED+=("Ghostty")
      fi
      ;;
    *)
      log_info "Ghostty installation: manual install required for $OS"
      SKIPPED+=("Ghostty (manual install needed)")
      ;;
  esac
}

configure_ghostty() {
  local ghostty_config_dir
  local ghostty_config_file

  case $OS in
    "macos")
      ghostty_config_dir="$HOME/Library/Application Support/com.mitchellh.ghostty"
      ;;
    *)
      # Linux and other Unix-like systems use XDG config
      ghostty_config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/ghostty"
      ;;
  esac

  ghostty_config_file="$ghostty_config_dir/config"
  mkdir -p "$ghostty_config_dir"

  # Check if config already has our settings (flexible spacing around =)
  if [ -f "$ghostty_config_file" ] && grep -qE 'font-family\s*=\s*MesloLGS NF' "$ghostty_config_file"; then
    log_skip "Ghostty already configured"
    return 0
  fi

  log_info "Configuring Ghostty..."

  # If config exists, append our settings; otherwise create new
  if [ -f "$ghostty_config_file" ]; then
    # Check if settings already exist before appending
    if ! grep -q 'font-family' "$ghostty_config_file"; then
      echo "" >> "$ghostty_config_file"
      echo "# Font" >> "$ghostty_config_file"
      echo "font-family = MesloLGS NF" >> "$ghostty_config_file"
    fi
    if ! grep -q 'background' "$ghostty_config_file"; then
      echo "" >> "$ghostty_config_file"
      echo "# Colors" >> "$ghostty_config_file"
      echo "background = #0d0d0d" >> "$ghostty_config_file"
    fi
    if ! grep -q 'foreground' "$ghostty_config_file"; then
      echo "foreground = #bd93f9" >> "$ghostty_config_file"
    fi
  else
    cat > "$ghostty_config_file" << 'EOL'
# Ghostty Configuration

# Font
font-family = MesloLGS NF

# Colors (Dracula-inspired)
background = #0d0d0d
foreground = #bd93f9
EOL
  fi

  CONFIGURED+=("Ghostty config")
}

install_ghostty
configure_ghostty

# -----------------------------------------------------------------------------
log_section "Configuring .zshrc"
# -----------------------------------------------------------------------------

# History timestamp format (epoch, ISO date, time with timezone)
if ! grep -q 'HIST_STAMPS=' ~/.zshrc; then
  log_info "Adding history timestamp format..."
  sed -i.bak 's/# HIST_STAMPS="mm\/dd\/yyyy"/HIST_STAMPS="%s %F %R-%Z "/' ~/.zshrc
  CONFIGURED+=("HIST_STAMPS → epoch + ISO date + time")
else
  log_skip "HIST_STAMPS already configured"
fi

# Homebrew configuration (macOS)
if [ "$OS" = "macos" ]; then
  if ! grep -q 'eval "\$(/opt/homebrew/bin/brew shellenv)"' ~/.zshrc; then
    log_info "Adding Homebrew configuration..."
    echo "" >> ~/.zshrc
    echo "# Homebrew configuration" >> ~/.zshrc
    echo 'if [[ -f "/opt/homebrew/bin/brew" ]]; then' >> ~/.zshrc
    echo '    eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zshrc
    echo 'elif [[ -f "/usr/local/bin/brew" ]]; then' >> ~/.zshrc
    echo '    eval "$(/usr/local/bin/brew shellenv)"' >> ~/.zshrc
    echo 'fi' >> ~/.zshrc
    CONFIGURED+=("Homebrew shell env")
  else
    log_skip "Homebrew configuration already present"
  fi
fi

# zoxide init
if ! grep -q 'zoxide init' ~/.zshrc; then
  log_info "Adding zoxide initialization..."
  echo "" >> ~/.zshrc
  echo "# zoxide" >> ~/.zshrc
  echo 'eval "$(zoxide init --cmd cd zsh)"' >> ~/.zshrc
  CONFIGURED+=("zoxide init")
else
  log_skip "zoxide init already configured"
fi

# thefuck init
if ! grep -q 'thefuck --alias' ~/.zshrc; then
  log_info "Adding thefuck initialization..."
  echo "" >> ~/.zshrc
  echo "# thefuck" >> ~/.zshrc
  echo 'eval "$(thefuck --alias)"' >> ~/.zshrc
  CONFIGURED+=("thefuck alias")
else
  log_skip "thefuck alias already configured"
fi

# fzf init
if ! grep -q 'fzf --zsh' ~/.zshrc && ! grep -q 'fzf.zsh' ~/.zshrc; then
  log_info "Adding fzf initialization..."
  echo "" >> ~/.zshrc
  echo "# fzf" >> ~/.zshrc
  echo 'if command -v fzf &> /dev/null; then' >> ~/.zshrc
  echo '  eval "$(fzf --zsh)"' >> ~/.zshrc
  echo 'fi' >> ~/.zshrc
  CONFIGURED+=("fzf init")
else
  log_skip "fzf init already configured"
fi

# bat alias (cat replacement)
# On Ubuntu/Debian, bat is installed as 'batcat'
if ! grep -q 'alias cat=' ~/.zshrc; then
  log_info "Adding bat alias (cat replacement)..."
  echo "" >> ~/.zshrc
  echo "# bat (cat replacement)" >> ~/.zshrc
  echo 'if command -v bat &> /dev/null; then' >> ~/.zshrc
  echo '  alias cat="bat --paging=never"' >> ~/.zshrc
  echo '  alias catp="bat"' >> ~/.zshrc
  echo 'elif command -v batcat &> /dev/null; then' >> ~/.zshrc
  echo '  alias cat="batcat --paging=never"' >> ~/.zshrc
  echo '  alias catp="batcat"' >> ~/.zshrc
  echo 'fi' >> ~/.zshrc
  CONFIGURED+=("alias cat → bat")
else
  log_skip "cat alias already configured"
fi

# fd alias (on Ubuntu/Debian it's 'fdfind')
if ! grep -q 'alias fd=' ~/.zshrc; then
  log_info "Adding fd alias..."
  echo "" >> ~/.zshrc
  echo "# fd (on Ubuntu/Debian it's fdfind)" >> ~/.zshrc
  echo 'if ! command -v fd &> /dev/null && command -v fdfind &> /dev/null; then' >> ~/.zshrc
  echo '  alias fd="fdfind"' >> ~/.zshrc
  echo 'fi' >> ~/.zshrc
  CONFIGURED+=("alias fd")
else
  log_skip "fd alias already configured"
fi

# Custom aliases
if ! grep -q 'alias pip=' ~/.zshrc; then
  log_info "Adding pip alias..."
  echo "" >> ~/.zshrc
  echo "# Custom aliases" >> ~/.zshrc
  echo 'alias pip="python3 -m pip"' >> ~/.zshrc
  CONFIGURED+=("alias pip")
else
  log_skip "pip alias already configured"
fi

if ! grep -q 'alias python=' ~/.zshrc; then
  log_info "Adding python alias..."
  echo 'alias python="python3"' >> ~/.zshrc
  CONFIGURED+=("alias python")
else
  log_skip "python alias already configured"
fi

# macOS-specific aliases
if [ "$OS" = "macos" ]; then
  if ! grep -q 'alias ip="ifconfig"' ~/.zshrc; then
    log_info "Adding ip alias (macOS)..."
    echo 'alias ip="ifconfig"' >> ~/.zshrc
    CONFIGURED+=("alias ip")
  else
    log_skip "ip alias already configured"
  fi
fi

# GAM (Google Workspace Admin) - remove conflicting Oh My Zsh git aliases
if ! grep -q 'unalias gam' ~/.zshrc; then
  log_info "Adding GAM alias conflict resolution..."
  echo "" >> ~/.zshrc
  echo "# Remove git am aliases that conflict with GAM (Google Workspace Admin)" >> ~/.zshrc
  echo 'unalias gam gama gamc gams gamscp 2>/dev/null' >> ~/.zshrc
  CONFIGURED+=("GAM alias conflict resolution")
else
  log_skip "GAM alias conflict resolution already configured"
fi

# GAM alias (GAMADV-XTD3)
if ! grep -q 'alias gam=' ~/.zshrc; then
  if [ -d "$HOME/bin/gamadv-xtd3" ]; then
    log_info "Adding GAM alias..."
    echo "" >> ~/.zshrc
    echo 'alias gam="$HOME/bin/gamadv-xtd3/gam"' >> ~/.zshrc
    CONFIGURED+=("alias gam → GAMADV-XTD3")
  else
    log_skip "GAMADV-XTD3 not found in ~/bin/gamadv-xtd3 — skipping alias"
  fi
else
  log_skip "GAM alias already configured"
fi

# PATH configuration
if ! grep -q '\.local/bin' ~/.zshrc; then
  log_info "Adding ~/.local/bin to PATH..."
  echo "" >> ~/.zshrc
  echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc
  CONFIGURED+=("PATH += ~/.local/bin")
else
  log_skip "$HOME/.local/bin already in PATH"
fi

# -----------------------------------------------------------------------------
# Konsole profile (Linux only)
# -----------------------------------------------------------------------------
if [ "$OS" != "macos" ] && command -v konsole &> /dev/null; then
  log_section "Configuring Konsole"
  log_info "Creating Konsole p10k profile..."
  mkdir -p ~/.local/share/konsole
  cat > ~/.local/share/konsole/p10k.profile << EOL
[Appearance]
ColorScheme=BlueOnBlack
Font=MesloLGS NF,10,-1,5,50,0,0,0,0,0

[General]
Name=p10k
Parent=FALLBACK/

[Terminal Features]
Command=/usr/bin/zsh
EOL

  konsole_config="$HOME/.config/konsolerc"
  if [ -f "$konsole_config" ]; then
    sed -i 's/^DefaultProfile=.*/DefaultProfile=p10k.profile/' "$konsole_config"
  else
    echo "[Desktop Entry]" > "$konsole_config"
    echo "DefaultProfile=p10k.profile" >> "$konsole_config"
  fi
  CONFIGURED+=("Konsole p10k profile")
fi

# -----------------------------------------------------------------------------
# Cleanup
# -----------------------------------------------------------------------------

# Remove .bak files created by sed
if ls ~/.zshrc.bak &> /dev/null; then
  rm -f ~/.zshrc.bak
  log_info "Cleaned up .zshrc.bak"
fi

# =============================================================================
# Summary
# =============================================================================
echo ""
echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                         SUMMARY                               ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""

if [ ${#INSTALLED[@]} -gt 0 ]; then
  echo -e "${GREEN}Installed:${NC}"
  for item in "${INSTALLED[@]}"; do
    echo -e "  ${GREEN}✓${NC} $item"
  done
  echo ""
fi

if [ ${#CONFIGURED[@]} -gt 0 ]; then
  echo -e "${BLUE}Configured:${NC}"
  for item in "${CONFIGURED[@]}"; do
    echo -e "  ${BLUE}✓${NC} $item"
  done
  echo ""
fi

if [ ${#SKIPPED[@]} -gt 0 ]; then
  echo -e "${YELLOW}Skipped (already present):${NC}"
  for item in "${SKIPPED[@]}"; do
    echo -e "  ${YELLOW}–${NC} $item"
  done
  echo ""
fi

if [ ${#FAILED[@]} -gt 0 ]; then
  echo -e "${RED}Failed:${NC}"
  for item in "${FAILED[@]}"; do
    echo -e "  ${RED}✗${NC} $item"
  done
  echo ""
fi

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "To apply changes, run:"
echo -e "  ${GREEN}exec zsh${NC}"
echo ""
