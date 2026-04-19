"""List V4L2 cameras and supported formats via Qt Multimedia.

Usage: python scripts/probe_camera.py [--backend qt|gstreamer]
Useful before launching main.py --mode live to verify the camera is detected
by the chosen Qt Multimedia backend and to pick --camera-size/--camera-fps
values that match the sensor.
"""
import argparse
import os
import sys


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--backend", choices=["qt", "gstreamer"], default="qt")
    args = parser.parse_args()

    if args.backend == "gstreamer":
        os.environ["QT_MEDIA_BACKEND"] = "gstreamer"

    from PySide6.QtCore import QCoreApplication
    from PySide6.QtMultimedia import QMediaDevices

    app = QCoreApplication(sys.argv)  # noqa: F841

    cams = QMediaDevices.videoInputs()
    if not cams:
        print("no video input devices detected.")
        return 1

    print(f"backend: {os.environ.get('QT_MEDIA_BACKEND', '(default=ffmpeg)')}")
    print(f"detected {len(cams)} video input(s):")
    for idx, cam in enumerate(cams):
        is_default = cam == QMediaDevices.defaultVideoInput()
        tag = "  [default]" if is_default else ""
        print(f"\n[{idx}] id={bytes(cam.id()).decode('utf-8', 'replace')}{tag}")
        print(f"    description: {cam.description()}")
        pos = cam.position()
        print(f"    position: {pos}")
        formats = cam.videoFormats()
        print(f"    formats: {len(formats)}")
        for f in formats:
            res = f.resolution()
            print(f"      {res.width():4d}x{res.height():<4d}  "
                  f"{f.minFrameRate():5.1f}-{f.maxFrameRate():5.1f} fps  "
                  f"{f.pixelFormat().name.decode() if isinstance(f.pixelFormat().name, bytes) else f.pixelFormat().name}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
