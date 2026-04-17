pragma Singleton
import QtQuick

QtObject {
    // === Colors - Premium Observatory Dark Theme ===
    readonly property color backgroundColor: "#0D1117"
    readonly property color surfaceColor: Qt.rgba(1, 1, 1, 0.07)
    readonly property color surfaceHover: Qt.rgba(1, 1, 1, 0.12)
    readonly property color glassBorder: Qt.rgba(1, 1, 1, 0.12)
    readonly property color glassHighlight: Qt.rgba(1, 1, 1, 0.06)

    readonly property color primaryColor: "#3B82F6"
    readonly property color accentColor: "#F59E0B"
    readonly property color ctaStart: "#3B82F6"
    readonly property color ctaEnd: "#8B5CF6"

    readonly property color textPrimary: "#F8FAFC"
    readonly property color textSecondary: "#94A3B8"
    readonly property color textMuted: "#64748B"

    readonly property color successColor: "#10B981"
    readonly property color errorColor: "#EF4444"
    readonly property color warningColor: "#F59E0B"

    // === Holographic Palette (information layer) ===
    readonly property color holoTeal: "#22D3EE"
    readonly property color cosmicPurple: "#A78BFA"
    readonly property color amberWarm: "#FBBF24"
    readonly property color holoGridLine: Qt.rgba(0.13, 0.83, 0.93, 0.06)

    // === Typography ===
    property string fontFamily: "Pretendard"
    property string assetsUrl: ""
    function init(primary, assets) {
        if (primary && primary.length > 0) fontFamily = primary;
        if (assets && assets.length > 0) assetsUrl = assets;
    }
    readonly property int fontHero: 64
    readonly property int fontDisplay: 48
    readonly property int fontTitle: 32
    readonly property int fontHeading: 24
    readonly property int fontBody: 20
    readonly property int fontCaption: 16
    readonly property int fontSmall: 14

    // === Spacing ===
    readonly property int spacingXL: 48
    readonly property int spacingLG: 32
    readonly property int spacingMD: 24
    readonly property int spacingSM: 16
    readonly property int spacingXS: 8

    // === Sizing ===
    readonly property int buttonHeight: 72
    readonly property int buttonRadius: 16
    readonly property int cardRadius: 16
    readonly property int panelRadius: 24

    // === Animation ===
    readonly property int animFast: 150
    readonly property int animNormal: 300
    readonly property int animSlow: 500

    // === Effect tokens (MultiEffect) ===
    readonly property real glowRadiusSm: 0.4
    readonly property real glowRadiusMd: 0.7
    readonly property real glowRadiusLg: 1.0
    readonly property int shadowOffsetSm: 4
    readonly property int shadowOffsetMd: 8
    readonly property int shadowOffsetLg: 16
    readonly property real shadowBlurSoft: 0.6
    readonly property real shadowBlurDeep: 1.0
    readonly property real blurMaxPanel: 32.0

    // === Runtime quality flags ===
    // Set by main.py from config or settings UI.
    property bool enableEffects: true
    property bool enableParticles: true
    property bool enableBlur: true
}
