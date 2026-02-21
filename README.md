# Zsh Configuration Script

Automated setup for Zsh with Oh My Zsh, Powerlevel10k, and useful tools.

Idempotent — skips what's already installed, so you can re-run it to pick up new additions.

## What You Get

**Go from a bare terminal to a fully-featured, beautiful shell environment in under 5 minutes.**

- **Instant prompt** — Powerlevel10k displays immediately while background processes load
- **Smart autocompletion** — Suggestions based on your command history as you type
- **Syntax highlighting** — See command errors before you hit enter
- **Smarter navigation** — `cd` learns your most-used directories and jumps to them with partial matches
- **Typo correction** — Made a mistake? Type `fuck` and it fixes your last command
- **Better file viewing** — `cat` now has syntax highlighting courtesy of bat
  - Tip: `cat -p` for plain output (closer to traditional cat)
- **Fuzzy finding** — `Ctrl+R` for history, `Ctrl+T` for files, `Alt+C` for directories
- **Fast file search** — `fd` is a modern, user-friendly alternative to `find`
- **Beautiful terminal** — Ghostty with a sleek dark theme and proper font rendering
- **Cross-platform** — Works on macOS, Ubuntu, Debian, and Fedora with OS-appropriate installers

## Quick Start

```bash
git clone https://github.com/im007/zsh-deployment.git
cd zsh-deployment
chmod +x zsh-config.sh
./zsh-config.sh
```

After running:

1. Run `exec zsh` to apply changes
2. Run `p10k configure` to customize your prompt (first time only)
3. Set Ghostty as your default terminal (optional)

## Supported Platforms

| Platform | Package Manager |
|----------|-----------------|
| macOS | Homebrew |
| Ubuntu/Debian | apt |
| Fedora | dnf |

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
| jq | Lightweight JSON processor | [GitHub](https://github.com/jqlang/jq) |
| tree | Directory listing in tree format | [GitHub](https://github.com/Old-Man-Programmer/tree) |
| ShellCheck | Shell script static analysis tool | [GitHub](https://github.com/koalaman/shellcheck) |
| Ghostty | Fast, GPU-accelerated terminal | [ghostty.org](https://ghostty.org/) |

## What It Configures

### Shell (~/.zshrc)

- Sets Powerlevel10k as the theme
- Enables plugins: `git`, `zsh-autosuggestions`, `zsh-syntax-highlighting`
- Initializes zoxide (replaces `cd` command)
- Initializes thefuck
- Initializes fzf keybindings and completion
- Sets `HIST_STAMPS` for history timestamps (epoch + ISO date + time with timezone)
- Adds Homebrew to PATH (macOS)
- Adds `~/.local/bin` to PATH

### Aliases

| Alias | Command | Platform |
|-------|---------|----------|
| `cat` | `bat --paging=never` | All |
| `catp` | `bat` (with paging) | All |
| `fd` | `fdfind` | Ubuntu/Debian only* |
| `pip` | `python3 -m pip` | All |
| `python` | `python3` | All |
| `ip` | `ifconfig` | macOS only |

\*On Ubuntu/Debian, `fd` is packaged as `fd-find` and the binary is `fdfind`. The alias normalizes this.

### Keyboard Shortcuts (fzf)

| Shortcut | Action |
|----------|--------|
| `Ctrl+R` | Fuzzy search command history |
| `Ctrl+T` | Fuzzy find files in current directory |
| `Alt+C` | Fuzzy find and cd into directory |

### Ghostty

- Font: `MesloLGS NF`
- Background: `#0d0d0d` (dark black)
- Foreground: `#bd93f9` (Dracula purple)
- Config: `~/Library/Application Support/com.mitchellh.ghostty/config` (macOS) or `~/.config/ghostty/config` (Linux)

For alternative installation methods, see the [official Ghostty docs](https://ghostty.org/docs/install/binary).

### Konsole (Linux only)

Creates a `p10k` profile with Meslo fonts if Konsole is detected.

## Options

### `--gam`

```bash
./zsh-config.sh --gam
```

For Google Workspace admins: removes Oh My Zsh git aliases that conflict with GAMADV-XTD3 (`gam`, `gama`, `gamc`, `gams`, `gamscp`) and adds a `gam` alias pointing to `~/bin/gamadv-xtd3/gam`. The alias is added even if GAMADV-XTD3 isn't installed yet.
