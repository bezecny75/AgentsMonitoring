#!/usr/bin/env bash
# Agents Monitoring one-command installer.
# Usage:  curl -fsSL <raw-url>/install.sh | bash      (or run it from a clone)
set -euo pipefail
cd "$PWD" 2>/dev/null || cd "$HOME" 2>/dev/null || cd /

REPO="https://github.com/petrludwig-collab/AgentsMonitoring.git"
say() { printf '\033[1;36m==>\033[0m %s\n' "$*"; }
err() { printf '\033[1;31mError:\033[0m %s\n' "$*" >&2; exit 1; }

PY="$(command -v python3 || true)"
[ -n "$PY" ] || err "python3 not found. Install Python 3.10+ first."
"$PY" - <<'PYEOF' || err "Python 3.10+ required."
import sys; sys.exit(0 if sys.version_info[:2] >= (3,10) else 1)
PYEOF
say "Using $("$PY" --version)"
command -v tmux >/dev/null || say "note: tmux not found — agents run in tmux, install it before setup."

# Get the code (clone unless already inside it).
if [ -f pyproject.toml ] && grep -q "agents-monitoring" pyproject.toml 2>/dev/null; then
  SRC="$(pwd)"; say "Installing from current directory"
else
  command -v git >/dev/null || err "git not found."
  SRC="${HOME}/.agentsmon-src"
  if [ -d "$SRC/.git" ]; then say "Updating $SRC"; git -C "$SRC" pull --ff-only
  else say "Cloning into $SRC"; git clone --depth 1 "$REPO" "$SRC"; fi
fi

# pip is OPTIONAL — the package is pure standard library, so fall back to running from the clone.
INSTALLED=0
if "$PY" -m pip --version >/dev/null 2>&1 || "$PY" -m ensurepip --upgrade >/dev/null 2>&1; then
  if "$PY" -m pip install --user --upgrade "$SRC" >/dev/null 2>&1 \
     || "$PY" -m pip install --user --break-system-packages --upgrade "$SRC" >/dev/null 2>&1; then
    INSTALLED=1
  fi
fi
if [ "$INSTALLED" = 1 ]; then
  RUN=("$PY" -m agentsmon); HOW="agentsmon"
else
  # No pip: drop a tiny launcher so `agentsmon` is still a real command (not a long PYTHONPATH line).
  say "pip unavailable — installing a launcher in ~/.local/bin (dependency-free)."
  mkdir -p "$HOME/.local/bin"
  printf '#!/bin/sh\nexec env PYTHONPATH="%s" "%s" -m agentsmon "$@"\n' "$SRC" "$PY" > "$HOME/.local/bin/agentsmon"
  chmod +x "$HOME/.local/bin/agentsmon"
  case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc";; esac
  export PATH="$HOME/.local/bin:$PATH"
  RUN=("$HOME/.local/bin/agentsmon"); HOW="agentsmon"
fi

say "Run it later with:  $HOW status   (add more bots anytime with:  $HOW add)"
if [ -e /dev/tty ]; then say "Starting setup…"; exec "${RUN[@]}" setup </dev/tty
else say "Installed. Finish setup with:  $HOW setup"; fi
