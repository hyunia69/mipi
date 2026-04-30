import os
import sys
from pathlib import Path

# Ensure kiosk/ is importable
KIOSK_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(KIOSK_ROOT))
sys.path.insert(0, str(KIOSK_ROOT / "scripts"))

# QtWebEngineQuick.initialize() must be called before ANY QApplication is created.
# Do it here at import time so it runs first regardless of test collection order.
try:
    from PySide6.QtWebEngineQuick import QtWebEngineQuick
    QtWebEngineQuick.initialize()
except ImportError:
    pass  # WebEngine not available; skip silently
