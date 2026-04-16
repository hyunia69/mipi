# DeepStream + Qt EGLFS 하이브리드 키오스크 앱 구현 계획

## Context

현재 `view_camera.py`는 GStreamer + xvimagesink로 X Window 위에서 카메라 영상을 표시하고, 키보드로 VISCA 카메라를 제어한다. 상용 키오스크 제품으로 발전시키기 위해:

1. **X Window 제거** → Qt EGLFS로 직접 렌더링 (부팅 속도, 보안, 안정성)
2. **AI 객체 인식 추가** → DeepStream nvinfer + TensorRT (Jetson 최적 경로)
3. **터치 UI** → QML로 애니메이션 바운딩 박스, 컨트롤 패널, 설정 화면
4. **기존 VISCA 코드 포팅** → I2C/VISCA 프로토콜 로직 재사용 + QThread 스레드 생명주기 재설계

**아키텍처 선택: 옵션 C (DeepStream + Qt EGLFS 하이브리드)**
- DeepStream의 `nvinfer`로 GPU 최적 AI 추론
- Qt QML로 자유로운 UI (nvosd 대신)
- `appsink` 기반 프레임 브리징 (qml6glsink은 PySide6에서 빌드 복잡도 너무 높음)

---

## 아키텍처

```
GStreamer Pipeline (별도 스레드):
  v4l2src(UYVY 1080p60) → nvvidconv(→NV12 NVMM) → tee
    ├─ [Display] nvvidconv(→BGRx) → videorate(30fps) → appsink
    └─ [AI] queue → nvstreammux(1920x1080) → nvinfer → [probe] → fakesink
                     ↑ 원본 해상도 유지, nvinfer가 내부적으로 모델 입력 크기로 리사이즈
                       좌표는 nvstreammux 해상도(1920x1080) 기준으로 반환

Qt Main Thread (EGLFS):
  appsink frame → FrameBridge → VideoItem(QQuickItem, GPU texture upload)
  nvinfer metadata → pad probe → DetectionModel → QML Repeater(바운딩 박스)
  VISCA commands → VISCAWorker(QThread) → I2C bus 9
```

**성능 예상 (Orin Nano, YOLOv8s FP16):**
- 디스플레이: 30fps (appsink BGRx → QSGTexture, 프레임당 GPU↔CPU 왕복 ~5-10ms 예상)
- AI 추론: 15-20fps (nvinfer interval=2, ~20ms/프레임)
- QML 오버레이: <3ms
- 전체 지연: ~50-80ms

> **핵심 리스크**: appsink → QImage → QSGTexture 경로는 프레임마다 GPU→CPU→GPU 복사가
> 발생한다. 1080p BGRx 30fps 기준 ~240MB/s 처리량이며, DDR 대역폭(~25GB/s)상 여유가
> 있으나 DMA 지연과 캐시 오버헤드로 실측 5-10ms가 예상된다. 이 경로의 성능이
> Phase 0-1의 진행 여부를 결정하는 게이트 조건이다.
> 실패 시 대안: EGLImage/DMA-BUF 직접 임포트 (CPU 왕복 제거, 구현 난이도 높음)

---

## 프로젝트 구조

