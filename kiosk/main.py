import sys
import argparse
from pathlib import Path

from PySide6.QtCore import QUrl
from PySide6.QtGui import QFontDatabase, QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine


FONT_PREFERENCES = ("Pretendard", "Noto Sans KR", "Malgun Gothic", "Apple SD Gothic Neo")


def load_application_fonts(font_dir: Path) -> list[str]:
    loaded_families: list[str] = []
    if not font_dir.exists():
        return loaded_families
    for pattern in ("*.otf", "*.ttf"):
        for font_file in sorted(font_dir.glob(pattern)):
            font_id = QFontDatabase.addApplicationFont(str(font_file))
            if font_id == -1:
                print(f"[fonts] Failed to load: {font_file.name}", file=sys.stderr)
                continue
            for family in QFontDatabase.applicationFontFamilies(font_id):
                if family not in loaded_families:
                    loaded_families.append(family)
    return loaded_families


def resolve_primary_font(loaded_families: list[str]) -> str:
    system_families = set(QFontDatabase.families())
    available = set(loaded_families) | system_families
    for candidate in FONT_PREFERENCES:
        if candidate in available:
            return candidate
    return QGuiApplication.font().family()


def main() -> int:
    parser = argparse.ArgumentParser(description="Digital Telescope Kiosk")
    parser.add_argument("--theme", choices=["holo", "minimal", "future"], default="holo", help="UI Theme Style")
    args, _ = parser.parse_known_args()

    app = QGuiApplication(sys.argv)
    app.setApplicationName("Digital Telescope Kiosk")
    app.setOrganizationName("Dasam")

    base_dir = Path(__file__).resolve().parent
    assets_dir = base_dir / "assets"

    loaded = load_application_fonts(assets_dir / "fonts")
    primary_font = resolve_primary_font(loaded)
    print(f"[fonts] Loaded: {loaded or '(none)'}  |  Primary: {primary_font}")
    print(f"[theme] Active Style: {args.theme}")

    engine = QQmlApplicationEngine()

    ctx = engine.rootContext()
    ctx.setContextProperty("ASSETS_URL", QUrl.fromLocalFile(str(assets_dir)).toString())
    ctx.setContextProperty("PRIMARY_FONT", primary_font)
    ctx.setContextProperty("appTheme", args.theme)

    qml_dir = base_dir / "qml"
    engine.addImportPath(str(qml_dir))

    qml_file = qml_dir / "Main.qml"
    engine.load(QUrl.fromLocalFile(str(qml_file)))

    if not engine.rootObjects():
        print("Failed to load QML", file=sys.stderr)
        return -1

    return app.exec()


if __name__ == "__main__":
    sys.exit(main())
