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
    if bundles_dst.exists():
        shutil.rmtree(bundles_dst)
    bundles_dst.mkdir(parents=True)

    bundles_index_path = bundles_src / "index.json"
    try:
        full_index = json.loads(bundles_index_path.read_text(encoding="utf-8"))
    except FileNotFoundError:
        print(f"[prepare_avatar_assets] ERROR: bundles index not found: {bundles_index_path}", file=sys.stderr)
        raise SystemExit(2)
    except json.JSONDecodeError as e:
        print(f"[prepare_avatar_assets] ERROR: bundles index is not valid JSON: {bundles_index_path}: {e}", file=sys.stderr)
        raise SystemExit(2)
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

    if not kept:
        print("[prepare_avatar_assets] WARNING: no glosses copied (all requested were missing or input list was empty)", file=sys.stderr)

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
        if path.is_file() and path.name != "manifest.json" and not path.name.startswith("."):
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
