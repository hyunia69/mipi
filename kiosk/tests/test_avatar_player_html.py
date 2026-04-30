"""End-to-end tests for kiosk/web/avatar/player.js using a headless QWebEngineView.

These run real Three.js inside Chromium-via-Qt, so they require the asset bundle
prepared by scripts/prepare_avatar_assets.py.

NOTE: A local HTTP server is used to serve the avatar directory because Chromium
blocks ES module imports from file:// URLs (CORS-like restriction). The server
binds to 127.0.0.1 on a dynamic port chosen at session startup.
"""
from __future__ import annotations

import threading
import time
from http.server import HTTPServer, SimpleHTTPRequestHandler
from pathlib import Path
from typing import Any

import pytest

pytest.importorskip("PySide6.QtWebEngineWidgets")

from PySide6.QtCore import QEventLoop, QTimer, QUrl
from PySide6.QtWidgets import QApplication
from PySide6.QtWebEngineWidgets import QWebEngineView

KIOSK_ROOT = Path(__file__).resolve().parent.parent
AVATAR_DIR = KIOSK_ROOT / "web" / "avatar"
ASSETS_DIR = AVATAR_DIR / "assets"

# ------------------------------------------------------------------
# HTTP server fixtures
# ------------------------------------------------------------------

class _SilentHandler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(AVATAR_DIR), **kwargs)

    def log_message(self, fmt, *args):  # suppress request logs
        pass


@pytest.fixture(scope="session")
def http_server():
    """Serve kiosk/web/avatar/ over 127.0.0.1 for the test session."""
    server = HTTPServer(("127.0.0.1", 0), _SilentHandler)
    port = server.server_address[1]
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    yield f"http://127.0.0.1:{port}"
    server.shutdown()


# ------------------------------------------------------------------
# Qt app / view fixtures
# ------------------------------------------------------------------

@pytest.fixture(scope="module")
def assets_present():
    if not (ASSETS_DIR / "icaro.glb").exists() or not (
        ASSETS_DIR / "bundles" / "CASA.threejs.json"
    ).exists():
        pytest.skip(
            "avatar assets not prepared; run scripts/prepare_avatar_assets.py first"
        )


@pytest.fixture(scope="module")
def qapp():
    app = QApplication.instance()
    if app is None:
        app = QApplication([])
    return app


@pytest.fixture
def view(qapp, http_server, assets_present):
    v = QWebEngineView()
    v.resize(400, 500)
    v.show()  # required: requestAnimationFrame only fires in a visible window
    loop = QEventLoop()
    v.loadFinished.connect(lambda ok: loop.quit())
    v.load(QUrl(f"{http_server}/index.html"))
    QTimer.singleShot(20000, loop.quit)
    loop.exec()
    yield v
    v.hide()
    v.deleteLater()


# ------------------------------------------------------------------
# Helpers
# ------------------------------------------------------------------

def _eval_js(view: QWebEngineView, script: str, timeout_ms: int = 15000) -> Any:
    """Run *script* in the page and return the result (blocks)."""
    loop = QEventLoop()
    result_box: dict = {}

    def cb(value):
        result_box["v"] = value
        loop.quit()

    QTimer.singleShot(timeout_ms, loop.quit)
    view.page().runJavaScript(script, 0, cb)
    loop.exec()
    if "v" not in result_box:
        raise TimeoutError(f"runJavaScript timeout: {script[:80]}")
    return result_box["v"]


def _wait_until(view: QWebEngineView, expr: str, timeout_ms: int = 20000) -> Any:
    """Poll *expr* every 200 ms until truthy or *timeout_ms* expires.

    Uses QTimer so the Qt event loop keeps running between polls (required for
    WebEngine to process network/JS events).
    """
    deadline = time.monotonic() + timeout_ms / 1000

    while time.monotonic() < deadline:
        v = _eval_js(view, f"!!({expr})", timeout_ms=3000)
        if v:
            return _eval_js(view, f"({expr})", timeout_ms=3000)
        # Pump the event loop for 200 ms instead of blocking with time.sleep
        inner = QEventLoop()
        QTimer.singleShot(200, inner.quit)
        inner.exec()

    raise TimeoutError(f"waitUntil timeout: {expr}")


