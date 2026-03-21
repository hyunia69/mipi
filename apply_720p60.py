#!/usr/bin/env python3
"""
720p60 Device Tree Overlay Patch for LT9211C
Oppila explicitly supports 720p60 LVDS input.
720p60 Single LVDS: TCLK = 74.25 MHz (well within receiver range)

Usage: sudo python3 apply_720p60.py
"""
import subprocess
import shutil
import os
import sys

DTBO_PATH = "/boot/tegra234-p3767-camera-p3768-imx219-C.dtbo"
BACKUP_PATH = DTBO_PATH + ".bak.1080p60"

# 720p60 standard timing (SMPTE 296M / CEA-861)
# Total: 1650 x 750, Active: 1280 x 720, Pixel clock: 74.25 MHz
PATCHES = {
    # Current 1080p60 values -> 720p60 values
    b'"1920"':       b'"1280"',       # active_w
    b'"1080"':       b'"720"',        # active_h
    b'"148400000"':  b'"74250000"',   # pix_clk_hz (74.25 MHz)
    b'"2500"':       b'"1650"',       # line_length (720p60 standard)
    b'"16667"':      b'"16667"',      # default_exp_time (keep same)
    b'"24"':         b'"9"',          # mclk_multiplier (74.25/8.25 ~= 9)
}

def main():
    if os.geteuid() != 0:
        print("ERROR: Run with sudo")
        sys.exit(1)

    # Read current dtbo
    with open(DTBO_PATH, "rb") as f:
        data = f.read()

    print(f"Original DTBO size: {len(data)} bytes")

    # Verify current values exist
    if b'"148400000"' not in data:
        print("WARNING: pix_clk_hz '148400000' not found - may already be patched")
        print("To restore: sudo cp {} {}".format(BACKUP_PATH, DTBO_PATH))
        sys.exit(1)

    # Backup
    if not os.path.exists(BACKUP_PATH):
        shutil.copy2(DTBO_PATH, BACKUP_PATH)
        print(f"Backup created: {BACKUP_PATH}")
    else:
        print(f"Backup already exists: {BACKUP_PATH}")

    # Apply patches
    patched = data
    for old, new in PATCHES.items():
        if old == new:
            continue
        count = patched.count(old)
        if count == 0:
            print(f"  SKIP: {old} not found")
            continue
        patched = patched.replace(old, new)
        print(f"  PATCH: {old} -> {new} ({count} occurrence(s))")

    # Handle size difference (DT strings must maintain alignment)
    # "1920" (4 chars) -> "1280" (4 chars) OK
    # "1080" (4 chars) -> "720"  (3 chars) - need padding!
    # Actually in FDT, strings include null terminator and may need same length
    # Let's use "0720" to maintain 4 chars
    if b'"720"' in patched and b'"1080"' in data:
        # Re-read and use zero-padded value
        patched = data
        patches_fixed = {
            b'"1920"':       b'"1280"',
            b'"1080"':       b'"0720"',       # zero-padded to maintain length
            b'"148400000"':  b'"074250000"',   # zero-padded to maintain length
            b'"2500"':       b'"1650"',
            b'"24"':         b'"09"',          # zero-padded
        }
        for old, new in patches_fixed.items():
            if old == new:
                continue
            count = patched.count(old)
            if count == 0:
                print(f"  SKIP: {old} not found")
                continue
            patched = patched.replace(old, new)
            print(f"  PATCH: {old} -> {new} ({count} occurrence(s))")

    if len(patched) != len(data):
        print(f"WARNING: Size changed {len(data)} -> {len(patched)}")
        print("DT overlay size must remain constant. Adjusting...")
        # This means our string replacements changed the size
        # Need to ensure same-length replacements
        print("ERROR: Cannot safely patch - string length mismatch")
        sys.exit(1)

    # Write patched dtbo
    with open(DTBO_PATH, "wb") as f:
        f.write(patched)

    print(f"\nPatched DTBO written: {len(patched)} bytes")
    print("\n=== 720p60 Settings Applied ===")
    print("  active_w:      1280")
    print("  active_h:      720")
    print("  pix_clk_hz:    74250000")
    print("  line_length:   1650")
    print("  max_framerate:  60000000 (unchanged)")
    print("\nReboot required: sudo reboot")
    print("To restore: sudo cp {} {}".format(BACKUP_PATH, DTBO_PATH))

if __name__ == "__main__":
    main()
