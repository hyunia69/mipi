# WebEngine spike on Jetson Orin Nano — results template

> Fill this in after running `scripts/spike_webengine.py` on the Jetson.

## Environment

- Date:                    <YYYY-MM-DD>
- JetPack:                 6.1
- L4T kernel:              <`uname -r`>
- PySide6 version:         <`python -c "import PySide6; print(PySide6.__version__)"`>
- QtWebEngine version:     <comes with PySide6-Addons>
- Display:                 <HDMI-1, resolution>

## Boot result

- Local dev (Windows / macOS / Linux desktop): **PASS** / FAIL
  - Notes:
- Jetson EGLFS:                                **PASS** / FAIL
  - Notes:

## Working environment variables on Jetson

```
QT_QPA_PLATFORM=eglfs
QT_OPENGL=es2
QSG_RHI_BACKEND=opengl
QTWEBENGINE_CHROMIUM_FLAGS="--use-gl=egl --no-sandbox --disable-gpu-driver-bug-workarounds"
```

(Edit if you needed any additional flags.)

## Concurrent live camera test (30 minutes)

Ran `python main.py --mode live --theme holo` in another terminal alongside the spike.

- Avatar window stayed up:                     YES / NO (count: ___ context-loss events)
- Camera fps before spike start:               <fps>
- Camera fps with spike running:               <fps>
- RSS memory delta on kiosk:                   <MB before> -> <MB after>  (delta: ___ MB)
- `dmesg` GPU-reset messages during run:       <count>

## GO / NO-GO decision

- [ ] **GO** — proceed with Tasks 5+ (WebEngine on EGLFS works, no camera regression)
- [ ] **NO-GO** — abort plan, escalate to user. Reason: ___

## Console output snippets (paste relevant errors / warnings)

```
<paste here>
```

## Recommendations for production main.py

- Chromium flags to bake in: ___
- Env vars to set in launch script: ___
- Known quirks to watch: ___
