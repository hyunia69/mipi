#!/bin/bash
#
# quick_capture_test.sh
# K2/K3 버튼으로 싱크 잡힌 후 바로 실행하는 캡처 테스트
#
# 사용법:
#   1. MIPI 보드 전원 ON → 10초 대기 → K2, K3 버튼 순서대로 누름
#   2. TP2 UART 로그에서 타이밍 정상(1920x1080) 확인
#   3. sudo bash quick_capture_test.sh 실행
#

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG="${SCRIPT_DIR}/quick_capture_$(date +%Y%m%d_%H%M%S).log"

echo "============================================" | tee $LOG
echo " Quick Capture Test - $(date)" | tee -a $LOG
echo "============================================" | tee -a $LOG
echo "" | tee -a $LOG

# ──────────────────────────────────────────────
# Phase 1: 클럭 초기화
# ──────────────────────────────────────────────
echo ">>> [Phase 1] 클럭 초기화 - $(date +%H:%M:%S)" | tee -a $LOG
bash "${SCRIPT_DIR}/rc.local" 2>&1 | tee -a $LOG
sleep 1
echo "" | tee -a $LOG

# ──────────────────────────────────────────────
# Phase 2: 현재 상태 확인
# ──────────────────────────────────────────────
echo ">>> [Phase 2] 현재 상태 확인 - $(date +%H:%M:%S)" | tee -a $LOG
echo "--- video device ---" | tee -a $LOG
ls -la /dev/video* 2>&1 | tee -a $LOG
echo "--- v4l2 format ---" | tee -a $LOG
v4l2-ctl --device=/dev/video0 --get-fmt-video 2>&1 | tee -a $LOG
echo "" | tee -a $LOG

# ──────────────────────────────────────────────
# Phase 3: 화면에 영상 표시 (5초)
# ──────────────────────────────────────────────
echo ">>> [Phase 3] 화면 영상 표시 (5초) - $(date +%H:%M:%S)" | tee -a $LOG
dmesg -C

# nveglglessink → xvimagesink → autovideosink 순서로 시도
DISPLAYED=0
for SINK in nveglglessink xvimagesink autovideosink; do
  echo "    ${SINK} 시도..." | tee -a $LOG
  timeout 5 gst-launch-1.0 v4l2src device=/dev/video0 \
    ! "video/x-raw,format=UYVY,width=1920,height=1080" \
    ! videoconvert \
    ! ${SINK} 2>&1 | tee -a $LOG
  RESULT=${PIPESTATUS[0]}
  if [ $RESULT -eq 0 ] || [ $RESULT -eq 124 ]; then
    DISPLAYED=1
    break
  fi
  echo "    ${SINK} 실패, 다음 시도..." | tee -a $LOG
done

if [ $DISPLAYED -eq 0 ]; then
  echo "    [!] 모든 비디오 싱크 실패" | tee -a $LOG
fi
echo "" | tee -a $LOG

# ──────────────────────────────────────────────
# Phase 4: 이미지 캡처
# ──────────────────────────────────────────────
echo ">>> [Phase 4] 이미지 캡처 - $(date +%H:%M:%S)" | tee -a $LOG
CAPTURE_FILE="${SCRIPT_DIR}/quick_capture_$(date +%Y%m%d_%H%M%S).jpg"
timeout 10 gst-launch-1.0 v4l2src device=/dev/video0 num-buffers=1 \
  ! "video/x-raw,format=UYVY,width=1920,height=1080" \
  ! videoconvert \
  ! jpegenc \
  ! filesink location="${CAPTURE_FILE}" 2>&1 | tee -a $LOG
echo "    캡처 파일: ${CAPTURE_FILE}" | tee -a $LOG
echo "" | tee -a $LOG

# ──────────────────────────────────────────────
# Phase 5: dmesg 확인
# ──────────────────────────────────────────────
echo ">>> [Phase 5] dmesg - $(date +%H:%M:%S)" | tee -a $LOG
dmesg 2>&1 | tee -a $LOG
echo "" | tee -a $LOG

# ──────────────────────────────────────────────
# 완료
# ──────────────────────────────────────────────
echo "============================================" | tee -a $LOG
echo " 테스트 완료 - $(date)" | tee -a $LOG
echo "============================================" | tee -a $LOG
echo "로그: $LOG" | tee -a $LOG