```
D:/dasam/mipi/kiosk-app/
├── main.py                     # 진입점 (QT_QPA_PLATFORM=eglfs)
├── requirements.txt
├── core/
│   ├── pipeline.py             # GStreamer 파이프라인 관리 (tee, appsink, nvinfer)
│   ├── frame_bridge.py         # GStreamer→QML 프레임 전달 (QObject, Signal)
│   ├── video_item.py           # QQuickItem (QSGSimpleTextureNode로 GPU 텍스처)
│   ├── detection_model.py      # QAbstractListModel (바운딩 박스 데이터)
│   └── visca_controller.py     # VISCAWorker(QObject) + QThread (기존 코드 포팅)
├── qml/
│   ├── main.qml                # ApplicationWindow (풀스크린)
│   ├── OverlayLayer.qml        # 바운딩 박스 Repeater + 애니메이션
│   ├── BoundingBoxDelegate.qml # 개별 감지 박스 (글로우, 페이드인)
│   ├── StatusBar.qml           # FPS, 추론시간, 객체수
│   ├── ControlPanel.qml        # 카메라 제어 터치 버튼
│   ├── SettingsDrawer.qml      # 설정 패널 (모델, 임계값, 간격)
│   └── style/
│       ├── Theme.qml           # 색상/폰트/크기 싱글톤
│       └── IconButton.qml      # 재사용 버튼 컴포넌트
├── models/
│   ├── config_yolov8.txt       # nvinfer 설정
│   ├── labels.txt              # 클래스 라벨 (COCO 80개)
│   └── yolov8s.onnx            # ONNX 모델 (첫 실행 시 .engine 생성)
├── config/
│   ├── app_config.json         # 런타임 설정 (임계값, 모델 등)
│   └── eglfs.json              # Qt EGLFS KMS 설정
├── scripts/
│   ├── setup_clocks.sh         # rc.local 클럭 락 (기존 코드)
│   ├── build_engine.sh         # trtexec ONNX→TensorRT 변환
│   └── kiosk.service           # systemd 자동시작 서비스
└── tests/
    ├── test_pipeline.py        # GStreamer 단독 테스트
    ├── test_qt_eglfs.py        # Qt EGLFS 단독 테스트
    └── test_visca.py           # VISCA 통신 테스트
```

---

## 구현 단계

### Phase 0: 환경 확인 및 의존성 설치

**목표**: Jetson에서 PySide6 EGLFS + DeepStream이 동작하는지 확인

| # | 작업 | 검증 방법 |
|---|------|----------|
| 0.1 | `pip3 install PySide6 smbus2 numpy` | import 성공 |
| 0.2 | EGLFS 테스트: 간단한 QML 창 표시 | `QT_QPA_PLATFORM=eglfs` 실행 |
| 0.3 | DeepStream pyds 설치/확인 | `import pyds` 성공 |
| 0.4 | YOLOv8s ONNX 다운로드 + TensorRT 엔진 빌드 | `trtexec --onnx=yolov8s.onnx --fp16` |
| 0.5 | 기존 `view_camera.py` 동작 확인 | 영상 출력 + VISCA 제어 |
| 0.6 | **appsink → QImage → QSGTexture 성능 측정** | 아래 게이트 조건 참조 |

**Phase 0-1 게이트 조건 (appsink 경로 성능):**
- 테스트: `v4l2src ! nvvidconv ! appsink` → QImage → VideoItem(QQuickItem) → EGLFS 표시
- **통과 기준**: 1080p 30fps에서 프레임당 복사+텍스처 업로드 지연 ≤ 15ms
- **실패 시 대안**: EGLImage/DMA-BUF 직접 임포트로 전환 (GstBuffer → DMA-BUF fd → EGLImageKHR → QSGTexture)
- 이 게이트를 통과하지 못하면 Phase 1 이후 전체 일정에 영향. 조기 검증 필수

**위험 요소**: PySide6 aarch64 EGLFS 호환성 → Phase 0.2에서 조기 확인  
**대안**: PyQt6 또는 C++ Qt6

---

### Phase 1: Qt EGLFS 영상 출력 (view_camera.py 대체)

**목표**: appsink → QQuickItem으로 1080p 30fps 영상 표시

**수정/생성 파일:**
- `kiosk-app/main.py` (신규)
- `kiosk-app/core/pipeline.py` (신규) — 디스플레이 전용 파이프라인
- `kiosk-app/core/frame_bridge.py` (신규) — QObject, frameReady Signal
- `kiosk-app/core/video_item.py` (신규) — QQuickItem, updatePaintNode()
- `kiosk-app/qml/main.qml` (신규) — VideoItem만 풀스크린

**GStreamer 파이프라인 (Phase 1):**
```
v4l2src device=/dev/video0
! video/x-raw,format=UYVY,width=1920,height=1080
! nvvidconv
! video/x-raw,format=BGRx
! appsink name=sink emit-signals=true max-buffers=1 drop=true sync=false
```

