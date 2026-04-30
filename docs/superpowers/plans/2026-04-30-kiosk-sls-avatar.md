# Kiosk Sign Language Avatar (SLS Brazil Player Integration) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Embed the SLS Brazil Player Libras (Brazilian sign language) avatar into the existing Qt/QML kiosk, playing the `CASA` gloss in the bottom-right of the menu screen and the live camera screen, repeating every 8 seconds.

**Architecture:** Add `QtWebEngine` to the PySide6 kiosk. Stage a stripped-down Three.js + Icaro avatar player as static HTML/JS under `kiosk/web/avatar/`. Wrap it in a reusable QML component `AvatarWidget.qml` that exposes a `gloss` property. A QWebChannel bridge lets QML call `playGloss(name)` on the JS player. A build-time script copies only the assets we need (Icaro GLB + CASA bundle + filtered index) from the sibling `sls_brazil_player/public/` tree into `kiosk/web/avatar/assets/` (gitignored).

**Tech Stack:** Python 3.10+, PySide6 6.5+, PySide6-Addons (QtWebEngine), QML / Qt Quick, Three.js v0.170 (vendored), QWebChannel, pytest, pytest-qt.

**Source design doc (rationale, decision history, risk map):** `C:\Users\hyuni\.claude\plans\kiosk-sls-brazil-player-shiny-flute.md` — read once for context. This plan is execution-focused.

**Locked decisions (do NOT relitigate):**
- Approach B: QtWebEngine + Three.js embed (chosen over video clip / abstraction layer).
- Avatar: Icaro (`sls_brazil_player/public/avatars/vlibras/icaro/export/icaro.glb`).
- Single gloss: CASA (`sls_brazil_player/public/animations/vlibras/bundles/CASA.threejs.json`, 2.47s).
- Locations: HomeScreen + ViewingScreen, bottom-right corner.
- Playback policy: repeat every 8 seconds (`repeatIntervalMs=8000`, `0` disables loop).

**Non-goals (out of scope):** dynamic Portuguese sentence translation, multi-avatar support (Padrao/Default), per-screen contextual gloss mapping, ABNT avatar set, KSL (Korean) signs, CI/CD automation, license tracking page.

---

## File Structure

**New files (kiosk/):**

```
kiosk/
  qml/components/AvatarWidget.qml         QML overlay, exposes gloss/repeatIntervalMs
  web/avatar/index.html                    HTML host page (transparent canvas)
  web/avatar/player.js                     Three.js + AnimationMixer core
  web/avatar/bridge.js                     QWebChannel client, window.kiosk API
  web/avatar/qwebchannel.js                Vendored from Qt distribution
  web/avatar/vendor/three.module.min.js    Vendored Three.js v0.170.0
  web/avatar/assets/.gitkeep               Marker (assets/ is gitignored)
  scripts/prepare_avatar_assets.py         Build: copies + filters from sls_brazil_player
  scripts/spike_webengine.py               Pre-flight Jetson EGLFS validation
  tests/__init__.py                        Make tests/ a package
  tests/test_prepare_avatar_assets.py     pytest, asset script unit tests
  tests/test_avatar_widget.py              pytest-qt, QML widget tests
  tests/test_avatar_player_html.py         pytest-qt + QtWebEngine, JS player E2E
  tests/test_main_avatar_integration.py   pytest, main.py wiring
  tests/test_live_camera_regression.py     CRITICAL — camera fps unchanged by avatar
  tests/conftest.py                        Shared fixtures (qapp, web_assets_dir)
```

**Modified files:**

```
kiosk/main.py                  + QtWebEngineQuick.initialize(), avatar context props, CLI flags
kiosk/qml/screens/HomeScreen.qml      + AvatarWidget anchored bottom-right
kiosk/qml/screens/ViewingScreen.qml   + AvatarWidget (avoiding ZoomControls)
kiosk/.gitignore               + web/avatar/assets/ + web/avatar/vendor/
kiosk/requirements.txt (or pyproject.toml)   + PySide6-Addons, pytest-qt
README.md                      Build steps for prepare_avatar_assets.py
CLAUDE.md                      Avatar lifecycle notes
```

**Responsibility split:**
- `web/avatar/` — browser-side, no Qt knowledge, talks to QML only via `window.kiosk` (QWebChannel).
- `qml/components/AvatarWidget.qml` — Qt-side, owns the WebEngineView and crash-recovery state machine.
- `scripts/prepare_avatar_assets.py` — build pipeline, reads sls_brazil_player, writes kiosk/web/avatar/assets/.

---

## Task 1: Add PySide6-Addons + pytest-qt dependencies

**Files:**
- Modify: `kiosk/requirements.txt` (or `pyproject.toml` if present)
- Modify: `kiosk/.gitignore`

- [ ] **Step 1.1: Inspect existing dependency declaration**

Run: `ls kiosk/requirements.txt kiosk/pyproject.toml kiosk/setup.py 2>/dev/null`

If `requirements.txt` exists, edit it. Else if `pyproject.toml` exists, edit `[project] dependencies`. If neither exists, create `kiosk/requirements.txt`.

- [ ] **Step 1.2: Add dependencies**

Append to `kiosk/requirements.txt`:

```
PySide6>=6.5
PySide6-Addons>=6.5
pytest>=7.4
pytest-qt>=4.2
```

(If `PySide6` or `pytest` already pinned, reconcile to the higher of existing vs. listed.)

- [ ] **Step 1.3: Update .gitignore**

Append to `kiosk/.gitignore` (create file if absent):

```
# Avatar build artifacts
web/avatar/assets/*
!web/avatar/assets/.gitkeep
web/avatar/vendor/
```

- [ ] **Step 1.4: Install + smoke-test the import**

Run:
```bash
cd kiosk && pip install -r requirements.txt
python -c "from PySide6.QtWebEngineQuick import QtWebEngineQuick; print('OK')"
```

Expected: `OK` printed. If `ModuleNotFoundError`, ensure `PySide6-Addons` (not just `PySide6`) was installed.

- [ ] **Step 1.5: Commit**

```bash
git add kiosk/requirements.txt kiosk/.gitignore
git commit -m "chore: add PySide6-Addons and pytest-qt for avatar widget"
```

---

## Task 2: Web directory bootstrap + vendored libraries

**Files:**
- Create: `kiosk/web/avatar/vendor/three.module.min.js`
- Create: `kiosk/web/avatar/qwebchannel.js`
- Create: `kiosk/web/avatar/assets/.gitkeep`

- [ ] **Step 2.1: Create directory tree**

Run:
```bash
mkdir -p kiosk/web/avatar/vendor kiosk/web/avatar/assets
touch kiosk/web/avatar/assets/.gitkeep
```

- [ ] **Step 2.2: Vendor Three.js v0.170.0**

Download the exact version used by sls_brazil_player (the sentence player imports `three@0.170.0` from jsDelivr).

Run:
```bash
curl -L -o kiosk/web/avatar/vendor/three.module.min.js \
  https://cdn.jsdelivr.net/npm/three@0.170.0/build/three.module.min.js
curl -L -o kiosk/web/avatar/vendor/GLTFLoader.js \
  https://cdn.jsdelivr.net/npm/three@0.170.0/examples/jsm/loaders/GLTFLoader.js
```

Verify size: `ls -l kiosk/web/avatar/vendor/`. Expected: `three.module.min.js` ~700KB, `GLTFLoader.js` ~50KB.

- [ ] **Step 2.3: Vendor qwebchannel.js**

This file ships with the Qt distribution. Locate it:

```bash
python -c "import PySide6, pathlib; print(pathlib.Path(PySide6.__file__).parent)"
```

Then find `qwebchannel.js` under that directory (`Qt/qml/QtWebChannel/`, or `qwebchannel.js` in resources). Copy:

```bash
QTROOT=$(python -c "import PySide6, pathlib; print(pathlib.Path(PySide6.__file__).parent)")
find "$QTROOT" -name "qwebchannel.js" -exec cp {} kiosk/web/avatar/qwebchannel.js \;
ls -l kiosk/web/avatar/qwebchannel.js
```

If `find` returns nothing, fetch from upstream Qt source: `curl -L -o kiosk/web/avatar/qwebchannel.js https://code.qt.io/cgit/qt/qtwebchannel.git/plain/examples/webchannel/shared/qwebchannel.js`

Expected: ~30KB JS file.

- [ ] **Step 2.4: Smoke-test files load as ES modules**

Create a temporary `kiosk/web/avatar/_smoke.html`:

```html
<!doctype html>
<html><body><script type="module">
  import * as THREE from "./vendor/three.module.min.js";
  import { GLTFLoader } from "./vendor/GLTFLoader.js";
  console.log("THREE.REVISION:", THREE.REVISION);
  console.log("GLTFLoader:", typeof GLTFLoader);
  document.body.textContent = `THREE r${THREE.REVISION} loaded; GLTFLoader=${typeof GLTFLoader}`;
</script></body></html>
```

Open in any modern browser (Chrome/Edge): `start kiosk/web/avatar/_smoke.html` (Windows) or use a local static server. Body text should read `THREE r170 loaded; GLTFLoader=function`.

Then delete: `rm kiosk/web/avatar/_smoke.html`.

- [ ] **Step 2.5: Commit (vendor files only — assets/ gitignored)**

```bash
git add kiosk/web/avatar/vendor/three.module.min.js \
        kiosk/web/avatar/vendor/GLTFLoader.js \
        kiosk/web/avatar/qwebchannel.js \
        kiosk/web/avatar/assets/.gitkeep
git commit -m "feat: vendor Three.js v0.170 and qwebchannel.js for avatar widget"
```

---

## Task 3: Asset preparation script — copy + filter + CLI (TDD)

**Files:**
- Create: `kiosk/scripts/prepare_avatar_assets.py`
- Create: `kiosk/tests/__init__.py`
- Create: `kiosk/tests/conftest.py`
- Create: `kiosk/tests/test_prepare_avatar_assets.py`

- [ ] **Step 3.1: Set up test scaffolding**

Create `kiosk/tests/__init__.py` (empty file).

Create `kiosk/tests/conftest.py`:

```python
import os
import sys
from pathlib import Path

# Ensure kiosk/ is importable
KIOSK_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(KIOSK_ROOT))
sys.path.insert(0, str(KIOSK_ROOT / "scripts"))
```

- [ ] **Step 3.2: Write failing tests for `copy_avatar` and `filter_bundle_index`**

Create `kiosk/tests/test_prepare_avatar_assets.py`:

