# 카메라 영상 정상 출력 성공 기록

- **작성일**: 2026-03-18 21:41 KST
- **상태**: 카메라 영상 정상 출력 확인 (Full Screen, 선명한 화면)

---

## 1. 현재 동작 상태 요약

| 항목 | 상태 |
|------|------|
| **영상 출력** | 정상 (전체 화면 출력, 선명) |
| **해상도** | 1920x1080 @ 60fps |
| **픽셀 포맷** | UYVY (YUV 4:2:2) |
| **카메라 전원** | ON |
| **VISCA 통신** | 정상 |
| **LT9211C** | LVDS Lock 성공, MIPI CSI Out 활성 |

---

## 2. 영상 출력 성공을 위한 필수 절차 (순서 중요)

### Step 1: 카메라 + MIPI 보드 전원 ON

카메라와 LT9211C MIPI 보드에 전원을 공급한다. LT9211C가 LVDS 신호를 Lock하는 데 수 초~수십 초 걸릴 수 있다.

LT9211C 정상 Lock 시 TP2 UART 로그에서 다음 값이 확인되어야 한다:
```
[INFO ] RXPLL_FM_FREQ_IN_KHZ: 148496
[INFO ] Rx Pll Lock
[INFO ] hfp, hs, hbp, hact, htotal = 88 44 148 1920 2200
[INFO ] vfp, vs, vbp, vact, vtotal = 4 5 36 1080 1125
[INFO ] Tx Pll Lock
[INFO ] Mipi CSI Out
```

**주의**: 초기 부팅 시 `RXPLL_FM_FREQ_IN_KHZ: 0`으로 여러 차례 실패 후 Lock되는 것이 정상이다. K2, K3 버튼을 순서대로 눌러 리셋하면 Lock 성공률이 높아진다.

### Step 2: rc.local 실행 (클럭 최대값 고정)

```bash
sudo bash /home/hyunia/work/mipi/rc.local
```

이 스크립트는 vi/isp/nvcsi/emc 클럭을 최대값으로 고정한다. **이 단계를 건너뛰면 영상이 나오지 않는다.**

정상 출력:
```
550400000   (vi: 550.4 MHz)
729600000   (isp: 729.6 MHz)
214300000   (nvcsi: 214.3 MHz)
3199000000  (emc: 3,199 MHz)
```

`/sys/kernel/debug/camrtc/log-level: No such file or directory` 경고는 무시해도 된다.

### Step 3: 영상 출력 확인

```bash
python3 /home/hyunia/work/mipi/view_camera.py
```

또는 GStreamer 직접 실행:
```bash
gst-launch-1.0 v4l2src device=/dev/video0 \
  ! 'video/x-raw,format=UYVY,width=1920,height=1080' \
  ! videoconvert ! autovideosink sync=false
```

### Step 4: VISCA 카메라 제어 (필요 시)

영상이 나온 후 초점/줌이 맞지 않으면 아래 명령을 실행한다.

**줌 Wide (최소 줌):**
```bash
python3 -c "
import smbus2, time
bus = smbus2.SMBus(9)
I2C_ADDR = 0x48
def write_reg(s, d): bus.write_byte_data(I2C_ADDR, (s << 3) | 0x00, d)
def read_reg(s): return bus.read_byte_data(I2C_ADDR, (s << 3) | 0x00)
write_reg(0x03, 0x80); write_reg(0x00, 0x60); write_reg(0x01, 0x00)
write_reg(0x03, 0x03); write_reg(0x02, 0x07); time.sleep(0.01); write_reg(0x02, 0x01)
def flush():
    while read_reg(0x05) & 0x01: read_reg(0x00)
def send(cmd, t=1.0):
    flush()
    for b in cmd:
        while not (read_reg(0x05) & 0x20): time.sleep(0.005)
        write_reg(0x00, b)
    time.sleep(t)
    r = []
    while read_reg(0x05) & 0x01: r.append(read_reg(0x00))
    return r
send([0x88, 0x30, 0x01, 0xFF], t=0.3)
send([0x88, 0x01, 0x00, 0x01, 0xFF], t=0.3)
# Zoom Wide
send([0x81, 0x01, 0x04, 0x47, 0x00, 0x00, 0x00, 0x00, 0xFF], t=2.0)
# Auto Focus ON + Trigger
send([0x81, 0x01, 0x04, 0x38, 0x02, 0xFF], t=0.5)
send([0x81, 0x01, 0x04, 0x18, 0x01, 0xFF], t=2.0)
# Auto Exposure ON
send([0x81, 0x01, 0x04, 0x39, 0x00, 0xFF], t=0.5)
# Auto White Balance ON
send([0x81, 0x01, 0x04, 0x35, 0x00, 0xFF], t=0.5)
bus.close()
print('Done')
"
```

