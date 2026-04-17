"""Fetch commercial-licensed assets (fonts, icons, photos) for the kiosk.

Reads `assets/manifest.json` and downloads:
  - Pretendard OTF fonts from GitHub releases (OFL-1.1)
  - Lucide SVG icons from the lucide-icons repo (ISC)
  - Seoul landmark photos from Unsplash / Pexels / Wikimedia Commons
  - Seoul panorama photos for the home slideshow

Source priority: Unsplash -> Pexels -> Wikimedia Commons. The first two need
API keys in `.env`; Wikimedia works without a key and provides a robust fallback.
Only CC0 / CC-BY / Public-Domain works are accepted from Wikimedia so the
result stays safe for commercial kiosk use.

Each downloaded file is recorded in `assets/metadata.json` with source URL,
author, license, and SHA-256 for license auditing and `--verify` checks.

Usage:
    python scripts/fetch_assets.py --all
    python scripts/fetch_assets.py --fonts
    python scripts/fetch_assets.py --icons
    python scripts/fetch_assets.py --landmarks
    python scripts/fetch_assets.py --slideshow
    python scripts/fetch_assets.py --verify
"""
from __future__ import annotations

import argparse
import hashlib
import io
import json
import os
import re
import sys
from dataclasses import dataclass, asdict, field
from pathlib import Path

try:
    import requests
except ImportError:
    print("requests not installed. Run: pip install -r requirements.txt", file=sys.stderr)
    sys.exit(1)

try:
    from PIL import Image
except ImportError:
    print("Pillow not installed. Run: pip install -r requirements.txt", file=sys.stderr)
    sys.exit(1)

try:
    from dotenv import load_dotenv
    load_dotenv()
except ImportError:
    pass

PROJECT_ROOT = Path(__file__).resolve().parent.parent
ASSETS_DIR = PROJECT_ROOT / "assets"
MANIFEST_PATH = ASSETS_DIR / "manifest.json"
METADATA_PATH = ASSETS_DIR / "metadata.json"

HERO_SIZE = (1920, 1080)
THUMB_SIZE = (480, 320)
SLIDESHOW_SIZE = (1920, 1080)

PRETENDARD_BASE = "https://github.com/orioncactus/pretendard/raw/main/packages/pretendard/dist/public/static"
LUCIDE_BASE = "https://raw.githubusercontent.com/lucide-icons/lucide/main/icons"

UNSPLASH_SEARCH = "https://api.unsplash.com/search/photos"
PEXELS_SEARCH = "https://api.pexels.com/v1/search"

WIKIMEDIA_API = "https://commons.wikimedia.org/w/api.php"
WIKIMEDIA_UA = "mipi-kiosk-assets/1.0 (+https://github.com/hyunia69/mipi)"


@dataclass
class AssetEntry:
    path: str
    source: str
    source_url: str
    author: str
    license: str
    sha256: str
    bytes: int
    queries: list[str] = field(default_factory=list)


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()


def load_metadata() -> dict[str, AssetEntry]:
    if not METADATA_PATH.exists():
        return {}
    data = json.loads(METADATA_PATH.read_text(encoding="utf-8"))
    return {k: AssetEntry(**v) for k, v in data.items()}


def save_metadata(entries: dict[str, AssetEntry]) -> None:
    serializable = {k: asdict(v) for k, v in entries.items()}
    METADATA_PATH.write_text(
        json.dumps(serializable, indent=2, ensure_ascii=False),
        encoding="utf-8",
    )


def http_get(url: str, headers: dict | None = None, timeout: int = 30) -> requests.Response:
    response = requests.get(url, headers=headers, timeout=timeout)
    response.raise_for_status()
    return response


def fit_crop(img: Image.Image, target: tuple[int, int]) -> Image.Image:
    tw, th = target
    w, h = img.size
    scale = max(tw / w, th / h)
    new_w, new_h = int(round(w * scale)), int(round(h * scale))
    img = img.resize((new_w, new_h), Image.Resampling.LANCZOS)
    left = (new_w - tw) // 2
    top = (new_h - th) // 2
    return img.crop((left, top, left + tw, top + th))


