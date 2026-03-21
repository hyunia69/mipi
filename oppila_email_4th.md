Subject: RE: LVDS-MIPI Bridge Board - LT9211C Timing Sync & Gray Image Issue

Dear Kamalesh,

Following your guide, we captured the LT9211C debug log from the TP2 UART test point. We powered on the MIPI board, waited 10 seconds, then pressed K2 and K3 buttons in sequence.

We found that the timing detection is inconsistent — sometimes it fails, sometimes it succeeds. When it succeeds, we can receive video on the Jetson, but the image has a problem. Details below.

## 1. LT9211C Debug Log (Correct Timing)

When the timing is detected correctly, the log shows proper 1920x1080 values:

```
[INFO ] LT9211C Feb 05 2025 20:23:30
[INFO ] LT9211C Chip ID: 0x21 0x03 0xe1
[INFO ] LT9211C Code Version: U2
[DEBUG] RxState = 0x02
[DEBUG] TxState = 0x02
[INFO ] LVDS Input PortA
[DEBUG] RxState = 0x03
[INFO ] LVDS RX Config
[INFO ] Data Format: VESA
[INFO ] Mode: sync
[INFO ] ColorSpace: YUV422
[INFO ] ColorDepth: 8Bit
[INFO ] LaneNum: 4Lane
[INFO ] Lvds Sync Code Mode: Internal
[INFO ] Lvds Video Format: Progressive
[INFO ] Lvds Sync Code Send: Non-respectively.
[DEBUG] RxState = 0x04
[DEBUG] RxState = 0x05
[INFO ] RXPLL_FM_CLK_DET Stable
[INFO ] RXPLL_FM_FREQ_IN_KHZ: 148496
[INFO ] Rx Pll Lock
[INFO ] sync_polarity = 0x0f
[INFO ] hfp, hs, hbp, hact, htotal = 88 44 148 1920 2200
[INFO ] vfp, vs, vbp, vact, vtotal = 4 5 36 1080 1125
[DEBUG] RxState = 0x06
[DEBUG] TxState = 0x03
[DEBUG] burst:0x01
[INFO ] FM CLOCK DET Stable
[DEBUG] ulMipiDataRate:713984, ulHalfPixClk:74248, ulMpiTXPhyClk:713984, ucBpp:16, ucTxPortNum:0x01, ucTxLaneNum:0x04
[DEBUG] ucSericlkDiv N1:0x01, ucDivSet M2:0x1c
[INFO ] Tx Pll Lock
[INFO ] MIPI Output PortA & B
[INFO ] FM CLOCK DET Stable
[DEBUG] byteclk: 87M
[DEBUG] ck_post (0xD4A9) = 0x0d
[DEBUG] ck_zero (0xD4A7) = 0x14
[DEBUG] hs_lpx  (0xD4A4) = 0x06
[DEBUG] hs_prep (0xD4A5) = 0x05
[DEBUG] hs_trail(0xD4A6) = 0x0a
[DEBUG] hs_rqst (0xD48A) = 0x21
[INFO ] MipiTx Output Format: YUV422 8bit
[DEBUG] rddly is 0x0094;
[DEBUG] TxState = 0x04
[INFO ] Finish initial panel
[INFO ] Mipi CSI Out
[DEBUG] TxState = 0x05
```

Note: On some attempts, the timing detection fails with wrong values (hact=14360, vact=1, rddly=0x13da) instead of the correct values above. This happens inconsistently with the same procedure.

## 2. Jetson Capture Test Result (With Correct Timing)

When the LT9211C timing is correct (1920x1080), we ran a capture test on the Jetson:

**V4L2 device status:**
```
Driver name      : tegra-video
Card type        : vi-output, lt9211cmipi 9-0010
Width/Height     : 1920/1080
Pixel Format     : 'UYVY' (UYVY 4:2:2)
Frames per second: 60.000 (60/1)
```

**GStreamer pipeline used:**
```
gst-launch-1.0 v4l2src device=/dev/video0 \
  ! video/x-raw,format=UYVY,width=1920,height=1080 \
  ! videoconvert ! xvimagesink
```

**Result:**
- No "Signal lost" warning, no dmesg errors
- The video stream runs without timeout errors
- However, the **image appears as a uniform gray with very faint, blurry movement visible**
- We also sent VISCA Auto Focus, Auto Exposure, and Auto White Balance commands to the camera — all acknowledged successfully, but the image remains gray and blurry

**Captured image:** attached (quick_capture_20260311_220659.jpg)

## 3. Questions

1. The timing detection is inconsistent between attempts (correct 1920x1080 vs incorrect 14360x1). What could cause this?
2. When timing is correct, we receive video but the image is gray and blurry. Could this be a color space or data format issue in the MIPI output?
3. Is there anything we should adjust or check on our side?

Best regards,
Hyun