# ------------------------------------------------------------------
# Tests
# ------------------------------------------------------------------

def test_player_initializes(view):
    _wait_until(view, "window.__player && window.__player.ready === true")


def test_loads_icaro_avatar(view):
    _wait_until(view, "window.__player && window.__player.ready === true")
    has_skinned_mesh = _eval_js(view, """
        (function walk(o) {
            if (o.type === 'SkinnedMesh') return true;
            return (o.children || []).some(walk);
        })(window.__player.scene)
    """)
    assert has_skinned_mesh is True


def test_play_casa_completes(view):
    _wait_until(view, "window.__player && window.__player.ready === true")
    _eval_js(
        view,
        """
        window.__finishedGloss = null;
        window.__player.onFinished = (g) => { window.__finishedGloss = g; };
        window.__player.playGloss('CASA');
        """,
    )
    _wait_until(view, "window.__finishedGloss === 'CASA'", timeout_ms=12000)


def test_unknown_gloss_rejects(view):
    _wait_until(view, "window.__player && window.__player.ready === true")
    # Qt 6.10 runJavaScript does NOT auto-await Promises, so we use a side-channel
    # variable and poll until it's populated.
    _eval_js(view, """
        window.__glossError = undefined;
        window.__player.playGloss('BOGUS_DOES_NOT_EXIST').then(
            () => { window.__glossError = null; },
            (e) => { window.__glossError = String(e); }
        );
    """)
    err = _wait_until(
        view,
        "window.__glossError !== undefined && window.__glossError !== null"
        " ? window.__glossError : false",
        timeout_ms=5000,
    )
    assert err and "BOGUS_DOES_NOT_EXIST" in err


def test_dispose_releases_resources(view):
    _wait_until(view, "window.__player && window.__player.ready === true")
    has_skinned_before = _eval_js(view, """
        (function walk(o) {
            if (o.type === 'SkinnedMesh') return true;
            return (o.children || []).some(walk);
        })(window.__player.scene)
    """)
    assert has_skinned_before is True
    _eval_js(view, "window.__player.dispose()")
    has_skinned_after = _eval_js(view, """
        (window.__player.scene === null) ? false :
        (function walk(o) {
            if (o.type === 'SkinnedMesh') return true;
            return (o.children || []).some(walk);
        })(window.__player.scene)
    """)
    assert has_skinned_after is False


def test_playgloss_interrupt_rejects_previous(view):
    _wait_until(view, "window.__player && window.__player.ready === true")
    # Prime the clip cache so the second playGloss doesn't race the first on
    # _loadGlossClip — we want to test the interrupt path, not the cold-fetch path.
    _eval_js(view, """
        window.__primed = false;
        window.__player.playGloss('CASA').then(() => { window.__primed = true; });
    """)
    _wait_until(view, "window.__primed === true", timeout_ms=12000)
    _eval_js(view, """
        window.__interruptResult = null;
        window.__player.playGloss('CASA').then(
            (n) => window.__interruptResult = 'resolved:' + n,
            (e) => window.__interruptResult = 'rejected:' + String(e)
        );
        // Immediately preempt with another playGloss (will reject the first promise)
        setTimeout(() => window.__player.playGloss('CASA'), 50);
    """)
    result = _wait_until(
        view,
        "window.__interruptResult ? window.__interruptResult : false",
        timeout_ms=5000,
    )
    assert result.startswith("rejected:") and "interrupted by:" in result, (
        f"expected interrupt rejection, got: {result!r}"
    )


def test_bridge_module_loads_without_qt(view):
    """In headless QWebEngineView (no QWebChannel), bridge should still resolve."""
    _wait_until(view, "window.__player && window.__player.ready === true")
    # connectBridge is called by index.html; without qt.webChannelTransport in this
    # plain-browser-style fixture, the bridge should fall through and set __bridgeReady.
    _wait_until(view, "window.__bridgeReady === true", timeout_ms=8000)
