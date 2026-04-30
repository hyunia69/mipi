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
