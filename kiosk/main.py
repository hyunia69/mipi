import os
import sys
import argparse
from pathlib import Path


FONT_PREFERENCES = ("Pretendard", "Noto Sans KR", "Malgun Gothic", "Apple SD Gothic Neo")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Digital Telescope Kiosk")
    parser.add_argument("--theme", choices=["holo", "minimal", "future"], default="holo", help="UI Theme Style")
    parser.add_argument("--mode", choices=["demo", "live"], default="demo",
                        help="demo=기존 슬라이드쇼, live=실제 카메라 영상")
    parser.add_argument("--camera-device", default="/dev/video0", help="V4L2 device path")
    parser.add_argument("--camera-backend", choices=["qt", "gstreamer"], default="qt",
                        help="qt=FFmpeg/Qt 기본 백엔드, gstreamer=Qt Multimedia GStreamer 백엔드")
    parser.add_argument("--camera-size", default="1920x1080", help="WxH (e.g. 1920x1080)")
    parser.add_argument("--camera-fps", type=int, default=60)
    args, _ = parser.parse_known_args()
    try:
        w, h = (int(x) for x in args.camera_size.lower().split("x"))
    except (ValueError, AttributeError):
        w, h = 1920, 1080
    args.camera_width = w
    args.camera_height = h
    return args


# Args must be parsed before any Qt Multimedia import so QT_MEDIA_BACKEND can take effect
_ARGS = parse_args()
if _ARGS.mode == "live" and _ARGS.camera_backend == "gstreamer":
    os.environ["QT_MEDIA_BACKEND"] = "gstreamer"


from PySide6.QtCore import QUrl  # noqa: E402
from PySide6.QtGui import QFontDatabase, QGuiApplication  # noqa: E402
from PySide6.QtQml import QQmlApplicationEngine  # noqa: E402

from camera_control import CameraController  # noqa: E402


def load_application_fonts(font_dir: Path) -> list[str]:
    loaded_families: list[str] = []
    if not font_dir.exists():
        return loaded_families
    for pattern in ("*.otf", "*.ttf"):
        for font_file in sorted(font_dir.glob(pattern)):
            font_id = QFontDatabase.addApplicationFont(str(font_file))
            if font_id == -1:
                print(f"[fonts] Failed to load: {font_file.name}", file=sys.stderr)
                continue
            for family in QFontDatabase.applicationFontFamilies(font_id):
                if family not in loaded_families:
                    loaded_families.append(family)
    return loaded_families


def resolve_primary_font(loaded_families: list[str]) -> str:
    system_families = set(QFontDatabase.families())
    available = set(loaded_families) | system_families
    for candidate in FONT_PREFERENCES:
        if candidate in available:
            return candidate
    return QGuiApplication.font().family()


def main() -> int:
    args = _ARGS

    app = QGuiApplication(sys.argv)
    app.setApplicationName("Digital Telescope Kiosk")
    app.setOrganizationName("Dasam")

    base_dir = Path(__file__).resolve().parent
    assets_dir = base_dir / "assets"

    loaded = load_application_fonts(assets_dir / "fonts")
    primary_font = resolve_primary_font(loaded)
    print(f"[fonts] Loaded: {loaded or '(none)'}  |  Primary: {primary_font}")
    print(f"[theme] Active Style: {args.theme}")
    print(f"[mode]  {args.mode}  "
          f"(camera={args.camera_device}  backend={args.camera_backend}  "
          f"{args.camera_width}x{args.camera_height}@{args.camera_fps})")

    engine = QQmlApplicationEngine()

    camera_controller = CameraController(args.mode, parent=app)
    app.aboutToQuit.connect(camera_controller.close)

    ctx = engine.rootContext()
    ctx.setContextProperty("ASSETS_URL", QUrl.fromLocalFile(str(assets_dir)).toString())
    ctx.setContextProperty("PRIMARY_FONT", primary_font)
    ctx.setContextProperty("appTheme", args.theme)
    ctx.setContextProperty("appMode", args.mode)
    ctx.setContextProperty("cameraDevicePath", args.camera_device)
    ctx.setContextProperty("cameraBackend", args.camera_backend)
    ctx.setContextProperty("cameraWidth", args.camera_width)
    ctx.setContextProperty("cameraHeight", args.camera_height)
    ctx.setContextProperty("cameraFps", args.camera_fps)
    ctx.setContextProperty("cameraController", camera_controller)

    qml_dir = base_dir / "qml"
    engine.addImportPath(str(qml_dir))

    qml_file = qml_dir / "Main.qml"
    engine.load(QUrl.fromLocalFile(str(qml_file)))

    if not engine.rootObjects():
        print("Failed to load QML", file=sys.stderr)
        return -1

    return app.exec()


if __name__ == "__main__":
    sys.exit(main())
