/**
 * Stub bridge — Task 7 will replace with QWebChannel-aware version.
 * For now, just signal alive so index.html doesn't error.
 */
export async function connectBridge(player) {
  window.__bridgeReady = true;
  return null;
}
