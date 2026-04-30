"""VISCA-over-I2C 카메라 줌 컨트롤.

view_camera.py의 VISCAController를 키오스크용으로 이식하고, hold-to-zoom
의미에 맞춰 start/stop 메서드를 분리. QML에서 호출 가능한 CameraController
QObject를 함께 제공한다.
"""

from __future__ import annotations

import sys
import threading
import time

from PySide6.QtCore import QObject, Property, Signal, Slot

I2C_BUS = 9
I2C_ADDR = 0x48

VISCA_ZOOM_TELE_START = [0x81, 0x01, 0x04, 0x07, 0x23, 0xFF]
VISCA_ZOOM_WIDE_START = [0x81, 0x01, 0x04, 0x07, 0x33, 0xFF]
VISCA_ZOOM_STOP = [0x81, 0x01, 0x04, 0x07, 0x00, 0xFF]


class VISCAController:
    """SMBus 기반 UART 브리지(0x48)를 통한 VISCA 명령 전송."""

    def __init__(self, bus_num: int = I2C_BUS, addr: int = I2C_ADDR):
        import smbus2  # 지연 import: demo 환경에 smbus2가 없어도 모듈 로드는 통과
        self.bus = smbus2.SMBus(bus_num)
        self.addr = addr
        self.lock = threading.Lock()
        self._init_uart()
        self._init_visca()

    def _write_reg(self, s: int, d: int) -> None:
        self.bus.write_byte_data(self.addr, (s << 3) | 0x00, d)

    def _read_reg(self, s: int) -> int:
        return self.bus.read_byte_data(self.addr, (s << 3) | 0x00)

    def _init_uart(self) -> None:
        self._write_reg(0x03, 0x80)
        self._write_reg(0x00, 0x60)
        self._write_reg(0x01, 0x00)
        self._write_reg(0x03, 0x03)
        self._write_reg(0x02, 0x07)
        time.sleep(0.01)
        self._write_reg(0x02, 0x01)

    def _init_visca(self) -> None:
        self._send([0x88, 0x30, 0x01, 0xFF], t=0.3)
        self._send([0x88, 0x01, 0x00, 0x01, 0xFF], t=0.3)

    def _flush(self) -> None:
        while self._read_reg(0x05) & 0x01:
            self._read_reg(0x00)

    def _send(self, cmd: list[int], t: float = 0.05) -> list[int]:
        self._flush()
        for b in cmd:
            while not (self._read_reg(0x05) & 0x20):
                time.sleep(0.005)
            self._write_reg(0x00, b)
        time.sleep(t)
        r: list[int] = []
        while self._read_reg(0x05) & 0x01:
            r.append(self._read_reg(0x00))
        return r

    def send_cmd(self, cmd: list[int], t: float = 0.05) -> list[int]:
        with self.lock:
            return self._send(cmd, t)

    def zoom_tele_start(self) -> None:
        self.send_cmd(VISCA_ZOOM_TELE_START)

    def zoom_wide_start(self) -> None:
        self.send_cmd(VISCA_ZOOM_WIDE_START)

    def zoom_stop(self) -> None:
        self.send_cmd(VISCA_ZOOM_STOP)

    def close(self) -> None:
        try:
            self.bus.close()
        except Exception:
            pass


class CameraController(QObject):
    """QML rootContext에 주입되는 카메라 컨트롤러.

    - mode == "live"일 때만 VISCA 하드웨어를 초기화한다.
    - 슬롯 호출은 데몬 스레드로 디스패치되어 QML 스레드를 블록하지 않는다.
    - VISCA 초기화에 실패하면 enabled == False가 되고 모든 슬롯은 no-op.
    """

    enabledChanged = Signal()

    def __init__(self, mode: str, parent: QObject | None = None):
        super().__init__(parent)
        self._enabled = False
        self._visca: VISCAController | None = None

        if mode != "live":
            print("[camera] non-live mode — VISCA 초기화 건너뜀", flush=True)
            return

        try:
            self._visca = VISCAController()
            self._enabled = True
            print(f"[camera] VISCA 초기화 완료 (bus={I2C_BUS}, addr=0x{I2C_ADDR:02X})", flush=True)
        except Exception as exc:  # noqa: BLE001
            print(f"[camera] VISCA 초기화 실패 — 줌 비활성화: {exc}", file=sys.stderr, flush=True)
            self._visca = None
            self._enabled = False

    @Property(bool, notify=enabledChanged)
    def enabled(self) -> bool:
        return self._enabled

    def _dispatch(self, fn) -> None:
        if not self._enabled or self._visca is None:
            return
        threading.Thread(target=fn, daemon=True).start()

    @Slot()
    def startZoomIn(self) -> None:
        if self._visca is None:
            return
        self._dispatch(self._visca.zoom_tele_start)

    @Slot()
    def startZoomOut(self) -> None:
        if self._visca is None:
            return
        self._dispatch(self._visca.zoom_wide_start)

    @Slot()
    def stopZoom(self) -> None:
        if self._visca is None:
            return
        self._dispatch(self._visca.zoom_stop)

    @Slot()
    def close(self) -> None:
        if self._visca is not None:
            try:
                self._visca.zoom_stop()
            except Exception:  # noqa: BLE001
                pass
            self._visca.close()
            self._visca = None
        if self._enabled:
            self._enabled = False
            self.enabledChanged.emit()