---

## 3. 현재 카메라 설정 (VISCA 조회 결과)

| 항목 | VISCA 응답 | 값 |
|------|-----------|-----|
| Video Format (Reg 0x72) | `90 50 01 03 FF` | **0x13 = 1080p/60** |
| LVDS Mode (Reg 0x74) | `90 50 00 00 FF` | **0x00 = Single LVDS** |
| Zoom Position | `90 50 00 00 00 00 FF` | **0x0000 = Wide end (최소 줌)** |
| Focus Mode | `90 50 02 FF` | **0x02 = Auto Focus** |
| Power | `90 50 02 FF` | **0x02 = ON** |
| AE Mode | `90 50 00 FF` | **0x00 = Full Auto** |
| WB Mode | `90 50 00 FF` | **0x00 = Auto** |

---

## 4. V4L2 디바이스 상태

```
Driver name      : tegra-video
Card type        : vi-output, lt9211cmipi 9-0010
Bus info         : platform:tegra-capture-vi:2
Driver version   : 5.15.148
Width/Height     : 1920/1080
Pixel Format     : 'UYVY' (UYVY 4:2:2)
Colorspace       : sRGB
YCbCr Encoding   : ITU-R 601
Quantization     : Limited Range
Frames per second: 60.000 (60/1)
```

---

## 5. 미디어 파이프라인 토폴로지

```
lt9211cmipi 9-0010 (/dev/v4l-subdev1)
  [fmt:UYVY8_1X16/1920x1080@1/60 field:none colorspace:srgb]
    → [ENABLED] →
nvcsi@15a00000 (/dev/v4l-subdev0)
    → [ENABLED] →
vi-output (/dev/video0)
```

모든 링크: ENABLED

---

## 6. I2C 디바이스 상태

```
I2C Bus 9:
  0x10 = UU (LT9211C, 커널 드라이버 사용 중)
  0x48 = SC16IS752 (I2C-UART 브릿지, VISCA 통신용)
```

---

## 7. LT9211C 정상 동작 시 파라미터

| 항목 | 값 |
|------|-----|
| Chip ID | 0x21 0x03 0xe1 |
| Firmware | Feb 05 2025 20:23:30, Code Version U2 |
| LVDS 입력 | PortA, Single, VESA, YUV422, 8Bit, 4Lane, Progressive |
| RX PLL 클럭 | 148,496 KHz (148.5 MHz = 1080p60 정확) |
| 수평 타이밍 | hfp=88, hs=44, hbp=148, hact=1920, htotal=2200 |
| 수직 타이밍 | vfp=4, vs=5, vbp=36, vact=1080, vtotal=1125 |
| MIPI Data Rate | 713,984 kbps |
| MIPI byteclk | 87 MHz |
| TX 출력 | YUV422 8bit, 4Lane, PortA & B |
| MIPI PHY | ck_post=0x0d, ck_zero=0x14, hs_lpx=0x06, hs_prep=0x05, hs_trail=0x0a, hs_rqst=0x21 |

---

## 8. 시스템 구성

