Subject: LVDS-MIPI Bridge Board - Green Screen Issue with KT&C Camera + VISCA Bridge Not Working

Dear Oppila Support Team,

We recently purchased your LVDS → MIPI CSI-2 Bridge Board and have been following your setup guide to integrate it with our system. We are experiencing several issues and would greatly appreciate your assistance.

## Our Setup

- **Host Platform**: NVIDIA Jetson Orin Nano Super Developer Kit
- **Adapter Board**: Oppila LVDS-MIPI Bridge Board (LT9211C)
- **Camera**: KT&C ATC-HZ5540T-LP (LVDS block camera, 30-pin micro coaxial, same pinout as Sony FCB-EV)
- **Firmware**: Custom image `ORIN_NX_IMAGE.tar.bz2` flashed via `nvsdkmanager_flash.sh`
- **L4T Version**: R36.4.4
- **CSI Connector**: CAM1 (24-pin CSI)
- **CSI Pin Configuration**: IMX219-C (via `jetson-io.py`)

## Issue 1: Green Screen — No Video from Camera (PRIMARY)

After completing all setup steps (flashing, CSI pin configuration, running `rc.local`), we get a **green screen** when attempting to view the camera feed:

```
gst-launch-1.0 v4l2src device=/dev/video0 ! "video/x-raw,format=UYVY,width=1920,height=1080" ! videoconvert ! xvimagesink
```

**What works:**
- The LT9211C driver loads successfully: `detected lt9211cmipi sensor`
- LT9211C is detected on I2C bus 9, address 0x10
- `/dev/video0` is created and accessible
- v4l2 reports supported format: UYVY 1920x1080 @ 60fps
- The camera powers on through the adapter board (audible click from IR filter/lens initialization)
- `rc.local` executes successfully (clock rates applied)

**What fails:**
- The VI engine continuously reports: `uncorr_err: request timed out after 2500 ms`
- No actual video frames are received — only green screen

**Our analysis:**
The v4l2 driver only lists **1080p @ 60fps**. The KT&C camera's default output format may be **1080p30**, which has a different LVDS pixel clock (74.25 MHz vs 148.5 MHz for 1080p60). If the LT9211C is configured only for 1080p60 input, a 1080p30 signal from the camera would not be recognized.

**Questions:**
1. Does the bridge board / LT9211C support LVDS input at resolutions other than 1080p60 (e.g., 1080p30, 720p60)?
2. If the camera outputs 1080p30 by default, how can we configure the LT9211C to accept it?
3. Is there a register map or configuration guide for the LT9211C on your board?
4. Have you tested with any KT&C cameras? The ATC-HZ5540T-LP uses the same 30-pin micro coaxial connector and pinout as Sony FCB-EV cameras.

## Issue 2: I2C-to-UART Bridge (VISCA) Not Functional

Your product specification states that the board includes an **I2C-to-UART bridge for VISCA camera control**. We need VISCA communication to:
- Change the camera's output format to 1080p60
- Control zoom, focus, and other camera functions

However, we cannot find the I2C-UART bridge on the I2C bus:

- `i2cdetect -y -a 9` shows only the LT9211C at 0x10 — no UART bridge device
- Scanned all I2C buses (1, 2, 5, 7, 9, 10, 11) at addresses 0x48–0x4F (common SC16IS7xx range) — no device found
- No `sc16is7xx` kernel module is present in the custom image
- No `/dev/ttySC*` serial device exists
- No Device Tree entry for an I2C-UART bridge was found

**Questions:**
1. What is the I2C-to-UART bridge chip model on your board? (e.g., NXP SC16IS750?)
2. What I2C bus and address should the bridge be on?
3. Does the custom image (`ORIN_NX_IMAGE.tar.bz2`) include the driver and Device Tree configuration for the I2C-UART bridge? If not, how do we enable it?
4. Can you provide a Device Tree overlay snippet and/or kernel module for the bridge?
5. Is there example code for sending VISCA commands through the bridge?

## Additional Issues (Lower Priority)

### OEM Configuration Repeats on Every Reboot

After flashing and completing the initial OEM setup (license agreement, keyboard settings, etc.), the OEM configuration wizard **runs again on every reboot**. We had to manually run `sudo systemctl disable oem-config.service` to stop it. Is this expected behavior with the custom image?

### Empty Desktop After Setup

After completing the OEM setup, the desktop appears but is **completely empty** — no application icons, no dock, no file manager. Only the top bar with the power button is visible. Is this the expected state of the custom image, or is there an additional setup step we are missing?

## Summary of Requests

| # | Request | Priority |
|---|---------|----------|
| 1 | How to resolve green screen with KT&C camera (1080p30 vs 1080p60 mismatch?) | HIGH |
| 2 | I2C-UART bridge chip model, I2C address, and driver/DT configuration | HIGH |
| 3 | VISCA control example code for your bridge board | MEDIUM |
| 4 | OEM config repeating on reboot — expected behavior? | LOW |
| 5 | Empty desktop after setup — expected behavior? | LOW |

We would be very grateful for any documentation, configuration files, or guidance you can provide. We are happy to share additional logs or diagnostic information if needed.

Thank you for your support.

Best regards,
[Your Name]
[Your Company]
[Your Email]
