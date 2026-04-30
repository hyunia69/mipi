"""Tests for AvatarWidget.qml using pytest-qt + QQuickWidget.

We drive the widget by setting properties from Python and observing emitted signals
plus internal state.

NOTE: AvatarWidget loads index.html which uses ES modules; like the player tests,
we serve the avatar tree over a tiny localhost HTTP server because Chromium blocks
file:// module imports.
"""
from __future__ import annotations

import http.server
import socket
import socketserver
import threading
from pathlib import Path

import pytest

pytest.importorskip("PySide6.QtQuickWidgets")
pytest.importorskip("PySide6.QtWebEngineWidgets")

from PySide6.QtCore import QEventLoop, QTimer, QUrl
from PySide6.QtWidgets import QApplication
from PySide6.QtQuickWidgets import QQuickWidget

KIOSK_ROOT = Path(__file__).resolve().parent.parent
QML_DIR = KIOSK_ROOT / "qml"
AVATAR_DIR = KIOSK_ROOT / "web" / "avatar"


@pytest.fixture(scope="module", autouse=True)
def _qapp():
    # QQuickWidget is a QWidget subclass — needs QApplication, not just QGuiApplication.
    # QtWebEngineQuick.initialize() is called in conftest.py before any QApplication.
    app = QApplication.instance()
    if app is None:
        app = QApplication([])
    yield app


@pytest.fixture(scope="session")
def avatar_http_url():
    """Serve kiosk/web/avatar over localhost so ES modules load (file:// blocks them)."""
    if not (AVATAR_DIR / "assets" / "icaro.glb").exists():
        pytest.skip("avatar assets not prepared; run scripts/prepare_avatar_assets.py first")

    handler_factory = lambda *a, **kw: http.server.SimpleHTTPRequestHandler(
        *a, directory=str(AVATAR_DIR), **kw)

    with socketserver.TCPServer(("127.0.0.1", 0), handler_factory) as httpd:
        port = httpd.server_address[1]
        thread = threading.Thread(target=httpd.serve_forever, daemon=True)
        thread.start()
        try:
            yield f"http://127.0.0.1:{port}/index.html"
        finally:
            httpd.shutdown()


def _spin(ms: int):
    loop = QEventLoop()
    QTimer.singleShot(ms, loop.quit)
    loop.exec()


def _load_widget(avatar_url: str, *, repeat_ms: int = 0, ready_timeout_ms: int = 5000,
                 enabled: bool = True, gloss: str = "CASA"):
    """Load AvatarWidget standalone in a QQuickWidget.

    NOTE: The inline QML is written into the qml/ directory (not tests/) so
    that ``import "components"`` resolves as a relative path — Qt 6 does NOT
    resolve absolute-path directory imports unless a qmldir is present AND the
    import path is registered exactly.  Placing the file next to Main.qml means
    the existing addImportPath(QML_DIR) covers it automatically.

    We spin the event loop until QQuickWidget.Status.Ready because setSource()
    is asynchronous — calling rootObject() before the status reaches Ready
    returns None and the event loop never progresses.
    """
    w = QQuickWidget()
    w.engine().rootContext().setContextProperty("AVATAR_URL", avatar_url)
    w.engine().rootContext().setContextProperty("AVATAR_ENABLED", enabled)
    w.engine().addImportPath(str(QML_DIR))
    qml = f"""
        import QtQuick
        import "components"
        AvatarWidget {{
            id: a
            width: 280; height: 360
            gloss: "{gloss}"
            repeatIntervalMs: {repeat_ms}
            readyTimeoutMs: {ready_timeout_ms}
        }}
    """
    # Write into qml/ so relative "components" import resolves correctly
    qml_file = QML_DIR / "_inline_avatar_widget_test.qml"
    qml_file.write_text(qml, encoding="utf-8")

    # Spin until QML finishes loading (setSource is async in QQuickWidget).
    load_loop = QEventLoop()
    def _on_status(status):
        if status != QQuickWidget.Status.Loading:
            load_loop.quit()
    w.statusChanged.connect(_on_status)
    w.setSource(QUrl.fromLocalFile(str(qml_file)))
    w.resize(280, 360)
    w.show()  # required for rAF inside the embedded WebEngineView
    QTimer.singleShot(8000, load_loop.quit)  # safety timeout
    load_loop.exec()
    w.statusChanged.disconnect(_on_status)

    qml_file.unlink(missing_ok=True)
    return w


def test_widget_loads_when_assets_present(avatar_http_url):
    w = _load_widget(avatar_http_url)
    root = w.rootObject()
    assert root is not None
    assert root.property("visible") is True
    w.deleteLater()


def test_widget_hidden_when_disabled(avatar_http_url):
    w = _load_widget(avatar_http_url, enabled=False)
    _spin(200)
    assert w.rootObject().property("visible") is False
    w.deleteLater()


def test_render_process_terminated_increments_counter(avatar_http_url):
    w = _load_widget(avatar_http_url)
    root = w.rootObject()
    assert root.property("rebuildCount") == 0
    root.metaObject().invokeMethod(root, "_simulateCrash")
    assert root.property("rebuildCount") == 1
    w.deleteLater()


def test_max_3_rebuilds_then_emits_player_error(avatar_http_url):
    w = _load_widget(avatar_http_url)
    root = w.rootObject()
    errors = []
    root.playerError.connect(lambda msg: errors.append(msg))
    for _ in range(4):
        root.metaObject().invokeMethod(root, "_simulateCrash")
    assert root.property("rebuildCount") == 3  # capped at maxRebuilds (default 3)
    assert any("rebuild" in e.lower() or "crash" in e.lower() or "give" in e.lower() for e in errors)
    assert root.property("visible") is False
    w.deleteLater()


def test_watchdog_fires_when_no_ready(avatar_http_url):
    """If bridge never reports ready within readyTimeoutMs, widget records a watchdog fire."""
    w = _load_widget("http://127.0.0.1:1/does-not-exist.html", ready_timeout_ms=800)
    root = w.rootObject()
    _spin(1500)
    assert root.property("watchdogFires") >= 1
    w.deleteLater()


def test_repeat_loops_after_finished(avatar_http_url):
    w = _load_widget(avatar_http_url, repeat_ms=500)
    root = w.rootObject()
    starts = []
    root.playbackStarted.connect(lambda g: starts.append(g))
    # CASA is 2.47s; first finish + 500ms repeat + second start should land in ~5s.
    # Allow extra slack for QtWebEngine boot.
    _spin(12000)
    assert len(starts) >= 2, f"expected ≥2 plays, got {len(starts)}"
    w.deleteLater()


def test_repeat_stops_when_hidden(avatar_http_url):
    w = _load_widget(avatar_http_url, repeat_ms=500)
    root = w.rootObject()
    _spin(6000)  # let one finish
    starts_before = root.property("playCount")
    root.setProperty("visible", False)
    _spin(2500)
    starts_after = root.property("playCount")
    assert starts_after == starts_before, \
        f"expected no new plays while hidden; before={starts_before} after={starts_after}"
    w.deleteLater()