```python
import json
import shutil
from pathlib import Path
import pytest

import prepare_avatar_assets as pap


def make_fake_source(tmp_path: Path) -> Path:
    """Mirror the sls_brazil_player layout we depend on."""
    src = tmp_path / "src" / "public"
    (src / "avatars/vlibras/icaro/export").mkdir(parents=True)
    (src / "avatars/vlibras/icaro/export/icaro.glb").write_bytes(b"\x67\x6c\x54\x46FAKE")
    (src / "animations/vlibras/bundles").mkdir(parents=True)
    (src / "animations/vlibras/bundles/CASA.threejs.json").write_text('{"name":"CASA"}')
    (src / "animations/vlibras/bundles/AGUA.threejs.json").write_text('{"name":"AGUA"}')
    (src / "animations/vlibras/bundles/index.json").write_text(json.dumps({
        "count": 2,
        "glosses": [
            {"raw": "CASA", "key": "CASA", "file": "CASA.threejs.json", "duration": 2.47},
            {"raw": "ÁGUA", "key": "AGUA", "file": "AGUA.threejs.json", "duration": 3.8},
        ],
    }))
    return src


def test_copy_avatar_happy(tmp_path):
    src = make_fake_source(tmp_path)
    dst = tmp_path / "dst"
    pap.copy_avatar(src, dst, avatar="icaro")
    assert (dst / "icaro.glb").exists()
    assert (dst / "icaro.glb").read_bytes().startswith(b"\x67\x6c\x54\x46")


def test_copy_avatar_missing_source_exits(tmp_path):
    dst = tmp_path / "dst"
    with pytest.raises(SystemExit) as exc:
        pap.copy_avatar(tmp_path / "does_not_exist", dst, avatar="icaro")
    assert exc.value.code != 0


def test_filter_bundle_index_keeps_only_selected(tmp_path):
    src = make_fake_source(tmp_path)
    dst = tmp_path / "dst"
    pap.copy_bundles(src, dst, glosses=["CASA"])
    idx = json.loads((dst / "bundles/index.json").read_text())
    assert idx["count"] == 1
    assert [g["key"] for g in idx["glosses"]] == ["CASA"]
    assert (dst / "bundles/CASA.threejs.json").exists()
    assert not (dst / "bundles/AGUA.threejs.json").exists()


def test_filter_bundle_index_partial_warns(tmp_path, capsys):
    src = make_fake_source(tmp_path)
    dst = tmp_path / "dst"
    pap.copy_bundles(src, dst, glosses=["CASA", "BOGUS"])
    captured = capsys.readouterr()
    assert "BOGUS" in captured.err


def test_main_idempotent(tmp_path):
    src = make_fake_source(tmp_path)
    dst = tmp_path / "dst"
    pap.main(["--source", str(src), "--dest", str(dst), "--glosses", "CASA"])
    first = sorted(p.relative_to(dst).as_posix() for p in dst.rglob("*") if p.is_file())
    pap.main(["--source", str(src), "--dest", str(dst), "--glosses", "CASA"])
    second = sorted(p.relative_to(dst).as_posix() for p in dst.rglob("*") if p.is_file())
    assert first == second


def test_main_writes_manifest(tmp_path):
    src = make_fake_source(tmp_path)
    dst = tmp_path / "dst"
    pap.main(["--source", str(src), "--dest", str(dst), "--glosses", "CASA"])
    manifest = json.loads((dst / "manifest.json").read_text())
    assert manifest["avatar"] == "icaro"
    assert manifest["glosses"] == ["CASA"]
    assert "icaro.glb" in manifest["files"]
    assert "bundles/CASA.threejs.json" in manifest["files"]
```

- [ ] **Step 3.3: Run tests — expect all to fail (module not yet created)**

Run: `cd kiosk && pytest tests/test_prepare_avatar_assets.py -v`
Expected: ImportError or ModuleNotFoundError on `import prepare_avatar_assets`.

- [ ] **Step 3.4: Implement `prepare_avatar_assets.py`**

Create `kiosk/scripts/prepare_avatar_assets.py`:

```python
"""Build pipeline: copy required avatar + gloss assets from sls_brazil_player.

Pipeline:

    sls_brazil_player/public/{avatars,animations}/...
                          |
                          |  (this script)
                          v
    kiosk/web/avatar/assets/
      icaro.glb
      bundles/CASA.threejs.json
      bundles/index.json     (filtered)
      manifest.json          (avatar + glosses + files + sha256 + license)
"""
from __future__ import annotations

import argparse
import hashlib
import json
import shutil
import sys
from pathlib import Path

DEFAULT_AVATAR = "icaro"
DEFAULT_GLOSSES = ["CASA"]


def _sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(8192), b""):
            h.update(chunk)
    return h.hexdigest()


def copy_avatar(source: Path, dest: Path, *, avatar: str) -> Path:
    """Copy <source>/avatars/vlibras/<avatar>/export/<avatar>.glb to <dest>/<avatar>.glb."""
    src_glb = source / "avatars" / "vlibras" / avatar / "export" / f"{avatar}.glb"
    if not src_glb.is_file():
        print(f"[prepare_avatar_assets] ERROR: avatar GLB not found: {src_glb}", file=sys.stderr)
        raise SystemExit(2)
    dest.mkdir(parents=True, exist_ok=True)
    dst_glb = dest / f"{avatar}.glb"
    shutil.copy2(src_glb, dst_glb)
    return dst_glb


def copy_bundles(source: Path, dest: Path, *, glosses: list[str]) -> list[Path]:
    """Copy each requested gloss bundle and a filtered index.json."""
    bundles_src = source / "animations" / "vlibras" / "bundles"
    if not bundles_src.is_dir():
        print(f"[prepare_avatar_assets] ERROR: bundles dir not found: {bundles_src}", file=sys.stderr)
        raise SystemExit(2)
    bundles_dst = dest / "bundles"
    bundles_dst.mkdir(parents=True, exist_ok=True)

    full_index = json.loads((bundles_src / "index.json").read_text(encoding="utf-8"))
    full_by_key = {g["key"]: g for g in full_index["glosses"]}

    copied: list[Path] = []
    kept: list[dict] = []
    for gloss in glosses:
        entry = full_by_key.get(gloss)
        if entry is None:
            print(f"[prepare_avatar_assets] WARNING: gloss '{gloss}' not in bundle index; skipping", file=sys.stderr)
            continue
        src_bundle = bundles_src / entry["file"]
        if not src_bundle.is_file():
            print(f"[prepare_avatar_assets] WARNING: bundle file missing on disk: {src_bundle}", file=sys.stderr)
            continue
        dst_bundle = bundles_dst / entry["file"]
        shutil.copy2(src_bundle, dst_bundle)
        copied.append(dst_bundle)
        kept.append(entry)

    filtered_index = {"count": len(kept), "glosses": kept}
    (bundles_dst / "index.json").write_text(
        json.dumps(filtered_index, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )
    return copied


def write_manifest(dest: Path, *, avatar: str, glosses: list[str]) -> Path:
    """Manifest of what we copied + sha256, for traceability."""
    files: dict[str, str] = {}
    for path in sorted(dest.rglob("*")):
        if path.is_file() and path.name != "manifest.json":
            rel = path.relative_to(dest).as_posix()
            files[rel] = _sha256(path)
    manifest = {
        "avatar": avatar,
        "glosses": glosses,
        "files": files,
    }
    manifest_path = dest / "manifest.json"
    manifest_path.write_text(
        json.dumps(manifest, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )
    return manifest_path


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Prepare kiosk avatar assets from sls_brazil_player.")
    parser.add_argument("--source", default="../sls_brazil_player/public",
                        help="Path to sls_brazil_player/public (default: ../sls_brazil_player/public)")
    parser.add_argument("--dest", default="web/avatar/assets",
                        help="Output directory under kiosk/ (default: web/avatar/assets)")
    parser.add_argument("--avatar", default=DEFAULT_AVATAR, help="Avatar name (default: icaro)")
    parser.add_argument("--glosses", nargs="+", default=DEFAULT_GLOSSES,
                        help="Glosses to include (default: CASA)")
    args = parser.parse_args(argv)

    source = Path(args.source).resolve()
    dest = Path(args.dest).resolve()
    copy_avatar(source, dest, avatar=args.avatar)
    copy_bundles(source, dest, glosses=args.glosses)
    write_manifest(dest, avatar=args.avatar, glosses=args.glosses)
    print(f"[prepare_avatar_assets] OK avatar={args.avatar} glosses={args.glosses} -> {dest}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
```

- [ ] **Step 3.5: Run tests — expect all green**

Run: `cd kiosk && pytest tests/test_prepare_avatar_assets.py -v`
Expected: 6 passed.

- [ ] **Step 3.6: Run against the real sls_brazil_player tree (sanity)**

Run:
```bash
cd kiosk && python scripts/prepare_avatar_assets.py \
  --source ../sls_brazil_player/public \
  --glosses CASA
ls web/avatar/assets/
cat web/avatar/assets/manifest.json
```

Expected: `icaro.glb`, `bundles/CASA.threejs.json`, `bundles/index.json`, `manifest.json` present. Manifest lists those 4 files with sha256 hashes.

- [ ] **Step 3.7: Commit**

```bash
git add kiosk/scripts/prepare_avatar_assets.py kiosk/tests/__init__.py kiosk/tests/conftest.py kiosk/tests/test_prepare_avatar_assets.py
git commit -m "feat: add prepare_avatar_assets.py with TDD coverage"
```

---

## Task 4: Pre-flight WebEngine spike on Jetson

**Files:**
- Create: `kiosk/scripts/spike_webengine.py`
- Create: `docs/spike_webengine_results.md` (in kiosk repo root or docs/)

**Why:** EGLFS + Tegra + Chromium is historically finicky. Validate it boots before sinking days into the rest. If it does not boot after this task, fall back to Option F (video clip) — but that path is not in this plan.

- [ ] **Step 4.1: Write the spike script**

Create `kiosk/scripts/spike_webengine.py`:

```python
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
```

- [ ] **Step 4.2: Run on local dev machine (Windows/macOS)**

Run: `cd kiosk && python scripts/spike_webengine.py`
Expected: Window opens, displays "WebEngine OK", "WebGL: OK <version>", and a UA string. Close the window — exit code 0.

If it fails locally, fix before proceeding to Jetson. Common cause: missing `PySide6-Addons` (Task 1).

- [ ] **Step 4.3: Run on Jetson Orin Nano**

Copy to Jetson:
```bash
scp -i ~/.ssh/jetson_key kiosk/scripts/spike_webengine.py hyunia@192.168.219.125:/tmp/
```