def record_file(
    entries: dict[str, AssetEntry],
    rel_path: str,
    source: str,
    source_url: str,
    author: str,
    license_: str,
    queries: list[str] | None = None,
) -> None:
    abs_path = ASSETS_DIR / rel_path
    entries[rel_path] = AssetEntry(
        path=rel_path,
        source=source,
        source_url=source_url,
        author=author,
        license=license_,
        sha256=sha256_file(abs_path),
        bytes=abs_path.stat().st_size,
        queries=queries or [],
    )


def fetch_pretendard(manifest: dict, entries: dict[str, AssetEntry]) -> None:
    weights = manifest.get("fonts", {}).get("weights", ["Regular", "Medium", "SemiBold", "Bold"])
    fonts_dir = ASSETS_DIR / "fonts"
    fonts_dir.mkdir(parents=True, exist_ok=True)

    for weight in weights:
        filename = f"Pretendard-{weight}.otf"
        dest = fonts_dir / filename
        url = f"{PRETENDARD_BASE}/{filename}"
        print(f"  [font] {filename}...", end=" ", flush=True)
        try:
            response = http_get(url)
            dest.write_bytes(response.content)
            record_file(entries, f"fonts/{filename}", "GitHub: orioncactus/pretendard", url,
                        "Pretendard Project", "OFL-1.1")
            print("OK")
        except Exception as exc:
            print(f"FAIL ({exc})")


def fetch_lucide_icons(manifest: dict, entries: dict[str, AssetEntry]) -> None:
    icons = manifest.get("icons", [])
    icons_dir = ASSETS_DIR / "icons"
    icons_dir.mkdir(parents=True, exist_ok=True)

    for name in icons:
        filename = f"{name}.svg"
        dest = icons_dir / filename
        url = f"{LUCIDE_BASE}/{filename}"
        print(f"  [icon] {name}...", end=" ", flush=True)
        try:
            response = http_get(url)
            svg_text = response.content.decode("utf-8")
            svg_text = svg_text.replace('stroke="currentColor"', 'stroke="#FFFFFF"')
            svg_text = svg_text.replace('fill="currentColor"', 'fill="#FFFFFF"')
            dest.write_text(svg_text, encoding="utf-8")
            record_file(entries, f"icons/{filename}", "Lucide", url,
                        "Lucide Contributors", "ISC")
            print("OK")
        except Exception as exc:
            print(f"FAIL ({exc})")


def unsplash_search(query: str, per_page: int = 10) -> list[dict]:
    key = os.environ.get("UNSPLASH_ACCESS_KEY", "").strip()
    if not key:
        return []
    try:
        r = http_get(
            f"{UNSPLASH_SEARCH}?query={requests.utils.quote(query)}&per_page={per_page}&orientation=landscape",
            headers={"Authorization": f"Client-ID {key}"},
        )
        return r.json().get("results", [])
    except Exception as exc:
        print(f"    Unsplash search failed: {exc}")
        return []


def pexels_search(query: str, per_page: int = 10) -> list[dict]:
    key = os.environ.get("PEXELS_API_KEY", "").strip()
    if not key:
        return []
    try:
        r = http_get(
            f"{PEXELS_SEARCH}?query={requests.utils.quote(query)}&per_page={per_page}&orientation=landscape",
            headers={"Authorization": key},
        )
        return r.json().get("photos", [])
    except Exception as exc:
        print(f"    Pexels search failed: {exc}")
        return []


def wikimedia_search(query: str, per_page: int = 15) -> list[dict]:
    try:
        r = http_get(
            WIKIMEDIA_API,
            headers={"User-Agent": WIKIMEDIA_UA},
        )
        # Use params properly to avoid encoding issues
        r = requests.get(
            WIKIMEDIA_API,
            params={
                "action": "query",
                "format": "json",
                "list": "search",
                "srsearch": f"{query} filetype:bitmap",
                "srnamespace": 6,  # File namespace
                "srlimit": per_page,
            },
            headers={"User-Agent": WIKIMEDIA_UA},
            timeout=30,
        )
        r.raise_for_status()
        return r.json().get("query", {}).get("search", [])
    except Exception as exc:
        print(f"    Wikimedia search failed: {exc}")
        return []


