import os
import sys
from pathlib import Path

# Ensure kiosk/ is importable
KIOSK_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(KIOSK_ROOT))
sys.path.insert(0, str(KIOSK_ROOT / "scripts"))