**핵심 로직:**
- `appsink` new-sample 콜백에서 GstBuffer → QImage(Format_RGB32)
- `QMetaObject.invokeMethod()`로 Qt 메인 스레드에 안전하게 전달
- `VideoItem.updatePaintNode()`에서 QSGSimpleTextureNode로 GPU 텍스처 업로드

**성능 게이트 (Phase 0.6에서 시작, Phase 1에서 확정):**
- appsink map + QImage 생성 + QSGTexture 업로드의 총 지연 측정
- ≤ 15ms/프레임 → appsink 경로 확정, Phase 2 진행
- \> 15ms/프레임 → DMA-BUF/EGLImage 경로로 전환 (별도 설계 필요)

**검증**: 1080p 영상 30fps, 티어링/끊김 없음, EGLFS 풀스크린, 프레임 지연 측정 로그 포함

---

### Phase 2: VISCA 카메라 제어 통합

**목표**: 터치 버튼 + 키보드 단축키로 카메라 제어

**재사용 코드**: `view_camera.py:29-97` (VISCAController의 I2C/VISCA 프로토콜 로직)

**수정/생성 파일:**
- `kiosk-app/core/visca_controller.py` (신규) — VISCAWorker(QObject) + QThread 래핑
- `kiosk-app/qml/ControlPanel.qml` (신규) — 터치 버튼 6개 + 설정
- `kiosk-app/qml/style/IconButton.qml` (신규)
- `kiosk-app/qml/main.qml` (수정) — ControlPanel + Keys.onPressed 추가

**포팅 방식 (I2C/VISCA 로직 재사용 + 스레드 생명주기 재설계):**
- `_write_reg()`, `_read_reg()`, `_init_uart()`, `_send()`, `_flush()` → 프레임워크 무관, 그대로 재사용
- `zoom_tele()` 등 6개 메서드 → `@Slot()` 데코레이터 추가
- **스레드 모델 변경**: `threading.Thread` + `threading.Lock` → `QThread` + `moveToThread()` 패턴
- **SMBus 핸들 생명주기**: worker 스레드의 `started` 시그널에서 `SMBus()` 생성, `finished`에서 `close()` (메인 스레드에서 생성하면 thread affinity 위반)
- **종료 순서**: `pipeline.stop()` → `visca_thread.quit()` → `visca_thread.wait()` → `SMBus.close()` 보장
- `busyChanged` Signal로 UI 버튼 비활성화

**키보드 매핑 (기존과 동일):**
- `+/=`: Zoom In, `-`: Zoom Out, `0`: Zoom Home
- `f`: Auto Focus, `a`: Auto Exposure, `w`: Auto WB, `q`: 종료

**검증**: 터치 버튼 클릭 → 카메라 반응, 키보드 단축키 동작

---

### Phase 3: DeepStream AI 추론 파이프라인

**목표**: YOLOv8 실시간 객체 인식, 감지 결과를 Python으로 추출

**참조**: `MIPI_DOCUMENT.md:506-581` (추론 파이프라인 패턴)

**수정/생성 파일:**
- `kiosk-app/core/pipeline.py` (수정) — tee 분기, nvinfer 경로 추가
- `kiosk-app/core/detection_model.py` (신규) — QAbstractListModel
- `kiosk-app/core/frame_bridge.py` (수정) — detectionsChanged Signal 추가
- `kiosk-app/models/config_yolov8.txt` (신규)
- `kiosk-app/models/labels.txt` (신규)

