"""CRITICAL regression: avatar must not affect live camera frame rate.

This test is GATED on a Jetson device with /dev/video0 + LT9211C bridge present.
On dev machines it skips. The test starts the kiosk in live mode twice (once
with --no-avatar, once without) and measures sustained FPS.

Run only on Jetson:    ON_JETSON=1 pytest tests/test_live_camera_regression.py -v
"""
from __future__ import annotations

import os
import subprocess
import sys
import time
from pathlib import Path

import pytest

JETSON = os.path.exists("/dev/video0") and os.environ.get("ON_JETSON") == "1"
pytestmark = pytest.mark.skipif(not JETSON, reason="requires Jetson with /dev/video0 and ON_JETSON=1")

KIOSK_ROOT = Path(__file__).resolve().parent.parent


def _run_kiosk_for(duration_s: float, *, avatar: bool) -> float:
    """Launch kiosk in live mode for duration_s, return measured camera fps."""
    measure_script = KIOSK_ROOT / "scripts" / "measure_camera_fps.py"

    env = os.environ.copy()
    env["QT_QPA_PLATFORM"] = "eglfs"
    env["QTWEBENGINE_CHROMIUM_FLAGS"] = "--use-gl=egl --no-sandbox"

    args = [sys.executable, "main.py", "--mode", "live", "--theme", "holo"]
    if not avatar:
        args.append("--no-avatar")

    kiosk = subprocess.Popen(args, cwd=str(KIOSK_ROOT), env=env,
                             stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    time.sleep(8)  # let it boot + camera settle

    measure = subprocess.run(
        [sys.executable, str(measure_script), "--duration", str(duration_s)],
        capture_output=True, text=True, env=env,
    )
    kiosk.terminate()
    try:
        kiosk.wait(timeout=10)
    except subprocess.TimeoutExpired:
        kiosk.kill()

    out = measure.stdout.strip()
    assert out.startswith("FPS:"), f"unexpected output: {out!r} stderr={measure.stderr!r}"
    return float(out.split(":", 1)[1].strip())


def test_live_camera_unaffected_by_avatar():
    fps_off = _run_kiosk_for(20.0, avatar=False)
    time.sleep(2)
    fps_on = _run_kiosk_for(20.0, avatar=True)
    delta = abs(fps_on - fps_off)
    print(f"\ncamera fps off={fps_off:.2f} on={fps_on:.2f} delta={delta:.2f}")
    # Allow up to 2 fps drift due to measurement noise
    assert delta <= 2.0, f"avatar regressed camera fps by {delta:.2f} (off={fps_off:.2f}, on={fps_on:.2f})"
