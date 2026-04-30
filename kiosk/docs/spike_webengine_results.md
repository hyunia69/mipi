# WebEngine spike on Jetson Orin Nano — results

## Environment

- Date:                    2026-05-01
- JetPack:                 6.1
- Hardware:                Jetson Orin Nano (8GB)
- Display:                 HDMI

## Boot result

- Local dev (Windows): **PASS**
  - Notes: Spike script imports cleanly, smoke verified.
- Jetson EGLFS (data: URL spike): **PARTIAL** — H1 "WebEngine OK" rendered, but inline `<script>` blocked by Chromium CSP for `data:` URLs (expected). Did not see WebGL/UA log lines via the spike alone.
- **Jetson real kiosk (definitive validation): PASS** — `python3 main.py --mode live --theme holo` renders Icaro avatar with CASA gloss animation correctly alongside live MIPI camera feed. WebGL on EGLFS confirmed working through the actual production code path.

## Pre-flight prerequisite (Jetson)

JetPack 6.1 / Ubuntu 22.04 only ships `libwebp.so.7`; PySide6 QtWebEngine looks for `libwebp.so.6`. One-time fix:

```bash
sudo ln -s /usr/lib/aarch64-linux-gnu/libwebp.so.7 /usr/lib/aarch64-linux-gnu/libwebp.so.6
```

## Working environment

For development on the Jetson **with the desktop session running**, NO env vars are
needed — Qt's default XCB/Wayland platform integrates with the desktop and mouse
input works as expected:

```bash
python3 main.py --mode live --theme holo
```

For **headless production deployment** (boot-to-kiosk, no desktop), use EGLFS:

```bash
QT_QPA_PLATFORM=eglfs \
QTWEBENGINE_CHROMIUM_FLAGS="--use-gl=egl --no-sandbox --disable-gpu-driver-bug-workarounds" \
python3 main.py --mode live --theme holo
```

In EGLFS mode the kiosk owns the framebuffer directly. The user must be in the
`input` group (`sudo usermod -aG input <user>`) and the desktop session must be
disabled, otherwise mouse events are swallowed.

## GO / NO-GO decision

- [x] **GO** — Avatar widget renders correctly on Jetson, both standalone and
      alongside the MIPI camera live feed. WebEngine + WebGL on EGLFS works
      through the kiosk's HTTP-server-based asset loading.

## Recommendations for production main.py

- `main.py` already auto-injects the EGLFS Chromium flags when
  `QT_QPA_PLATFORM=eglfs` is detected — no manual env-var management needed
  beyond setting that platform.
- Local HTTP server on 127.0.0.1 (random port) is required because Chromium
  blocks ES module imports from `file://` URLs. Already implemented in
  `main.start_avatar_server`.
- For production deployment, add the user to the `input` group and create a
  systemd unit that exports `QT_QPA_PLATFORM=eglfs` before launching `main.py`.
