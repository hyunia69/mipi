# LVDS-MIPI Bridge Board 작업 기록

- 작업일: 2026-02-26 (최종 업데이트: 2026-03-26)
- 대상 보드: NVIDIA Jetson Orin Nano Super Developer Kit (user: hyunia)
- 어댑터: Oppila LVDS-MIPI Bridge Board (LT9211C)
- 카메라: **KT&C ATC-HZ5540T-LP** (1/2.9" 1.58MP Global Shutter CMOS, 40x Zoom)
- L4T: R36.4.4, Kernel: 5.15.148-tegra
- 플래싱 PC: Ubuntu 22.04.5 LTS, SDK Manager 2.3.0.12617
- **현재 상태**: 새 이미지 재플래싱 완료, 초기 설정 진행 중 (2026-03-26)

---

## 0. 최신 현황 (2026-03-26) — 새 이미지 재플래싱

### 재플래싱 작업 (2026-03-26)

**새 ORIN_NX_IMAGE.tar.bz2 이미지로 Jetson 재플래싱 수행.**

#### 플래싱 절차 (PDF 기준 문서: IMAGE_BRINGUP_DOCUMENT.pdf)
1. 호스트 PC (Ubuntu 22.04.5 LTS)에서 새 이미지 압축 해제 + apply_binaries.sh
2. Jetson Recovery Mode (FC REC ↔ GND 점퍼) → USB-C 연결
3. `sudo ./nvsdkmanager_flash.sh --storage nvme0n1p1` 실행
4. 플래싱 완료 후 점퍼 제거 → 카메라/Bridge Board 연결 → 전원 ON

#### 플래싱 후 해결한 이슈들

| 이슈 | 증상 | 해결 방법 |
|------|------|----------|
| OEM 초기 설정 GUI 깨짐 | 검은 화면 + 마우스 포인터만 표시, 10분 이상 hang | 재부팅으로 해결 |
| SSH 서버 미설치 | openssh-server 미포함 | `sudo apt install -y openssh-server` |
| SSH 호스트 키 미생성 | `sshd` 시작 실패 ("no hostkeys available") | `sudo ssh-keygen -A` → `sudo systemctl start ssh` |
| OEM 설정 매 부팅 반복 | 부팅마다 oem-config 재실행 | 아래 명령으로 비활성화: |

```bash
# OEM 설정 반복 방지 (재플래싱 후 필수)
sudo systemctl disable nv-oem-config.service nv-oem-config-gui.service nv-oem-config.target
sudo touch /etc/nv-oem-config-done
```

**참고**: `nv-oem-config.service`가 "does not exist" 에러 나올 수 있음 → 무시하고 나머지 실행.
실제로 활성화되어 있던 서비스: `nv-oem-config-gui.service`, `nv-oem-config.service` (systemctl list-units로 확인)

#### 재플래싱 후 남은 작업 (PDF Section 5~6 기준)
1. ☐ rc.local 복사 (PC → Jetson)
2. ☐ jetson-io.py 핀 설정 (Camera IMX219-C 선택 → 리부트)
3. ☐ rc.local 실행 + 비디오 노드 확인
4. ☐ Python 패키지 재설치 (smbus2 등, VISCA 사용 시)
5. ☐ 스크립트 재업로드 (view_camera.py 등)

### 이전 영상 출력 성공 기록 (2026-03-18)

**카메라 영상이 정상적으로 출력됨을 확인.**
- 1920x1080 @ 60fps, UYVY, 전체 화면 선명한 영상 출력
- 상세 기록: `CAMERA_WORKING_STATE_20260318.md`

### 영상 출력 필수 절차

1. 카메라 + MIPI 보드 전원 ON → LT9211C LVDS Lock 대기
2. `sudo bash rc.local` → 클럭 최대값 고정 (필수)
3. `python3 view_camera.py` → 영상 확인
4. VISCA로 Zoom Wide + AF/AE/AWB ON (필요 시)

### 현재 카메라 설정

| 항목 | 값 |
|------|-----|
| Video Format | 1080p/60 (Reg 0x72 = 0x13) |
| LVDS Mode | Single (Reg 0x74 = 0x00) |
| Zoom | Wide end (0x0000) |
| Focus | Auto Focus |
| Exposure | Full Auto |
| White Balance | Auto |

---

## 1. 변경 사항 요약

### 1-1. Device Tree Overlay 수정 → 원복 완료

**파일**: `/boot/tegra234-p3767-camera-p3768-imx219-C.dtbo`

30fps 테스트를 위해 임시 수정했으나, **현재 원본 60fps로 원복 완료** 상태.

| 속성 | 원본 (60fps, 현재) | 임시 수정했던 값 (30fps) |
|------|-------------------|------------------------|
| `pix_clk_hz` | "148400000" | "74250000" |
| `max_framerate` | "60000000" | "30000000" |
| `default_framerate` | "60000000" | "30000000" |
| `default_exp_time` | "16667" | "33333" |
| `mclk_multiplier` | "24" | "12" |

**백업 파일**: `/boot/tegra234-p3767-camera-p3768-imx219-C.dtbo.bak.60fps` (원본 60fps 복사본)

### 1-2. 카메라 출력 포맷 변경 (VISCA)

**CAM_RegisterValue (Register 0x72) 명령으로 변경:**
- 변경 전: `0x07` = **1080p/30** (공장 기본값)
- 변경 후: `0x13` = **1080p/60**
- Custom Preset에 저장 완료 (재부팅 후에도 유지 확인됨)

원복 방법:
```
# VISCA 명령 (visca_set_1080p60.py 수정하여 사용)
# Register 0x72 = 0x07 (1080p/30)
81 01 04 24 72 00 07 FF
# 또는 공장 초기화
# KT_FactoryDefSystem: 81 01 70 EF EF FF
```

### 1-3. Jetson에 업로드한 파일

| 파일 | 용도 |
|------|------|
| `/home/hyunia/uart.py` | Oppila 제공 원본 (line 15 구문 오류 수정) |
| `/home/hyunia/uart_diag.py` | SC16IS752 + VISCA 진단 스크립트 |
| `/home/hyunia/visca_format.py` | VISCA Video Format Set 시도 (미지원 확인) |
| `/home/hyunia/visca_probe.py` | VISCA 명령 호환성 탐색 스크립트 |
| `/home/hyunia/visca_set_1080p60.py` | Register 0x72로 포맷 변경 (성공) |
| `/home/hyunia/quick_check.py` | 카메라 현재 포맷 조회/설정 |
| `/home/hyunia/lt9211_dump.py` | LT9211C 레지스터 덤프 (접근 실패) |
| `/home/hyunia/capture_*.jpg` | 캡처 테스트 이미지들 (모두 그린스크린) |

### 1-4. 패키지 설치

- `pip` (get-pip.py 통해 설치)
- `smbus2` 0.6.0

---

## 2. 원복 절차

### 2-1. DT Overlay — 이미 원복됨

현재 상태가 원본 60fps입니다. 확인 방법:
```bash
cat /proc/device-tree/bus@0/cam_i2cmux/i2c@1/rbpcv2_imx219_c@10/mode0/pix_clk_hz
# 148400000 이면 원본 상태
```

만약 다시 30fps로 변경되어 있다면:
```bash
sudo cp /boot/tegra234-p3767-camera-p3768-imx219-C.dtbo.bak.60fps \
        /boot/tegra234-p3767-camera-p3768-imx219-C.dtbo
sudo reboot
```

### 2-2. 카메라 포맷 원복 (1080p30으로 되돌리기)

`quick_check.py`를 수정하거나 아래 VISCA 명령 사용:
```
# Register 0x72 = 0x07 (1080p/30 공장 기본)
81 01 04 24 72 00 07 FF
# Custom Preset 저장
81 01 04 3F 01 7F FF
81 01 04 3F 11 7F FF
```

또는 공장 전체 초기화:
```
# KT_FactoryDefSystem (주의: 모든 설정 초기화)
81 01 70 EF EF FF
```

### 2-3. 업로드 파일 삭제 (선택)

```bash
rm -f /home/hyunia/uart_diag.py
rm -f /home/hyunia/visca_format.py
rm -f /home/hyunia/visca_probe.py
rm -f /home/hyunia/visca_set_1080p60.py
rm -f /home/hyunia/quick_check.py
rm -f /home/hyunia/lt9211_dump.py
rm -f /home/hyunia/capture_*.jpg /home/hyunia/frame_*.jpg
# uart.py는 Oppila 제공 원본이므로 보존 권장
```

---

## 3. 위험 평가

### DT Overlay — 원복 완료, 위험 없음

- 현재 원본 상태로 복원됨
- 백업 파일 `/boot/*.bak.60fps`이 남아있으나 부팅에 영향 없음

### 카메라 포맷 변경 (1080p30 → 1080p60) — 위험도: 낮음

- VISCA Register 0x72를 0x07에서 0x13으로 변경
- Custom Preset에 저장되어 재부팅 후에도 유지됨
- 원복: 위 2-2절의 VISCA 명령으로 즉시 복원 가능
- 카메라 하드웨어에 물리적 영향 없음 (소프트웨어 설정만 변경)

### 패키지/스크립트 — 위험도: 없음

- 시스템에 영향 없음, 삭제 자유

---

## 4. 진단 결과 요약

### 4-1. VISCA 통신 — 정상 동작 확인

- SC16IS752 I2C-UART 브리지 (I2C bus 9, addr 0x48) 정상 응답
- Oppila 원본 `uart.py`의 문제 2가지:
  1. baud divisor 오류: 0x5B(91) → **0x60(96)** 이 정확 (9600 baud @ 14.7456MHz)
  2. VISCA 초기화 누락: Address Set + IF Clear 필요
- 수정 후 VISCA 통신 성공: Zoom, Power, Focus 등 모두 정상 동작
- **카메라 Version**: Vendor 0x5568 (KT&C), Model 0x046F

### 4-2. KT&C 카메라 스펙 확인 (데이터시트 기반)

**센서**: 1/2.9" 1.58MP (1456x1088) Progressive Global Shutter CMOS

**지원 출력 포맷** (LVDS/Parallel/CVBS):
- 1080p: 60/50/30/25
- 720p: 60/50/30/25
- 1080i: 60/50

**포맷 변경 방법**: VISCA `CAM_RegisterValue` 명령 (Register 0x72)

| Register Value | 출력 포맷 |
|---------------|----------|
| 0x01, 0x02 | 1080i/60 |
| 0x04 | 1080i/50 |
| **0x06, 0x07** | **1080p/30 (공장 기본)** |
| 0x08 | 1080p/25 |
| 0x09, 0x0A | 720p/60 |
| 0x0C | 720p/50 |
| 0x0E, 0x0F | 720p/30 |
| 0x11 | 720p/25 |
| **0x13, 0x15** | **1080p/60** |
| 0x14 | 1080p/50 |

**참고**: Sony 표준 Video Format Set 명령 (`06 35`)은 미지원. KT&C 고유 Register 방식만 가능.

### 4-3. 그린스크린 테스트 결과

| # | 카메라 출력 | LVDS 모드 | DT (CSI) 설정 | 결과 | dmesg |
|---|-----------|----------|--------------|------|-------|
| 1 | 1080p/30 (기본) | Single (기본) | 60fps (원본) | 그린스크린 | `uncorr_err: request timed out` |
| 2 | 1080p/30 | Single | 30fps (수정) | 그린스크린 | 에러 없음, "Signal lost" |
| 3 | **1080p/60** (변경) | Single | **60fps** (원복) | **그린스크린** | "Signal lost" |
| 4 | 1080p/60 | Single | 60fps + 드라이버 재로드 | **그린스크린** | "Signal lost" |
| 5 | **1080p/60** | **Dual** | **60fps** + 드라이버 재로드 | **그린스크린** | "Signal lost" |

**핵심 발견: 카메라 출력 포맷, LVDS 모드(Single/Dual), DT 프레임레이트를 모든 조합으로 맞춰도 그린스크린이 지속됨.**

### 4-4. 그린스크린 근본 원인 분석

그린스크린은 Tegra VI 엔진이 프레임 타이밍은 받지만 유효 픽셀 데이터가 없을 때 발생합니다.

**LT9211C 브리지 칩이 LVDS → MIPI 변환을 수행하지 못하는 것으로 판단:**

1. **LT9211C 제어 주소 0x2d 미응답**: DT에 `lt9211@2d` 노드가 있지만, `i2cdetect`에서 0x2d가 검출되지 않음. 칩이 제대로 초기화되지 않았거나 하드웨어 문제 가능성
2. **드라이버 한계**: `lt9211cmipi.ko` (v2.0.6)는 0x10 주소만 사용하며, LT9211C 칩 내부 레지스터에 접근 시도 시 I/O 에러 발생
3. **LVDS 신호 경로 문제**: 카메라 LVDS 출력 → 30핀 커넥터 → Oppila 보드 → LT9211C 구간에서 신호가 도달하지 못할 가능성
4. **LVDS 모드 불일치**: 카메라의 Single/Dual LVDS 모드 (Register 0x74) vs LT9211C 수신 설정

---

## 5. 다음 단계 (권장)

| 우선순위 | 항목 | 담당 | 상세 |
|---------|------|------|------|
| 1 | **Oppila에 상세 진단 결과 전달** | 우리 | 아래 6절 내용 기반으로 이메일 작성 |
| 2 | LT9211C 0x2d 주소 미응답 확인 요청 | Oppila | 하드웨어 레벨 점검 필요 |
| 3 | LVDS Single/Dual 모드 설정 확인 | Oppila | 카메라 기본 Single, 보드 설정은? |
| 4 | Oppila 측에서 KT&C 카메라로 테스트 요청 | Oppila | Sony FCB-EV만 테스트한 상태 |
| 5 | 카메라 포맷을 1080p/30으로 원복 고려 | 우리 | Oppila가 30fps 드라이버 제공 시 |

---

## 6. Oppila 후속 이메일 작성 시 포함할 내용

### 새로 확인된 사실
1. 카메라 출력 포맷이 **1080p/30** (Register 0x72 = 0x07)이었음을 VISCA로 확인
2. VISCA `CAM_RegisterValue` 명령으로 **1080p/60** (0x13)으로 변경 성공, Custom Preset 저장 완료
3. 카메라 1080p/60 + DT overlay 60fps 일치 상태에서도 **그린스크린 지속**
4. `i2cdetect -y -r 9`에서 LT9211C 제어 주소 **0x2d가 검출되지 않음** (0x10만 UU로 표시)

### 질문 사항
1. LT9211C 주소 0x2d가 i2c에서 안 보이는 것이 정상인가?
2. 귀사에서 Sony FCB-EV 카메라로 실제 영상 출력 테스트를 성공한 적이 있는가?
3. LT9211C의 LVDS 수신 설정 (Single/Dual, JEIDA/VESA) 확인 가능한가?
4. `lt9211cmipi.ko` 드라이버 소스코드 또는 LT9211C 레지스터 초기화 시퀀스 공유 가능한가?

### 제공 가능한 자료
- `i2cdetect -y -r 9` 결과 (0x10=UU, 0x48=SC16IS752, 0x2d=없음)
- VISCA 통신 로그 (정상 동작 확인)
- `dmesg` 로그 (캡처 시도 시)
- `v4l2-ctl --all` 출력

---

## 7. 부트 구성 참고

```
# /boot/extlinux/extlinux.conf
DEFAULT JetsonIO
LABEL JetsonIO
    MENU LABEL Custom Header Config: <CSI Camera IMX219-C>
    LINUX /boot/Image
    FDT /boot/dtb/kernel_tegra234-p3768-0000+p3767-0005-nv-super.dtb
    INITRD /boot/initrd
    OVERLAYS /boot/tegra234-p3767-camera-p3768-imx219-C.dtbo
```

- 메인 DTB: `kernel_tegra234-p3768-0000+p3767-0005-nv-super.dtb`
- 카메라 Overlay: `tegra234-p3767-camera-p3768-imx219-C.dtbo` (Oppila 수정본)
- CSI 연결: CAM1 (serial_c), 4 lanes, port-index 2
- 드라이버: `/lib/modules/5.15.148-tegra/updates/drivers/media/i2c/lt9211cmipi.ko` (v2.0.6)

---

## 8. KT&C VISCA 명령 참고

### VISCA 초기화 (필수)
```
88 30 01 FF          # Address Set
88 01 00 01 FF       # IF Clear
```

### SC16IS752 UART 초기화 (I2C bus 9, addr 0x48)
```python
write_reg(0x03, 0x80)  # LCR: Enable divisor latch
write_reg(0x00, 0x60)  # DLL: 96 (9600 baud @ 14.7456MHz)
write_reg(0x01, 0x00)  # DLH: 0
write_reg(0x03, 0x03)  # LCR: 8N1
write_reg(0x02, 0x07)  # FCR: Enable + reset FIFOs
write_reg(0x02, 0x01)  # FCR: Enable FIFO
```

### 포맷 변경 (CAM_RegisterValue)
```
# 조회: 81 09 04 24 72 FF → 응답: 90 50 0p 0q FF (pq = 값)
# 설정: 81 01 04 24 72 0p 0q FF (pq = 값의 니블 분리)
# 예: 1080p/60(0x13) 설정 → 81 01 04 24 72 01 03 FF
# 예: 1080p/30(0x07) 설정 → 81 01 04 24 72 00 07 FF
```

### Custom Preset 저장 (재부팅 유지)
```
81 01 04 3F 01 7F FF   # Custom Set (현재 설정 저장)
81 01 04 3F 11 7F FF   # Custom Active (부팅 시 이 설정 적용)
```

---

## 9. 종합 현황 분석 (2026-03-06)

### 9-1. 그린스크린 근본 원인 종합 분석

그린스크린은 Tegra VI 엔진이 프레임 타이밍(sync)은 수신하지만 유효 픽셀 데이터가 없을 때 발생한다. **LT9211C 브릿지 칩이 LVDS → MIPI 변환을 수행하지 못하는 것**으로 판단.

**근거**:
1. 카메라 출력 포맷(1080p/30, 1080p/60), LVDS 모드(Single, Dual), DT 프레임레이트(30fps, 60fps) 5가지 조합을 모두 테스트했으나 결과 동일
2. LT9211C 제어 주소 `0x2D`가 I2C 버스에서 미검출 — 온보드 MCU 관리로 직접 접근 불가 추정
3. 드라이버(`lt9211cmipi.ko`)가 `0x10` 주소만 사용 — LT9211C 내부 레지스터 접근 시 I/O 에러
4. 테스트 5번(Dual LVDS)은 보드가 Single 전용이므로 무의미했음 (Oppila 2차 응답에서 확인)

**Oppila 2차 응답 기반 근본 원인 재분석**:
> 그린스크린의 근본 원인은 **KT&C 카메라와 Oppila 보드 간 LVDS 호환성 문제**로 확정.
> Oppila 보드 펌웨어는 **Sony FCB-EV9520L 전용, VESA 타이밍, 1080p/60fps, Single LVDS**로 구성.
> KT&C 카메라가 다른 타이밍(JEIDA 등)이나 다른 LVDS 파라미터를 사용할 경우 펌웨어 수정 필요.

### 9-2. Oppila 벤더 대응 현황 (2차 응답 수신, 2026-03-06)

| 항목 | 상태 |
|------|------|
| 최초 지원 요청 (`oppila_support_email.md`) | 발신 완료 |
| 진단 결과 후속 이메일 (`oppila_reply_email.md`) | 발신 완료 |
| 1차 응답 (SC16IS752 정보, 드라이버 스코프) | **수신 완료** |
| 2차 응답 (`oppila_email_response2.txt`) | **수신 완료** |

**Oppila 1차 응답 확인 사항**:
- 보드 지원 포맷: **1080p30, 720p60** LVDS 입력
- 설정 변경: 소스 코드 수정 필요 (향후 API 개발 중)
- SC16IS752: NXP SC16IS752IBS,151, I2C bus 9, addr 0x48
- SC16IS752용 DT/커널 드라이버 미포함 (직접 레지스터 프로그래밍)
- KT&C 카메라 사용 시 드라이버 설정 검증/조정 필요 (Oppila 상업팀과 논의)

**Oppila 2차 응답 핵심 내용**:
- **보드 하드웨어 정상** — Sony FCB-EV9520L로 출하 전 테스트 완료
- **Single LVDS 전용** — Sony 데이터시트 기반 설계 (Dual 미지원)
- **VESA 타이밍, 1080p/60fps** — KT&C 카메라가 VESA 아닌 경우 펌웨어 변경 필요
- **LT9211C 펌웨어**: 온보드 마이크로컨트롤러에 내장, Oppila가 관리
- **드라이버 패키지($99)**: Sony EV9520L 전용으로 검증, KT&C는 사전 통보 없었음
- **카메라 제어 명령**: 지원 범위 밖 (uart.py는 호의적 제공)
- **권고사항**: KT&C 카메라를 Oppila에 발송하여 기술 평가 및 펌웨어/드라이버 수정 논의

### 9-3. 객체 검출 적용 제약 분석

| 제약사항 | 심각도 | 극복 방법 |
|---------|:------:|----------|
| UYVY→RGB 변환 필요 | 중간 | `nvvidconv` GPU 가속 (~2ms) |
| `nvarguscamerasrc` 사용 불가 | 높음 | `v4l2src` 대체, 코드 수정 필요 |
| ISP 하드웨어 바이패스 | 높음 | 소프트웨어 AWB/AE/NR 또는 동일 카메라로 학습 |
| 해상도/FPS 제한 | 중간 | DT 오버레이 수정 |
| 추론 파이프라인 지연 | 낮음 | 네이티브 대비 ~5-25% 오버헤드 |

**권장 전략**: 동일 카메라로 학습 데이터 수집 → 전처리 생략 → TensorRT 최적화 (~5% 저하만)

### 9-4. 데이터시트 비교 (2026-03-06)

KT&C와 Sony 데이터시트를 상세 비교한 결과 LVDS 인터페이스는 동일:
- 30핀 커넥터 핀아웃: **완전 동일** (Sony p.70 실제 커넥터 핀아웃 기준)
- LVDS 포맷: THC63LVD 시리얼라이제이션, Y/Cb/Cr 4:2:2
- 픽셀 클럭: 동일 (148.5/74.25 MHz)
- 추천 수신 IC: 동일 (THC63LVD104C/1024)
- VESA/JEIDA: **양쪽 데이터시트 모두 미명시**

주의: Sony p.61 회로도의 CN001 핀 번호는 수신 보드측이며 카메라 핀아웃(p.70)과 다름.

### 9-5. 전체 재테스트 결과 (2026-03-06, 6가지 조합)

| # | 카메라 출력 | LVDS | DT 설정 | 결과 |
|---|-----------|------|---------|------|
| 1 | 1080p/30 (0x07) | Single | 1080p/60fps | Signal lost, uncorr_err |
| 2 | 1080p/60 (0x13) | Single | 1080p/60fps | Signal lost, uncorr_err |
| 3 | 1080p/60 (0x13) | Dual | 1080p/60fps | Signal lost, uncorr_err |
| 4 | 1080p/30 (0x07) | Single | 1080p/30fps | Signal lost, uncorr_err |
| 5 | 720p/60 (0x09) | Single | 720p/60fps | Signal lost, not-negotiated |
| 6 | 720p/30 (0x0F) | Single | 720p/60fps | Signal lost, not-negotiated |

**결론**: 6가지 조합 전부 "Signal lost". LT9211C가 KT&C LVDS 신호를 전혀 인식 못함.
포맷/DT 설정으로는 해결 불가 → **LT9211C 온보드 펌웨어 수정 필요**.

### 9-6. Oppila 3차 이메일 발송 (2026-03-06)

파일: `oppila_email_3rd.md`
내용: 데이터시트 비교 결과 + 6가지 테스트 결과 + KT&C 데이터시트 검토 요청 + 의견 요청
**상태: Oppila 응답 대기 중**

### 9-7. 결론 및 다음 단계

| 구분 | 내용 |
|------|------|
| 완료율 | ~70% (소프트웨어/통신 측면 완료) |
| 미해결 블로커 | 그린스크린 — LT9211C 펌웨어가 KT&C LVDS 신호 미인식 |
| 근본 원인 | LT9211C 온보드 MCU 펌웨어가 Sony 전용 초기화 |
| 보드 상태 | 하드웨어 정상 (Sony FCB-EV9520L로 출하 전 검증됨) |
| 현재 시스템 | DT 원본(1080p/60fps) 복원, 카메라 1080p/60 Single LVDS |

**다음 단계**: Oppila 3차 이메일 응답 대기 → 응답에 따라 방향 결정

| 옵션 | 설명 |
|------|------|
| **A. KT&C 카메라 Oppila 발송** | 펌웨어 수정 (배송 2-4주 + 추가 비용 미정) |
| **B. Sony FCB-EV9520L 구매** | 즉시 호환 보장 |
| **C. 오실로스코프 LVDS 신호 분석** | 구체적 차이점 파악 후 Oppila에 정보 제공 |
