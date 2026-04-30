# Kiosk — CLAUDE.md

Architecture and developer notes for the Digital Telescope Kiosk codebase.

## Avatar widget

- Component: `qml/components/AvatarWidget.qml` (registered in `qml/components/qmldir`)
- Web host: `web/avatar/index.html` (transparent canvas, ES module loader, import map for `'three'`)
- Player core: `web/avatar/player.js` (Three.js + GLTFLoader + AnimationMixer)
- Bridge: `web/avatar/bridge.js` (QWebChannel ↔ player.js)
- Vendored libs: `web/avatar/vendor/` — `three.module.min.js@0.170.0`, `GLTFLoader.js`,
  `utils/BufferGeometryUtils.js`, `qwebchannel.js`. Provenance in `vendor/VERSIONS.txt`.
- Assets: `web/avatar/assets/` (gitignored, populated by `scripts/prepare_avatar_assets.py`).

### Wiring

`main.py` calls `QtWebEngineQuick.initialize()` before `QGuiApplication`. It then
starts a localhost HTTP server (`http://127.0.0.1:<random>`) serving
`web/avatar/`, because Chromium blocks ES module imports from `file://` URLs.
The URL is injected via the `AVATAR_URL` context property; `AVATAR_ENABLED`
gates visibility based on filesystem state and `--no-avatar`; `AVATAR_REPEAT_MS`
controls the loop interval.

### Lifecycle

- Created with screen, plays `gloss` once `bridge.onReady()` fires.
- Repeats every `repeatIntervalMs` (default 8000) while `visible` and `!_giveUp`.
- Stops repeat on `visible=false` or `Component.onDestruction`; the destruction
  handler also sends `dispose()` over the bridge to free GPU resources.

### Crash recovery

- `WebEngineView.onRenderProcessTerminated` increments `rebuildCount` and
  bounces the `Loader.active` to recreate the view.
- After `maxRebuilds` (default 3) attempts, the widget sets `_giveUp=true`
  and emits `playerError`. The widget is then permanently hidden (gated by
  `visible: AVATAR_ENABLED && !_giveUp`).

### Watchdog

If `bridge.onReady()` doesn't fire within `readyTimeoutMs` (default 5000), the
watchdog Timer triggers `_onCrash("watchdog: ...")`. This catches scenarios
where the WebEngineView loaded but the bridge handshake stalled.

### Jetson note

Production launch must export `QT_QPA_PLATFORM=eglfs`; main.py then auto-injects
the right Chromium flags. WebGL on EGLFS shares GPU bandwidth with the MIPI
camera path — see `tests/test_live_camera_regression.py` for the gating
regression test (run with `ON_JETSON=1`).
