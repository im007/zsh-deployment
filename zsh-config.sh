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
      sudo dnf install -y $package_name
      ;;
    "ubuntu")
      sudo apt-get update
      sudo apt-get install -y $package_name
      ;;
    "macos")
      brew install $package_name
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
log_section "Installing Core Packages"
# -----------------------------------------------------------------------------

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
      chsh -s $(which zsh)
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
log_section "Installing Powerlevel10k Theme"
# -----------------------------------------------------------------------------

if [ ! -d "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k" ]; then
  log_info "Installing Powerlevel10k..."
  if git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k; then
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
  if git clone https://github.com/zsh-users/zsh-autosuggestions.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions; then
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
  if git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting; then
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

# PATH configuration
if ! grep -q '\.local/bin' ~/.zshrc; then
  log_info "Adding ~/.local/bin to PATH..."
  echo "" >> ~/.zshrc
  echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc
  CONFIGURED+=("PATH += ~/.local/bin")
else
  log_skip "~/.local/bin already in PATH"
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
