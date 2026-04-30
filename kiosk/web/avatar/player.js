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
    // Expose for tests/debugging
    if (typeof window !== "undefined") window.__player = this;
  }

  async init() {
    this.onStatus("init");
    this.scene = new THREE.Scene();
    this.scene.background = null; // transparent

    const w = this.canvas.clientWidth || 400;
    const h = this.canvas.clientHeight || 500;
    this.camera = new THREE.PerspectiveCamera(35, w / h, 0.1, 100);
    this.camera.position.set(0, 1.4, 2.4);
    this.camera.lookAt(0, 1.3, 0);

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

    // Load avatar GLB
    await this._loadAvatar(`${ASSETS_BASE}/icaro.glb`);

    // Load bundle index
    const r = await fetch(`${ASSETS_BASE}/bundles/index.json`);
    if (!r.ok) throw new Error(`bundles/index.json HTTP ${r.status}`);
    this._bundleIndex = await r.json();

    // WebGL context loss handler
    this.canvas.addEventListener("webglcontextlost", (e) => {
      e.preventDefault();
      this.onStatus("ctx-lost");
      this.onError("webglcontextlost");
    }, false);
    this.canvas.addEventListener("webglcontextrestored", async () => {
      this.onStatus("ctx-restored");
      await this._loadAvatar(`${ASSETS_BASE}/icaro.glb`);
    }, false);

    // Resize
    window.addEventListener("resize", () => this._onResize());
    this._onResize();

    // Render loop
    this._lastT = performance.now();
    const tick = (t) => {
      const dt = (t - this._lastT) / 1000;
      this._lastT = t;
      if (this.mixer) this.mixer.update(dt);
      this.renderer.render(this.scene, this.camera);
      this._raf = requestAnimationFrame(tick);
    };
    this._raf = requestAnimationFrame(tick);

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

    return new Promise((resolve) => {
      const onFinish = (e) => {
        if (e.action === action) {
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
    if (this._raf) cancelAnimationFrame(this._raf);
    this._raf = null;
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
