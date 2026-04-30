"""Wiring tests for main.py avatar integration.

We do NOT launch the GUI; we test that:
  - argparse exposes --no-avatar and --avatar-repeat-ms
  - compute_avatar_props correctly returns enable/disable based on filesystem + flags
  - start_avatar_server starts and serves on 127.0.0.1
"""
from __future__ import annotations

import sys
import urllib.request
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
    # URL is set (could be file:// or http:// depending on implementation)
    assert props["AVATAR_URL"]


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


def test_start_avatar_server_serves_index_html(tmp_path):
    """start_avatar_server should serve files from a directory and stop cleanly."""
    web = tmp_path / "avatar"
    web.mkdir()
    (web / "index.html").write_text("<!doctype html><title>ok</title>")
    server = main.start_avatar_server(web)
    try:
        url = server["url"]
        assert url.startswith("http://127.0.0.1:")
        body = urllib.request.urlopen(url, timeout=2).read().decode("utf-8")
        assert "ok" in body
    finally:
        server["stop"]()
