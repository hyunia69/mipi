import os
import sys
import argparse
import http.server
import socketserver
import threading
from pathlib import Path


FONT_PREFERENCES = ("Pretendard", "Noto Sans KR", "Malgun Gothic", "Apple SD Gothic Neo")


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Digital Telescope Kiosk")
    parser.add_argument("--theme", choices=["holo", "minimal", "future"], default="holo")
    parser.add_argument("--mode", choices=["demo", "live"], default="demo")
    parser.add_argument("--camera-device", default="/dev/video0")
    parser.add_argument("--camera-backend", choices=["qt", "gstreamer"], default="qt")
    parser.add_argument("--camera-size", default="1920x1080")
    parser.add_argument("--camera-fps", type=int, default=60)
    parser.add_argument("--no-avatar", action="store_true",
                        help="Disable the sign-language avatar widget.")
    parser.add_argument("--avatar-repeat-ms", type=int, default=8000,
                        help="Avatar repeat interval in ms (0 = play once).")
    args, _ = parser.parse_known_args(argv)
    try:
        w, h = (int(x) for x in args.camera_size.lower().split("x"))
    except (ValueError, AttributeError):
        w, h = 1920, 1080
    args.camera_width = w
    args.camera_height = h
    return args


def start_avatar_server(serve_dir: Path) -> dict:
    """Start a localhost HTTP server serving serve_dir on a random port.

    Returns {"url": str, "stop": callable, "port": int}. Stop is idempotent.

    Why HTTP and not file://: Chromium blocks ES module imports from file://
    by default; the avatar uses ES modules (Three.js, GLTFLoader). Serving from
    127.0.0.1 sidesteps the issue without weakening security policy.
    """
    serve_dir = Path(serve_dir).resolve()
    handler_factory = lambda *a, **kw: http.server.SimpleHTTPRequestHandler(
        *a, directory=str(serve_dir), **kw)
    httpd = socketserver.TCPServer(("127.0.0.1", 0), handler_factory)
    port = httpd.server_address[1]
    thread = threading.Thread(target=httpd.serve_forever, daemon=True,
                              name=f"avatar-http-{port}")
    thread.start()

    stopped = [False]
    def stop():
        if stopped[0]:
            return
        stopped[0] = True
        httpd.shutdown()
        httpd.server_close()
        thread.join(timeout=2.0)

    return {"url": f"http://127.0.0.1:{port}/index.html", "stop": stop, "port": port}


def compute_avatar_props(web_avatar_dir: Path, *, no_avatar: bool) -> dict:
    """Return {AVATAR_URL, AVATAR_ENABLED} given filesystem + flag state.

    AVATAR_URL is a file:// URL placeholder; the actual runtime URL comes from
    the local HTTP server in main(). Tests use this helper to verify enable/disable
    logic; production overrides AVATAR_URL after starting the server.
    """
    from PySide6.QtCore import QUrl

    index_html = web_avatar_dir / "index.html"
    icaro = web_avatar_dir / "assets" / "icaro.glb"
    casa = web_avatar_dir / "assets" / "bundles" / "CASA.threejs.json"
    enabled = (not no_avatar) and index_html.is_file() and icaro.is_file() and casa.is_file()
    return {
        "AVATAR_URL": QUrl.fromLocalFile(str(index_html)).toString(),
        "AVATAR_ENABLED": enabled,
    }


# Args must be parsed before any Qt Multimedia import so QT_MEDIA_BACKEND can take effect
_ARGS = parse_args()
if _ARGS.mode == "live" and _ARGS.camera_backend == "gstreamer":
    os.environ["QT_MEDIA_BACKEND"] = "gstreamer"

# WebEngine: ensure EGLFS-compatible flags BEFORE QtWebEngineQuick import
if os.environ.get("QT_QPA_PLATFORM") == "eglfs":
    _flags = os.environ.get("QTWEBENGINE_CHROMIUM_FLAGS", "")
    for needed in ("--use-gl=egl", "--no-sandbox", "--disable-gpu-sandbox"):
        if needed not in _flags:
            _flags = (_flags + " " + needed).strip()
    os.environ["QTWEBENGINE_CHROMIUM_FLAGS"] = _flags


from PySide6.QtCore import QUrl  # noqa: E402
from PySide6.QtGui import QFontDatabase, QGuiApplication  # noqa: E402
from PySide6.QtQml import QQmlApplicationEngine  # noqa: E402
from PySide6.QtWebEngineQuick import QtWebEngineQuick  # noqa: E402

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

    QtWebEngineQuick.initialize()
    app = QGuiApplication(sys.argv)
    app.setApplicationName("Digital Telescope Kiosk")
    app.setOrganizationName("Dasam")

    base_dir = Path(__file__).resolve().parent
    assets_dir = base_dir / "assets"
    web_avatar_dir = base_dir / "web" / "avatar"

    loaded = load_application_fonts(assets_dir / "fonts")
    primary_font = resolve_primary_font(loaded)
    avatar_props = compute_avatar_props(web_avatar_dir, no_avatar=args.no_avatar)

    # If avatar is enabled, start the local HTTP server and override the URL
    avatar_server = None
    if avatar_props["AVATAR_ENABLED"]:
        try:
            avatar_server = start_avatar_server(web_avatar_dir)
            avatar_props["AVATAR_URL"] = avatar_server["url"]
        except OSError as e:
            print(f"[avatar] WARNING: failed to start local server ({e}); disabling avatar", file=sys.stderr)
            avatar_props["AVATAR_ENABLED"] = False

    # Stop the avatar server on app exit
    if avatar_server:
        app.aboutToQuit.connect(avatar_server["stop"])

    print(f"[fonts] Loaded: {loaded or '(none)'}  |  Primary: {primary_font}")
    print(f"[theme] Active Style: {args.theme}")
    print(f"[mode]  {args.mode}  "
          f"(camera={args.camera_device}  backend={args.camera_backend}  "
          f"{args.camera_width}x{args.camera_height}@{args.camera_fps})")
    print(f"[avatar] enabled={avatar_props['AVATAR_ENABLED']}  "
          f"repeat_ms={args.avatar_repeat_ms}  url={avatar_props['AVATAR_URL']}")

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
    ctx.setContextProperty("AVATAR_URL", avatar_props["AVATAR_URL"])
    ctx.setContextProperty("AVATAR_ENABLED", avatar_props["AVATAR_ENABLED"])
    ctx.setContextProperty("AVATAR_REPEAT_MS", args.avatar_repeat_ms)

    qml_dir = base_dir / "qml"
    engine.addImportPath(str(qml_dir))

    qml_file = qml_dir / "Main.qml"
    engine.load(QUrl.fromLocalFile(str(qml_file)))

    if not engine.rootObjects():
        print("Failed to load QML", file=sys.stderr)
        if avatar_server:
            avatar_server["stop"]()
        return -1

    rc = app.exec()
    if avatar_server:
        avatar_server["stop"]()
    return rc


if __name__ == "__main__":
    sys.exit(main())
