"""Spike: minimal QtWebEngine + QtQuick window. Used to validate Jetson EGLFS boot.

Run on dev machine:    python scripts/spike_webengine.py
Run on Jetson:         QT_QPA_PLATFORM=eglfs \\
                       QTWEBENGINE_CHROMIUM_FLAGS="--use-gl=egl --no-sandbox" \\
                       python scripts/spike_webengine.py
"""
from __future__ import annotations

import sys
from pathlib import Path

from PySide6.QtCore import QUrl
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtWebEngineQuick import QtWebEngineQuick


QML = """
import QtQuick
import QtQuick.Window
import QtWebEngine

Window {
    width: 800; height: 600; visible: true; title: "spike-webengine"
    WebEngineView {
        anchors.fill: parent
        url: "data:text/html;charset=utf-8," + encodeURIComponent(`
            <!doctype html><html><body style='background:#111;color:#0f0;font:18px monospace'>
            <h1>WebEngine OK</h1>
            <canvas id='c' width='200' height='200'></canvas>
            <pre id='log'></pre>
            <script>
              const log = (m) => document.getElementById('log').textContent += m + '\\n';
              const c = document.getElementById('c');
              const gl = c.getContext('webgl');
              log('WebGL: ' + (gl ? 'OK ' + gl.getParameter(gl.VERSION) : 'NULL'));
              log('UA: ' + navigator.userAgent);
            </script></body></html>`)
    }
}
"""

def main() -> int:
    QtWebEngineQuick.initialize()
    app = QGuiApplication(sys.argv)
    engine = QQmlApplicationEngine()
    qml_file = Path("__spike.qml").resolve()
    qml_file.write_text(QML, encoding="utf-8")
    engine.load(QUrl.fromLocalFile(str(qml_file)))
    if not engine.rootObjects():
        print("Failed to load QML", file=sys.stderr)
        qml_file.unlink(missing_ok=True)
        return 1
    rc = app.exec()
    qml_file.unlink(missing_ok=True)
    return rc


if __name__ == "__main__":
    sys.exit(main())
