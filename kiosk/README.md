# Digital Telescope Kiosk

서울 관광지를 위한 **40배 줌 AI 망원경 키오스크**. Jetson Orin Nano를 타깃으로 하는 PySide6 + QML 풀스크린 앱이며, 실사 랜드마크 사진과 홀로그래픽 UI로 관측 체험을 시각화한다.

## 스크린 플로우

```
HomeScreen ──► LandmarkDetailScreen ──► PaymentScreen ──► ViewingScreen ──► SessionEndScreen
     │                  │                      │                │                    │
  랜드마크 카드        상세 정보 + CTA       1,000 KRW · 3분    라이브 뷰(실사,       Thank-you
  6곳 슬라이드         "이곳 보러 가기"       카드 결제         pan 시뮬레이션,      → 홈 자동 복귀
                                                                EXIT 버튼)
```

## 주요 기능

- **HomeScreen**: 서울 파노라마 실사 슬라이드쇼(Ken Burns), 별빛 파티클 레이어, 6개 랜드마크 카드, glass 스타일 `HeroCTA`
- **LandmarkDetailScreen**: 전면 히어로 이미지, 좌측 설명·역사, 우측 stats 카드 + "VIEW THIS LANDMARK" CTA
- **ViewingScreen**: 6개 실사 뷰(Seoul Panorama · Skyline · Namsan · Lotte · Hangang · Bukhansan)를 18초 간격으로 crossfade, `DetectionBox` 3개 라이브 감지 시뮬레이션, 좌하단 `END SESSION` + 확인 다이얼로그, 상단 View Indicator dots, 홀로그래픽 회전 크로스헤어, CRT 스캔라인 오버레이
- **공용 컴포넌트**: `TouchButton`, `LocationCard`, `GlassPanel`, `CountdownTimer`, `LandmarkInfoPanel`, `ZoomControls`, `StatusBar`, `AnnouncementBanner`, `Icon`(Lucide SVG 렌더러), `ScanlineOverlay`, `StarsBackdrop`, `HeroCTA`, `ExitConfirmDialog`
- **효과 레이어**: `QtQuick.Effects.MultiEffect` 기반 glow/shadow, 런타임 품질 토글(`Theme.enableEffects`, `enableParticles`, `enableBlur`)
- **데이터 출처 단일화**: `qml/LandmarkData.qml` 싱글톤이 6개 랜드마크의 이름·설명·역사·거리·방향·고도·썸네일 색과 이미지 경로 헬퍼를 모두 보유

## 요구사항

- Python 3.10 이상
- PySide6 6.5 이상 (개발 확인: 6.10.2)
- 운영: Jetson Orin Nano + JetPack 6.1, Qt EGLFS 플랫폼
- 개발: Windows/Linux/macOS 어디든 PySide6 런타임이 있으면 동작

## 설치

```bash
pip install -r requirements.txt
cp .env.example .env   # Unsplash/Pexels API 키가 있으면 채워넣음 (선택)
```

## 에셋 수집

`scripts/fetch_assets.py`는 폰트·아이콘·랜드마크 사진을 자동으로 수집한다. 우선순위는 **Unsplash → Pexels → Wikimedia Commons**이며, 앞 두 소스는 API 키가 있어야 한다. 키가 없으면 Wikimedia Commons만으로도 CC0/CC-BY/CC-BY-SA 이미지가 모두 받아진다.

```bash
python scripts/fetch_assets.py --all        # 폰트 + 아이콘 + 랜드마크 + 슬라이드쇼
python scripts/fetch_assets.py --fonts      # Pretendard OFL
python scripts/fetch_assets.py --icons      # Lucide SVG
python scripts/fetch_assets.py --landmarks  # 6곳 × hero/thumb/night
python scripts/fetch_assets.py --slideshow  # 서울 파노라마 5장
python scripts/fetch_assets.py --verify     # SHA-256 무결성 검사
```

각 파일의 출처·작가·라이선스·SHA-256은 `assets/metadata.json`에 기록된다(`assets/LICENSES.md`에서 요약 참조).

## 실행

```bash
python main.py                              # 개발용 (창 모드)
QT_QPA_PLATFORM=eglfs python main.py        # Jetson 배포용 (풀스크린 EGLFS)
```

`main.py`는 `assets/fonts/`의 Pretendard를 우선 로드하고 Noto Sans KR → Malgun Gothic 순으로 폴백한 뒤, QML `rootContext`에 `ASSETS_URL`과 `PRIMARY_FONT`를 주입한다. `Main.qml`에서 `Theme.init()`으로 이를 받아 싱글톤 `Theme`과 `LandmarkData`가 모두 공유한다.

## 개발 보조

```bash
pyside6-qmllint qml/**/*.qml                # QML 정적 분석
python scripts/smoke_test.py                # QML 로드 경고 0 확인
```

## 프로젝트 구조

