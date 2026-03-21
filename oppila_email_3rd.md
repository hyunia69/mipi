Subject: RE: LVDS-MIPI Bridge Board - Datasheet Comparison & Complete Test Results

Dear Kamalesh,

Thank you for your previous response and the Sony FCB-EV9520L datasheet.

Have you had a chance to review the KT&C ATC-HZ5540T-LP datasheet that we sent previously? We compared it briefly with the Sony FCB-EV9520L datasheet and found no significant differences at the LVDS interface level, as shown in the table below. However, this was only a preliminary check on our part — we would appreciate it if you could examine the KT&C datasheet in detail from your expertise, as there may be subtle differences that we are not able to identify.

Since our last email, we have done two things: a detailed datasheet comparison and a complete re-test of all possible combinations.

## 1. Datasheet Comparison: KT&C vs Sony FCB-EV9520L

We compared the KT&C ATC-HZ5540T-LP datasheet against the Sony FCB-EV9520L datasheet you provided. The results show that both cameras are electrically identical at the LVDS interface level:

| Parameter | KT&C ATC-HZ5540T-LP | Sony FCB-EV9520L (p.70) | Match |
|-----------|---------------------|------------------------|:-----:|
| Connector | USL00-30L-C (KEL) | USL00-30L-C (KEL) | YES |
| Pin 1-10 | Single LVDS (OUT0-3 + CLK) | Single LVDS (OUT0-3 + CLK) | YES |
| Pin 12-13 | TXD / RXD | TxD / RxD | YES |
| Pin 14-18 | +12V DC | DC IN (7-12V) | YES |
| Pin 21-30 | Dual LVDS (open in Single) | Dual LVDS (open in Single) | YES |
| LVDS TX format | THC63LVD827 (THINE) | THC63LVD compatible | YES |
| Recommended RX IC | THC63LVD104C / THC63LVD1024 | THC63LVD104C / THC63LVD1024 | YES |
| Pixel data | Y[7:0], C[7:0], 4:2:2 | Y, Pb, Pr 4:2:2 (BT.709) | YES |
| Pixel clock (1080p60) | 148.5 MHz | 148.5 MHz | YES |
| Pixel clock (1080p30) | 74.25 MHz | 74.25 MHz | YES |
| Pixel clock (720p60) | 74.25 MHz | 74.25 MHz | YES |

The connector pinout was verified against p.70 of the Sony datasheet (the actual camera output connector table), not the receiver circuit example on p.61.

## 2. Complete Test Results (6 Combinations)

We systematically tested all combinations of camera output format, LVDS mode, and Device Tree settings. Each camera setting was verified via VISCA register readback before capture.

| Test | Camera Output | LVDS Mode | DT Settings | Result |
|:----:|--------------|-----------|-------------|:------:|
| 1 | 1080p/30 (Reg72=0x07) | Single | 1080p, 60fps, 148.4MHz | Signal lost, uncorr_err |
| 2 | 1080p/60 (Reg72=0x13) | Single | 1080p, 60fps, 148.4MHz | Signal lost, uncorr_err |
| 3 | 1080p/60 (Reg72=0x13) | Dual | 1080p, 60fps, 148.4MHz | Signal lost, uncorr_err |
| 4 | 1080p/30 (Reg72=0x07) | Single | 1080p, 30fps, 74.25MHz | Signal lost, uncorr_err |
| 5 | 720p/60 (Reg72=0x09) | Single | 720p, 60fps, 74.25MHz | Signal lost |
| 6 | 720p/30 (Reg72=0x0F) | Single | 720p, 60fps, 74.25MHz | Signal lost |

All 6 tests show the same "Signal lost" warning — the LT9211C does not detect any valid LVDS input from the KT&C camera, regardless of format, resolution, or frame rate.

## Your Opinion

Given that our comparison shows identical LVDS specifications, yet the bridge board does not recognize the KT&C camera's signal in any configuration, we would like to hear your opinion on:

- What could be causing this incompatibility despite the matching specifications?
- What would you recommend as the next step to resolve this?

We are open to any suggestion, including sending the camera module for evaluation if needed.

Best regards,
Hyun
