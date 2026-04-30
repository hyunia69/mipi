/**
 * connectBridge(player) — see player.js for the player API.
 *
 * QML side exposes a QtObject with WebChannel.id = "kiosk" that has:
 *   signals:  sendPlayGloss(string), sendSetVisible(bool), sendDispose()
 *   slots:    onReady(), onFinished(string), onError(string)
 *
 * We connect the QML signals to player methods, and call kiosk.onReady() once
 * we are alive. If no qt transport is present (plain browser test), set
 * window.__bridgeReady=true so tests/manual-debug pages still know we are alive.
 */
export async function connectBridge(player) {
  if (typeof qt === "undefined" || !qt.webChannelTransport) {
    window.__bridgeReady = true;
    return null;
  }

  return new Promise((resolve) => {
    // QWebChannel is a global from vendor/qwebchannel.js (loaded via classic <script>)
    // eslint-disable-next-line no-undef
    new QWebChannel(qt.webChannelTransport, (channel) => {
      const kiosk = channel.objects.kiosk;

      // player events -> QML
      player.onFinished = (name) => kiosk.onFinished(name);
      player.onError = (msg) => kiosk.onError(String(msg));

      // QML signals -> player methods
      kiosk.sendPlayGloss.connect((name) => {
        player.playGloss(name).catch((e) => kiosk.onError(String(e)));
      });
      kiosk.sendSetVisible.connect((v) => player.setVisible(!!v));
      kiosk.sendDispose.connect(() => player.dispose());

      // Tell QML we're alive
      kiosk.onReady();
      window.__bridgeReady = true;
      resolve(kiosk);
    });
  });
}
