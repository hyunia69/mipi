"""Headless smoke test: load QML and exit. Prints load status and any errors."""
import os
import sys
from pathlib import Path

from PySide6.QtCore import QTimer, QUrl
from PySide6.QtGui import QFontDatabase, QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine

base = Path(__file__).resolve().parent.parent
sys.stdout.reconfigure(line_buffering=True)

app = QGuiApplication(sys.argv)
fonts_dir = base / "assets" / "fonts"
for p in fonts_dir.glob("*.otf"):
    QFontDatabase.addApplicationFont(str(p))

engine = QQmlApplicationEngine()
ctx = engine.rootContext()
ctx.setContextProperty("ASSETS_URL", QUrl.fromLocalFile(str(base / "assets")).toString())
ctx.setContextProperty("PRIMARY_FONT", "Pretendard")
engine.addImportPath(str(base / "qml"))

errors = []
def on_warnings(warnings):
    for w in warnings:
        line = f"{w.url().toString()}:{w.line()}:{w.column()}: {w.description()}"
        errors.append(line)
        print("WARN:", line)

engine.warnings.connect(on_warnings)
engine.load(QUrl.fromLocalFile(str(base / "qml" / "Main.qml")))

if not engine.rootObjects():
    print("FAIL: No root objects (QML failed to load).")
    if errors:
        print("Errors recorded:")
        for e in errors:
            print("  ", e)
    sys.exit(1)

print(f"OK: QML loaded. {len(engine.rootObjects())} root object(s).")
if errors:
    print(f"(Loaded with {len(errors)} warning(s).)")

QTimer.singleShot(1500, app.quit)
sys.exit(app.exec())
