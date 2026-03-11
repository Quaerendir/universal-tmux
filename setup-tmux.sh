#!/bin/bash
# setup-tmux.sh
# Quick deploy of universal tmux config on any machine
# Usage: bash setup-tmux.sh

set -e

echo "=== Tmux Universal Setup ==="

# 1. Check tmux
if ! command -v tmux &>/dev/null; then
    echo "ERROR: tmux not installed"
    echo "  Ubuntu/Debian: sudo apt install tmux"
    echo "  RHEL/Fedora:   sudo dnf install tmux"
    echo "  macOS:         brew install tmux"
    exit 1
fi

TMUX_VER=$(tmux -V | awk '{print $2}')
echo "Tmux version: $TMUX_VER"

# 2. Backup existing config
if [ -f ~/.tmux.conf ]; then
    cp ~/.tmux.conf ~/.tmux.conf.bak.$(date +%Y%m%d%H%M%S)
    echo "Backup: ~/.tmux.conf -> ~/.tmux.conf.bak.*"
fi

# 3. Install TPM
if [ ! -d ~/.tmux/plugins/tpm ]; then
    echo "Installing TPM..."
    git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
else
    echo "TPM already installed"
fi

# 4. Copy files
cp tmux-universal.conf ~/.tmux.conf
echo "Config -> ~/.tmux.conf"

mkdir -p ~/.tmux
cp gpu-stats.sh ~/.tmux/gpu-stats.sh
chmod +x ~/.tmux/gpu-stats.sh
echo "GPU script -> ~/.tmux/gpu-stats.sh"

# 5. Create resurrect directory
mkdir -p ~/.tmux/resurrect

# 6. Disable flow control (fix C-s interception by terminal)
if ! grep -q 'stty -ixon' ~/.bashrc 2>/dev/null && \
   ! grep -q 'stty -ixon' ~/.zshrc 2>/dev/null; then
    SHELL_RC="$HOME/.bashrc"
    [ -f "$HOME/.zshrc" ] && SHELL_RC="$HOME/.zshrc"
    echo 'stty -ixon' >> "$SHELL_RC"
    echo "Added 'stty -ixon' to $SHELL_RC"
fi

# 7. Summary
echo ""
echo "=== DONE ==="
echo ""
echo "Next steps:"
echo "  1. Start tmux (or: tmux kill-server && tmux)"
echo "  2. prefix + I (C-a, Shift+i) — install plugins via TPM"
echo "  3. prefix + r — reload config"
echo ""
echo "Keybindings:"
echo "  prefix + S  — save session (resurrect)"
echo "  prefix + R  — restore session"
echo "  prefix + -  — horizontal split"
echo "  prefix + |  — vertical split"
echo "  Alt+arrows  — pane navigation"
echo ""
echo "GPU auto-detect: $(~/.tmux/gpu-stats.sh 2>/dev/null || echo 'no GPU found')"
