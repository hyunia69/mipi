"""Load Main.qml, jump directly to ViewingScreen, keep the window alive for N seconds.

Supports --mode demo|live (and other camera args) so we can exercise both paths
headfully. Used for eyeballing the live camera path on the Jetson.

Usage:
    python scripts/smoke_test_screen.py --mode live
    python scripts/smoke_test_screen.py --mode demo --seconds 5
"""
import argparse
import os
import sys
import time
from pathlib import Path


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--theme", default="holo")
    parser.add_argument("--mode", choices=["demo", "live"], default="live")
    parser.add_argument("--camera-device", default="/dev/video0")
    parser.add_argument("--camera-backend", choices=["qt", "gstreamer"], default="qt")
    parser.add_argument("--camera-size", default="1920x1080")
    parser.add_argument("--camera-fps", type=int, default=60)
    parser.add_argument("--seconds", type=float, default=4.0)
    parser.add_argument("--capture", default=None,
                        help="save a PNG screenshot after --capture-delay seconds and exit")
    parser.add_argument("--capture-delay", type=float, default=2.5)
    args = parser.parse_args()

    if args.mode == "live" and args.camera_backend == "gstreamer":
        os.environ["QT_MEDIA_BACKEND"] = "gstreamer"

    from PySide6.QtCore import QTimer, QUrl
    from PySide6.QtGui import QFontDatabase, QGuiApplication
    from PySide6.QtQml import QQmlApplicationEngine
    from PySide6.QtQuick import QQuickWindow

    base = Path(__file__).resolve().parent.parent
    sys.stdout.reconfigure(line_buffering=True)

    app = QGuiApplication(sys.argv)
    for p in (base / "assets" / "fonts").glob("*.otf"):
        QFontDatabase.addApplicationFont(str(p))

    try:
        w, h = (int(x) for x in args.camera_size.lower().split("x"))
    except Exception:
        w, h = 1920, 1080

    engine = QQmlApplicationEngine()
    ctx = engine.rootContext()
    ctx.setContextProperty("ASSETS_URL", QUrl.fromLocalFile(str(base / "assets")).toString())
    ctx.setContextProperty("PRIMARY_FONT", "Pretendard")
    ctx.setContextProperty("appTheme", args.theme)
    ctx.setContextProperty("appMode", args.mode)
    ctx.setContextProperty("cameraDevicePath", args.camera_device)
    ctx.setContextProperty("cameraBackend", args.camera_backend)
    ctx.setContextProperty("cameraWidth", w)
    ctx.setContextProperty("cameraHeight", h)
    ctx.setContextProperty("cameraFps", args.camera_fps)
    engine.addImportPath(str(base / "qml"))

    warnings_captured = []

    def on_warnings(ws):
        for w in ws:
            line = f"{w.url().toString()}:{w.line()}:{w.column()}: {w.description()}"
            warnings_captured.append(line)
            print("WARN:", line)

    engine.warnings.connect(on_warnings)

    # Use Main.qml but jump straight to viewing via a short QML load
    viewer_qml = f"""
import QtQuick
import QtQuick.Window
import "../qml"
import "../qml/screens"

Window {{
    id: win
    width: 1920
    height: 1080
    visible: true
    title: "SmokeTestScreen - {args.mode}"
    color: "#000"

    Component.onCompleted: Theme.init(
        typeof PRIMARY_FONT !== "undefined" ? PRIMARY_FONT : "",
        typeof ASSETS_URL !== "undefined" ? ASSETS_URL : ""
    )

    ViewingScreen {{
        anchors.fill: parent
    }}
}}
"""
    tmp = base / "scripts" / "_smoke_viewing_window.qml"
    tmp.write_text(viewer_qml, encoding="utf-8")
    try:
        engine.load(QUrl.fromLocalFile(str(tmp)))
        if not engine.rootObjects():
            print("FAIL: QML did not load.")
            for w in warnings_captured:
                print("  ", w)
            return 1
        print(f"OK: running for {args.seconds}s...")
        start = time.monotonic()

        if args.capture:
            def do_capture():
                roots = engine.rootObjects()
                if not roots:
                    print("capture: no root object")
                    app.quit()
                    return
                win = roots[0]
                img = None
                if isinstance(win, QQuickWindow):
                    img = win.grabWindow()
                if img is None or img.isNull():
                    screen = app.primaryScreen()
                    if screen is not None:
                        pix = screen.grabWindow(win.winId() if hasattr(win, "winId") else 0)
                        img = pix.toImage() if pix is not None else None
                if img is not None and not img.isNull() and img.save(args.capture):
                    print(f"capture saved: {args.capture} ({img.width()}x{img.height()})")
                else:
                    print(f"capture save FAILED: {args.capture}")
                app.quit()
            QTimer.singleShot(int(args.capture_delay * 1000), do_capture)
        else:
            QTimer.singleShot(int(args.seconds * 1000), app.quit)

        rc = app.exec()
        elapsed = time.monotonic() - start
        print(f"ran for {elapsed:.2f}s; warnings={len(warnings_captured)}")
        return rc
    finally:
        try:
            tmp.unlink()
        except Exception:
            pass


if __name__ == "__main__":
    sys.exit(main())
