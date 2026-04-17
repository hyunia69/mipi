pragma Singleton
import QtQuick

QtObject {
    // === Theme Engine Control ===
    property string activeStyle: typeof appTheme !== "undefined" ? appTheme : "holo"
    readonly property bool isMinimal: activeStyle === "minimal"
    readonly property bool isFuture: activeStyle === "future"
    readonly property bool isHolo: activeStyle === "holo"

    // === Colors ===
    readonly property color backgroundColor: isMinimal ? "#020408" : (isFuture ? "#050510" : "#0D1117")
    readonly property color surfaceColor: isMinimal ? Qt.rgba(1, 1, 1, 0.05) : (isFuture ? Qt.rgba(0.2, 0.4, 1.0, 0.1) : Qt.rgba(1, 1, 1, 0.07))
    readonly property color surfaceHover: isMinimal ? Qt.rgba(1, 1, 1, 0.08) : (isFuture ? Qt.rgba(0.2, 0.5, 1.0, 0.15) : Qt.rgba(1, 1, 1, 0.12))
    readonly property color glassBorder: isMinimal ? Qt.rgba(1, 1, 1, 0.1) : (isFuture ? Qt.rgba(0.3, 0.6, 1.0, 0.3) : Qt.rgba(1, 1, 1, 0.12))
    readonly property color glassHighlight: isMinimal ? Qt.rgba(1, 1, 1, 0.04) : (isFuture ? Qt.rgba(0.5, 0.8, 1.0, 0.2) : Qt.rgba(1, 1, 1, 0.06))

    readonly property color primaryColor: isMinimal ? "#F8FAFC" : (isFuture ? "#A855F7" : "#3B82F6")
    readonly property color accentColor: isMinimal ? "#94A3B8" : (isFuture ? "#FF00E5" : "#F59E0B")
    readonly property color ctaStart: isMinimal ? "#334155" : (isFuture ? "#7C3AED" : "#3B82F6")
    readonly property color ctaEnd: isMinimal ? "#0F172A" : (isFuture ? "#DB2777" : "#8B5CF6")

    readonly property color textPrimary: "#F8FAFC"
    readonly property color textSecondary: isMinimal ? "#CBD5E1" : (isFuture ? "#E2E8F0" : "#94A3B8")
    readonly property color textMuted: isMinimal ? "#475569" : (isFuture ? "#94A3B8" : "#64748B")

    readonly property color successColor: "#10B981"
    readonly property color errorColor: "#EF4444"
    readonly property color warningColor: "#F59E0B"

    // === Future Palette (Vibrant Neo-Tokyo / Chrome) ===
    readonly property color futureCyan: "#22D3EE"
    readonly property color futureMagenta: "#FF00E5"
    readonly property color futureViolet: "#8B5CF6"
    readonly property color chromeHighlight: Qt.rgba(1, 1, 1, 0.4)

    // === Holographic Palette ===
    readonly property color holoTeal: isMinimal ? "#F8FAFC" : (isFuture ? "#22D3EE" : "#22D3EE")
    readonly property color cosmicPurple: isMinimal ? "#94A3B8" : (isFuture ? "#FF00E5" : "#A78BFA")
    readonly property color amberWarm: isMinimal ? "#E2E8F0" : (isFuture ? "#FBBF24" : "#FBBF24")
    readonly property color holoGridLine: isMinimal ? "transparent" : (isFuture ? Qt.rgba(0.66, 0.33, 1.0, 0.12) : Qt.rgba(0.13, 0.83, 0.93, 0.06))

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
    readonly property int buttonRadius: isMinimal ? 8 : (isFuture ? 20 : 16)
    readonly property int cardRadius: isMinimal ? 12 : (isFuture ? 24 : 16)
    readonly property int panelRadius: isMinimal ? 20 : (isFuture ? 32 : 24)

    // === Animation ===
    readonly property int animFast: 150
    readonly property int animNormal: 300
    readonly property int animSlow: 500

    // === Effect tokens ===
    readonly property real glowRadiusSm: isMinimal ? 0.0 : (isFuture ? 0.6 : 0.4)
    readonly property real glowRadiusMd: isMinimal ? 0.0 : (isFuture ? 1.0 : 0.7)
    readonly property real glowRadiusLg: isMinimal ? 0.0 : (isFuture ? 1.5 : 1.0)
    readonly property int shadowOffsetSm: 4
    readonly property int shadowOffsetMd: 8
    readonly property int shadowOffsetLg: 16
    readonly property real shadowBlurSoft: 0.6
    readonly property real shadowBlurDeep: 1.0
    readonly property real blurMaxPanel: 32.0

    // === Feature Toggles ===
    readonly property bool showScanlines: !isMinimal
    readonly property bool enableEffects: true
    readonly property bool enableParticles: !isMinimal
    readonly property bool enableBlur: true
    readonly property bool enable3D: isFuture
}
