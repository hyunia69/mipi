import sys
import os
from pathlib import Path
from PySide6.QtGui import QGuiApplication, QFontDatabase
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtCore import QUrl


def main():
    app = QGuiApplication(sys.argv)
    app.setApplicationName("Digital Telescope Kiosk")
    app.setOrganizationName("Dasam")

    # Load custom fonts if available
    base_dir = Path(__file__).parent
    font_dir = base_dir / "assets" / "fonts"
    if font_dir.exists():
        for ext in ("*.otf", "*.ttf"):
            for font_file in font_dir.glob(ext):
                QFontDatabase.addApplicationFont(str(font_file))

    engine = QQmlApplicationEngine()

    # QML import paths
    qml_dir = base_dir / "qml"
    engine.addImportPath(str(qml_dir))

    # Load main QML
    qml_file = qml_dir / "Main.qml"
    engine.load(QUrl.fromLocalFile(str(qml_file)))

    if not engine.rootObjects():
        print("Failed to load QML")
        sys.exit(-1)

    sys.exit(app.exec())


if __name__ == "__main__":
    main()
