#!/usr/bin/env python3
"""카메라 영상 출력 확인 스크립트 (GStreamer) - 저지연 버전
사용법:
  python3 view_camera_simple.py          # 기본 UYVY
  python3 view_camera_simple.py nv16     # NV16 포맷
"""

import gi
gi.require_version('Gst', '1.0')
from gi.repository import Gst, GLib
import signal
import sys

DEVICE = "/dev/video0"
WIDTH = 1920
HEIGHT = 1080

PIPELINES = {
    "uyvy": (
        f"v4l2src device={DEVICE} ! "
        f"video/x-raw,format=UYVY,width={WIDTH},height={HEIGHT} ! "
        f"videoconvert ! "
        f"autovideosink sync=false"
    ),
    "nv16": (
        f"v4l2src device={DEVICE} ! "
        f"video/x-raw,format=NV16,width={WIDTH},height={HEIGHT} ! "
        f"videoconvert ! "
        f"autovideosink sync=false"
    ),
}

def on_message(bus, message, loop):
    t = message.type
    if t == Gst.MessageType.EOS:
        print("스트림 종료 (EOS)")
        loop.quit()
    elif t == Gst.MessageType.ERROR:
        err, debug = message.parse_error()
        print(f"에러: {err.message}")
        print(f"디버그: {debug}")
        loop.quit()
    elif t == Gst.MessageType.STATE_CHANGED:
        if message.src.get_name() == "pipeline":
            old, new, pending = message.parse_state_changed()
            print(f"파이프라인 상태: {old.value_nick} -> {new.value_nick}")
    return True

def main():
    mode = sys.argv[1].lower() if len(sys.argv) > 1 else "uyvy"

    if mode not in PIPELINES:
        print(f"지원 모드: {', '.join(PIPELINES.keys())}")
        sys.exit(1)

    Gst.init(None)

    pipeline_str = PIPELINES[mode]
    print(f"모드: {mode}")
    print(f"파이프라인: {pipeline_str}")
    print("영상 창을 닫거나 Ctrl+C로 종료\n")

    pipeline = Gst.parse_launch(pipeline_str)
    pipeline.set_name("pipeline")

    bus = pipeline.get_bus()
    bus.add_signal_watch()

    loop = GLib.MainLoop()
    bus.connect("message", on_message, loop)

    signal.signal(signal.SIGINT, lambda *_: loop.quit())

    pipeline.set_state(Gst.State.PLAYING)

    try:
        loop.run()
    finally:
        pipeline.set_state(Gst.State.NULL)
        print("종료됨")

if __name__ == "__main__":
    main()
