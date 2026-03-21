#!/usr/bin/env python3
"""카메라 영상 출력 + VISCA 제어 스크립트 (저지연)

영상 창에 포커스 후 키보드 입력:
  +/=     Zoom In
  -       Zoom Out
  0       Zoom Home (최소)
  f       Auto Focus
  a       Auto Exposure ON
  w       Auto White Balance ON
  q/Esc   종료
"""

import gi
gi.require_version('Gst', '1.0')
from gi.repository import Gst, GLib
import smbus2
import time
import threading
import signal

DEVICE = "/dev/video0"
WIDTH = 1920
HEIGHT = 1080
I2C_BUS = 9
I2C_ADDR = 0x48


class VISCAController:
    def __init__(self):
        self.bus = smbus2.SMBus(I2C_BUS)
        self.lock = threading.Lock()
        self._init_uart()
        self._init_visca()

    def _write_reg(self, s, d):
        self.bus.write_byte_data(I2C_ADDR, (s << 3) | 0x00, d)

    def _read_reg(self, s):
        return self.bus.read_byte_data(I2C_ADDR, (s << 3) | 0x00)

    def _init_uart(self):
        self._write_reg(0x03, 0x80)
        self._write_reg(0x00, 0x60)
        self._write_reg(0x01, 0x00)
        self._write_reg(0x03, 0x03)
        self._write_reg(0x02, 0x07)
        time.sleep(0.01)
        self._write_reg(0x02, 0x01)

    def _init_visca(self):
        self._send([0x88, 0x30, 0x01, 0xFF], t=0.3)
        self._send([0x88, 0x01, 0x00, 0x01, 0xFF], t=0.3)

    def _flush(self):
        while self._read_reg(0x05) & 0x01:
            self._read_reg(0x00)

    def _send(self, cmd, t=0.5):
        self._flush()
        for b in cmd:
            while not (self._read_reg(0x05) & 0x20):
                time.sleep(0.005)
            self._write_reg(0x00, b)
        time.sleep(t)
        r = []
        while self._read_reg(0x05) & 0x01:
            r.append(self._read_reg(0x00))
        return r

    def send_cmd(self, cmd, t=0.5):
        with self.lock:
            return self._send(cmd, t)

    def zoom_tele(self):
        self.send_cmd([0x81, 0x01, 0x04, 0x07, 0x23, 0xFF], t=0.8)
        self.send_cmd([0x81, 0x01, 0x04, 0x07, 0x00, 0xFF], t=0.1)

    def zoom_wide(self):
        self.send_cmd([0x81, 0x01, 0x04, 0x07, 0x33, 0xFF], t=0.8)
        self.send_cmd([0x81, 0x01, 0x04, 0x07, 0x00, 0xFF], t=0.1)

    def zoom_home(self):
        self.send_cmd([0x81, 0x01, 0x04, 0x47, 0x00, 0x00, 0x00, 0x00, 0xFF], t=2.0)

    def auto_focus(self):
        self.send_cmd([0x81, 0x01, 0x04, 0x38, 0x02, 0xFF], t=0.3)
        self.send_cmd([0x81, 0x01, 0x04, 0x18, 0x01, 0xFF], t=1.0)

    def auto_exposure(self):
        self.send_cmd([0x81, 0x01, 0x04, 0x39, 0x00, 0xFF], t=0.3)

    def auto_wb(self):
        self.send_cmd([0x81, 0x01, 0x04, 0x35, 0x00, 0xFF], t=0.3)

    def close(self):
        self.bus.close()


def run_async(func, name):
    def worker():
        try:
            func()
            print(f"  [{name}] 완료")
        except Exception as e:
            print(f"  [{name}] 실패: {e}")
    threading.Thread(target=worker, daemon=True).start()


def handle_key(key, visca, loop):
    """키 입력 처리"""
    if key in ("plus", "equal", "KP_Add"):
        run_async(visca.zoom_tele, "Zoom In")
    elif key in ("minus", "KP_Subtract"):
        run_async(visca.zoom_wide, "Zoom Out")
    elif key in ("0", "KP_0"):
        run_async(visca.zoom_home, "Zoom Home")
    elif key in ("f", "F"):
        run_async(visca.auto_focus, "Auto Focus")
    elif key in ("a", "A"):
        run_async(visca.auto_exposure, "Auto Exp")
    elif key in ("w", "W"):
        run_async(visca.auto_wb, "Auto WB")
    elif key in ("q", "Q", "Escape"):
        print("종료 중...")
        loop.quit()


def on_message(bus, message, data):
    loop, visca = data
    t = message.type

    if t == Gst.MessageType.EOS:
        print("스트림 종료 (EOS)")
        loop.quit()
    elif t == Gst.MessageType.ERROR:
        err, debug = message.parse_error()
        print(f"에러: {err.message}")
        loop.quit()
    elif t == Gst.MessageType.ELEMENT:
        struct = message.get_structure()
        if struct and struct.get_name() == "GstNavigationMessage":
            event = struct.get_value("event")
            if event:
                nav_struct = event.get_structure()
                if nav_struct:
                    event_type = nav_struct.get_string("event")
                    if event_type == "key-press":
                        key = nav_struct.get_string("key")
                        print(f"  [KEY] {key}")
                        if key:
                            handle_key(key, visca, loop)
    return True


def main():
    Gst.init(None)

    visca = VISCAController()

    pipeline_str = (
        f"v4l2src device={DEVICE} ! "
        f"video/x-raw,format=UYVY,width={WIDTH},height={HEIGHT} ! "
        f"videoconvert ! "
        f"xvimagesink sync=false"
    )

    print("카메라 뷰어 + VISCA 제어")
    print("=" * 40)
    print("  영상 창 클릭 후 키 입력:")
    print("  +/=  Zoom In       -  Zoom Out")
    print("  0    Zoom Home     f  Auto Focus")
    print("  a    Auto Exp      w  Auto WB")
    print("  q    종료")
    print("=" * 40)

    pipeline = Gst.parse_launch(pipeline_str)

    bus = pipeline.get_bus()
    bus.add_signal_watch()

    loop = GLib.MainLoop()
    bus.connect("message", on_message, (loop, visca))

    signal.signal(signal.SIGINT, lambda *_: loop.quit())

    pipeline.set_state(Gst.State.PLAYING)

    try:
        loop.run()
    finally:
        pipeline.set_state(Gst.State.NULL)
        visca.close()
        print("종료됨")


if __name__ == "__main__":
    main()
