# Zsh Configuration Script

Automated setup for Zsh with Oh My Zsh, Powerlevel10k, and useful tools.

## Usage

```bash
~/.scripts/shell/zsh-config.sh
```

## What It Installs

| Component | Description |
|-----------|-------------|
| Zsh | Shell |
| Oh My Zsh | Zsh framework |
| Powerlevel10k | Theme |
| Meslo Nerd Fonts | Required fonts for p10k |
| zsh-autosuggestions | Fish-like suggestions |
| zsh-syntax-highlighting | Command highlighting |
| zoxide | Smarter cd |
| thefuck | Command correction |
| Ghostty | Terminal emulator |

## Supported Platforms

- **macOS** (Homebrew)
- **Ubuntu/Debian** (apt + community packages)
- **Fedora** (dnf + COPR)

## Configures

- `.zshrc` with plugins, aliases, and tool initializations
- Ghostty with Meslo font and Dracula-inspired colors
- Konsole profile (Linux only, if installed)

## Aliases Added

| Alias | Command | OS |
|-------|---------|-----|
| `pip` | `python3 -m pip` | All |
| `python` | `python3` | All |
| `ip` | `ifconfig` | macOS only |
