"""`agentsmon update` — pull the latest code and reload, without re-running setup."""
from __future__ import annotations

import shutil
import subprocess
import sys
from pathlib import Path

import agentsmon


def run() -> int:
    src = Path.home() / ".agentsmon-src"
    if not (src / ".git").is_dir():
        print("No ~/.agentsmon-src clone found — update manually (git pull / pip install -U).")
        return 1
    r = subprocess.run(["git", "-C", str(src), "pull", "--ff-only"], capture_output=True, text=True)
    print((r.stdout + r.stderr).strip()[:400] or "(no output)")
    if r.returncode != 0:
        return 1
    # If running from site-packages (a pip install), reinstall from the refreshed clone.
    if str(src.resolve()) not in str(Path(agentsmon.__file__).resolve()):
        if subprocess.run([sys.executable, "-m", "pip", "install", "--user", "--upgrade", str(src)],
                          capture_output=True).returncode != 0:
            subprocess.run([sys.executable, "-m", "pip", "install", "--user",
                            "--break-system-packages", "--upgrade", str(src)], capture_output=True)
    # Reload the running dashboard (cron brings it back on the new code within a minute).
    if shutil.which("pkill"):
        subprocess.run(["pkill", "-f", "agentsmon dashboard"], capture_output=True)
    print("✓ Updated. Dashboard/keepalive reload via cron. Add new bots with:  agentsmon add")
    return 0
