#!/bin/bash
#
# tp2_capture_test.sh
# TP2 UART 로그 캡처용 Jetson 측 테스트 스크립트
#
# 사용법:
#   1. MobaXterm에서 COM3/115200 시리얼 캡처를 먼저 시작
#   2. Jetson에서 sudo bash tp2_capture_test.sh 실행
#
# 각 단계 사이에 구분 마커를 echo하여 TP2 로그와 시간 대조 가능

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG="${SCRIPT_DIR}/jetson_tp2_test_$(date +%Y%m%d_%H%M%S).log"

echo "============================================" | tee $LOG
echo " TP2 Capture Test - $(date)" | tee -a $LOG
echo "============================================" | tee -a $LOG
echo "" | tee -a $LOG
echo "[!] MobaXterm에서 TP2 시리얼 캡처가 실행 중인지 확인하세요" | tee -a $LOG
echo "" | tee -a $LOG

# ──────────────────────────────────────────────
# Phase 1: 현재 상태 확인
# ──────────────────────────────────────────────
echo ">>> [Phase 1] 현재 상태 확인 - $(date +%H:%M:%S)" | tee -a $LOG

echo "--- lsmod (lt9211cmipi) ---" | tee -a $LOG
lsmod | grep lt9211 2>&1 | tee -a $LOG

echo "--- video device ---" | tee -a $LOG
ls -la /dev/video* 2>&1 | tee -a $LOG

echo "--- i2c devices (bus 9) ---" | tee -a $LOG
i2cdetect -y -r 9 2>&1 | tee -a $LOG

echo "" | tee -a $LOG

# ──────────────────────────────────────────────
# Phase 2: 드라이버 언로드
# ──────────────────────────────────────────────
echo ">>> [Phase 2] 드라이버 언로드 - $(date +%H:%M:%S)" | tee -a $LOG
rmmod lt9211cmipi 2>&1 | tee -a $LOG
sleep 3
echo "    드라이버 언로드 완료, 3초 대기 후 재로드" | tee -a $LOG
echo "" | tee -a $LOG

# ──────────────────────────────────────────────
# Phase 3: dmesg 클리어 + 드라이버 재로드
# ──────────────────────────────────────────────
echo ">>> [Phase 3] 드라이버 재로드 - $(date +%H:%M:%S)" | tee -a $LOG
dmesg -C
modprobe lt9211cmipi 2>&1 | tee -a $LOG
sleep 5
echo "    드라이버 로드 완료, 5초 대기" | tee -a $LOG

echo "--- dmesg (드라이버 로드 후) ---" | tee -a $LOG
dmesg 2>&1 | tee -a $LOG
echo "" | tee -a $LOG

# ──────────────────────────────────────────────
# Phase 4: 클럭 초기화 (rc.local)
# ──────────────────────────────────────────────
echo ">>> [Phase 4] 클럭 초기화 - $(date +%H:%M:%S)" | tee -a $LOG
bash "${SCRIPT_DIR}/rc.local" 2>&1 | tee -a $LOG
sleep 2
echo "" | tee -a $LOG

# ──────────────────────────────────────────────
# Phase 5: v4l2 디바이스 상태 확인
# ──────────────────────────────────────────────
echo ">>> [Phase 5] V4L2 디바이스 확인 - $(date +%H:%M:%S)" | tee -a $LOG
v4l2-ctl --device=/dev/video0 --all 2>&1 | tee -a $LOG
echo "" | tee -a $LOG

# ──────────────────────────────────────────────
# Phase 6: GStreamer 캡처 시도 (10초)
# ──────────────────────────────────────────────
echo ">>> [Phase 6] GStreamer 캡처 시도 (10초) - $(date +%H:%M:%S)" | tee -a $LOG
dmesg -C
timeout 10 gst-launch-1.0 v4l2src device=/dev/video0 num-buffers=60 \
  ! video/x-raw,format=UYVY \
  ! fakesink sync=false 2>&1 | tee -a $LOG
echo "" | tee -a $LOG

# ──────────────────────────────────────────────
# Phase 7: 캡처 후 dmesg
# ──────────────────────────────────────────────
echo ">>> [Phase 7] 캡처 후 dmesg - $(date +%H:%M:%S)" | tee -a $LOG
dmesg 2>&1 | tee -a $LOG
echo "" | tee -a $LOG

# ──────────────────────────────────────────────
# Phase 8: 이미지 캡처 시도 (증거용)
# ──────────────────────────────────────────────
echo ">>> [Phase 8] 이미지 캡처 시도 - $(date +%H:%M:%S)" | tee -a $LOG
timeout 10 gst-launch-1.0 v4l2src device=/dev/video0 num-buffers=1 \
  ! video/x-raw,format=UYVY \
  ! videoconvert \
  ! jpegenc \
  ! filesink location=${SCRIPT_DIR}/tp2_test_capture.jpg 2>&1 | tee -a $LOG
echo "" | tee -a $LOG

# ──────────────────────────────────────────────
# 완료
# ──────────────────────────────────────────────
echo "============================================" | tee -a $LOG
echo " 테스트 완료 - $(date)" | tee -a $LOG
echo "============================================" | tee -a $LOG
echo "" | tee -a $LOG
echo "Jetson 로그: $LOG" | tee -a $LOG
echo "TP2 UART 로그: MobaXterm에서 저장" | tee -a $LOG
echo "" | tee -a $LOG
echo "Oppila에 전달할 파일:" | tee -a $LOG
echo "  1. TP2 UART 로그 (MobaXterm 저장분) - 보드 전원 ON 시" | tee -a $LOG
echo "  2. TP2 UART 로그 (MobaXterm 저장분) - 이 스크립트 실행 시" | tee -a $LOG
echo "  3. $LOG" | tee -a $LOG