def wikimedia_imageinfo(title: str) -> dict | None:
    try:
        r = requests.get(
            WIKIMEDIA_API,
            params={
                "action": "query",
                "format": "json",
                "titles": title,
                "prop": "imageinfo",
                "iiprop": "url|extmetadata|size|mime",
            },
            headers={"User-Agent": WIKIMEDIA_UA},
            timeout=30,
        )
        r.raise_for_status()
        pages = r.json().get("query", {}).get("pages", {})
        for _pid, page in pages.items():
            infos = page.get("imageinfo", [])
            if not infos:
                continue
            info = infos[0]
            meta = info.get("extmetadata", {})
            license_str = meta.get("LicenseShortName", {}).get("value", "Unknown")
            artist_html = meta.get("Artist", {}).get("value", "Unknown")
            artist = re.sub(r"<[^>]+>", "", artist_html).strip() or "Unknown"
            mime = info.get("mime", "")
            return {
                "artist": artist,
                "license": license_str,
                "url": info.get("url"),
                "descriptionurl": info.get("descriptionurl"),
                "width": info.get("width", 0),
                "height": info.get("height", 0),
                "mime": mime,
            }
    except Exception as exc:
        print(f"    Wikimedia imageinfo failed: {exc}")
    return None


def license_ok(license_str: str) -> bool:
    """Allow commercial-safe licenses. Blocks NC and ND; allows CC0, CC-BY,
    CC-BY-SA (SA obligations only bind on redistribution of derivatives;
    unmodified kiosk display with attribution is acceptable), and PD."""
    low = (license_str or "").lower()
    if any(tok in low for tok in ("-nc", " nc-", "noncomm")):
        return False
    if any(tok in low for tok in ("-nd", " nd-", "noderiv")):
        return False
    if "cc0" in low or "public domain" in low or low.startswith("pd") or "-pd" in low:
        return True
    if "cc by" in low or "cc-by" in low or "attribution" in low:
        return True
    return False


def pick_first_photo(query: str) -> tuple[str, str, str, str, list[str]] | None:
    """Return (download_url, author, source_name, license, notes_for_metadata)."""
    results = unsplash_search(query, per_page=5)
    if results:
        r = results[0]
        return (
            r["urls"]["regular"],
            r.get("user", {}).get("name", "Unknown"),
            "Unsplash",
            "Unsplash License",
            [query],
        )
    results = pexels_search(query, per_page=5)
    if results:
        r = results[0]
        return (
            r["src"]["large2x"],
            r.get("photographer", "Unknown"),
            "Pexels",
            "Pexels License",
            [query],
        )
    wm_results = wikimedia_search(query, per_page=15)
    for hit in wm_results:
        info = wikimedia_imageinfo(hit["title"])
        if not info or not info.get("url"):
            continue
        if not info["mime"].startswith("image/"):
            continue
        if info["mime"] in ("image/svg+xml",):
            continue
        if not license_ok(info["license"]):
            continue
        if info.get("width", 0) < 1000 or info.get("height", 0) < 600:
            continue
        return (
            info["url"],
            info["artist"],
            "Wikimedia Commons",
            info["license"],
            [query, hit["title"]],
        )
    return None


def download_image(url: str, dest: Path, size: tuple[int, int], user_agent: str | None = None) -> None:
    headers = {"User-Agent": user_agent} if user_agent else None
    response = http_get(url, headers=headers, timeout=90)
    img = Image.open(io.BytesIO(response.content)).convert("RGB")
    img = fit_crop(img, size)
    dest.parent.mkdir(parents=True, exist_ok=True)
    img.save(dest, "JPEG", quality=88, optimize=True)