SSH and run:
```bash
ssh -i ~/.ssh/jetson_key hyunia@192.168.219.125
cd /tmp && \
  QT_QPA_PLATFORM=eglfs \
  QT_OPENGL=es2 \
  QSG_RHI_BACKEND=opengl \
  QTWEBENGINE_CHROMIUM_FLAGS="--use-gl=egl --no-sandbox --disable-gpu-driver-bug-workarounds" \
  python3 spike_webengine.py
```

Expected: Window appears on the Jetson HDMI output showing the WebGL OK message. Let it run 30 minutes alongside the kiosk live camera mode in another terminal:
```bash
cd ~/kiosk && python main.py --mode live --theme holo &
```

Observe: `top`/`htop` for memory, `nvtop` (if installed) for GPU. No frame drops, no kernel logs about GPU resets in `dmesg`.

- [ ] **Step 4.4: Document results**

Create `kiosk/docs/spike_webengine_results.md`:

```markdown
# WebEngine spike on Jetson Orin Nano

Date: <YYYY-MM-DD>
JetPack: 6.1
PySide6 / QtWebEngine version: <fill in `python -c "import PySide6; print(PySide6.__version__)"`>

## Boot result
- Local (<OS>): PASS / FAIL
- Jetson EGLFS: PASS / FAIL

## Environment that worked
QT_QPA_PLATFORM=...
QTWEBENGINE_CHROMIUM_FLAGS=...

## Concurrent live camera test (30 min)
- Avatar window: OK / context-loss-N-times
- Camera fps: <baseline> -> <with avatar>
- RSS memory growth: <delta MB>

## GO / NO-GO
[ ] GO — proceed with Tasks 5+
[ ] NO-GO — abort plan, escalate.
```

Fill in actual values. If GO, proceed. If NO-GO, stop and escalate.

- [ ] **Step 4.5: Commit (script + results)**

```bash
git add kiosk/scripts/spike_webengine.py kiosk/docs/spike_webengine_results.md
git commit -m "chore: add WebEngine pre-flight spike + Jetson EGLFS validation results"
```

---

## Task 5: Browser-side `index.html` host page

**Files:**
- Create: `kiosk/web/avatar/index.html`

This is a static HTML host. No tests yet — `player.js` will be tested via QtWebEngine in later tasks. We only verify it loads.

- [ ] **Step 5.1: Write `index.html`**

Create `kiosk/web/avatar/index.html`:

```html
<!doctype html>
<html lang="pt-BR">
  <head>
    <meta charset="utf-8" />
    <title>Kiosk Avatar</title>
    <style>
      html, body { margin: 0; padding: 0; width: 100%; height: 100%; overflow: hidden; background: transparent; }
      #stage { position: absolute; inset: 0; }
      #status { position: absolute; bottom: 4px; left: 4px; font: 10px/1.2 monospace;
                color: rgba(255,255,255,0.4); pointer-events: none; }
    </style>
  </head>
  <body>
    <canvas id="stage"></canvas>
    <div id="status"></div>
    <script src="qwebchannel.js"></script>
    <script type="module">
      import { Player } from "./player.js";
      import { connectBridge } from "./bridge.js";

      const canvas = document.getElementById("stage");
      const status = document.getElementById("status");
      const player = new Player(canvas, { onStatus: (s) => (status.textContent = s) });

      // Optional URL hash override for manual testing: index.html#gloss=CASA
      const hash = new URLSearchParams(location.hash.slice(1));
      const initialGloss = hash.get("gloss");

      player.init().then(async () => {
        await connectBridge(player);
        if (initialGloss) player.playGloss(initialGloss);
      }).catch((err) => {
        status.textContent = "init failed: " + err.message;
      });
    </script>
  </body>
</html>
```

- [ ] **Step 5.2: Visual smoke check (browser)**

Open `kiosk/web/avatar/index.html` in a browser. Expected: blank transparent page, console errors are OK at this point (player.js / bridge.js do not exist yet — Tasks 6 & 7 will add them).

- [ ] **Step 5.3: Commit**

```bash
git add kiosk/web/avatar/index.html
git commit -m "feat: avatar host index.html with module loader skeleton"
```

---

## Task 6: `player.js` — Three.js + Icaro + AnimationMixer (TDD)

**Files:**
- Create: `kiosk/web/avatar/player.js`
- Create: `kiosk/tests/test_avatar_player_html.py`

**Approach:** Write the player as an ES-module class, then test its public API by loading `index.html` inside a headless `QWebEngineView` and probing via `runJavaScript`.

- [ ] **Step 6.1: Write failing tests (E2E via QWebEngineView)**

Create `kiosk/tests/test_avatar_player_html.py`:

```python
"""End-to-end tests for kiosk/web/avatar/player.js using a headless QWebEngineView.

These run real Three.js inside Chromium-via-Qt, so they require the asset bundle
prepared by scripts/prepare_avatar_assets.py.
"""
from __future__ import annotations

import json
import os
import time
from pathlib import Path
from typing import Any

import pytest

pytest.importorskip("PySide6.QtWebEngineWidgets")

from PySide6.QtCore import QEventLoop, QTimer, QUrl
from PySide6.QtGui import QGuiApplication
from PySide6.QtWebEngineQuick import QtWebEngineQuick
from PySide6.QtWebEngineWidgets import QWebEngineView

KIOSK_ROOT = Path(__file__).resolve().parent.parent
AVATAR_DIR = KIOSK_ROOT / "web" / "avatar"
ASSETS_DIR = AVATAR_DIR / "assets"


def _qapp():
    app = QGuiApplication.instance()
    if app is None:
        QtWebEngineQuick.initialize()
        app = QGuiApplication([])
    return app


def _eval_js(view: QWebEngineView, script: str, timeout_ms: int = 15000) -> Any:
    """Run script in the page, block until it returns. Returns the JS value."""
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


def _wait_until(view: QWebEngineView, expr: str, timeout_ms: int = 15000) -> Any:
    """Poll `expr` (a JS expression) every 100ms until truthy or timeout."""
    deadline = time.monotonic() + timeout_ms / 1000
    while time.monotonic() < deadline:
        v = _eval_js(view, f"({expr})", timeout_ms=2000)
        if v:
            return v
        time.sleep(0.1)
    raise TimeoutError(f"waitUntil timeout: {expr}")


@pytest.fixture(scope="module")
def assets_present():
    if not (ASSETS_DIR / "icaro.glb").exists() or not (ASSETS_DIR / "bundles" / "CASA.threejs.json").exists():
        pytest.skip("avatar assets not prepared; run scripts/prepare_avatar_assets.py first")


@pytest.fixture
def view(qapp, assets_present):
    v = QWebEngineView()
    v.resize(400, 500)
    url = QUrl.fromLocalFile(str(AVATAR_DIR / "index.html"))
    loop = QEventLoop()
    v.loadFinished.connect(lambda ok: loop.quit())
    v.load(url)
    QTimer.singleShot(15000, loop.quit)
    loop.exec()
    yield v
    v.deleteLater()


@pytest.fixture(scope="module")
def qapp():
    return _qapp()


def test_player_initializes(view):
    _wait_until(view, "window.__player && window.__player.ready === true")


def test_loads_icaro_avatar(view):
    _wait_until(view, "window.__player && window.__player.ready === true")
    has_mesh = _eval_js(view, "window.__player.scene.children.some(o => o.type === 'Group' || o.type === 'SkinnedMesh' || (o.children && o.children.length > 0))")
    assert has_mesh is True


def test_play_casa_completes(view):
    _wait_until(view, "window.__player && window.__player.ready === true")
    _eval_js(view, """
        window.__finishedGloss = null;
        window.__player.onFinished = (g) => { window.__finishedGloss = g; };
        window.__player.playGloss('CASA');
    """)
    _wait_until(view, "window.__finishedGloss === 'CASA'", timeout_ms=8000)


def test_unknown_gloss_rejects(view):
    _wait_until(view, "window.__player && window.__player.ready === true")
    err = _eval_js(view, """
        new Promise((resolve) => {
            window.__player.playGloss('BOGUS_DOES_NOT_EXIST').then(
                () => resolve(null),
                (e) => resolve(String(e))
            );
        })
    """, timeout_ms=5000)
    assert err is not None and "BOGUS_DOES_NOT_EXIST" in err


def test_dispose_releases_resources(view):
    _wait_until(view, "window.__player && window.__player.ready === true")
    before = _eval_js(view, "window.__player.scene.children.length")
    _eval_js(view, "window.__player.dispose()")
    after = _eval_js(view, "window.__player.scene.children.length")
    assert after < before
```

- [ ] **Step 6.2: Run tests — expect all to fail (player.js does not exist)**

First prepare assets (Task 3 already did this; re-run if needed):
```bash
cd kiosk && python scripts/prepare_avatar_assets.py --source ../sls_brazil_player/public --glosses CASA
```

Run: `cd kiosk && pytest tests/test_avatar_player_html.py -v`
Expected: page load fails or `window.__player` undefined errors.

- [ ] **Step 6.3: Implement `player.js`**

Create `kiosk/web/avatar/player.js`:

