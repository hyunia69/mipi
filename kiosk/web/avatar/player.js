import * as THREE from "./vendor/three.module.min.js";
import { GLTFLoader } from "./vendor/GLTFLoader.js";

const ASSETS_BASE = "./assets";

export class Player {
  constructor(canvas, opts = {}) {
    this.canvas = canvas;
    this.onStatus = opts.onStatus || (() => {});
    this.onFinished = opts.onFinished || (() => {});
    this.onError = opts.onError || (() => {});
    this.ready = false;
    this.scene = null;
    this.camera = null;
    this.renderer = null;
    this.mixer = null;
    this.avatarRoot = null;
    this._activeAction = null;
    this._bundleIndex = null;
    this._clipCache = new Map();
    this._raf = null;
    this._lastT = 0;
    this._pendingReject = null;
    this._onCtxLost = null;
    this._onCtxRestored = null;
    this._onResizeBound = null;
    this._tickBound = null;
    // Expose for tests/debugging
    if (typeof window !== "undefined") window.__player = this;
  }

  async init() {
    this.onStatus("init");
    this.scene = new THREE.Scene();
    this.scene.background = null; // transparent

    const w = this.canvas.clientWidth || 400;
    const h = this.canvas.clientHeight || 500;
    this.camera = new THREE.PerspectiveCamera(45, w / h, 0.01, 100);
    // Initial position; _fitCameraToAvatar will refine based on the loaded GLB's bbox.
    this.camera.position.set(0, 0.85, 3.06);
    this.camera.lookAt(0, 0.77, 0);

    this.renderer = new THREE.WebGLRenderer({
      canvas: this.canvas,
      alpha: true,
      antialias: true,
      preserveDrawingBuffer: false,
    });
    this.renderer.setPixelRatio(window.devicePixelRatio || 1);
    this.renderer.setSize(w, h, false);
    this.renderer.setClearColor(0x000000, 0);

    const key = new THREE.DirectionalLight(0xffffff, 1.2);
    key.position.set(1, 2, 1.5);
    this.scene.add(key);
    this.scene.add(new THREE.AmbientLight(0xffffff, 0.6));

    try {
      await this._loadAvatar(`${ASSETS_BASE}/icaro.glb`);
      const r = await fetch(`${ASSETS_BASE}/bundles/index.json`);
      if (!r.ok) throw new Error(`bundles/index.json HTTP ${r.status}`);
      this._bundleIndex = await r.json();
    } catch (err) {
      // Tear down partial allocation so a retry doesn't leak the WebGL context
      if (this._raf) { cancelAnimationFrame(this._raf); this._raf = null; }
      if (this.renderer) {
        try { this.renderer.dispose(); this.renderer.forceContextLoss(); } catch (e) { /* ignore */ }
        this.renderer = null;
      }
      this.scene = null;
      this.camera = null;
      throw err;
    }

    // WebGL context loss handler
    this._onCtxLost = (e) => {
      e.preventDefault();
      this.onStatus("ctx-lost");
      this.onError("webglcontextlost");
    };
    this._onCtxRestored = async () => {
      this.onStatus("ctx-restored");
      await this._loadAvatar(`${ASSETS_BASE}/icaro.glb`);
      // Defensive: restart the render loop if it stopped
      if (!this._raf && this._tickBound) {
        this._lastT = performance.now();
        this._raf = requestAnimationFrame(this._tickBound);
      }
    };
    this._onResizeBound = () => this._onResize();

    this.canvas.addEventListener("webglcontextlost", this._onCtxLost, false);
    this.canvas.addEventListener("webglcontextrestored", this._onCtxRestored, false);
    window.addEventListener("resize", this._onResizeBound);
    this._onResize();

    // Render loop
    this._lastT = performance.now();
    this._tickBound = (t) => {
      const dt = Math.min((t - this._lastT) / 1000, 0.1);
      this._lastT = t;
      if (this.mixer) this.mixer.update(dt);
      if (this.renderer && this.scene && this.camera) {
        this.renderer.render(this.scene, this.camera);
      }
      this._raf = requestAnimationFrame(this._tickBound);
    };
    this._raf = requestAnimationFrame(this._tickBound);

    this.ready = true;
    this.onStatus("ready");
  }

  async _loadAvatar(url) {
    const loader = new GLTFLoader();
    const gltf = await new Promise((resolve, reject) =>
      loader.load(url, resolve, undefined, reject)
    );
    if (this.avatarRoot) {
      this.scene.remove(this.avatarRoot);
      this.avatarRoot = null;
    }
    this.avatarRoot = gltf.scene;
    this.scene.add(this.avatarRoot);
    this.mixer = new THREE.AnimationMixer(this.avatarRoot);
    this._fitCameraToAvatar();
  }