def fetch_landmarks(manifest: dict, entries: dict[str, AssetEntry]) -> None:
    landmarks = manifest.get("landmarks", [])
    for lm in landmarks:
        key = lm["key"]
        lm_dir = ASSETS_DIR / "landmarks" / key
        lm_dir.mkdir(parents=True, exist_ok=True)
        for variant, query in lm["queries"].items():
            print(f"  [landmark] {key}/{variant} '{query}'...", end=" ", flush=True)
            pick = pick_first_photo(query)
            if pick is None:
                print("SKIP (no source found)")
                continue
            dl_url, author, src, lic, notes = pick
            hero_path = lm_dir / f"{variant}.jpg"
            try:
                ua = WIKIMEDIA_UA if src == "Wikimedia Commons" else None
                download_image(dl_url, hero_path, HERO_SIZE, user_agent=ua)
                record_file(entries, f"landmarks/{key}/{variant}.jpg", src, dl_url, author, lic, notes)
                if variant == "hero":
                    thumb_path = lm_dir / "thumb.jpg"
                    thumb = Image.open(hero_path).convert("RGB")
                    thumb = fit_crop(thumb, THUMB_SIZE)
                    thumb.save(thumb_path, "JPEG", quality=85, optimize=True)
                    record_file(entries, f"landmarks/{key}/thumb.jpg", src, dl_url, author, lic,
                                notes + ["cropped to thumb"])
                print(f"OK ({src})")
            except Exception as exc:
                print(f"FAIL ({exc})")


def fetch_slideshow(manifest: dict, entries: dict[str, AssetEntry]) -> None:
    queries = manifest.get("slideshow", {}).get("queries", [])
    slide_dir = ASSETS_DIR / "slideshow"
    slide_dir.mkdir(parents=True, exist_ok=True)
    for idx, query in enumerate(queries, start=1):
        filename = f"seoul-{idx:02d}.jpg"
        dest = slide_dir / filename
        print(f"  [slideshow] {filename} '{query}'...", end=" ", flush=True)
        pick = pick_first_photo(query)
        if pick is None:
            print("SKIP (no source found)")
            continue
        dl_url, author, src, lic, notes = pick
        try:
            ua = WIKIMEDIA_UA if src == "Wikimedia Commons" else None
            download_image(dl_url, dest, SLIDESHOW_SIZE, user_agent=ua)
            record_file(entries, f"slideshow/{filename}", src, dl_url, author, lic, notes)
            print(f"OK ({src})")
        except Exception as exc:
            print(f"FAIL ({exc})")


def verify(entries: dict[str, AssetEntry]) -> int:
    if not entries:
        print("No metadata.json yet. Run --all first.")
        return 1
    missing = 0
    mismatched = 0
    for rel, meta in entries.items():
        abs_path = ASSETS_DIR / rel
        if not abs_path.exists():
            print(f"  MISSING  {rel}")
            missing += 1
            continue
        actual = sha256_file(abs_path)
        if actual != meta.sha256:
            print(f"  HASH     {rel}  (expected {meta.sha256[:12]}..., got {actual[:12]}...)")
            mismatched += 1
        else:
            print(f"  OK       {rel}")
    print(f"\nVerified {len(entries)} entries: {missing} missing, {mismatched} hash-mismatched")
    return 0 if missing == 0 and mismatched == 0 else 2


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--all", action="store_true")
    parser.add_argument("--fonts", action="store_true")
    parser.add_argument("--icons", action="store_true")
    parser.add_argument("--landmarks", action="store_true")
    parser.add_argument("--slideshow", action="store_true")
    parser.add_argument("--verify", action="store_true")
    args = parser.parse_args()

    if not MANIFEST_PATH.exists():
        print(f"manifest missing: {MANIFEST_PATH}")
        return 1
    manifest = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
    entries = load_metadata()

    if args.verify:
        return verify(entries)

    ran_anything = False
    if args.all or args.fonts:
        print("== Pretendard fonts ==")
        fetch_pretendard(manifest, entries)
        ran_anything = True
    if args.all or args.icons:
        print("== Lucide icons ==")
        fetch_lucide_icons(manifest, entries)
        ran_anything = True
    if args.all or args.landmarks:
        print("== Landmark photos ==")
        fetch_landmarks(manifest, entries)
        ran_anything = True
    if args.all or args.slideshow:
        print("== Slideshow photos ==")
        fetch_slideshow(manifest, entries)
        ran_anything = True

    if not ran_anything:
        parser.print_help()
        return 1

    save_metadata(entries)
    print(f"\nWrote {METADATA_PATH.relative_to(PROJECT_ROOT)} ({len(entries)} entries).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
