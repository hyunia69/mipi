"""Headless live-mode smoke test.

Opens /dev/video0 via QCamera + QVideoSink, counts frames for 3 seconds,
reports FPS. Exits with status 0 on >=10 frames, 1 otherwise.

Usage:
    python scripts/smoke_test_live.py
    python scripts/smoke_test_live.py --backend gstreamer
    python scripts/smoke_test_live.py --device /dev/video0 --seconds 3
"""
import argparse
import os
import sys
import time


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--backend", choices=["qt", "gstreamer"], default="qt")
    parser.add_argument("--device", default="/dev/video0")
    parser.add_argument("--seconds", type=float, default=3.0)
    parser.add_argument("--min-frames", type=int, default=10)
    args = parser.parse_args()

    if args.backend == "gstreamer":
        os.environ["QT_MEDIA_BACKEND"] = "gstreamer"

    from PySide6.QtCore import QCoreApplication, QTimer
    from PySide6.QtMultimedia import (
        QCamera,
        QMediaCaptureSession,
        QMediaDevices,
        QVideoSink,
    )

    app = QCoreApplication(sys.argv)

    def pick_device():
        inputs = QMediaDevices.videoInputs()
        for c in inputs:
            if bytes(c.id()).decode("utf-8", "replace") == args.device:
                return c
        for c in inputs:
            if args.device.encode() in bytes(c.id()):
                return c
        return QMediaDevices.defaultVideoInput()

    cam_device = pick_device()
    if not cam_device.description():
        print(f"FAIL: no camera matching '{args.device}' and no default input.")
        return 1
    print(f"backend: {os.environ.get('QT_MEDIA_BACKEND', '(default=ffmpeg)')}")
    print(f"camera : {cam_device.description()}  id={bytes(cam_device.id()).decode()}")

    camera = QCamera(cam_device)
    session = QMediaCaptureSession()
    sink = QVideoSink()
    session.setCamera(camera)
    session.setVideoSink(sink)

    counter = {"n": 0, "last_size": None, "last_fmt": None}

    def on_frame():
        frame = sink.videoFrame()
        if frame.isValid():
            counter["n"] += 1
            counter["last_size"] = (frame.width(), frame.height())
            counter["last_fmt"] = frame.pixelFormat()

    sink.videoFrameChanged.connect(on_frame)

    errors = []
    camera.errorOccurred.connect(lambda e, s: errors.append(f"{e}: {s}"))
    camera.start()

    start = time.monotonic()

    def tick():
        elapsed = time.monotonic() - start
        if elapsed >= args.seconds:
            camera.stop()
            app.quit()
            return

    timer = QTimer()
    timer.setInterval(50)
    timer.timeout.connect(tick)
    timer.start()

    app.exec()

    elapsed = time.monotonic() - start
    fps = counter["n"] / max(elapsed, 0.001)
    print(f"frames received: {counter['n']}  ({fps:.1f} fps over {elapsed:.2f}s)")
    if counter["last_size"]:
        print(f"last frame: {counter['last_size'][0]}x{counter['last_size'][1]} "
              f"fmt={counter['last_fmt']}")
    if errors:
        print("errors:")
        for e in errors:
            print(" ", e)
    if counter["n"] < args.min_frames:
        print(f"FAIL: received fewer than {args.min_frames} frames.")
        return 1
    print("OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