**확장된 GStreamer 파이프라인:**
```
v4l2src device=/dev/video0
  ! video/x-raw,format=UYVY,width=1920,height=1080,framerate=60/1
  ! nvvidconv
  ! video/x-raw(memory:NVMM),format=NV12
  ! tee name=t

# Display path (30fps, appsink으로 Qt에 전달)
t.
  ! queue max-size-buffers=2 leaky=downstream
  ! nvvidconv
  ! video/x-raw,format=BGRx,width=1920,height=1080
  ! videorate
  ! video/x-raw,framerate=30/1
  ! appsink name=displaysink emit-signals=true max-buffers=1 drop=true sync=false

# Inference path (원본 해상도 → nvstreammux → nvinfer 내부 리사이즈)
t.
  ! queue max-size-buffers=2 leaky=downstream
  ! mux.sink_0
  nvstreammux name=mux
    batch-size=1
    width=1920
    height=1080
    live-source=1
    batched-push-timeout=33333
  ! nvinfer name=infer config-file-path=models/config_yolov8.txt
  ! fakesink sync=false
```

**nvstreammux 설정 근거:**
- `width=1920 height=1080`: 원본 해상도 유지. nvinfer가 내부에서 모델 입력 크기(640x640)로 리사이즈하고, `NvDsObjectMeta.rect_params` 좌표를 이 해상도(1920x1080) 기준으로 반환. QML에서 별도 좌표 변환 불필요.
- `live-source=1`: 라이브 카메라 소스 (타임스탬프 기반 배칭 비활성화)
- `batched-push-timeout=33333`: 33ms (30fps 기준), 입력이 없을 때 대기 상한
- `batch-size=1`: 단일 스트림
- **메모리 타입**: tee 이전의 nvvidconv가 `memory:NVMM` NV12를 출력하므로, nvstreammux 입력은 NVMM 버퍼. 별도 caps 필터 불필요.

**메타데이터 추출 (pad probe):**
```python
# nvinfer src pad에 probe 설치
# NvDsBatchMeta → NvDsFrameMeta → NvDsObjectMeta
# rect_params의 좌표는 nvstreammux 해상도(1920x1080) 기준
# → {class_id, label, confidence, left, top, width, height}
# → detectionsChanged Signal로 QML에 전달 (추가 좌표 변환 없음)
```

**nvinfer 설정 (config_yolov8.txt):**
- `network-mode=2` (FP16)
- `interval=2` (3프레임마다 추론)
- `process-mode=1` (primary detector)
- `maintain-aspect-ratio=1` (letterbox 전처리, 왜곡 방지)
- ONNX → TensorRT 엔진 자동 생성

**검증**: 콘솔에 감지 결과 출력, 좌표/라벨/신뢰도 정확, 10분 연속 안정

---

### Phase 4: QML 감지 오버레이 UI

**목표**: 애니메이션 바운딩 박스 + 상태바

**수정/생성 파일:**
- `kiosk-app/qml/OverlayLayer.qml` (신규) — Repeater + detectionModel
- `kiosk-app/qml/BoundingBoxDelegate.qml` (신규) — 박스 + 라벨 + 애니메이션
- `kiosk-app/qml/StatusBar.qml` (신규) — FPS, 추론시간, 객체수
- `kiosk-app/qml/style/Theme.qml` (신규) — 색상/폰트 싱글톤
- `kiosk-app/qml/main.qml` (수정) — OverlayLayer + StatusBar 추가

**UI 구성:**
```
┌──────────────────────────────────────────┐
│ [FPS: 30] [AI: 18ms] [Objects: 3]        │ ← StatusBar (상단)
│                                          │
│   ┌─────────┐                            │
│   │ Car     │← 글로우 테두리              │
│   │  95.2%  │← 페이드인 라벨             │
│   └─────────┘                            │
│          ┌──────┐                        │
│          │Person│← SmoothedAnimation     │
│          │ 87%  │   (위치 이동 부드럽게)  │
│          └──────┘                        │
│                                          │
│  ┌──┐ ┌──┐ ┌──┐ ┌──┐ ┌──┐ ┌──┐ ┌──┐   │ ← ControlPanel
│  │Z+│ │Z-│ │ZH│ │AF│ │AE│ │WB│ │⚙ │   │   (하단, 반투명)
│  └──┘ └──┘ └──┘ └──┘ └──┘ └──┘ └──┘   │
└──────────────────────────────────────────┘
```