| 항목 | 내용 |
|------|------|
| 개발보드 | NVIDIA Jetson Orin Nano Super Developer Kit |
| L4T | R36.4.4 |
| 커널 | 5.15.148-tegra |
| 카메라 | KT&C ATC-HZ5540T-LP (40x Zoom, Global Shutter) |
| 변환보드 | Oppila LVDS-MIPI Bridge Board (LT9211C) |
| CSI 연결 | CAM1 커넥터, 4-lane MIPI CSI-2 |
| 드라이버 | lt9211cmipi.ko v2.0.6 |
| DT Overlay | tegra234-p3767-camera-p3768-imx219-C.dtbo (60fps) |
| UART 브릿지 | NXP SC16IS752IBS,151 (I2C bus 9, addr 0x48, 9600 baud) |

---

## 9. 이전 문제 해결 이력

| 날짜 | 상태 | 원인/조치 |
|------|------|----------|
| 2026-02-26 ~ 03-06 | **녹색 화면** | 카메라 포맷 불일치 (1080p/30 vs DT 60fps), LT9211C LVDS Lock 실패 |
| 2026-03-06 | **Signal lost** | 6가지 조합 테스트 모두 실패, Oppila 벤더와 이메일 교환 |
| 2026-03-11 | **회색 화면** | rc.local 실행 후 LT9211C Lock 성공, 영상 수신 시작 (흐릿) |
| **2026-03-18** | **정상 출력** | rc.local 실행 + Zoom Wide + AF/AE/AWB 활성화로 선명한 영상 확인 |

### 핵심 해결 포인트

1. **카메라 출력 포맷**: 공장 기본 1080p/30 → **1080p/60으로 변경** (VISCA Reg 0x72 = 0x13)
2. **rc.local 실행 필수**: vi/isp/nvcsi/emc 클럭을 최대값으로 고정해야 영상 수신 가능
3. **LT9211C Lock 대기**: 전원 ON 후 LVDS Lock에 시간이 걸림, K2/K3 리셋으로 촉진
4. **VISCA 카메라 제어**: Zoom Wide + Auto Focus + Auto Exposure + Auto WB 설정

---

## 10. 트러블슈팅 가이드

### 영상이 안 나올 때 (녹색/검정 화면)

1. `sudo bash rc.local` 실행했는지 확인
2. LT9211C가 Lock되었는지 TP2 UART 로그 확인 (`RXPLL_FM_FREQ_IN_KHZ: 148496`)
3. Lock 안 되면 K2 → K3 버튼 순서대로 눌러 리셋
4. 여러 번 실패 후 Lock될 수 있음 (정상)

### 영상은 나오지만 흐릿할 때

1. Zoom이 과도하게 들어가 있을 수 있음 → Zoom Wide 명령 전송
2. Auto Focus가 꺼져 있을 수 있음 → AF ON + One Push Trigger
3. Auto Exposure / Auto WB 꺼져 있을 수 있음 → AE/AWB ON

### VISCA 통신이 안 될 때

1. SC16IS752 I2C 주소 0x48 응답 확인: `i2cdetect -y -r 9`
2. UART 초기화 (baud divisor 0x60 = 9600 baud) 확인
3. VISCA Address Set (`88 30 01 FF`) + IF Clear (`88 01 00 01 FF`) 필수

---

## 11. 관련 파일

| 파일 | 용도 |
|------|------|
| `rc.local` | 클럭 초기화 스크립트 (영상 출력 전 필수 실행) |
| `view_camera.py` | GStreamer 영상 출력 스크립트 |
| `quick_check.py` | 카메라 포맷 조회/설정 (VISCA) |
| `visca_autofocus.py` | Auto Focus 제어 |
| `quick_capture_test.sh` | 캡처 테스트 스크립트 |
| `WORK_LOG.md` | 전체 작업 이력 |
| `MIPI_DOCUMENT.md` | 종합 기술 문서 |