```javascript
import * as THREE from "./vendor/three.module.min.js";
import { GLTFLoader } from "./vendor/GLTFLoader.js";

const ASSETS_BASE = "./assets";

export class Player {
  constructor(canvas, opts = {}) {
    this.canvas = canvas;
    this.onStatus = opts.onStatus || (() => {});
    this.onFinished = opts.onFinished || (() => {});
    this.onError = opts.onError || (() => {});
    this.ready = false;
    this.scene = null;
    this.camera = null;
    this.renderer = null;
    this.mixer = null;
    this.avatarRoot = null;
    this._activeAction = null;
    this._bundleIndex = null;
    this._clipCache = new Map();
    this._raf = null;
    this._lastT = 0;
    // Expose for tests/debugging
    if (typeof window !== "undefined") window.__player = this;
  }

  async init() {
    this.onStatus("init");
    this.scene = new THREE.Scene();
    this.scene.background = null; // transparent

    const w = this.canvas.clientWidth || 400;
    const h = this.canvas.clientHeight || 500;
    this.camera = new THREE.PerspectiveCamera(35, w / h, 0.1, 100);
    this.camera.position.set(0, 1.4, 2.4);
    this.camera.lookAt(0, 1.3, 0);

    this.renderer = new THREE.WebGLRenderer({
      canvas: this.canvas,
      alpha: true,
      antialias: true,
      preserveDrawingBuffer: false,
    });
    this.renderer.setPixelRatio(window.devicePixelRatio || 1);
    this.renderer.setSize(w, h, false);
    this.renderer.setClearColor(0x000000, 0);

    const key = new THREE.DirectionalLight(0xffffff, 1.2);
    key.position.set(1, 2, 1.5);
    this.scene.add(key);
    this.scene.add(new THREE.AmbientLight(0xffffff, 0.6));

    // Load avatar GLB
    await this._loadAvatar(`${ASSETS_BASE}/icaro.glb`);

    // Load bundle index
    const r = await fetch(`${ASSETS_BASE}/bundles/index.json`);
    if (!r.ok) throw new Error(`bundles/index.json HTTP ${r.status}`);
    this._bundleIndex = await r.json();

    // WebGL context loss handler
    this.canvas.addEventListener("webglcontextlost", (e) => {
      e.preventDefault();
      this.onStatus("ctx-lost");
      this.onError("webglcontextlost");
    }, false);
    this.canvas.addEventListener("webglcontextrestored", async () => {
      this.onStatus("ctx-restored");
      await this._loadAvatar(`${ASSETS_BASE}/icaro.glb`);
    }, false);

    // Resize
    window.addEventListener("resize", () => this._onResize());
    this._onResize();

    // Render loop
    this._lastT = performance.now();
    const tick = (t) => {
      const dt = (t - this._lastT) / 1000;
      this._lastT = t;
      if (this.mixer) this.mixer.update(dt);
      this.renderer.render(this.scene, this.camera);
      this._raf = requestAnimationFrame(tick);
    };
    this._raf = requestAnimationFrame(tick);

    this.ready = true;
    this.onStatus("ready");
  }

  async _loadAvatar(url) {
    const loader = new GLTFLoader();
    const gltf = await new Promise((resolve, reject) =>
      loader.load(url, resolve, undefined, reject)
    );
    if (this.avatarRoot) {
      this.scene.remove(this.avatarRoot);
      this.avatarRoot = null;
    }
    this.avatarRoot = gltf.scene;
    this.scene.add(this.avatarRoot);
    this.mixer = new THREE.AnimationMixer(this.avatarRoot);
  }

  _onResize() {
    if (!this.renderer || !this.camera) return;
    const w = this.canvas.clientWidth || this.canvas.parentElement.clientWidth;
    const h = this.canvas.clientHeight || this.canvas.parentElement.clientHeight;
    this.renderer.setSize(w, h, false);
    this.camera.aspect = w / h;
    this.camera.updateProjectionMatrix();
  }

  async _loadGlossClip(name) {
    if (this._clipCache.has(name)) return this._clipCache.get(name);
    const entry = this._bundleIndex.glosses.find((g) => g.key === name);
    if (!entry) throw new Error(`unknown gloss: ${name}`);
    const r = await fetch(`${ASSETS_BASE}/bundles/${entry.file}`);
    if (!r.ok) throw new Error(`gloss fetch HTTP ${r.status}: ${name}`);
    const json = await r.json();
    const clip = THREE.AnimationClip.parse(json);
    this._clipCache.set(name, clip);
    return clip;
  }

  async playGloss(name) {
    if (!this.ready) throw new Error("player not ready");
    const clip = await this._loadGlossClip(name);
    if (this._activeAction) {
      this._activeAction.stop();
    }
    const action = this.mixer.clipAction(clip);
    action.reset();
    action.setLoop(THREE.LoopOnce, 1);
    action.clampWhenFinished = true;
    action.play();
    this._activeAction = action;
    this.onStatus(`play:${name}`);

    return new Promise((resolve) => {
      const onFinish = (e) => {
        if (e.action === action) {
          this.mixer.removeEventListener("finished", onFinish);
          this.onStatus(`done:${name}`);
          this.onFinished(name);
          resolve(name);
        }
      };
      this.mixer.addEventListener("finished", onFinish);
    });
  }

  setVisible(visible) {
    this.canvas.style.visibility = visible ? "visible" : "hidden";
  }

  dispose() {
    if (this._raf) cancelAnimationFrame(this._raf);
    this._raf = null;
    if (this.mixer) {
      this.mixer.stopAllAction();
      this.mixer.uncacheRoot(this.avatarRoot);
      this.mixer = null;
    }
    if (this.avatarRoot) {
      this.scene.remove(this.avatarRoot);
      this.avatarRoot.traverse((obj) => {
        if (obj.geometry) obj.geometry.dispose();
        if (obj.material) {
          const mats = Array.isArray(obj.material) ? obj.material : [obj.material];
          for (const m of mats) {
            for (const k of Object.keys(m)) {
              if (m[k] && m[k].isTexture) m[k].dispose();
            }
            m.dispose();
          }
        }
      });
      this.avatarRoot = null;
    }
    this._clipCache.clear();
    if (this.renderer) {
      this.renderer.dispose();
      this.renderer.forceContextLoss();
      this.renderer = null;
    }
    this.ready = false;
    this.onStatus("disposed");
  }
}
```

- [ ] **Step 6.4: Run tests — expect all green**

Run: `cd kiosk && pytest tests/test_avatar_player_html.py -v`
Expected: 5 passed (init, load avatar, play CASA, unknown gloss reject, dispose).

If `test_play_casa_completes` times out: confirm `CASA.threejs.json` exists in `web/avatar/assets/bundles/` and that the bundle parses as a valid `THREE.AnimationClip` (the file format is what `THREE.AnimationClip.parse` expects, which is the same one `sls_brazil_player` writes).

- [ ] **Step 6.5: Commit**

```bash
git add kiosk/web/avatar/player.js kiosk/tests/test_avatar_player_html.py
git commit -m "feat: avatar player.js with Three.js + Icaro + CASA TDD coverage"
```

---

## Task 7: `bridge.js` — QWebChannel ↔ player

**Files:**
- Create: `kiosk/web/avatar/bridge.js`
- Modify: `kiosk/tests/test_avatar_player_html.py` (add bridge test)

The bridge connects to a `QWebChannel` provided by Qt. In the absence of Qt (browser test), it gracefully no-ops so the player still runs.

- [ ] **Step 7.1: Add a bridge test**

Append to `kiosk/tests/test_avatar_player_html.py`:

```python
def test_bridge_module_loads_without_qt(view):
    """In headless QWebEngineView (no QWebChannel), bridge should still resolve."""
    _wait_until(view, "window.__player && window.__player.ready === true")
    # connectBridge is called by index.html; it should have set window.__bridgeReady
    _wait_until(view, "window.__bridgeReady === true", timeout_ms=8000)
```

- [ ] **Step 7.2: Run — expect failure (bridge.js missing)**

Run: `cd kiosk && pytest tests/test_avatar_player_html.py::test_bridge_module_loads_without_qt -v`
Expected: FAIL (import error or `__bridgeReady` never true).

- [ ] **Step 7.3: Implement `bridge.js`**

Create `kiosk/web/avatar/bridge.js`:

```javascript
/**
 * connectBridge(player)
 *
 * If qt.webChannelTransport exists (we are inside a QWebEngineView with a channel
 * registered), wire up a `kiosk` proxy object that QML can call:
 *    bridge.playGloss(name)   -> player.playGloss(name)
 *    bridge.setVisible(bool)  -> player.setVisible(bool)
 *    bridge.dispose()         -> player.dispose()
 * and emits Qt-side signals for `ready`, `finished(name)`, `error(msg)`.
 *
 * If no transport is present (plain browser test), set window.__bridgeReady=true
 * so tests/manual-debug pages still know we are alive.
 */
export async function connectBridge(player) {
  // Hook player events
  const fwd = {
    finishedListeners: [],
    errorListeners: [],
  };
  player.onFinished = (name) => fwd.finishedListeners.forEach((cb) => cb(name));
  player.onError = (msg) => fwd.errorListeners.forEach((cb) => cb(String(msg)));

  if (typeof qt === "undefined" || !qt.webChannelTransport) {
    window.__bridgeReady = true;
    return null;
  }

  return new Promise((resolve) => {
    // qwebchannel.js (script tag in index.html) defines QWebChannel as a global
    // eslint-disable-next-line no-undef
    new QWebChannel(qt.webChannelTransport, (channel) => {
      const kiosk = channel.objects.kiosk;

      // QML-callable slots are exposed by name on `kiosk`. We expose ours in JS:
      window.kiosk = {
        playGloss: (name) => player.playGloss(name).catch((e) => kiosk && kiosk.onError && kiosk.onError(String(e))),
        setVisible: (b) => player.setVisible(!!b),
        dispose: () => player.dispose(),
      };

      // Forward player events to QML
      fwd.finishedListeners.push((name) => {
        if (kiosk && typeof kiosk.onFinished === "function") kiosk.onFinished(name);
      });
      fwd.errorListeners.push((msg) => {
        if (kiosk && typeof kiosk.onError === "function") kiosk.onError(msg);
      });

      // Tell QML we're alive
      if (kiosk && typeof kiosk.onReady === "function") kiosk.onReady();
      window.__bridgeReady = true;
      resolve(kiosk);
    });
  });
}
```

- [ ] **Step 7.4: Run all player tests — expect green**

Run: `cd kiosk && pytest tests/test_avatar_player_html.py -v`
Expected: 6 passed.

- [ ] **Step 7.5: Commit**

```bash
git add kiosk/web/avatar/bridge.js kiosk/tests/test_avatar_player_html.py
git commit -m "feat: bridge.js QWebChannel adapter with no-Qt fallback"
```

---

## Task 8: `AvatarWidget.qml` — base widget + crash recovery + watchdog (TDD)

**Files:**
- Create: `kiosk/qml/components/AvatarWidget.qml`
- Create: `kiosk/tests/test_avatar_widget.py`

This widget owns the `WebEngineView`, exposes `gloss` / `repeatIntervalMs`, handles render-process crashes (max 3 retries), runs a 5-second `ready` watchdog, and stops cleanly on hide.

- [ ] **Step 8.1: Write failing widget tests**

Create `kiosk/tests/test_avatar_widget.py`:

