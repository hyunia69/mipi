import QtQuick
import QtQuick.Controls
import QtWebEngine
import QtWebChannel

/*
 * AvatarWidget — Sign language avatar overlay.
 *
 * Lifecycle:
 *   onCreate -> WebEngineView loads AVATAR_URL
 *   bridge.onReady (QWebChannel) -> ready=true, watchdog cancelled
 *   gloss change -> playGloss via channel
 *   render process crash -> rebuildCount++, reload (max 3 retries)
 *   ready watchdog (default 5s): if no ready, force reload
 *   visible=false / destruction -> stop loop timer + dispose
 *
 * Repeat policy:
 *   repeatIntervalMs > 0  -> after finished, wait that long then play again.
 *   repeatIntervalMs == 0 -> play once, stay idle.
 */
Item {
    id: root

    // --- Public API ---
    property string gloss: ""
    property bool autoplay: true
    property int repeatIntervalMs: 8000   // 0 = play once
    property int readyTimeoutMs: 5000
    property int maxRebuilds: 3

    // --- Read-only state (exposed for tests) ---
    property int rebuildCount: 0
    property int playCount: 0
    property int watchdogFires: 0
    property bool ready: false
    property bool _giveUp: false

    signal playbackStarted(string gloss)
    signal playbackFinished(string gloss)
    signal playerError(string message)

    visible: typeof AVATAR_ENABLED !== "undefined" ? AVATAR_ENABLED && !_giveUp : !_giveUp

    // QWebChannel bridge object exposed as `kiosk` to JS.
    QtObject {
        id: bridge
        WebChannel.id: "kiosk"

        signal sendPlayGloss(string name)
        signal sendSetVisible(bool v)
        signal sendDispose()

        function onReady() {
            root.ready = true;
            watchdog.stop();
            if (root.autoplay && root.gloss.length > 0) {
                _doPlay(root.gloss);
            }
        }
        function onFinished(name) {
            root.playbackFinished(name);
            if (root.repeatIntervalMs > 0 && root.visible && !root._giveUp) {
                repeatTimer.restart();
            }
        }
        function onError(msg) {
            root.playerError(msg);
        }
    }

    WebChannel {
        id: channel
        registeredObjects: [bridge]
    }

    // The actual web view, recreated on render-process crash.
    Loader {
        id: viewLoader
        anchors.fill: parent
        active: !root._giveUp
        sourceComponent: webEngineComp
    }

    Component {
        id: webEngineComp
        WebEngineView {
            id: web
            anchors.fill: parent
            backgroundColor: "transparent"
            settings.localContentCanAccessFileUrls: true
            settings.localContentCanAccessRemoteUrls: false
            webChannel: channel
            url: typeof AVATAR_URL !== "undefined" ? AVATAR_URL : ""

            onLoadingChanged: function(info) {
                if (info.status === WebEngineView.LoadFailedStatus) {
                    root.playerError("load failed: " + info.errorString);
                }
            }
            onRenderProcessTerminated: function(terminationStatus, exitCode) {
                _onCrash("renderer terminated status=" + terminationStatus + " exit=" + exitCode);
            }
        }
    }

    Timer {
        id: watchdog
        interval: root.readyTimeoutMs
        running: !root.ready && !root._giveUp && viewLoader.active
        repeat: false
        onTriggered: {
            root.watchdogFires++;
            _onCrash("watchdog: no ready within " + root.readyTimeoutMs + "ms");
        }
    }

    Timer {
        id: repeatTimer
        interval: root.repeatIntervalMs
        repeat: false
        onTriggered: {
            if (root.visible && !root._giveUp && root.gloss.length > 0) {
                _doPlay(root.gloss);
            }
        }
    }

    onGlossChanged: {
        if (ready && autoplay && gloss.length > 0) _doPlay(gloss);
    }

    onVisibleChanged: {
        if (!visible) {
            repeatTimer.stop();
        }
    }

    Component.onDestruction: {
        repeatTimer.stop();
        if (ready) bridge.sendDispose();
    }

    // ---- Internal helpers ----

    function _doPlay(name) {
        playCount++;
        playbackStarted(name);
        bridge.sendPlayGloss(name);
    }

    function _onCrash(reason) {
        if (root._giveUp) return;       // already gave up; do nothing
        rebuildCount++;
        if (rebuildCount > maxRebuilds) {
            _giveUp = true;
            rebuildCount = maxRebuilds; // cap the visible count
            playerError("giving up after " + maxRebuilds + " rebuilds: " + reason);
            return;
        }
        ready = false;
        viewLoader.active = false;
        viewLoader.active = true;
    }

    // For tests — callable via metaObject().invokeMethod(root, "_simulateCrash")
    function _simulateCrash() {
        _onCrash("simulated");
    }
}
