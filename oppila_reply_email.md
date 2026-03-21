Subject: RE: LVDS-MIPI Bridge Board - Comprehensive Test Results & Remaining Green Screen Issue

Dear Oppila Support Team,

Thank you for your previous responses. Based on your answers, we have conducted extensive testing and made significant progress. However, the green screen issue persists despite matching all known parameters. We need your assistance to resolve the remaining problem.

## Our Setup

- **Host Platform**: NVIDIA Jetson Orin Nano Super Developer Kit
- **Adapter Board**: Oppila LVDS-MIPI Bridge Board (LT9211C)
- **Camera**: KT&C ATC-HZ5540T-LP (1/2.9" 1.58MP Global Shutter CMOS, 40x Optical Zoom)
- **L4T Version**: R36.4.4 (Kernel 5.15.148-tegra)
- **Firmware**: Custom image `ORIN_NX_IMAGE.tar.bz2` flashed via `nvsdkmanager_flash.sh`
- **CSI Configuration**: CAM1, IMX219-C pin config via `jetson-io.py`
- **Flashing Host PC**: Ubuntu 22.04.5 LTS, SDK Manager 2.3.0.12617 (Electron 13.6.9, Chrome 91.0.4472.164, Node.js 14.16.0, x86_64)

## Progress Since Last Email

### 1. VISCA Communication — Working Successfully

We fixed two issues in the provided `uart.py` script and established full VISCA communication:

**Issues found in `uart.py`:**
- **Line 15 syntax error**: A comment was merged with the code (`ony FCB-EV cameraswrite_reg(...)`)
- **Baud rate divisor**: The script used `0x5B` (91), but the correct value for 9600 baud with a 14.7456 MHz crystal is `0x60` (96). The calculation: 14,745,600 / (16 x 96) = 9,600 baud.
- **Missing VISCA initialization**: Address Set (`88 30 01 FF`) and IF Clear (`88 01 00 01 FF`) were not called before sending commands.

After fixing these issues, VISCA communication works correctly:
- **SC16IS752** responds at I2C bus 9, address 0x48
- **Camera Version**: Vendor 0x5568 (KT&C), Model 0x046F
- **Commands verified**: Address Set, IF Clear, Zoom Tele/Wide, Power Inquiry, Focus Mode — all return proper ACK + Completion responses

### 2. Camera Default Output Format — Was 1080p/30 (Not 1080p/60)

Using `CAM_RegisterValue` inquiry (`81 09 04 24 72 FF`), we discovered:

> **Register 0x72 (Monitoring Mode) = 0x07 → 1080p/30**

The KT&C camera's **factory default output is 1080p/30**, not 1080p/60. This does not match your driver, which is configured for 1080p/60.

**Note**: The standard Sony VISCA `Video Format Set` command (`06 35`) is not supported by this KT&C camera (returns Syntax Error). Format changes must be done via `CAM_RegisterValue` (Register 0x72).

### 3. LVDS Mode — Was Single (Not Dual)

Using `CAM_RegisterValue` inquiry for Register 0x74:

> **Register 0x74 (LVDS Mode) = 0x00 → Single LVDS**

Sony FCB-EV cameras typically use **Dual LVDS for 1080p60** (8 data pairs). The KT&C camera defaults to **Single LVDS** (4 data pairs), which is likely insufficient bandwidth for 1080p60 and may not match your bridge board's expected input configuration.

### 4. All Test Combinations — Green Screen Persists

We systematically tested every combination of camera output format, LVDS mode, and Device Tree configuration:

| Test | Camera Output | LVDS Mode | DT (CSI) Config | Result |
|------|--------------|-----------|-----------------|--------|
| 1 | 1080p/30 (default) | Single (default) | 60fps (original) | Green screen, `uncorr_err: request timed out` |
| 2 | 1080p/30 | Single | 30fps (modified DT) | Green screen, "Signal lost" |
| 3 | 1080p/60 (changed) | Single | 60fps (original) | Green screen, "Signal lost" |
| 4 | 1080p/60 | Single | 60fps + driver reload | Green screen, "Signal lost" |
| **5** | **1080p/60** | **Dual** | **60fps + driver reload** | **Green screen, "Signal lost"** |

**In Test 5, the camera is configured identically to a Sony FCB-EV camera: 1080p/60 + Dual LVDS.** Yet the green screen persists.

All camera settings were confirmed via VISCA register readback and saved to Custom Preset (persistent across power cycles).

### 5. I2C Bus Scan Results

```
i2cdetect -y -r 9:
     0  1  2  3  4  5  6  7  8  9  a  b  c  d  e  f
00:                         -- -- -- -- -- -- -- --
10: UU -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
20: -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
30: -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
40: -- -- -- -- -- -- -- -- 48 -- -- -- -- -- -- --
...
```

- **0x10 = UU** (LT9211C sensor driver, in use by kernel)
- **0x48** (SC16IS752 I2C-UART bridge, working)
- **0x2D = NOT DETECTED** — Your Device Tree defines `lt9211@2d` with `compatible = "lontium,lt9211c"` and `status = "okay"`, but this address does not respond on the I2C bus.

## Questions

1. **Is address 0x2D expected to be absent from `i2cdetect`?** The Device Tree has `lt9211@2d` defined as "okay" with reset-gpios, but no device responds at this address. Could this indicate a hardware initialization issue with the LT9211C?

2. **Have you successfully tested video output with a Sony FCB-EV camera on this specific board?** We want to confirm the board itself is functioning correctly. If you have a working reference setup, could you share the exact camera model and configuration used?

3. **What LVDS input mode does the LT9211C expect?** Specifically:
   - Single LVDS (4 data pairs) or Dual LVDS (8 data pairs)?
   - JEIDA or VESA bit mapping?
   - What pixel clock frequency does it expect?

4. **Can you share the LT9211C register initialization sequence** or the `lt9211cmipi.ko` driver source code? We need to verify that the LT9211C's LVDS receiver is properly configured for the incoming signal. When we attempted to read LT9211C registers via I2C (address 0x10, with force flag), we received I/O errors.

5. **Is there a known compatibility issue between KT&C cameras and your board?** Your product page lists KT&C as a compatible brand, but the KT&C ATC-HZ5540T-LP uses a different VISCA command set than Sony (e.g., `CAM_RegisterValue` instead of `Video Format Set`). Are there other differences in the LVDS output format that might affect compatibility?

6. **Could this be a cable issue?** We note that VISCA uses pins 12-13 (low-speed TTL serial) while LVDS uses pins 1-10 and 21-30 (high-speed differential pairs). VISCA working does not guarantee LVDS signal integrity. Should we try a different 30-pin micro-coaxial cable?

## Current System State

- **DT Overlay**: Original 60fps configuration (restored)
- **Camera**: 1080p/60, Dual LVDS (changed from factory defaults via VISCA, saved to Custom Preset)
- **Driver**: `lt9211cmipi.ko` v2.0.6 loaded, detects sensor at 0x10

## Requested Information from Oppila

| # | Request | Priority |
|---|---------|----------|
| 1 | Confirm working reference setup (camera model + configuration) | HIGH |
| 2 | Explain LT9211C address 0x2D absence on I2C bus | HIGH |
| 3 | LT9211C LVDS input configuration details (Single/Dual, JEIDA/VESA) | HIGH |
| 4 | Driver source or LT9211C register init sequence | MEDIUM |
| 5 | Cable replacement recommendation if applicable | MEDIUM |

We have invested significant effort in diagnosing this issue and have eliminated camera-side configuration as the cause. We believe the problem lies in the LT9211C bridge chip initialization or LVDS signal path. Your guidance would be greatly appreciated.

Thank you for your continued support.

Best regards,
Hyun
