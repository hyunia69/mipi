"""12-hour soak: run kiosk and sample RSS + free GPU memory every 60s.

Usage on Jetson:
    ON_JETSON=1 python scripts/soak_avatar.py --hours 12 --out soak.csv

Local sanity (Windows/macOS, no Jetson):
    python scripts/soak_avatar.py --hours 0.05 --interval 5 --out soak_local.csv
"""
from __future__ import annotations

import argparse
import csv
import os
import subprocess
import sys
import time
from pathlib import Path


def sample_rss_kb(pid: int) -> int:
    """Read /proc/<pid>/status VmRSS in kB. Returns -1 on non-Linux or missing."""
    try:
        with open(f"/proc/{pid}/status") as f:
            for line in f:
                if line.startswith("VmRSS:"):
                    return int(line.split()[1])
    except (FileNotFoundError, PermissionError):
        return -1
    return -1


def sample_gpu_free_kb() -> int:
    """Best-effort GPU-free measurement on Tegra. Returns -1 if unavailable."""
    # tegrastats parsing is platform-specific and noisy; placeholder for now.
    # User can extend this on Jetson with parsing logic if needed.
    return -1


def main():
    p = argparse.ArgumentParser(description="Soak runner for kiosk avatar widget.")
    p.add_argument("--hours", type=float, default=12.0,
                   help="Soak duration in hours (default 12).")
    p.add_argument("--interval", type=float, default=60.0,
                   help="Seconds between samples (default 60).")
    p.add_argument("--out", default="soak.csv",
                   help="Output CSV path (default soak.csv in cwd).")
    p.add_argument("--mode", choices=["demo", "live"], default="demo",
                   help="Kiosk mode (default demo).")
    args = p.parse_args()

    kiosk_root = Path(__file__).resolve().parent.parent
    env = os.environ.copy()
    if env.get("ON_JETSON") == "1":
        env.setdefault("QT_QPA_PLATFORM", "eglfs")
        env.setdefault("QTWEBENGINE_CHROMIUM_FLAGS", "--use-gl=egl --no-sandbox")

    print(f"[soak] launching kiosk mode={args.mode} hours={args.hours} interval={args.interval}s")
    proc = subprocess.Popen(
        [sys.executable, "main.py", "--mode", args.mode, "--theme", "holo"],
        cwd=str(kiosk_root),
        env=env,
    )
    time.sleep(10)  # let it boot

    deadline = time.monotonic() + args.hours * 3600
    out_path = Path(args.out).resolve()
    print(f"[soak] writing samples to {out_path}")

    rc = 0
    with open(out_path, "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["t_seconds", "rss_kb", "gpu_free_kb"])
        t0 = time.monotonic()
        while time.monotonic() < deadline:
            rss = sample_rss_kb(proc.pid)
            gpu = sample_gpu_free_kb()
            t = time.monotonic() - t0
            w.writerow([f"{t:.1f}", rss, gpu])
            f.flush()
            if proc.poll() is not None:
                print(f"[soak] kiosk exited after {t:.1f}s rc={proc.returncode}", file=sys.stderr)
                rc = 1
                break
            time.sleep(args.interval)

    proc.terminate()
    try:
        proc.wait(timeout=15)
    except subprocess.TimeoutExpired:
        proc.kill()
    print(f"[soak] done. samples in {out_path}")
    return rc


if __name__ == "__main__":
    sys.exit(main())
