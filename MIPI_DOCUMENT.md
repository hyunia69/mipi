# MIPI Camera Bringup Guide - Jetson Orin Nano + LT9211C Adapter Board

## 프로젝트 현황 요약

**목적**: KT&C ATC-HZ5540T-LP 카메라(LVDS 출력) → Oppila LT9211C 변환보드 → Jetson Orin Nano(MIPI CSI-2 입력) 연결
**최종 목표**: 카메라 영상을 Jetson에서 수신하여 객체 검출(YOLOv8 등) 수행

### 하드웨어 구성

| 구성요소 | 상세 |
|---------|------|
| **카메라** | KT&C ATC-HZ5540T-LP (1/2.9" 1.58MP Global Shutter CMOS, 40x 광학줌) |
| **출력** | LVDS (30-pin 마이크로 동축 커넥터) |
| **변환보드** | Oppila LVDS-MIPI Bridge (LT9211C 칩) |
| **개발보드** | NVIDIA Jetson Orin Nano Super Developer Kit (L4T R36.4.4) |
| **CSI 연결** | CAM1 커넥터 (4-lane MIPI CSI-2) |

### 작업 완료 현황 (~70%)

| 작업 | 상태 | 비고 |
|------|:----:|------|
| Jetson 보드 셋업 및 드라이버 로딩 | ✅ | L4T R36.4.4, lt9211cmipi.ko v2.0.6 |
| VISCA 통신 문제 해결 | ✅ | SC16IS752 I2C-UART 브릿지, baud divisor 수정 |
| 카메라 포맷/LVDS 모드 변경 | ✅ | 1080p/30↔60, Single↔Dual LVDS |
| Device Tree 수정 및 복원 | ✅ | 60fps↔30fps 파라미터 테스트 |
| 종합 진단 스크립트 개발 | ✅ | uart_diag, visca_probe, check_lt9211 등 |
| 기술 문서화 | ✅ | 본 문서 + WORK_LOG.md |
| **영상 캡처 (그린스크린)** | ❌ | **미해결 블로커** |

### 현재 문제: 그린 스크린

**증상**: GStreamer로 캡처 시 초록색 화면만 출력. VI 엔진이 프레임 동기화는 감지하나 실제 픽셀 데이터 없음.

**테스트 조합 (5가지 - 모두 실패)**:

| # | 카메라 출력 | LVDS 모드 | DT 설정 | 결과 | dmesg |
|---|-----------|----------|---------|------|-------|
| 1 | 1080p/30 (공장) | Single (공장) | 60fps (원본) | 그린스크린 | `uncorr_err: request timed out` |
| 2 | 1080p/30 | Single | 30fps (수정) | 그린스크린 | Signal lost |
| 3 | 1080p/60 (변경) | Single | 60fps (원본) | 그린스크린 | Signal lost |
| 4 | 1080p/60 | Single | 60fps + 드라이버 리로드 | 그린스크린 | Signal lost |
| 5 | 1080p/60 | Dual LVDS | 60fps + 드라이버 리로드 | 그린스크린 | Signal lost |

> **테스트 5번 의미**: Sony FCB-EV 레퍼런스 카메라와 동일한 설정임에도 실패

**근본 원인 (데이터시트 분석 + Oppila 2차 응답, 2026-03-06)**:

> **핀아웃은 동일 — 문제는 LT9211C 펌웨어/초기화**

**데이터시트 비교 결과 (Sony p.70 실제 커넥터 핀아웃 확인)**:
- 30핀 커넥터 핀아웃: **KT&C와 Sony 완전 동일** (Single LVDS=Pin 1-10, UART=Pin 12/13, DC=Pin 14-18)
- LVDS 데이터 포맷: **동일** (THC63LVD 시리얼라이제이션, Y/Cb/Cr 4:2:2, BT.709)
- 픽셀 클럭: **동일** (1080p60=148.5MHz, 1080p30=74.25MHz)
- 추천 수신 IC: **동일** (THC63LVD104C/THC63LVD1024)
- LVDS 커넥터: **동일** (KEL USL00-30L-C)

**그렇다면 왜 그린스크린인가? — LT9211C 펌웨어 수준 문제**:
1. **LT9211C 온보드 펌웨어가 Sony 전용 초기화** — 카메라별 초기화 시퀀스/레지스터 설정 차이
2. **LVDS 신호 레벨 차이 가능성** — Sony가 Sub-LVDS(200mV) 사용 시, KT&C 표준 LVDS(350mV)와 전기적 특성 다름
3. **카메라 power-on 시퀀스 차이** — 각 카메라 모듈의 LVDS 출력 안정화 타이밍이 다를 수 있음
4. **LT9211C가 LVDS 신호를 lock하지 못함** — 칩이 입력 신호를 인식하지 못하여 MIPI 출력이 빈 프레임

**보드 확정 스펙 (Oppila 확인)**:
- LVDS 입력: **Single 모드만 지원** (Dual 미지원)
- 타이밍: **VESA** (1080p/60fps)
- 펌웨어: 온보드 마이크로컨트롤러에 내장, Sony FCB-EV9520L/9500L 전용
- **출하 전 Sony FCB-EV9520L로 테스트 완료** → 보드 하드웨어 자체는 정상

**I2C 버스 상태**:
```
I2C Bus 9:
  0x10 = LT9211C (LVDS-MIPI 변환, 커널 드라이버 사용 중) ← 정상
  0x48 = SC16IS752 (I2C-UART 브릿지, VISCA용) ← 정상
  0x2D = LT9211C 제어 주소 ← 미검출 (온보드 MCU 관리로 추정)
```

### Oppila 벤더 대응 상황 (2차 응답 수신)

**1차 응답 확인 사항**:
- 보드는 **1080p30, 720p60** LVDS 입력 지원
- 설정 변경은 **소스 코드 수정** 필요 (공개 API 없음, 향후 API 개발 중)
- SC16IS752 칩 모델: NXP SC16IS752IBS,151
- I2C bus 9, 주소 0x48 (직접 레지스터 프로그래밍)

**2차 응답 핵심 내용** (`oppila_email_response2.txt`):
- **보드 하드웨어 정상** — Sony FCB-EV9520L로 출하 전 테스트 완료
- **Single LVDS 전용** — Sony 데이터시트 기반 설계
- **VESA 타이밍, 1080p/60fps** — 다른 타이밍 사용 시 펌웨어 변경 필요
- **KT&C 카메라 사전 통보 없었음** — 드라이버 패키지는 Sony 전용($99)
- **카메라 발송 권고** — KT&C 카메라를 Oppila에 보내서 기술 평가 및 펌웨어 수정 논의
- **카메라 제어 명령은 지원 범위 밖** — uart.py는 호의적 제공

### 다음 단계

| 우선순위 | 항목 | 담당 | 비고 |
|---------|------|------|------|
| 1 | **KT&C 카메라 LVDS 타이밍 확인** | 우리 | VESA인지 JEIDA인지 데이터시트 확인 |
| 2 | **선택지 결정** (아래 참조) | 우리 | 비용/시간 트레이드오프 |
| 3 | 케이블 교체 테스트 | 우리 | LVDS 신호 무결성 확인 |

**선택지 분석**:

| 옵션 | 장점 | 단점 | 예상 비용/시간 |
|------|------|------|--------------|
| **A. KT&C 카메라를 Oppila에 발송** | 펌웨어 수정 확실 | 국제 배송 + 추가 비용 | 2-4주 + 수정 비용 미정 |
| **B. Sony FCB-EV9520L 구매** | 즉시 호환, 검증된 조합 | 카메라 교체 비용 | 카메라 가격 + 배송 |
| **C. 오실로스코프 LVDS 신호 분석** | 차이점 정확 파악 | 장비/전문성 필요 | 1-2일 |

---

## 시스템 개요

| 항목 | 내용 |
|------|------|
| 호스트 PC | Ubuntu 22.04 / 20.04 |
| 타겟 보드 | Jetson Orin Nano Super Developer Kit |
| 카메라 인터페이스 | MIPI CSI-2 (24pin CSI Connector, CAM1) |
| 브릿지 칩 | LT9211C (LVDS → MIPI 변환) |
| 카메라 호환 설정 | IMX219-C (Device Tree Overlay) |
| 영상 포맷 | UYVY (V4L2) |
| 커스텀 이미지 | ORIN_NX_IMAGE.tar.bz2 |

---

## 1. 호스트 PC 환경 설정

### 1.1 필요 파일 다운로드

Google Drive: https://drive.google.com/drive/folders/1TDUXYL6gGu0oZq7z41naLT2DZZxhkUus

- `rc.local` - 카메라 파이프라인 초기화 스크립트
- `ORIN_NX_IMAGE.tar.bz2` - 커스텀 Jetson 이미지 (LT9211C 드라이버 포함)

### 1.2 이미지 추출

```bash
mkdir ~/New
mv ~/Downloads/ORIN_NX_IMAGE.tar.bz2 ~/New/
cd ~/New/
sudo tar -xvJf Linux_for_Tegra_2.tar.bz2
cd Linux_for_Tegra/
sudo ./apply_binaries.sh
```

### 1.3 의존성 설치

```bash
sudo apt update
sudo apt install -y qemu-user-static sshpass binutils abootimg \
  libxml2-utils nfs-kernel-server u-boot-tools android-tools-fastboot \
  python3-pip lz4
pip3 install -U pip
sudo reboot
```

---

## 2. Jetson 플래싱

### 2.1 Recovery Mode 진입

1. Jetson Orin Nano Developer Kit에서 **FC REC** 핀과 **GND** 핀을 점퍼로 연결
2. 전원 어댑터 연결하여 전원 공급
3. 호스트 PC와 USB Type-C 케이블 연결

### 2.2 Recovery Mode 확인

```bash
lsusb
# "NVIDIA Corp. APX" 디바이스가 보여야 함
```

### 2.3 플래싱 실행

```bash
sudo ./nvsdkmanager_flash.sh --storage nvme0n1p1
```

### 2.4 플래싱 완료 후

1. Recovery 점퍼 제거
2. Orin NX 모듈과 카메라 연결 후 전원 ON

---

## 3. 하드웨어 연결

```
[카메라 모듈] --LVDS--> [LT9211C 어댑터 보드] --CSI 케이블--> [Jetson CAM1 커넥터]
```                                                                    

- CSI 케이블로 어댑터 보드의 카메라 출력을 Jetson의 **CAM1** 커넥터에 연결

---

## 4. MIPI CSI 핀 설정 (플래싱 후 1회)

```bash
sudo /opt/nvidia/jetson-io/jetson-io.py
```

설정 경로:
1. **Configure Jetson 24pin CSI Connector**
2. **Configure for compatible hardware**
3. **Camera IMX219-C** 선택
4. **Save pin changes**
5. **Save and reboot to reconfigure pins**
6. 아무 키 → 리부팅 (MIPI 핀 재설정 적용)

---

## 5. rc.local 스크립트 분석

`rc.local`은 카메라 파이프라인 클럭 최적화 및 디버그 트레이싱 초기화 스크립트이다.

### 5.1 전체 스크립트

```bash
#!/bin/bash

# [Section 1] 클럭 Rate Lock
echo 1 > /sys/kernel/debug/bpmp/debug/clk/vi/mrq_rate_locked
echo 1 > /sys/kernel/debug/bpmp/debug/clk/isp/mrq_rate_locked
echo 1 > /sys/kernel/debug/bpmp/debug/clk/nvcsi/mrq_rate_locked
echo 1 > /sys/kernel/debug/bpmp/debug/clk/emc/mrq_rate_locked

# [Section 2] 클럭을 최대 주파수로 설정
cat /sys/kernel/debug/bpmp/debug/clk/vi/max_rate | tee /sys/kernel/debug/bpmp/debug/clk/vi/rate
cat /sys/kernel/debug/bpmp/debug/clk/isp/max_rate | tee /sys/kernel/debug/bpmp/debug/clk/isp/rate
cat /sys/kernel/debug/bpmp/debug/clk/nvcsi/max_rate | tee /sys/kernel/debug/bpmp/debug/clk/nvcsi/rate
cat /sys/kernel/debug/bpmp/debug/clk/emc/max_rate | tee /sys/kernel/debug/bpmp/debug/clk/emc/rate

# [Section 3] ftrace 트레이싱 설정
echo 1 > /sys/kernel/debug/tracing/tracing_on
echo 30720 > /sys/kernel/debug/tracing/buffer_size_kb
echo 1 > /sys/kernel/debug/tracing/events/tegra_rtcpu/enable
echo 1 > /sys/kernel/debug/tracing/events/freertos/enable
echo 2 > /sys/kernel/debug/camrtc/log-level
echo 1 > /sys/kernel/debug/tracing/events/camera_common/enable
echo > /sys/kernel/debug/tracing/trace
```

### 5.2 Section 1: 카메라 파이프라인 클럭 잠금

BPMP(Boot and Power Management Processor)를 통해 4개 클럭의 동적 주파수 변경을 비활성화한다.

| 클럭 | 모듈 | 역할 |
|------|------|------|
| `vi` | Video Input | 카메라 센서에서 프레임 데이터 수신 |
| `isp` | Image Signal Processor | 이미지 처리 파이프라인 (디베이어링, 노이즈 제거 등) |
| `nvcsi` | NVIDIA CSI Controller | MIPI CSI-2 물리 계층 수신기 |
| `emc` | External Memory Controller | DDR 메모리 대역폭 제어 |

`mrq_rate_locked = 1` → 클럭 주파수를 고정하여 DVFS(Dynamic Voltage and Frequency Scaling)에 의한 변동 방지

### 5.3 Section 2: 클럭 최대 주파수 적용

각 모듈의 `max_rate`를 읽어 현재 `rate`에 기록한다. 이를 통해 카메라 파이프라인 전체가 **최대 성능**으로 동작한다.

```
max_rate → rate  (각 모듈별 최대 클럭으로 설정)
```

이는 LT9211C 브릿지 칩을 통한 LVDS→MIPI 변환 시 충분한 클럭/대역폭을 보장하기 위한 설정이다.

### 5.4 Section 3: 카메라 디버그 트레이싱

ftrace 기반 커널 트레이싱을 활성화하여 카메라 파이프라인 디버깅을 지원한다.

| 설정 | 값 | 설명 |
|------|-----|------|
| `tracing_on` | 1 | ftrace 전역 활성화 |
| `buffer_size_kb` | 30720 (30MB) | 트레이스 버퍼 크기 |
| `tegra_rtcpu/enable` | 1 | Tegra Real-Time CPU 이벤트 추적 |
| `freertos/enable` | 1 | FreeRTOS (카메라 RTCPU 펌웨어) 이벤트 추적 |
| `camrtc/log-level` | 2 | 카메라 RTCPU 로그 레벨 (verbose) |
| `camera_common/enable` | 1 | 공통 카메라 프레임워크 이벤트 추적 |
| `trace` | (clear) | 기존 트레이스 버퍼 초기화 |

---

## 6. 영상 캡처 및 스트리밍

### 6.1 드라이버 초기화

```bash
sudo ./rc.local
```

### 6.2 비디오 디바이스 확인

```bash
ls /dev/video
# /dev/video0 이 표시되어야 함
```

### 6.3 GStreamer 영상 스트리밍

```bash
gst-launch-1.0 v4l2src device=/dev/video0 \
  ! video/x-raw,format=UYVY \
  ! videoconvert \
  ! xvimagesink
```

### 6.4 GStreamer 파이프라인 구조

```
v4l2src (/dev/video0)
  → video/x-raw, format=UYVY   (V4L2에서 UYVY 원시 프레임 캡처)
  → videoconvert                (색공간 변환)
  → xvimagesink                 (X11 윈도우에 디스플레이)
```

---

## 7. 디버깅

### 7.1 LT9211C 드라이버 로그 확인

```bash
sudo dmesg | grep -i lt9211c
```

### 7.2 카메라 트레이스 로그 확인

```bash
# rc.local 실행 후 트레이싱이 활성화된 상태에서
cat /sys/kernel/debug/tracing/trace
```

### 7.3 문제 발생 시 연락처

support@oppila.in

---

## 전체 동작 흐름

```
[호스트 PC]                          [Jetson Orin Nano]
  커스텀 이미지 플래싱 ───────────→  LT9211C 드라이버 포함 커널 부팅
                                       │
                                       ▼
                                  jetson-io.py로 CSI 핀 설정 (IMX219-C)
                                       │
                                       ▼
                                  rc.local 실행
                                   ├─ 카메라 클럭 최대값 고정 (vi/isp/nvcsi/emc)
                                   └─ ftrace 디버그 트레이싱 활성화
                                       │
                                       ▼
                                  /dev/video0 V4L2 디바이스 생성
                                       │
                                       ▼
                                  GStreamer로 UYVY 영상 캡처/디스플레이
```

---

## 8. 사물 인식(Object Detection) 적용 시 제약 분석

### 8.1 사용 시나리오

```
[외부 서버/PC에서 모델 학습 (YOLOv8, SSD 등)]
        │
        ▼  (모델 export: ONNX → TensorRT)
[Jetson Orin Nano에 모델 배포]
        │
        ▼
[LT9211C 카메라 영상] → [전처리] → [추론(Inference)] → [결과 출력]
```

### 8.2 제약사항 총정리

#### 제약 A: UYVY 포맷 → RGB 변환 필수

| 구분 | 내용 |
|------|------|
| 원인 | LT9211C가 UYVY(YUV 4:2:2) 포맷으로 출력 |
| 영향 | 모든 ML 프레임워크(TensorRT, PyTorch, ONNX Runtime)는 RGB/BGR 입력 요구 |
| 심각도 | **중간** - 해결 가능하지만 파이프라인 설계 필수 |

**변환 방법 비교:**

| 방법 | 처리 장치 | 성능 | 권장 여부 |
|------|----------|------|----------|
| `videoconvert` (GStreamer) | CPU | 느림, 고해상도에서 병목 | X |
| `nvvidconv` (GStreamer) | GPU (VIC 엔진) | 빠름, 하드웨어 가속 | O |
| `cv2.cvtColor()` (OpenCV) | CPU | 보통 | 소규모 OK |
| `cv2.cuda.cvtColor()` (OpenCV CUDA) | GPU | 빠름 | O |

#### 제약 B: nvarguscamerasrc 사용 불가

| 구분 | 내용 |
|------|------|
| 원인 | nvarguscamerasrc는 Bayer RAW 센서 + NVIDIA ISP 전용 |
| 영향 | NVIDIA 최적화 카메라 파이프라인 사용 불가, 많은 예제/튜토리얼 적용 불가 |
| 심각도 | **높음** - NVIDIA 공식 예제 대부분이 nvarguscamerasrc 기반 |

**실질적 영향:**
- NVIDIA 공식 DL/ML 예제 (jetson-inference, jetson-utils) 코드 수정 필요
- DeepStream 기본 config 사용 불가, v4l2 소스로 변경 필요
- libargus API 사용 불가

#### 제약 C: NVIDIA ISP(Image Signal Processor) 완전 바이패스

| 구분 | 내용 |
|------|------|
| 원인 | ISP는 Bayer RAW 데이터 처리용, UYVY는 이미 처리된 데이터 |
| 영향 | 하드웨어 AE/AWB/AF, HDR, 노이즈 리덕션, 렌즈 보정 없음 |
| 심각도 | **높음** - 조명 변화에 취약, 인식 정확도 직접 영향 |

**사물 인식에 미치는 구체적 영향:**
- **조명 변화 시** 노출이 고정되어 과다/부족 노출 → 인식률 저하
- **색온도 변화 시** 화이트밸런스 보정 없음 → 색상 기반 인식 오류
- **저조도 환경** 노이즈 리덕션 없음 → 노이즈로 인한 오탐지 증가

#### 제약 D: 해상도/FPS 제한 가능성

| 구분 | 내용 |
|------|------|
| 원인 | IMX219-C Device Tree Overlay 기반, LT9211C 실제 출력과 불일치 가능 |
| 영향 | 원하는 해상도/FPS로 캡처 못할 수 있음 |
| 심각도 | **중간** - 부팅 후 확인 필요 |

**확인 명령:**
```bash
v4l2-ctl --device=/dev/video0 --list-formats-ext   # 지원 포맷/해상도 목록
v4l2-ctl --device=/dev/video0 --get-fmt-video       # 현재 설정
```

#### 제약 E: 추론 파이프라인 지연(Latency) 추가

| 구분 | 내용 |
|------|------|
| 원인 | v4l2src → 포맷변환 → 추론까지 단계가 nvarguscamerasrc 대비 1단계 추가 |
| 영향 | 실시간 인식 시 1~3ms 추가 지연 |
| 심각도 | **낮음** - 대부분의 사물 인식 시나리오에서 무시 가능 |

---

### 8.3 제약의 근본 원인: 어디서 오는 제약인가?

```
제약 원인 분석
│
├─ [하드웨어 구조적 제약] ← LVDS→MIPI 브릿지를 사용하면 반드시 발생
│   ├─ UYVY 포맷 출력 (제약 A)
│   ├─ nvarguscamerasrc 사용 불가 (제약 B)
│   └─ NVIDIA ISP 바이패스 (제약 C)
│
├─ [Device Tree 설정 제약] ← 설정 변경으로 개선 가능
│   └─ 해상도/FPS 제한 (제약 D)
│
└─ [파이프라인 설계 제약] ← 소프트웨어 최적화로 극복 가능
    └─ 추론 지연 (제약 E)
```

#### Q1: LVDS → MIPI 브릿지를 사용하면 원래 이런 것인가?

**YES.** 이것은 LVDS→MIPI 브릿지 칩의 본질적 특성이다.

- LT9211C뿐 아니라 모든 LVDS→MIPI 브릿지(TC358748, ADV7282 등)가 동일
- 브릿지 칩은 LVDS에서 받은 영상을 YUV/RGB로 변환하여 MIPI CSI-2로 전송
- Jetson ISP는 Bayer RAW 데이터 전용이므로, 이미 변환된 YUV 데이터는 ISP를 거치지 않음
- **LVDS→MIPI 브릿지를 사용하는 한, 어떤 드라이버를 쓰더라도 이 제약은 동일**

#### Q2: Config를 변경하면 해결되는가?

**부분적으로만.** Device Tree/드라이버 config 변경으로 개선 가능한 것과 불가능한 것이 있다.

| 제약 | Config 변경으로 해결 | 설명 |
|------|:-------------------:|------|
| UYVY 포맷 | X | 하드웨어 출력 포맷, 변경 불가 |
| nvarguscamerasrc 불가 | X | Bayer RAW 전용, 구조적 한계 |
| ISP 바이패스 | X | UYVY 입력에 ISP 적용 불가 |
| 해상도/FPS | **O** | DT 수정으로 조정 가능 |
| V4L2 컨트롤 | **O** | 드라이버 수정으로 추가 가능 |

#### Q3: 커스텀 이미지 대신 드라이버만 별도 설치하면 제약이 없어지는가?

**NO.** 근본적 제약은 해소되지 않는다.

커스텀 이미지에 포함된 것:
- LT9211C용 커널 드라이버 모듈 (.ko)
- LT9211C용 Device Tree Overlay
- 수정된 NVIDIA 카메라 프레임워크 설정

드라이버를 별도로 빌드/설치하더라도:
- V4L2 디바이스(`/dev/videoX`)로 등록되는 구조는 동일
- UYVY 출력은 하드웨어 특성이므로 변하지 않음
- nvarguscamerasrc는 여전히 사용 불가
- ISP 바이패스도 동일

**드라이버 별도 설치로 개선 가능한 것:**
- Device Tree에서 해상도/FPS 모드 추가/변경
- V4L2 커스텀 컨트롤 추가 (밝기, 대비 등)
- 커널 버전 업그레이드 호환성

---

### 8.4 제약 극복 방법

#### 극복 1: 최적 추론 파이프라인 구성 (제약 A, E 해결)

**GStreamer + TensorRT 파이프라인 (권장):**

```bash
# DeepStream 기반 파이프라인
gst-launch-1.0 v4l2src device=/dev/video0 \
  ! video/x-raw,format=UYVY \
  ! nvvidconv \
  ! 'video/x-raw(memory:NVMM),format=NV12' \
  ! mux.sink_0 nvstreammux name=mux batch-size=1 width=640 height=480 \
  ! nvinfer config-file-path=config_infer.txt \
  ! nvvideoconvert \
  ! nvdsosd \
  ! nvegltransform \
  ! nveglglessink
```

**Python + OpenCV + TensorRT 파이프라인:**

```python
import cv2
import tensorrt as trt

# V4L2에서 UYVY 캡처
cap = cv2.VideoCapture(0, cv2.CAP_V4L2)
cap.set(cv2.CAP_PROP_FOURCC, cv2.VideoWriter_fourcc(*'UYVY'))

while True:
    ret, frame = cap.read()
    if not ret:
        break

    # UYVY → BGR 변환 (OpenCV가 자동 처리)
    # frame은 이미 BGR 포맷

    # BGR → RGB 변환 (TensorRT 모델 입력용)
    rgb_frame = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)

    # 리사이즈 (모델 입력 크기에 맞춤)
    input_tensor = cv2.resize(rgb_frame, (640, 640))

    # TensorRT 추론 실행
    detections = run_inference(engine, input_tensor)

    # 결과 표시
    draw_boxes(frame, detections)
    cv2.imshow("Detection", frame)
```

**GStreamer appsink을 통한 Python 연동 (GPU 가속 변환):**

```python
import gi
gi.require_version('Gst', '1.0')
from gi.repository import Gst
import numpy as np

Gst.init(None)

pipeline_str = (
    'v4l2src device=/dev/video0 '
    '! video/x-raw,format=UYVY '
    '! nvvidconv '
    '! video/x-raw,format=BGRx '
    '! videoconvert '
    '! video/x-raw,format=BGR '
    '! appsink name=sink emit-signals=true max-buffers=1 drop=true'
)

pipeline = Gst.parse_launch(pipeline_str)
appsink = pipeline.get_by_name('sink')
pipeline.set_state(Gst.State.PLAYING)

# appsink에서 BGR 프레임을 numpy 배열로 수신하여 추론에 사용
```

#### 극복 2: DeepStream v4l2 소스 설정 (제약 B 해결)

**deepstream_config.txt:**

```ini
[source0]
enable=1
type=1                          # V4L2 Camera (nvarguscamerasrc가 아닌 v4l2)
camera-v4l2-dev-node=0
camera-width=1920               # 실제 지원 해상도로 변경
camera-height=1080
camera-fps-n=30
camera-fps-d=1

[primary-gie]
enable=1
gpu-id=0
model-engine-file=model.engine  # TensorRT 엔진 파일
config-file=config_infer.txt
batch-size=1

[osd]
enable=1
```

#### 극복 3: 소프트웨어 ISP 전처리 (제약 C 해결)

ISP가 없으므로 추론 전 소프트웨어 전처리로 화질을 보정한다.

```python
import cv2
import numpy as np

def preprocess_for_inference(frame):
    """ISP 부재를 보완하는 소프트웨어 전처리"""

    # 1. Auto White Balance (그레이월드 알고리즘)
    avg_b, avg_g, avg_r = np.mean(frame, axis=(0, 1))
    avg_all = (avg_b + avg_g + avg_r) / 3
    frame[:,:,0] = np.clip(frame[:,:,0] * (avg_all / avg_b), 0, 255)
    frame[:,:,1] = np.clip(frame[:,:,1] * (avg_all / avg_g), 0, 255)
    frame[:,:,2] = np.clip(frame[:,:,2] * (avg_all / avg_r), 0, 255)
    frame = frame.astype(np.uint8)

    # 2. Auto Exposure 보정 (히스토그램 이퀄라이제이션)
    lab = cv2.cvtColor(frame, cv2.COLOR_BGR2LAB)
    l, a, b = cv2.split(lab)
    clahe = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(8, 8))
    l = clahe.apply(l)
    frame = cv2.cvtColor(cv2.merge([l, a, b]), cv2.COLOR_LAB2BGR)

    # 3. 노이즈 리덕션 (저조도 환경용)
    frame = cv2.fastNlMeansDenoisingColored(frame, None, 5, 5, 7, 21)

    return frame
```

**주의:** `fastNlMeansDenoisingColored`는 무거우므로 실시간에서는 가벼운 대안 사용:

```python
# 실시간용 경량 노이즈 리덕션
frame = cv2.GaussianBlur(frame, (3, 3), 0)
# 또는
frame = cv2.bilateralFilter(frame, 5, 50, 50)
```

#### 극복 4: 해상도/FPS 최적화 (제약 D 해결)

부팅 후 실제 지원 모드를 확인하고, 필요 시 Device Tree를 수정한다.

```bash
# 지원 모드 확인
v4l2-ctl --device=/dev/video0 --list-formats-ext

# 해상도/FPS 수동 설정
v4l2-ctl --device=/dev/video0 --set-fmt-video=width=1280,height=720,pixelformat=UYVY

# 프레임레이트 설정
v4l2-ctl --device=/dev/video0 --set-parm=30
```

---

### 8.5 권장 추론 아키텍처

```
[LT9211C 카메라]
      │ UYVY (MIPI CSI-2)
      ▼
[v4l2src /dev/video0]
      │ UYVY raw frames
      ▼
[nvvidconv]  ← GPU 가속 포맷 변환 (VIC 엔진)
      │ NV12 또는 BGR
      ▼
[소프트웨어 전처리]  ← AWB, AE 보정, 노이즈 리덕션
      │ 보정된 BGR/RGB
      ▼
[리사이즈 + 정규화]  ← 모델 입력 크기에 맞춤 (640x640 등)
      │ float32 tensor
      ▼
[TensorRT 추론 엔진]  ← 외부에서 학습된 모델 (.engine)
      │ 바운딩 박스 + 클래스 + 신뢰도
      ▼
[후처리 + NMS]
      │ 최종 검출 결과
      ▼
[결과 표시/전송]
```

**모델 배포 절차:**

```bash
# 1. 외부 서버에서 학습 후 ONNX로 export
#    (PyTorch → ONNX → TensorRT)

# 2. Jetson에서 TensorRT 엔진으로 변환
/usr/src/tensorrt/bin/trtexec \
  --onnx=model.onnx \
  --saveEngine=model.engine \
  --fp16                        # FP16 최적화 (Orin Nano GPU 활용)

# 3. 추론 실행
python3 detect.py --engine model.engine --source /dev/video0
```

---

### 8.6 제약 vs 극복 요약

| 제약 | 원인 | 극복 가능 | 극복 방법 |
|------|------|:---------:|----------|
| UYVY→RGB 변환 필요 | 하드웨어 (브릿지 칩) | O | `nvvidconv` GPU 가속 변환 |
| nvarguscamerasrc 불가 | 하드웨어 (브릿지 칩) | △ | `v4l2src`로 대체, 코드 수정 |
| ISP 기능 없음 | 하드웨어 (브릿지 칩) | △ | 소프트웨어 전처리 (AWB, AE, NR) |
| DeepStream 기본 설정 불가 | 소프트웨어 설정 | O | config에서 `type=1` V4L2 소스 지정 |
| 해상도/FPS 제한 | Device Tree 설정 | O | DT 수정 또는 v4l2-ctl로 조정 |
| 추론 지연 추가 | 파이프라인 구조 | O | 파이프라인 최적화, drop=true |

**결론:** LVDS→MIPI 브릿지를 사용하는 한 UYVY 출력, ISP 바이패스, nvarguscamerasrc 불가는 피할 수 없는 구조적 제약이다. 드라이버를 별도로 설치하더라도 이 세 가지는 해결되지 않는다. 하지만 `nvvidconv` + 소프트웨어 전처리 + TensorRT 조합으로 **실시간 사물 인식은 충분히 구현 가능**하다.

---

## 9. 퍼포먼스 영향 분석

### 9.1 네이티브 센서 vs LT9211C 브릿지 처리 경로 비교

```
[네이티브 Bayer 센서 (nvarguscamerasrc)]
  센서 → ISP(HW, 0ms) → NV12(NVMM) → 추론
         AE/AWB/NR 전부 HW 처리, GPU 메모리에 바로 적재

[LT9211C 브릿지 (v4l2src)]
  센서 → 브릿지 → UYVY(시스템 메모리) → nvvidconv → NV12(NVMM) → 추론
         ISP 없음, 포맷 변환 단계 추가, 메모리 복사 발생
```

### 9.2 프레임당 처리 시간 비교 (1080p 기준)

| 처리 단계 | 네이티브 센서 | LT9211C 브릿지 | 차이 |
|-----------|:---:|:---:|:---:|
| 캡처 → 메모리 | 0ms (ISP가 NVMM에 직접) | 0ms (시스템 메모리) | - |
| 포맷 변환 | 0ms (ISP 출력이 NV12) | 1~2ms (nvvidconv, VIC 엔진) | +1~2ms |
| 시스템 → GPU 메모리 복사 | 0ms (처음부터 NVMM) | 0.5~1ms (DMA 전송) | +0.5~1ms |
| ISP 보정 (AE/AWB/NR) | 0ms (HW 병렬 처리) | 소프트웨어 전처리 필요 | **가변** |
| TensorRT 추론 (YOLOv8s 640x640) | 15~25ms | 15~25ms | 동일 |

### 9.3 소프트웨어 전처리 개별 비용 (1080p, CPU 기준)

| 전처리 항목 | 처리 시간 | 비고 |
|------------|:---:|------|
| AWB 그레이월드 알고리즘 | 3~5ms | numpy 배열 연산 |
| CLAHE 노출 보정 | 2~4ms | OpenCV |
| GaussianBlur (경량 NR) | 1~2ms | 실시간 가능 |
| bilateralFilter | 10~30ms | 에지 보존, 느림 |
| fastNlMeansDenoising | 50~200ms | **실시간 불가** |

### 9.4 시나리오별 총 성능 비교

YOLOv8s 640x640, Jetson Orin Nano 기준 추정치:

| 시나리오 | 추론 외 오버헤드 | 총 시간/프레임 | 예상 FPS | 네이티브 대비 저하 |
|----------|:---:|:---:|:---:|:---:|
| **네이티브 센서 (기준)** | ~0ms | 15~25ms | 40~66 | - |
| **브릿지 + 전처리 없음** | ~2ms | 17~27ms | 37~58 | **~5%** |
| **브릿지 + 경량 전처리 (CPU)** | ~8ms | 23~33ms | 30~43 | **~25%** |
| **브릿지 + CUDA 전처리 (GPU)** | ~3ms | 18~28ms | 35~55 | **~10%** |
| **브릿지 + 풀 전처리 (CPU)** | ~40ms+ | 55~65ms+ | 15~18 | **~60%** |

### 9.5 퍼포먼스 최적화 전략

#### 전략 1: 전처리 생략 - 동일 카메라 학습 (저하 ~5%, 최고 권장)

**가장 효과적인 방법.** ISP 없는 영상 조건 자체를 학습에 반영한다.

```
[학습 단계 - 외부 서버]
  LT9211C 카메라로 학습 데이터 촬영 (ISP 미적용 원본 그대로)
      ↓
  이 영상으로 모델 학습 (모델이 ISP 없는 조건에 적응)
      ↓
  ONNX export

[추론 단계 - Jetson]
  v4l2src → nvvidconv (포맷 변환만) → TensorRT 추론
  소프트웨어 전처리 불필요 → 오버헤드 ~2ms만 추가
```

**장점:**
- 네이티브 대비 ~5% 저하로 최소화
- 파이프라인 단순, 구현 용이
- 추가 CPU/GPU 리소스 소모 없음

**단점:**
- 학습 데이터를 이 카메라로 직접 수집해야 함
- 조명이 크게 변하는 환경에서 인식률이 떨어질 수 있음
- 다른 카메라로 수집한 기존 학습 데이터 재사용 어려움

**조명 변화 대응 보완:**
```
학습 시 데이터 증강(augmentation)으로 보완:
  - 밝기 변화: RandomBrightnessContrast
  - 색온도 변화: ColorJitter
  - 노이즈 추가: GaussNoise
  → 다양한 조건을 학습에 포함시켜 로버스트니스 향상
```

#### 전략 2: CUDA 가속 전처리 (저하 ~10%)

소프트웨어 전처리가 필요한 경우, CPU 대신 GPU에서 수행하면 5~10배 빠르다.

```python
import cv2

# GPU에 프레임 업로드
gpu_frame = cv2.cuda_GpuMat()
gpu_frame.upload(frame)

# CUDA 가속 색공간 변환
gpu_lab = cv2.cuda.cvtColor(gpu_frame, cv2.COLOR_BGR2LAB)

# CUDA CLAHE
clahe = cv2.cuda.createCLAHE(clipLimit=2.0, tileGridSize=(8, 8))
l_channel, a_channel, b_channel = cv2.cuda.split(gpu_lab)
l_channel = clahe.apply(l_channel, cv2.cuda.Stream.Null())
gpu_lab = cv2.cuda.merge([l_channel, a_channel, b_channel])

# CUDA 가속 가우시안 블러
gpu_filtered = cv2.cuda.createGaussianFilter(
    cv2.CV_8UC3, cv2.CV_8UC3, (3, 3), 0
).apply(gpu_frame)

# GPU 메모리에서 바로 TensorRT로 전달 (CPU 복사 없음)
```

| 전처리 항목 | CPU 시간 | CUDA 시간 | 속도 향상 |
|------------|:---:|:---:|:---:|
| AWB | 3~5ms | 0.3~0.5ms | ~10x |
| CLAHE | 2~4ms | 0.3~0.5ms | ~8x |
| GaussianBlur | 1~2ms | 0.1~0.2ms | ~10x |
| **합계** | **6~11ms** | **0.7~1.2ms** | **~8x** |

#### 전략 3: DeepStream 파이프라인 통합 (저하 ~10~15%)

DeepStream은 전체 파이프라인을 GPU 메모리(NVMM) 내에서 처리하여 CPU-GPU 간 메모리 복사를 최소화한다.

```
v4l2src → nvvidconv → nvstreammux → nvinfer(TensorRT) → nvdsosd → 출력
                    (NVMM 내에서 전부 처리)
```

#### 전략 4: 파이프라인 레벨 최적화

```python
# GStreamer appsink 최적화 옵션
'appsink name=sink emit-signals=true max-buffers=1 drop=true sync=false'
#                                     └─ 버퍼 1개만  └─ 밀리면 드롭  └─ 클럭 동기화 해제
```

- `max-buffers=1`: 최신 프레임만 유지, 메모리 절약
- `drop=true`: 추론이 늦으면 오래된 프레임 드롭 → 지연 누적 방지
- `sync=false`: 디스플레이 클럭 동기화 해제 → 처리 속도 우선

---

### 9.6 전략 선택 가이드

```
어떤 전략을 선택할 것인가?
│
├─ 조명 조건이 일정한가? (실내, 고정 조명)
│   └─ YES → 전략 1 (전처리 생략, ~5% 저하) ★ 최고 권장
│
├─ 조명이 변하지만 실시간이 중요한가?
│   └─ YES → 전략 2 (CUDA 전처리, ~10% 저하)
│
├─ NVIDIA 생태계 활용이 중요한가? (멀티스트림, 분석)
│   └─ YES → 전략 3 (DeepStream, ~10~15% 저하)
│
└─ 최대 FPS가 필요한가?
    └─ YES → 전략 1 + 전략 4 조합 (전처리 생략 + 파이프라인 최적화)
```

### 9.7 퍼포먼스 요약

| 항목 | 결론 |
|------|------|
| 퍼포먼스 저하 없이 가능한가? | **NO**, 구조적으로 오버헤드 존재 |
| 최소 저하 수준 | 전처리 생략 시 **~5%** (nvvidconv 변환만) |
| 실시간 사물 인식 가능한가? | **YES**, 30FPS 이상 충분히 달성 가능 |
| 가장 큰 병목 | 소프트웨어 전처리(CPU), 특히 노이즈 리덕션 |
| 핵심 권장사항 | **동일 카메라로 학습 데이터 수집 → 전처리 생략 → ~5% 저하만 감수** |

---

## 10. 프로젝트 파일 구조

```
C:\Work\baeksan\digital\code\mipi\
├── 문서
│   ├── MIPI_DOCUMENT.md        (본 문서 - 종합 가이드)
│   ├── WORK_LOG.md             (작업 이력 및 테스트 결과)
│   ├── oppila_support_email.md (Oppila 지원 요청 이메일)
│   └── oppila_reply_email.md   (진단 결과 포함 후속 이메일)
├── VISCA 제어 스크립트
│   ├── uart.py                 (SC16IS752 초기화, Oppila 원본 수정)
│   ├── uart_diag.py            (SC16IS752 종합 진단)
│   ├── visca_probe.py          (VISCA 명령 호환성 탐색)
│   ├── visca_set_1080p60.py    (카메라 포맷 1080p60 변경)
│   ├── visca_format.py         (Sony VISCA 포맷 테스트)
│   ├── visca_set_dual_lvds.py  (LVDS Dual 모드 변경)
│   └── quick_check.py          (포맷 빠른 확인/설정)
├── 시스템 설정/진단
│   ├── apply_30fps.py          (DT 오버레이 30fps 패치)
│   ├── check_lt9211.py         (LT9211C 레지스터 검사)
│   ├── lt9211_dump.py          (LT9211C 레지스터 덤프)
│   ├── rc.local                (Jetson 초기화 스크립트)
│   └── rc.download             (rc.local 백업)
├── 참조 문서
│   ├── (ATC-HZ5540T-LP).pdf    (KT&C 카메라 데이터시트)
│   ├── FCB-EV9520L_TM.pdf      (Sony FCB-EV 참조)
│   ├── LVDS-MIPI.pdf           (LVDS-MIPI 참조 문서)
│   └── IMAGE_BRINGUP_DOCUMENT_ADAPTER_BOARD.docx (Oppila 가이드)
├── 테스트 결과
│   ├── capture_test.jpg        (그린스크린 - 1080p30 Single)
│   ├── capture_1080p60.jpg     (그린스크린 - 1080p60 Single)
│   ├── capture_reload.jpg      (그린스크린 - 드라이버 리로드)
│   └── capture_dual.jpg        (그린스크린 - Dual LVDS)
└── 기타
    └── board_compatibility_report_clean.txt (보드 호환성 보고서)
```