```
kiosk/
├── main.py                   # 엔트리포인트 (폰트 로드, ASSETS_URL 주입)
├── requirements.txt
├── .env.example              # API 키 템플릿
├── assets/
│   ├── LICENSES.md           # 라이선스 요약 (상세는 metadata.json)
│   ├── manifest.json         # fetch_assets.py 입력: 랜드마크/아이콘/폰트 쿼리
│   ├── metadata.json         # (자동생성) 파일별 출처·작가·라이선스·SHA-256
│   ├── fonts/                # Pretendard OFL
│   ├── icons/                # Lucide SVG (currentColor → white 후처리)
│   ├── landmarks/
│   │   ├── namsan/           # hero.jpg, thumb.jpg, night.jpg
│   │   ├── lotte/
│   │   ├── hangang/
│   │   ├── gyeongbok/
│   │   ├── sixty3/
│   │   └── bukhan/
│   └── slideshow/            # seoul-01.jpg ~ seoul-05.jpg
├── qml/
│   ├── Main.qml              # ApplicationWindow + StackView 4-screen 라우팅
│   ├── Theme.qml             # Singleton: 색/폰트/간격/효과 토큰
│   ├── LandmarkData.qml      # Singleton: 랜드마크 메타데이터
│   ├── qmldir                # Singleton 등록
│   ├── screens/
│   │   ├── HomeScreen.qml
│   │   ├── LandmarkDetailScreen.qml
│   │   ├── PaymentScreen.qml
│   │   ├── ViewingScreen.qml
│   │   └── SessionEndScreen.qml
│   └── components/
│       ├── TouchButton.qml, HeroCTA.qml
│       ├── LocationCard.qml, GlassPanel.qml
│       ├── CountdownTimer.qml, ZoomControls.qml
│       ├── DetectionBox.qml, LandmarkInfoPanel.qml
│       ├── ImageSlideshow.qml, StarsBackdrop.qml, ScanlineOverlay.qml
│       ├── StatusBar.qml, AnnouncementBanner.qml
│       ├── Icon.qml, ExitConfirmDialog.qml
└── scripts/
    ├── fetch_assets.py       # 폰트·아이콘·사진 자동 수집
    └── smoke_test.py         # QML 로드 검증
```

## 라이선스

- 소스 코드: 본 저장소의 설정을 따른다
- 폰트: Pretendard — SIL OFL 1.1
- 아이콘: Lucide — ISC
- 사진: 파일별 `metadata.json` 참조 (Unsplash License / Pexels License / CC0 / CC-BY / CC-BY-SA). CC-BY-SA 자료는 **파생물 재배포 시 동일 라이선스 전파**에 유의. 상용 출시 전에는 `metadata.json` 전체 감사 권장.

## 관련 문서

- 상위 저장소의 `archi_design.md` — 추후 **DeepStream + Qt EGLFS 하이브리드** 카메라 파이프라인 통합 계획. `ViewingScreen`의 실사 배경은 DeepStream 카메라 피드로 대체 예정이며, 오버레이 컴포넌트(DetectionBox · CountdownTimer · ZoomControls · LandmarkInfoPanel)는 그대로 재사용된다.

## Avatar widget (Libras sign language)

The kiosk overlays a Brazilian sign-language avatar (Icaro) in the bottom-right
corner of the menu and live screens. It plays the `CASA` gloss every 8 seconds.

### One-time asset prep

The avatar consumes Three.js animation bundles from a sibling `sls_brazil_player/`
checkout. Run this once after cloning, and again whenever the gloss list changes:

```bash
cd kiosk
python scripts/prepare_avatar_assets.py \
    --source ../sls_brazil_player/public \
    --glosses CASA
```

This populates `kiosk/web/avatar/assets/` (gitignored) with `icaro.glb`,
`bundles/CASA.threejs.json`, `bundles/index.json`, and a `manifest.json`.

### Toggling at launch

- `--no-avatar`: hide the widget entirely.
- `--avatar-repeat-ms <int>`: change repeat interval in ms (`0` = play once).

Example: `python main.py --theme holo --avatar-repeat-ms 0` plays the avatar
once per screen entry instead of looping.

### Jetson EGLFS deployment

The kiosk auto-injects the right Chromium flags for EGLFS when launched with
`QT_QPA_PLATFORM=eglfs`:

```bash
QT_QPA_PLATFORM=eglfs python main.py --mode live --theme holo
```

main.py adds `--use-gl=egl --no-sandbox --disable-gpu-sandbox` to
`QTWEBENGINE_CHROMIUM_FLAGS` automatically.

### Dev / test dependencies

Test-only packages live in `requirements-dev.txt`:

```bash
pip install -r requirements-dev.txt
pytest tests/ -v
```

The full suite includes pytest-qt + QtWebEngine tests that spin up a headless
QWebEngineView — these need a desktop on Windows / macOS, but skip cleanly on
headless CI.

### Pre-flight WebEngine validation on new Jetsons

Run `scripts/spike_webengine.py` once to confirm Chromium boots under EGLFS
on the target Jetson. Fill in `docs/spike_webengine_results.md` with the
working environment variables.

### 12-hour soak

Memory leak check before production rollout:

```bash
ON_JETSON=1 python scripts/soak_avatar.py --hours 12 --out soak.csv
```

See `docs/soak_results.md` template for what to record.
