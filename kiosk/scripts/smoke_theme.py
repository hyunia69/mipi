"""Smoke-test that Theme.activeStyle follows the --theme CLI flag.

Usage: python kiosk/scripts/smoke_theme.py [holo|minimal|future]
Exits 0 if Theme.activeStyle matches the requested theme, 1 otherwise.
"""

import os
import sys
from pathlib import Path

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")

from PySide6.QtCore import QUrl, QTimer, QCoreApplication
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine


def run(theme: str) -> int:
    app = QGuiApplication.instance() or QGuiApplication(sys.argv)

    base = Path(__file__).resolve().parent.parent
    engine = QQmlApplicationEngine()
    ctx = engine.rootContext()
    ctx.setContextProperty("ASSETS_URL", QUrl.fromLocalFile(str(base / "assets")).toString())
    ctx.setContextProperty("PRIMARY_FONT", "Pretendard")
    ctx.setContextProperty("appTheme", theme)
    engine.addImportPath(str(base / "qml"))
    engine.load(QUrl.fromLocalFile(str(base / "qml" / "Main.qml")))

    if not engine.rootObjects():
        print(f"[{theme}] FAIL: Main.qml failed to load")
        return 1

    result = {"active": None}

    def check():
        # Evaluate the Theme singleton state via a JS expression on the root window.
        root = engine.rootObjects()[0]
        active = root.property("color")  # just to ensure root is live
        # Use evaluate via QMetaObject by adding a temporary QML item.
        from PySide6.QtQml import QQmlComponent
        comp = QQmlComponent(engine)
        comp.setData(
            b'import QtQuick\nimport "."\nQtObject {\n'
            b'  property string v: Theme.activeStyle\n'
            b'  property color bg: Theme.backgroundColor\n'
            b'  property color pri: Theme.primaryColor\n'
            b'  property color acc: Theme.accentColor\n'
            b'}',
            QUrl.fromLocalFile(str(base / "qml" / "probe.qml")),
        )
        obj = comp.create()
        if obj is None:
            print(f"[{theme}] FAIL: probe component errors: {comp.errors()}")
            result["active"] = "<error>"
        else:
            result["active"] = obj.property("v")
            result["bg"] = obj.property("bg").name()
            result["pri"] = obj.property("pri").name()
            result["acc"] = obj.property("acc").name()
        QCoreApplication.quit()

    QTimer.singleShot(100, check)
    app.exec()

    active = result["active"]
    ok = active == theme
    tag = "OK" if ok else "FAIL"
    print(
        f"[{theme}] {tag}: activeStyle={active!r} bg={result.get('bg')} "
        f"primary={result.get('pri')} accent={result.get('acc')}"
    )
    return 0 if ok else 1


if __name__ == "__main__":
    theme = sys.argv[1] if len(sys.argv) > 1 else "holo"
    sys.exit(run(theme))