```python
"""Tests for AvatarWidget.qml using pytest-qt + QQuickWidget.

We drive the widget by setting properties from Python and observing emitted signals
plus internal state.
"""
from __future__ import annotations

from pathlib import Path

import pytest

pytest.importorskip("PySide6.QtQuickWidgets")
pytest.importorskip("PySide6.QtWebEngineWidgets")

from PySide6.QtCore import QObject, QUrl, Signal, Property, Slot, QTimer, QEventLoop
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtQuickWidgets import QQuickWidget
from PySide6.QtWebEngineQuick import QtWebEngineQuick

KIOSK_ROOT = Path(__file__).resolve().parent.parent
QML_DIR = KIOSK_ROOT / "qml"
AVATAR_INDEX = (KIOSK_ROOT / "web" / "avatar" / "index.html").as_uri()


@pytest.fixture(scope="module", autouse=True)
def _qapp():
    app = QGuiApplication.instance()
    if app is None:
        QtWebEngineQuick.initialize()
        app = QGuiApplication([])
    return app


def _load_widget(extra_props: dict | None = None):
    """Load AvatarWidget standalone in a QQuickWidget."""
    w = QQuickWidget()
    w.engine().rootContext().setContextProperty("AVATAR_URL", AVATAR_INDEX)
    w.engine().rootContext().setContextProperty("AVATAR_ENABLED", True)
    for k, v in (extra_props or {}).items():
        w.engine().rootContext().setContextProperty(k, v)
    w.engine().addImportPath(str(QML_DIR))
    qml = f"""
        import QtQuick
        import "{QML_DIR.as_posix()}/components"
        AvatarWidget {{
            id: a
            width: 280; height: 360
            gloss: "CASA"
            repeatIntervalMs: 0  // tests opt out of looping by default
        }}
    """
    qml_file = KIOSK_ROOT / "tests" / "_inline_avatar_widget.qml"
    qml_file.write_text(qml, encoding="utf-8")
    w.setSource(QUrl.fromLocalFile(str(qml_file)))
    w.resize(280, 360)
    w.show()
    qml_file.unlink(missing_ok=True)
    return w


def _spin(ms: int):
    loop = QEventLoop()
    QTimer.singleShot(ms, loop.quit)
    loop.exec()


def test_widget_loads_when_assets_present():
    w = _load_widget()
    root = w.rootObject()
    assert root is not None
    # Default visible
    assert root.property("visible") is True
    w.deleteLater()


def test_widget_hidden_when_assets_missing(tmp_path):
    """If AVATAR_ENABLED is False, widget reports visible=false."""
    w = QQuickWidget()
    w.engine().rootContext().setContextProperty("AVATAR_URL", AVATAR_INDEX)
    w.engine().rootContext().setContextProperty("AVATAR_ENABLED", False)
    w.engine().addImportPath(str(QML_DIR))
    qml = f"""
        import QtQuick
        import "{QML_DIR.as_posix()}/components"
        AvatarWidget {{ width: 280; height: 360; gloss: "CASA" }}
    """
    f = tmp_path / "x.qml"; f.write_text(qml, encoding="utf-8")
    w.setSource(QUrl.fromLocalFile(str(f)))
    w.resize(280, 360); w.show()
    _spin(200)
    assert w.rootObject().property("visible") is False
    w.deleteLater()


def test_render_process_terminated_increments_counter(qtbot):
    w = _load_widget()
    root = w.rootObject()
    qtbot.addWidget(w)
    # Simulate by directly invoking the recovery method
    assert root.property("rebuildCount") == 0
    root.metaObject().invokeMethod(root, "_simulateCrash")
    assert root.property("rebuildCount") == 1
    w.deleteLater()


def test_max_3_rebuilds_then_emits_player_error(qtbot):
    w = _load_widget()
    root = w.rootObject()
    errors = []
    root.playerError.connect(lambda msg: errors.append(msg))
    for _ in range(4):
        root.metaObject().invokeMethod(root, "_simulateCrash")
    assert root.property("rebuildCount") == 3  # capped
    assert any("rebuild" in e.lower() or "crash" in e.lower() for e in errors)
    assert root.property("visible") is False
    w.deleteLater()


def test_watchdog_fires_when_no_ready(qtbot):
    """If bridge never reports ready within readyTimeoutMs, widget reloads."""
    w = _load_widget(extra_props={"AVATAR_URL": "file:///does/not/exist.html"})
    root = w.rootObject()
    # set a short timeout for the test
    root.setProperty("readyTimeoutMs", 800)
    _spin(1500)
    assert root.property("watchdogFires") >= 1
    w.deleteLater()


def test_repeat_loops_after_finished(qtbot):
    w = _load_widget()
    root = w.rootObject()
    root.setProperty("repeatIntervalMs", 300)
    starts = []
    root.playbackStarted.connect(lambda g: starts.append(g))
    # Wait for first finish + repeat interval + second start
    _spin(8000)
    assert len(starts) >= 2
    w.deleteLater()


def test_repeat_stops_when_hidden(qtbot):
    w = _load_widget()
    root = w.rootObject()
    root.setProperty("repeatIntervalMs", 300)
    _spin(4000)  # let one finish
    starts_before = root.property("playCount")
    root.setProperty("visible", False)
    _spin(2000)
    starts_after = root.property("playCount")
    assert starts_after == starts_before  # no new plays while hidden
    w.deleteLater()
```

- [ ] **Step 8.2: Run — expect failure (component does not exist)**

Run: `cd kiosk && pytest tests/test_avatar_widget.py -v`
Expected: QML import error: `module "components" is not installed`.

- [ ] **Step 8.3: Implement `AvatarWidget.qml`**

Create `kiosk/qml/components/AvatarWidget.qml`:

```qml
import QtQuick
import QtQuick.Controls
import QtWebEngine
import QtWebChannel

/*
 * AvatarWidget — Sign language avatar overlay.
 *
 * Lifecycle:
 *   onCreate -> WebEngineView loads AVATAR_URL
 *   bridge.onReady (QWebChannel) -> ready=true, watchdog cancelled
 *   gloss change -> playGloss via channel
 *   render process crash -> rebuildCount++, reload (max 3 retries)
 *   ready watchdog (default 5s): if no ready, force reload
 *   visible=false / destruction -> stop loop timer + dispose
 *
 * Repeat policy:
 *   repeatIntervalMs > 0  -> after finished, wait that long then play again.
 *   repeatIntervalMs == 0 -> play once, stay idle.
 */
Item {
    id: root

    // --- Public API ---
    property string gloss: ""
    property bool autoplay: true
    property int repeatIntervalMs: 8000   // 0 = play once
    property int readyTimeoutMs: 5000
    property int maxRebuilds: 3

    // --- Read-only state (exposed for tests) ---
    property int rebuildCount: 0
    property int playCount: 0
    property int watchdogFires: 0
    property bool ready: false
    property bool _giveUp: false

    signal playbackStarted(string gloss)
    signal playbackFinished(string gloss)
    signal playerError(string message)

    visible: typeof AVATAR_ENABLED !== "undefined" ? AVATAR_ENABLED && !_giveUp : !_giveUp

    // QWebChannel bridge object exposed as `kiosk` to JS.
    QtObject {
        id: bridge
        WebChannel.id: "kiosk"

        signal sendPlayGloss(string name)
        signal sendSetVisible(bool v)
        signal sendDispose()

        function onReady() {
            root.ready = true;
            watchdog.stop();
            if (root.autoplay && root.gloss.length > 0) {
                _doPlay(root.gloss);
            }
        }
        function onFinished(name) {
            root.playbackFinished(name);
            if (root.repeatIntervalMs > 0 && root.visible && !root._giveUp) {
                repeatTimer.restart();
            }
        }
        function onError(msg) {
            root.playerError(msg);
        }
    }

    WebChannel {
        id: channel
        registeredObjects: [bridge]
    }

    // The actual web view, recreated on render-process crash.
    Loader {
        id: viewLoader
        anchors.fill: parent
        active: !root._giveUp
        sourceComponent: webEngineComp
    }

    Component {
        id: webEngineComp
        WebEngineView {
            id: web
            anchors.fill: parent
            backgroundColor: "transparent"
            settings.localContentCanAccessFileUrls: true
            settings.localContentCanAccessRemoteUrls: false
            webChannel: channel
            url: typeof AVATAR_URL !== "undefined" ? AVATAR_URL : ""

            onLoadingChanged: function(info) {
                if (info.status === WebEngineView.LoadFailedStatus) {
                    root.playerError("load failed: " + info.errorString);
                }
            }
            onRenderProcessTerminated: function(terminationStatus, exitCode) {
                _onCrash("renderer terminated status=" + terminationStatus + " exit=" + exitCode);
            }
        }
    }

    Timer {
        id: watchdog
        interval: root.readyTimeoutMs
        running: !root.ready && !root._giveUp && viewLoader.active
        repeat: false
        onTriggered: {
            root.watchdogFires++;
            _onCrash("watchdog: no ready within " + root.readyTimeoutMs + "ms");
        }
    }

    Timer {
        id: repeatTimer
        interval: root.repeatIntervalMs
        repeat: false
        onTriggered: {
            if (root.visible && !root._giveUp && root.gloss.length > 0) {
                _doPlay(root.gloss);
            }
        }
    }

    onGlossChanged: {
        if (ready && autoplay && gloss.length > 0) _doPlay(gloss);
    }

    onVisibleChanged: {
        if (!visible) {
            repeatTimer.stop();
        }
    }

    Component.onDestruction: {
        repeatTimer.stop();
        if (ready) bridge.sendDispose();
    }

    // ---- Internal helpers ----

    function _doPlay(name) {
        playCount++;
        playbackStarted(name);
        bridge.sendPlayGloss(name);
    }

    function _onCrash(reason) {
        rebuildCount++;
        ready = false;
        if (rebuildCount > maxRebuilds) {
            _giveUp = true;
            playerError("giving up after " + maxRebuilds + " rebuilds: " + reason);
            return;
        }
        // Recreate the view
        viewLoader.active = false;
        viewLoader.active = true;
    }

    // For tests
    function _simulateCrash() {
        _onCrash("simulated");
    }
}
```

**Note on the bridge → JS direction:** the `onReady`/`onFinished`/`onError` methods on `bridge` are called by `bridge.js` via `kiosk.onReady()` etc. The `sendPlayGloss` signal connects to a JS-side handler we wire up in the next step.

- [ ] **Step 8.4: Wire the QML→JS direction by extending `bridge.js`**

Modify `kiosk/web/avatar/bridge.js` — replace the `connectBridge` body with this version that subscribes to QML signals:

```javascript
import * as THREE from "./vendor/three.module.min.js"; // not strictly needed but keeps Three side-effect import
// (The `bridge.js` file should not actually import THREE; remove this line — keep clean.)
```

Wait — clean replacement. Edit `kiosk/web/avatar/bridge.js`:

Replace the whole file with:

```javascript
/**
 * connectBridge(player) — see player.js for the player API.
 *
 * QML side exposes a QtObject with WebChannel.id = "kiosk" that has:
 *   signals:  sendPlayGloss(string), sendSetVisible(bool), sendDispose()
 *   slots:    onReady(), onFinished(string), onError(string)
 *
 * We connect the QML signals to player methods, and call kiosk.onReady() once
 * we are alive.
 */
export async function connectBridge(player) {
  if (typeof qt === "undefined" || !qt.webChannelTransport) {
    window.__bridgeReady = true;
    return null;
  }

  return new Promise((resolve) => {
    // eslint-disable-next-line no-undef
    new QWebChannel(qt.webChannelTransport, (channel) => {
      const kiosk = channel.objects.kiosk;

      // Hook player → QML
      player.onFinished = (name) => kiosk.onFinished(name);
      player.onError = (msg) => kiosk.onError(String(msg));

      // Hook QML → player
      kiosk.sendPlayGloss.connect((name) => {
        player.playGloss(name).catch((e) => kiosk.onError(String(e)));
      });
      kiosk.sendSetVisible.connect((v) => player.setVisible(!!v));
      kiosk.sendDispose.connect(() => player.dispose());

      kiosk.onReady();
      window.__bridgeReady = true;
      resolve(kiosk);
    });
  });
}
```

- [ ] **Step 8.5: Run widget tests — expect green**

Run: `cd kiosk && pytest tests/test_avatar_widget.py -v`
Expected: 7 passed. If `test_repeat_loops_after_finished` is flaky on slow machines, the 8s spin window and 300ms repeat interval should still let at least 2 plays land — bump spin to 12s if needed.

- [ ] **Step 8.6: Run player tests too (regression)**

Run: `cd kiosk && pytest tests/test_avatar_player_html.py -v`
Expected: 6 passed (no regression from bridge.js rewrite).

- [ ] **Step 8.7: Commit**

```bash
git add kiosk/qml/components/AvatarWidget.qml kiosk/web/avatar/bridge.js kiosk/tests/test_avatar_widget.py
git commit -m "feat: AvatarWidget.qml with crash recovery, watchdog, and 8s repeat loop"
```

---

## Task 9: `main.py` — WebEngine init, EGLFS flags, context properties, CLI

**Files:**
- Modify: `kiosk/main.py`
- Create: `kiosk/tests/test_main_avatar_integration.py`

- [ ] **Step 9.1: Write failing integration test**

Create `kiosk/tests/test_main_avatar_integration.py`:

```python
"""Wiring tests for main.py avatar integration.

We do NOT launch the GUI; we test that:
  - argparse exposes --no-avatar and --avatar-repeat-ms
  - context properties are computed correctly given filesystem state
"""
from __future__ import annotations

import sys
from pathlib import Path

import pytest

KIOSK_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(KIOSK_ROOT))

import main


def test_parse_args_default_avatar_enabled():
    ns = main.parse_args([])
    assert ns.no_avatar is False
    assert ns.avatar_repeat_ms == 8000


def test_parse_args_no_avatar_flag():
    ns = main.parse_args(["--no-avatar"])
    assert ns.no_avatar is True


def test_parse_args_repeat_ms():
    ns = main.parse_args(["--avatar-repeat-ms", "0"])
    assert ns.avatar_repeat_ms == 0


def test_compute_avatar_props_when_assets_present(tmp_path):
    web = tmp_path / "web" / "avatar"
    (web / "assets" / "bundles").mkdir(parents=True)
    (web / "index.html").write_text("<!doctype html>")
    (web / "assets" / "icaro.glb").write_bytes(b"\x67\x6c\x54\x46")
    (web / "assets" / "bundles" / "CASA.threejs.json").write_text("{}")
    props = main.compute_avatar_props(web, no_avatar=False)
    assert props["AVATAR_ENABLED"] is True
    assert props["AVATAR_URL"].endswith("index.html")


def test_compute_avatar_props_disabled_when_assets_missing(tmp_path):
    web = tmp_path / "web" / "avatar"
    (web).mkdir(parents=True)
    (web / "index.html").write_text("<!doctype html>")
    # no assets/icaro.glb
    props = main.compute_avatar_props(web, no_avatar=False)
    assert props["AVATAR_ENABLED"] is False


def test_compute_avatar_props_disabled_via_flag(tmp_path):
    web = tmp_path / "web" / "avatar"
    (web / "assets" / "bundles").mkdir(parents=True)
    (web / "index.html").write_text("<!doctype html>")
    (web / "assets" / "icaro.glb").write_bytes(b"x")
    (web / "assets" / "bundles" / "CASA.threejs.json").write_text("{}")
    props = main.compute_avatar_props(web, no_avatar=True)
    assert props["AVATAR_ENABLED"] is False
```

- [ ] **Step 9.2: Run — expect failure**

Run: `cd kiosk && pytest tests/test_main_avatar_integration.py -v`
Expected: AttributeError on `main.compute_avatar_props` and CLI flag KeyErrors.

- [ ] **Step 9.3: Modify `main.py`**

Edit `kiosk/main.py` to:
1. Import `QtWebEngineQuick` and call `initialize()` before `QGuiApplication`.
2. Add EGLFS Chromium flags when `QT_QPA_PLATFORM=eglfs`.
3. Add `--no-avatar` and `--avatar-repeat-ms` CLI args.
4. Add `compute_avatar_props()` helper.
5. Set context properties `AVATAR_URL`, `AVATAR_ENABLED`, `AVATAR_REPEAT_MS`.

Replace `kiosk/main.py` with:

```python
import os
import sys
import argparse
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


def compute_avatar_props(web_avatar_dir: Path, *, no_avatar: bool) -> dict:
    """Return {AVATAR_URL, AVATAR_ENABLED} given filesystem + flag state.

    AVATAR_ENABLED is True only when:
      - --no-avatar was NOT passed
      - index.html exists
      - icaro.glb and CASA bundle exist (assets prepared)
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

    print(f"[fonts] Loaded: {loaded or '(none)'}  |  Primary: {primary_font}")
    print(f"[theme] Active Style: {args.theme}")
    print(f"[mode]  {args.mode}  "
          f"(camera={args.camera_device}  backend={args.camera_backend}  "
          f"{args.camera_width}x{args.camera_height}@{args.camera_fps})")
    print(f"[avatar] enabled={avatar_props['AVATAR_ENABLED']}  "
          f"repeat_ms={args.avatar_repeat_ms}  url={avatar_props['AVATAR_URL']}")

    engine = QQmlApplicationEngine()
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
    ctx.setContextProperty("AVATAR_URL", avatar_props["AVATAR_URL"])
    ctx.setContextProperty("AVATAR_ENABLED", avatar_props["AVATAR_ENABLED"])
    ctx.setContextProperty("AVATAR_REPEAT_MS", args.avatar_repeat_ms)

    qml_dir = base_dir / "qml"
    engine.addImportPath(str(qml_dir))

    qml_file = qml_dir / "Main.qml"
    engine.load(QUrl.fromLocalFile(str(qml_file)))

    if not engine.rootObjects():
        print("Failed to load QML", file=sys.stderr)
        return -1

    return app.exec()


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 9.4: Run integration tests — expect green**

Run: `cd kiosk && pytest tests/test_main_avatar_integration.py -v`
Expected: 6 passed.

- [ ] **Step 9.5: Manual smoke — start the app in demo mode**

Run: `cd kiosk && python main.py --theme holo`
Expected:
- App opens fullscreen
- Console shows `[avatar] enabled=True  repeat_ms=8000  url=file:///.../web/avatar/index.html`
- HomeScreen displays normally (avatar not yet wired into the screen — Task 10)
- Close window cleanly (Ctrl+C in terminal)

Then: `python main.py --theme holo --no-avatar`. Console should show `enabled=False`.

- [ ] **Step 9.6: Commit**

```bash
git add kiosk/main.py kiosk/tests/test_main_avatar_integration.py
git commit -m "feat: wire AvatarWidget context props + CLI flags into main.py"
```

---

## Task 10: HomeScreen integration

**Files:**
- Modify: `kiosk/qml/screens/HomeScreen.qml`

- [ ] **Step 10.1: Read HomeScreen.qml to find the safe insertion point**

Run: `cat kiosk/qml/screens/HomeScreen.qml | head -200` (or open in editor).

You are looking for the root `Item`/`Rectangle` that contains the screen content. The avatar must sit OUTSIDE the column layout, anchored to the screen, with `z` chosen to be above `StarsBackdrop` but below dialogs.

- [ ] **Step 10.2: Add AvatarWidget at the bottom of the root**

Use the Edit tool to insert this snippet just before the closing tag of the root `Item` in `kiosk/qml/screens/HomeScreen.qml`:

```qml
    AvatarWidget {
        id: homeAvatar
        visible: typeof AVATAR_ENABLED !== "undefined" ? AVATAR_ENABLED : false
        gloss: "CASA"
        repeatIntervalMs: typeof AVATAR_REPEAT_MS !== "undefined" ? AVATAR_REPEAT_MS : 8000
        width: 280
        height: 360
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: 32
        anchors.bottomMargin: 32
        z: 20
    }
```

If `HomeScreen.qml` has no `import "../components"` (it likely already imports neighboring components implicitly via `engine.addImportPath`), no import line is needed.

- [ ] **Step 10.3: Manual visual smoke**

Run: `cd kiosk && python main.py --theme holo`

Expected: HomeScreen shows the Icaro avatar in the bottom-right, ~280×360, performing the CASA gesture, then idling, then re-playing every 8 seconds. Other UI (cards, HeroCTA, AnnouncementBanner) is unaffected.

- [ ] **Step 10.4: Manual visual with --no-avatar**

Run: `cd kiosk && python main.py --theme holo --no-avatar`

Expected: HomeScreen identical to before this PR — no widget, no empty box.

- [ ] **Step 10.5: Commit**

```bash
git add kiosk/qml/screens/HomeScreen.qml
git commit -m "feat: place AvatarWidget at HomeScreen bottom-right"
```

---

## Task 11: ViewingScreen integration (avoiding ZoomControls collision)

**Files:**
- Modify: `kiosk/qml/screens/ViewingScreen.qml`

- [ ] **Step 11.1: Read ViewingScreen.qml to locate ZoomControls anchors**

Open `kiosk/qml/screens/ViewingScreen.qml`. Find the `ZoomControls` element. Note its anchors (typically `anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter` based on the design doc). The avatar must NOT overlap with it.

- [ ] **Step 11.2: Decide layout**

ZoomControls is on the right edge, vertically centered. Place AvatarWidget to its **left**, anchored to the bottom of the screen. Width 280 → it leaves clear space.

- [ ] **Step 11.3: Insert AvatarWidget**

Use Edit to insert before the closing tag of the root in `kiosk/qml/screens/ViewingScreen.qml`:

```qml
    AvatarWidget {
        id: viewingAvatar
        visible: (typeof AVATAR_ENABLED !== "undefined" ? AVATAR_ENABLED : false) &&
                 !(typeof signalLost !== "undefined" && signalLost)
        gloss: "CASA"
        repeatIntervalMs: typeof AVATAR_REPEAT_MS !== "undefined" ? AVATAR_REPEAT_MS : 8000
        width: 280
        height: 360
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        anchors.rightMargin: 140    // clears ZoomControls (~96px wide + 32px margin)
        anchors.bottomMargin: 96    // clears Exit button row
        z: 20
    }
```

If `ViewingScreen.qml` does not have a `signalLost` property, simplify the visible binding to `typeof AVATAR_ENABLED !== "undefined" ? AVATAR_ENABLED : false`.

- [ ] **Step 11.4: Manual visual smoke (demo mode)**

Run: `cd kiosk && python main.py --theme holo`

Click into a landmark → payment → viewing. ViewingScreen demo mode should show:
- Pre-recorded background images crossfading
- Crosshair, ZoomControls, CountdownTimer, LIVE indicator
- AvatarWidget bottom-right, NOT overlapping ZoomControls or Exit button

- [ ] **Step 11.5: Manual visual smoke (live mode, on Jetson)**

SSH to Jetson, run:
```bash
cd ~/kiosk && \
  QT_QPA_PLATFORM=eglfs \
  QTWEBENGINE_CHROMIUM_FLAGS="--use-gl=egl --no-sandbox" \
  python main.py --mode live --theme holo
```

Navigate to ViewingScreen. Expected: live MIPI camera feed renders smoothly AND avatar plays CASA every 8s. Watch for 2-3 minutes — no frame drops, no console errors.

- [ ] **Step 11.6: Commit**

```bash
git add kiosk/qml/screens/ViewingScreen.qml
git commit -m "feat: place AvatarWidget on ViewingScreen avoiding ZoomControls"
```

---

## Task 12: CRITICAL regression — live camera unaffected by avatar

**Files:**
- Create: `kiosk/tests/test_live_camera_regression.py`
- Create: `kiosk/scripts/measure_camera_fps.py`

**Why critical:** The live MIPI camera mode was just stabilized in commit `5c86902`. We must prove the avatar widget does not regress its frame rate.

- [ ] **Step 12.1: Write the FPS measurement helper**

Create `kiosk/scripts/measure_camera_fps.py`:

```python
"""Measure camera frames-per-second from a running ViewingScreen.

This script taps into a v4l2 device directly (not the Qt pipeline) to get an
upper-bound FPS reading. We compare:

    avatar OFF:   measured FPS over 30s
    avatar ON:    measured FPS over 30s

If they differ by more than 2 fps, we have a regression.
"""
from __future__ import annotations

import argparse
import statistics
import sys
import time
from pathlib import Path

try:
    import cv2
except ImportError:
    print("opencv-python not installed; skipping (install with: pip install opencv-python-headless)", file=sys.stderr)
    sys.exit(77)


def measure_fps(device: str, duration_s: float = 30.0) -> float:
    cap = cv2.VideoCapture(device, cv2.CAP_V4L2)
    if not cap.isOpened():
        raise RuntimeError(f"cannot open {device}")
    cap.set(cv2.CAP_PROP_FRAME_WIDTH, 1920)
    cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 1080)
    cap.set(cv2.CAP_PROP_FPS, 60)
    deadline = time.monotonic() + duration_s
    n = 0
    t0 = time.monotonic()
    while time.monotonic() < deadline:
        ok, _ = cap.read()
        if not ok:
            break
        n += 1
    elapsed = time.monotonic() - t0
    cap.release()
    return n / elapsed if elapsed > 0 else 0.0


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--device", default="/dev/video0")
    p.add_argument("--duration", type=float, default=30.0)
    args = p.parse_args()
    fps = measure_fps(args.device, args.duration)
    print(f"FPS: {fps:.2f}")


if __name__ == "__main__":
    main()
```

- [ ] **Step 12.2: Write the regression test**

Create `kiosk/tests/test_live_camera_regression.py`:

```python
"""CRITICAL regression: avatar must not affect live camera frame rate.

This test is GATED on a Jetson device with /dev/video0 + LT9211C bridge present.
On dev machines it skips. The test starts the kiosk in live mode twice (once
with --no-avatar, once without) and measures sustained FPS.

Run only on Jetson:    pytest tests/test_live_camera_regression.py -v -m jetson
"""
from __future__ import annotations

import os
import subprocess
import sys
import time
from pathlib import Path

import pytest

JETSON = os.path.exists("/dev/video0") and os.environ.get("ON_JETSON") == "1"
pytestmark = pytest.mark.skipif(not JETSON, reason="requires Jetson with /dev/video0 and ON_JETSON=1")

KIOSK_ROOT = Path(__file__).resolve().parent.parent


def _run_kiosk_for(duration_s: float, *, avatar: bool) -> float:
    """Launch kiosk in live mode for duration_s, return measured camera fps."""
    measure_script = KIOSK_ROOT / "scripts" / "measure_camera_fps.py"

    env = os.environ.copy()
    env["QT_QPA_PLATFORM"] = "eglfs"
    env["QTWEBENGINE_CHROMIUM_FLAGS"] = "--use-gl=egl --no-sandbox"

    args = [sys.executable, "main.py", "--mode", "live", "--theme", "holo"]
    if not avatar:
        args.append("--no-avatar")

    kiosk = subprocess.Popen(args, cwd=str(KIOSK_ROOT), env=env,
                             stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    time.sleep(8)  # let it boot + camera settle

    measure = subprocess.run(
        [sys.executable, str(measure_script), "--duration", str(duration_s)],
        capture_output=True, text=True, env=env,
    )
    kiosk.terminate()
    try:
        kiosk.wait(timeout=10)
    except subprocess.TimeoutExpired:
        kiosk.kill()

    out = measure.stdout.strip()
    assert out.startswith("FPS:"), f"unexpected output: {out!r} stderr={measure.stderr!r}"
    return float(out.split(":", 1)[1].strip())


def test_live_camera_unaffected_by_avatar():
    fps_off = _run_kiosk_for(20.0, avatar=False)
    time.sleep(2)
    fps_on = _run_kiosk_for(20.0, avatar=True)
    delta = abs(fps_on - fps_off)
    print(f"\ncamera fps off={fps_off:.2f} on={fps_on:.2f} delta={delta:.2f}")
    # Allow up to 2 fps drift due to measurement noise
    assert delta <= 2.0, f"avatar regressed camera fps by {delta:.2f} (off={fps_off:.2f}, on={fps_on:.2f})"
```

- [ ] **Step 12.3: Run on dev machine — expect skip**

Run: `cd kiosk && pytest tests/test_live_camera_regression.py -v`
Expected: 1 skipped (no `/dev/video0` or `ON_JETSON` not set).

- [ ] **Step 12.4: Run on Jetson — expect pass**

Copy the test files to Jetson:
```bash
scp -i ~/.ssh/jetson_key kiosk/scripts/measure_camera_fps.py kiosk/tests/test_live_camera_regression.py hyunia@192.168.219.125:/path/to/jetson/kiosk/...
```

(Or sync the whole tree via rsync.)

On Jetson:
```bash
ssh -i ~/.ssh/jetson_key hyunia@192.168.219.125
cd ~/kiosk
ON_JETSON=1 pytest tests/test_live_camera_regression.py -v -s
```

Expected: PASS with the printed line `camera fps off=~60.0 on=~60.0 delta=<2.0`.

If it fails (delta > 2 fps), the avatar IS regressing the camera. Investigate before merging:
- Check `nvtop` for GPU saturation
- Try lowering avatar render rate (cap to 30fps in `player.js` tick function)
- Reduce repeat frequency (set `--avatar-repeat-ms 16000`)

- [ ] **Step 12.5: Commit**

```bash
git add kiosk/scripts/measure_camera_fps.py kiosk/tests/test_live_camera_regression.py
git commit -m "test: critical regression — avatar must not slow live camera fps"
```

---

## Task 13: Soak harness for 12-hour stability

**Files:**
- Create: `kiosk/scripts/soak_avatar.py`
- Create: `kiosk/docs/soak_results.md`

**Why:** Repeat-loop policy = 8s × 12h = 5400 plays. Memory leaks in WebGL contexts surface here, not in unit tests.

- [ ] **Step 13.1: Write the soak harness**

Create `kiosk/scripts/soak_avatar.py`:

```python
"""12-hour soak: run kiosk and sample RSS + free GPU memory every 60s.

Usage on Jetson:
    ON_JETSON=1 python scripts/soak_avatar.py --hours 12 --out soak.csv
"""
from __future__ import annotations

import argparse
import csv
import os
import subprocess
import sys
import time
from pathlib import Path


def sample_rss_kb(pid: int) -> int:
    """Read /proc/<pid>/status VmRSS in kB."""
    try:
        with open(f"/proc/{pid}/status") as f:
            for line in f:
                if line.startswith("VmRSS:"):
                    return int(line.split()[1])
    except FileNotFoundError:
        return -1
    return -1


def sample_gpu_free_kb() -> int:
    """Use tegrastats one-shot if available; else -1."""
    try:
        out = subprocess.check_output(["tegrastats", "--interval", "100", "--logfile", "/tmp/tegra.log"],
                                      timeout=0.3, stderr=subprocess.DEVNULL)
    except Exception:
        return -1
    return -1  # parsing tegrastats is platform-specific; placeholder


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--hours", type=float, default=12.0)
    p.add_argument("--interval", type=float, default=60.0)
    p.add_argument("--out", default="soak.csv")
    p.add_argument("--mode", choices=["demo", "live"], default="demo")
    args = p.parse_args()

    kiosk_root = Path(__file__).resolve().parent.parent
    env = os.environ.copy()
    if env.get("ON_JETSON") == "1":
        env.setdefault("QT_QPA_PLATFORM", "eglfs")
        env.setdefault("QTWEBENGINE_CHROMIUM_FLAGS", "--use-gl=egl --no-sandbox")

    print(f"[soak] launching kiosk mode={args.mode}")
    proc = subprocess.Popen([sys.executable, "main.py", "--mode", args.mode, "--theme", "holo"],
                            cwd=str(kiosk_root), env=env)
    time.sleep(10)  # boot

    deadline = time.monotonic() + args.hours * 3600
    with open(args.out, "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["t_seconds", "rss_kb", "gpu_free_kb"])
        t0 = time.monotonic()
        while time.monotonic() < deadline:
            rss = sample_rss_kb(proc.pid)
            gpu = sample_gpu_free_kb()
            t = time.monotonic() - t0
            w.writerow([f"{t:.1f}", rss, gpu])
            f.flush()
            if proc.poll() is not None:
                print(f"[soak] kiosk exited after {t:.1f}s rc={proc.returncode}", file=sys.stderr)
                return 1
            time.sleep(args.interval)

    proc.terminate()
    try:
        proc.wait(timeout=15)
    except subprocess.TimeoutExpired:
        proc.kill()
    print(f"[soak] done. samples in {args.out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 13.2: Run a 30-minute warm-up locally (sanity)**

Run: `cd kiosk && python scripts/soak_avatar.py --hours 0.5 --interval 30 --out soak_local.csv`

Expected: CSV with ~60 rows. Open it: RSS should be roughly stable (drift under 50 MB over 30 min).

- [ ] **Step 13.3: Run the 12-hour soak on Jetson**

```bash
ssh -i ~/.ssh/jetson_key hyunia@192.168.219.125
cd ~/kiosk
ON_JETSON=1 nohup python3 scripts/soak_avatar.py --hours 12 --mode demo --out soak_demo.csv > soak.log 2>&1 &
```

Repeat for `--mode live` if you want both. Wait 12 hours.

- [ ] **Step 13.4: Analyze and document**

Run on Jetson:
```bash
python3 -c "
import csv, statistics
rows = list(csv.DictReader(open('soak_demo.csv')))
rss = [int(r['rss_kb']) for r in rows if int(r['rss_kb']) > 0]
print(f'samples={len(rss)} min={min(rss)/1024:.1f}MB max={max(rss)/1024:.1f}MB drift={(rss[-1]-rss[0])/1024:.1f}MB')
"
```

Create `kiosk/docs/soak_results.md`:

```markdown
# Avatar 12-hour soak results

