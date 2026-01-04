# Zsh Configuration Script

Automated setup for Zsh with Oh My Zsh, Powerlevel10k, and useful tools.

Idempotent - skips what's already installed, so you can re-run it to pick up new additions.

## Why Use This?

Go from a bare terminal to a fully-featured, beautiful shell environment in under 5 minutes. This script gives you:

- **Instant prompt** - Powerlevel10k displays immediately while background processes load
- **Smart autocompletion** - Suggestions based on your command history as you type
- **Syntax highlighting** - See command errors before you hit enter
- **Smarter navigation** - `cd` learns your most-used directories and jumps to them with partial matches
- **Typo correction** - Made a mistake? Type `fuck` and it fixes your last command
- **Better file viewing** - `cat` now has syntax highlighting courtesy of bat
  - Tip: `cat -p` for plain output (closer to traditional cat)
- **Fuzzy finding** - `Ctrl+R` for history, `Ctrl+T` for files, `Alt+C` for directories
- **Fast file search** - `fd` is a modern, user-friendly alternative to `find`
- **Beautiful terminal** - Ghostty with a sleek dark theme and proper font rendering
- **Cross-platform** - Works on macOS, Ubuntu, Debian, and Fedora with OS-appropriate installers

One script. No manual configuration. Just run it and go.

## Usage

```bash
~/.scripts/shell/zsh-config.sh
```

After running, apply changes with:
```bash
exec zsh
```

## What It Installs

| Component | Description | Link |
|-----------|-------------|------|
| Zsh | Modern shell | [zsh.org](https://www.zsh.org/) |
| Oh My Zsh | Zsh framework for managing config | [ohmyz.sh](https://ohmyz.sh/) |
| Powerlevel10k | Fast, customizable prompt theme | [GitHub](https://github.com/romkatv/powerlevel10k) |
| Meslo Nerd Fonts | Patched fonts with icons for p10k | [GitHub](https://github.com/romkatv/powerlevel10k#fonts) |
| zsh-autosuggestions | Fish-like command suggestions | [GitHub](https://github.com/zsh-users/zsh-autosuggestions) |
| zsh-syntax-highlighting | Syntax highlighting for commands | [GitHub](https://github.com/zsh-users/zsh-syntax-highlighting) |
| zoxide | Smarter `cd` that learns your habits | [GitHub](https://github.com/ajeetdsouza/zoxide) |
| thefuck | Corrects your previous command | [GitHub](https://github.com/nvbn/thefuck) |
| fd | Fast, user-friendly `find` replacement | [GitHub](https://github.com/sharkdp/fd) |
| bat | `cat` with syntax highlighting | [GitHub](https://github.com/sharkdp/bat) |
| fzf | Fuzzy finder for files, history, and more | [GitHub](https://github.com/junegunn/fzf) |
| Ghostty | Fast, GPU-accelerated terminal | [ghostty.org](https://ghostty.org/) |

## Supported Platforms

| Platform | Package Manager | Ghostty Source |
|----------|-----------------|----------------|
| macOS | Homebrew | `brew install --cask ghostty` |
| Ubuntu/Debian | apt | [mkasberg/ghostty-ubuntu](https://github.com/mkasberg/ghostty-ubuntu) |
| Fedora | dnf | [COPR pgdev/ghostty](https://copr.fedorainfracloud.org/coprs/pgdev/ghostty) |

## What It Configures

### ~/.zshrc
- Sets Powerlevel10k as the theme
- Enables plugins: `git`, `zsh-autosuggestions`, `zsh-syntax-highlighting`
- Initializes zoxide (replaces `cd` command)
- Initializes thefuck
- Initializes fzf keybindings and completion
- Aliases `cat` to `bat` for syntax-highlighted file viewing
- Adds Homebrew to PATH (macOS)
- Adds `~/.local/bin` to PATH

### Ghostty Terminal
- Font: `MesloLGS NF`
- Background: `#0d0d0d` (dark black)
- Foreground: `#bd93f9` (Dracula purple)

Config location:
- macOS: `~/Library/Application Support/com.mitchellh.ghostty/config`
- Linux: `~/.config/ghostty/config`

### Konsole (Linux only)
Creates a `p10k` profile with Meslo fonts if Konsole is detected.

## Aliases

| Alias | Command | Platform |
|-------|---------|----------|
| `cat` | `bat --paging=never` | All |
| `catp` | `bat` (with paging) | All |
| `fd` | `fdfind` | Ubuntu/Debian only* |
| `pip` | `python3 -m pip` | All |
| `python` | `python3` | All |
| `ip` | `ifconfig` | macOS |

*On Ubuntu/Debian, `fd` is packaged as `fd-find` and the binary is `fdfind`. The alias normalizes this.

## Keyboard Shortcuts (fzf)

| Shortcut | Action |
|----------|--------|
| `Ctrl+R` | Fuzzy search command history |
| `Ctrl+T` | Fuzzy find files in current directory |
| `Alt+C` | Fuzzy find and cd into directory |

## Features

- **Idempotent**: Skips already-installed components
- **Error handling**: Tracks and reports failures
- **Color-coded output**: Easy to read progress and summary
- **Cleanup**: Removes temporary `.bak` files after sed operations

## Post-Install

After running the script for the first time, you may want to:

1. Run `p10k configure` to customize your Powerlevel10k prompt
2. Restart your terminal or run `exec zsh` to apply changes
3. Set Ghostty as your default terminal (if desired)