  _fitCameraToAvatar() {
    if (!this.avatarRoot || !this.camera) return;
    // Bbox-based framing (mirrors sls_brazil_player/players/sentence/index.html:991).
    // Recenter model so its feet sit at y=0, then place camera at 1.8x model height
    // away on z, half-height up, looking at ~45% of model height (chest level).
    const box = new THREE.Box3().setFromObject(this.avatarRoot);
    const center = box.getCenter(new THREE.Vector3());
    const size = box.getSize(new THREE.Vector3());
    this.avatarRoot.position.sub(new THREE.Vector3(center.x, box.min.y, center.z));
    // Frame the "signing space" — upper-thigh up to just above head, full
    // arm-span horizontally. Legs cropped (no meaning in Libras), hands
    // at any height visible. Distance ~1.0x model height in a 4:5 portrait
    // canvas yields ~3x apparent size vs. full-body framing.
    const targetY = size.y * 0.55;
    this.camera.position.set(0, size.y * 0.55, size.y * 1.4);
    this.camera.lookAt(0, targetY, 0);
    this.camera.updateProjectionMatrix();
  }

  _onResize() {
    if (!this.renderer || !this.camera) return;
    const w = this.canvas.clientWidth || this.canvas.parentElement.clientWidth;
    const h = this.canvas.clientHeight || this.canvas.parentElement.clientHeight;
    this.renderer.setSize(w, h, false);
    this.camera.aspect = w / h;
    this.camera.updateProjectionMatrix();
  }

  async _loadGlossClip(name) {
    if (this._clipCache.has(name)) return this._clipCache.get(name);
    const entry = this._bundleIndex.glosses.find((g) => g.key === name);
    if (!entry) throw new Error(`unknown gloss: ${name}`);
    const r = await fetch(`${ASSETS_BASE}/bundles/${entry.file}`);
    if (!r.ok) throw new Error(`gloss fetch HTTP ${r.status}: ${name}`);
    const json = await r.json();
    const clip = THREE.AnimationClip.parse(json);
    this._clipCache.set(name, clip);
    return clip;
  }

  async playGloss(name) {
    if (!this.ready) throw new Error("player not ready");
    const clip = await this._loadGlossClip(name);

    // Reject any in-flight promise from a previous playGloss
    if (this._pendingReject) {
      const reject = this._pendingReject;
      this._pendingReject = null;
      reject(new Error(`interrupted by: ${name}`));
    }
    if (this._activeAction) {
      this._activeAction.stop();
    }
    const action = this.mixer.clipAction(clip);
    action.reset();
    action.setLoop(THREE.LoopOnce, 1);
    action.clampWhenFinished = true;
    action.play();
    this._activeAction = action;
    this.onStatus(`play:${name}`);

    return new Promise((resolve, reject) => {
      this._pendingReject = reject;
      const onFinish = (e) => {
        if (e.action === action) {
          if (this._pendingReject === reject) this._pendingReject = null;
          this.mixer.removeEventListener("finished", onFinish);
          this.onStatus(`done:${name}`);
          this.onFinished(name);
          resolve(name);
        }
      };
      this.mixer.addEventListener("finished", onFinish);
    });
  }

  setVisible(visible) {
    this.canvas.style.visibility = visible ? "visible" : "hidden";
  }

  dispose() {
    if (this._pendingReject) {
      const reject = this._pendingReject;
      this._pendingReject = null;
      reject(new Error("disposed"));
    }
    if (this._raf) cancelAnimationFrame(this._raf);
    this._raf = null;
    if (this._onCtxLost) {
      this.canvas.removeEventListener("webglcontextlost", this._onCtxLost);
      this._onCtxLost = null;
    }
    if (this._onCtxRestored) {
      this.canvas.removeEventListener("webglcontextrestored", this._onCtxRestored);
      this._onCtxRestored = null;
    }
    if (this._onResizeBound) {
      window.removeEventListener("resize", this._onResizeBound);
      this._onResizeBound = null;
    }
    this._tickBound = null;
    if (this.mixer) {
      this.mixer.stopAllAction();
      this.mixer.uncacheRoot(this.avatarRoot);
      this.mixer = null;
    }
    if (this.avatarRoot) {
      this.scene.remove(this.avatarRoot);
      this.avatarRoot.traverse((obj) => {
        if (obj.geometry) obj.geometry.dispose();
        if (obj.material) {
          const mats = Array.isArray(obj.material) ? obj.material : [obj.material];
          for (const m of mats) {
            for (const k of Object.keys(m)) {
              if (m[k] && m[k].isTexture) m[k].dispose();
            }
            m.dispose();
          }
        }
      });
      this.avatarRoot = null;
    }
    this._clipCache.clear();
    if (this.renderer) {
      this.renderer.dispose();
      this.renderer.forceContextLoss();
      this.renderer = null;
    }
    this.ready = false;
    this.onStatus("disposed");
  }
}