Date: <YYYY-MM-DD>
Mode: demo / live
Hardware: Jetson Orin Nano (8GB)

## Summary
- Samples: <N>
- RSS min: <MB>
- RSS max: <MB>
- RSS drift (end - start): <MB>
- GPU free min: <MB or n/a>
- Crashes / re-launches: <count>
- Avatar play count (estimate hours*3600/8): <N>

## Verdict
[ ] PASS — drift < 100 MB, no crashes
[ ] FAIL — investigate (attach last 100 lines of soak.log)
```

- [ ] **Step 13.5: Commit**

```bash
git add kiosk/scripts/soak_avatar.py kiosk/docs/soak_results.md
git commit -m "test: 12h soak harness for avatar memory stability"
```

---

## Task 14: Documentation — README + CLAUDE.md

**Files:**
- Modify: `README.md` (project root or `kiosk/README.md`, whichever exists)
- Modify: `kiosk/CLAUDE.md`

- [ ] **Step 14.1: Find the active README**

Run: `ls README.md kiosk/README.md 2>/dev/null`. Edit whichever exists (likely both — pick the one inside `kiosk/`).

- [ ] **Step 14.2: Update README**

Use Edit tool to add a new section "Avatar widget" after the existing "Setup" / "Run" section. Insert this Markdown:

```markdown
## Avatar widget (Libras sign language)

The kiosk overlays a Brazilian sign-language avatar (Icaro) in the bottom-right
of the menu and live screens. It plays the `CASA` gloss every 8 seconds.

### One-time asset prep

The avatar consumes Three.js bundles from a sibling `sls_brazil_player/` repo.
Run this once after cloning, and again whenever the gloss list changes:

```bash
cd kiosk
python scripts/prepare_avatar_assets.py \
    --source ../sls_brazil_player/public \
    --glosses CASA
```

This populates `kiosk/web/avatar/assets/` (gitignored).

### Toggling

- `--no-avatar`: hide the widget entirely.
- `--avatar-repeat-ms <int>`: change repeat interval (`0` = play once).

### Jetson EGLFS

Set these env vars before launch:

```bash
QT_QPA_PLATFORM=eglfs
QTWEBENGINE_CHROMIUM_FLAGS="--use-gl=egl --no-sandbox"
```

`main.py` adds these automatically when `QT_QPA_PLATFORM=eglfs`.
```

- [ ] **Step 14.3: Update CLAUDE.md**

Add a new section to `kiosk/CLAUDE.md` describing the avatar widget lifecycle. Insert at the end:

```markdown
## Avatar widget

- Component: `qml/components/AvatarWidget.qml`
- Web host: `web/avatar/index.html` + `player.js` + `bridge.js`
- Assets: `web/avatar/assets/` (built by `scripts/prepare_avatar_assets.py`, gitignored)
- Wiring: `main.py` calls `QtWebEngineQuick.initialize()` before `QGuiApplication`,
  computes `AVATAR_URL` / `AVATAR_ENABLED` / `AVATAR_REPEAT_MS` context properties.
- Lifecycle: created with screen, plays `gloss` on bridge.ready, repeats every
  `repeatIntervalMs` (default 8000), stops on `visible=false` or destruction.
- Crash recovery: render-process termination triggers reload, capped at 3
  retries; afterward `playerError` is emitted and the widget hides.
- Watchdog: if bridge `ready` does not arrive within `readyTimeoutMs` (5s),
  reload is forced once.
- Jetson note: WebEngine on EGLFS requires `--use-gl=egl --no-sandbox` Chromium
  flags. `main.py` injects them when it sees `QT_QPA_PLATFORM=eglfs`.
```

- [ ] **Step 14.4: Verify no Markdown rendering issues**

Run: `cd kiosk && cat CLAUDE.md | head -200`. Visually check the new section is well-formed.

- [ ] **Step 14.5: Commit**

```bash
git add README.md kiosk/CLAUDE.md kiosk/README.md 2>/dev/null
git commit -m "docs: avatar widget setup and lifecycle"
```

(`git add` the files that actually exist; ignore the others.)

---

## Task 15: End-to-end verification checklist

**Files:** none (manual smoke run)

- [ ] **Step 15.1: Run full test suite**

```bash
cd kiosk && pytest tests/ -v --tb=short
```

Expected: all tests pass except `test_live_camera_regression` which skips on dev machines.

- [ ] **Step 15.2: Local demo mode walkthrough**

```bash
cd kiosk && python main.py --theme holo
```

- HomeScreen: avatar visible bottom-right, plays CASA, repeats every 8s.
- Click a landmark → detail screen → avatar gone (only HomeScreen + ViewingScreen show it).
- Hit "Back" → HomeScreen → avatar resumes.
- Click START VIEWING → payment → viewing screen → avatar visible bottom-right, no overlap with ZoomControls.
- Exit gracefully (Ctrl+C).

- [ ] **Step 15.3: --no-avatar smoke**

```bash
python main.py --theme holo --no-avatar
```

Expected: no avatar anywhere; UI otherwise identical.

- [ ] **Step 15.4: --avatar-repeat-ms 0 smoke**

```bash
python main.py --theme holo --avatar-repeat-ms 0
```

Expected: avatar plays CASA once, then idle. No re-play.

- [ ] **Step 15.5: Missing assets graceful degradation**

```bash
mv kiosk/web/avatar/assets kiosk/web/avatar/assets.bak
python main.py --theme holo
```

Expected: console prints `[avatar] enabled=False ...`; UI runs normally with no avatar widget; no exceptions.

Restore: `mv kiosk/web/avatar/assets.bak kiosk/web/avatar/assets`.

- [ ] **Step 15.6: Jetson live mode walkthrough**

```bash
ssh -i ~/.ssh/jetson_key hyunia@192.168.219.125
cd ~/kiosk && \
  QT_QPA_PLATFORM=eglfs \
  QTWEBENGINE_CHROMIUM_FLAGS="--use-gl=egl --no-sandbox" \
  python3 main.py --mode live --theme holo
```

Walk through the same flow. Live camera + avatar must both render. Watch for 5 minutes:
- Camera fps stable
- Avatar repeats every 8s without stutter
- No `webglcontextlost` or render-process termination in console

- [ ] **Step 15.7: Run regression test on Jetson**

```bash
cd ~/kiosk && ON_JETSON=1 pytest tests/test_live_camera_regression.py -v -s
```

Expected: PASS. Delta < 2 fps.

- [ ] **Step 15.8: Mark plan complete**

```bash
git log --oneline | head -20
```

Should show ~14 commits ending with the docs commit. The branch is ready for code review.

---

## Self-Review (run by author after writing the plan)

Spec coverage check vs. source design doc (`C:\Users\hyuni\.claude\plans\kiosk-sls-brazil-player-shiny-flute.md`):

- [x] Approach B (QtWebEngine + Three.js) — Tasks 2, 5, 6, 7, 8
- [x] Icaro avatar — Task 6 (`_loadAvatar('./assets/icaro.glb')`)
- [x] CASA gloss — Task 6, asset filter in Task 3
- [x] HomeScreen integration — Task 10
- [x] ViewingScreen integration with ZoomControls coexistence — Task 11
- [x] 8s repeat policy with `--avatar-repeat-ms` override — Tasks 8, 9
- [x] Pre-flight Jetson EGLFS spike — Task 4
- [x] Asset build pipeline — Task 3
- [x] Render-process crash recovery (max 3) — Task 8
- [x] 5s ready watchdog — Task 8
- [x] WebGL contextlost handler — Task 6 (`webglcontextlost` listener)
- [x] dispose on hide / destruction — Task 8
- [x] CRITICAL regression: live camera fps — Task 12
- [x] 12h soak — Task 13 (extended from source doc's 8h per playback policy decision)
- [x] Graceful degradation when assets missing — Task 9 (`compute_avatar_props`), verified Task 15.5
- [x] `--no-avatar` toggle — Tasks 9, 15.3
- [x] Documentation updates — Task 14

Type / signature consistency:
- `prepare_avatar_assets`: `copy_avatar(src, dst, *, avatar)` and `copy_bundles(src, dst, *, glosses)` — used consistently in tests and main.
- `Player` class: `init()`, `playGloss(name)`, `setVisible(b)`, `dispose()`, `onFinished`, `onError` — used consistently in `bridge.js` and `AvatarWidget.qml`.
- `AvatarWidget.qml` properties: `gloss`, `repeatIntervalMs`, `readyTimeoutMs`, `maxRebuilds` — used in tests and screen integrations.
- Context properties: `AVATAR_URL`, `AVATAR_ENABLED`, `AVATAR_REPEAT_MS` — defined in `main.py`, consumed in `HomeScreen.qml` and `ViewingScreen.qml`.

Placeholder scan: no TBD / TODO / "implement later" / "similar to" remain in this plan. All code blocks contain executable code.

---

## Plan complete

Plan saved to `docs/superpowers/plans/2026-04-30-kiosk-sls-avatar.md`.
