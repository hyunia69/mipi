"""Measure camera frames-per-second from /dev/video0.

This script taps into a v4l2 device directly (not the Qt pipeline) to get an
upper-bound FPS reading. We compare:

    avatar OFF:   measured FPS over <duration>s
    avatar ON:    measured FPS over <duration>s

If they differ by more than 2 fps, we have a regression.
"""
from __future__ import annotations

import argparse
import sys
import time
from pathlib import Path

try:
    import cv2
except ImportError:
    print("opencv-python not installed; skipping (install with: pip install opencv-python-headless)", file=sys.stderr)
    sys.exit(77)


def measure_fps(device: str, duration_s: float = 30.0) -> float:
    cap = cv2.VideoCapture(device, cv2.CAP_V4L2)
    if not cap.isOpened():
        raise RuntimeError(f"cannot open {device}")
    cap.set(cv2.CAP_PROP_FRAME_WIDTH, 1920)
    cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 1080)
    cap.set(cv2.CAP_PROP_FPS, 60)
    deadline = time.monotonic() + duration_s
    n = 0
    t0 = time.monotonic()
    while time.monotonic() < deadline:
        ok, _ = cap.read()
        if not ok:
            break
        n += 1
    elapsed = time.monotonic() - t0
    cap.release()
    return n / elapsed if elapsed > 0 else 0.0


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--device", default="/dev/video0")
    p.add_argument("--duration", type=float, default=30.0)
    args = p.parse_args()
    fps = measure_fps(args.device, args.duration)
    print(f"FPS: {fps:.2f}")


if __name__ == "__main__":
    main()