**바운딩 박스 좌표**: nvinfer의 `rect_params`가 nvstreammux 해상도(1920x1080) 기준 좌표를 반환하므로, QML에서 별도 좌표 변환 없이 직접 사용

**검증**: 바운딩 박스가 객체를 정확히 추적, 애니메이션 부드러움, 3프레임 지속

---

### Phase 5: 설정 패널 + 런타임 조정

**수정/생성 파일:**
- `kiosk-app/qml/SettingsDrawer.qml` (신규) — Drawer, 슬라이더, 콤보박스
- `kiosk-app/config/app_config.json` (신규) — 설정 저장/로드
- `kiosk-app/core/pipeline.py` (수정) — apply_settings() 메서드

**설정 항목**: 모델 선택, 신뢰도 임계값, 추론 간격, 박스 표시 토글

---

### Phase 6: 상용화 (부팅 자동시작, 에러 복구, 워치독)

**수정/생성 파일:**
- `kiosk-app/scripts/kiosk.service` (신규) — systemd 유닛
- `kiosk-app/scripts/setup_clocks.sh` (신규) — rc.local에서 추출

**systemd 서비스:**
```ini
[Unit]
Description=Kiosk Camera AI App
After=multi-user.target

[Service]
Type=notify                                # sd_notify 사용 시 필수
ExecStartPre=/path/to/setup_clocks.sh      # 클럭 락
ExecStart=QT_QPA_PLATFORM=eglfs python3 main.py
Restart=on-failure
RestartSec=5
WatchdogSec=30                             # 앱이 주기적으로 heartbeat 필요 (아래 참조)

[Install]
WantedBy=multi-user.target
```

**WatchdogSec 동작 조건**: 앱 코드에서 `sd_notify("WATCHDOG=1")`을 주기적으로 호출해야 함. 이것 없이 WatchdogSec만 설정하면 30초마다 프로세스가 강제 종료됨.
```python
# main.py에서 구현 필요 (Phase 6)
import sdnotify
notifier = sdnotify.SystemdNotifier()
notifier.notify("READY=1")  # 서비스 시작 완료 알림
# QTimer로 WatchdogSec/2 (15초) 간격 호출:
notifier.notify("WATCHDOG=1")
```

---

## 위험 요소 및 대안

| 위험 | 심각도 | 확인 시점 | 게이트 | 대안 |
|------|--------|----------|--------|------|
| PySide6 EGLFS 미동작 | 치명적 | Phase 0.2 | 실패 시 중단 | PyQt6 또는 C++ Qt6 |
| **appsink→QSGTexture 지연 > 15ms** | **치명적** | **Phase 0.6~1** | **실패 시 경로 전환** | **EGLImage/DMA-BUF 직접 임포트** |
| pyds 미설치/비호환 | 높음 | Phase 0.3 | 실패 시 대안 검토 | 소스 빌드 또는 OpenCV+TensorRT 대체 |
| nvstreammux caps 협상 실패 | 중간 | Phase 3 | - | live-source, timeout, 메모리 타입 조정 |
| LT9211C 부팅 시 LVDS 락 불안정 | 중간 | Phase 6 | - | 재시도 루프 + 스플래시 화면 |

---

## 검증 계획

| Phase | 테스트 | 성공 기준 |
|-------|--------|----------|
| 0 | `test_qt_eglfs.py` | EGLFS 창 표시, import 성공 |
| 1 | `test_pipeline.py` | 1080p 30fps, 티어링 없음 |
| 2 | `test_visca.py` | 6개 VISCA 명령 모두 응답 |
| 3 | `test_pipeline.py` (확장) | 감지 결과 출력, 10분 안정 |
| 4 | 육안 확인 | 바운딩 박스 정확, 애니메이션 부드러움 |
| 5 | 설정 변경 후 동작 | 임계값/간격 변경 즉시 반영 |
| 6 | 재부팅 테스트 | 전원 ON → 영상+AI 자동 시작 (<30초) |
