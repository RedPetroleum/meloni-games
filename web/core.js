// Meloni-Kern im Browser: WASI-Minimalsystem mit Dateien im Speicher + Engine-Aufrufe (web/meloni.wasm).
function createMeloni(wasmBytes, opts) {
  const files = new Map();          // Pfad -> Uint8Array
  const fds = new Map();            // fd -> {path, pos}
  let nextFd = 4, mem, inst, logBuf = "";
  const onLog = opts.onLog || (() => {});
  const onSave = opts.onSave || (() => {});
  const E = {SUCCESS: 0, BADF: 8, NOENT: 44, INVAL: 28};
  const dv = () => new DataView(mem.buffer);
  const u8 = () => new Uint8Array(mem.buffer);
  const str = (p, n) => new TextDecoder().decode(u8().subarray(p, p + n));
  const norm = (p) => p.replace(/^\/+/, "").replace(/^\.\//, "");

  const wasi = {
    clock_time_get(id, prec, out) { dv().setBigUint64(out, BigInt(Math.round(performance.now() * 1e6)), true); return 0; },
    fd_prestat_get(fd, buf) {
      if (fd !== 3) return E.BADF;
      dv().setUint32(buf, 0, true); dv().setUint32(buf + 4, 1, true); return 0;
    },
    fd_prestat_dir_name(fd, p, n) { if (fd !== 3) return E.BADF; u8()[p] = 47; return 0; },
    fd_fdstat_get(fd, buf) {
      const d = dv();
      d.setUint8(buf, fd <= 2 ? 2 : fd === 3 ? 3 : 4);
      d.setUint16(buf + 2, 0, true);
      d.setBigUint64(buf + 8, 0xffffffffffffffffn, true);
      d.setBigUint64(buf + 16, 0xffffffffffffffffn, true);
      return 0;
    },
    fd_fdstat_set_flags() { return 0; },
    path_open(dirfd, dflags, pp, pl, oflags, rb, ri, fdflags, out) {
      const path = norm(str(pp, pl));
      if (!files.has(path)) {
        if (!(oflags & 1)) return E.NOENT;
        files.set(path, new Uint8Array(0));
      } else if (oflags & 8) files.set(path, new Uint8Array(0));
      const fd = nextFd++;
      fds.set(fd, {path, pos: 0, append: !!(fdflags & 1)});
      dv().setUint32(out, fd, true);
      return 0;
    },
    fd_read(fd, iovs, n, out) {
      const f = fds.get(fd); if (!f) return E.BADF;
      const data = files.get(f.path) || new Uint8Array(0);
      let total = 0; const d = dv();
      for (let i = 0; i < n; i++) {
        const p = d.getUint32(iovs + i * 8, true), l = d.getUint32(iovs + i * 8 + 4, true);
        const chunk = data.subarray(f.pos, Math.min(f.pos + l, data.length));
        u8().set(chunk, p); f.pos += chunk.length; total += chunk.length;
        if (chunk.length < l) break;
      }
      d.setUint32(out, total, true); return 0;
    },
    fd_write(fd, iovs, n, out) {
      const d = dv(); let total = 0;
      for (let i = 0; i < n; i++) {
        const p = d.getUint32(iovs + i * 8, true), l = d.getUint32(iovs + i * 8 + 4, true);
        const bytes = u8().slice(p, p + l); total += l;
        if (fd === 1 || fd === 2) {
          logBuf += new TextDecoder().decode(bytes);
          let k; while ((k = logBuf.indexOf("\n")) >= 0) { onLog(logBuf.slice(0, k)); logBuf = logBuf.slice(k + 1); }
        } else {
          const f = fds.get(fd); if (!f) return E.BADF;
          let data = files.get(f.path);
          if (f.append) f.pos = data.length;
          if (f.pos + l > data.length) { const nd = new Uint8Array(f.pos + l); nd.set(data); data = nd; files.set(f.path, data); }
          data.set(bytes, f.pos); f.pos += l;
        }
      }
      d.setUint32(out, total, true); return 0;
    },
    fd_seek(fd, off, whence, out) {
      const f = fds.get(fd); if (!f) return E.BADF;
      const size = files.get(f.path).length;
      let pos = Number(off);
      if (whence === 1) pos += f.pos; else if (whence === 2) pos += size;
      if (pos < 0) return E.INVAL;
      f.pos = pos; dv().setBigUint64(out, BigInt(pos), true); return 0;
    },
    fd_close(fd) { fds.delete(fd); return 0; },
    fd_renumber() { return E.BADF; },
    path_filestat_get(fd, flags, pp, pl, buf) {
      const path = norm(str(pp, pl));
      const d = dv();
      for (let i = 0; i < 64; i++) d.setUint8(buf + i, 0);
      if (path === "" || path === ".") { d.setUint8(buf + 16, 3); return 0; }
      if (!files.has(path)) return E.NOENT;
      d.setUint8(buf + 16, 4);
      d.setBigUint64(buf + 24, 1n, true);
      d.setBigUint64(buf + 32, BigInt(files.get(path).length), true);
      return 0;
    },
    path_rename(fd, op, ol, nfd, np, nl) {
      const a = norm(str(op, ol)), b = norm(str(np, nl));
      if (!files.has(a)) return E.NOENT;
      files.set(b, files.get(a)); files.delete(a);
      onSave(b, files.get(b));
      return 0;
    },
    path_unlink_file(fd, pp, pl) { const p = norm(str(pp, pl)); if (!files.delete(p)) return E.NOENT; return 0; },
    path_remove_directory() { return E.NOENT; },
    proc_exit(code) { throw new Error("exit " + code); },
  };

  const module = new WebAssembly.Module(wasmBytes);
  inst = new WebAssembly.Instance(module, {wasi_snapshot_preview1: wasi});
  mem = inst.exports.memory;
  inst.exports._initialize();
  const X = inst.exports;

  function cstr(s) {
    const b = new TextEncoder().encode(s + "\0");
    const p = X.web_alloc(b.length); u8().set(b, p); return p;
  }
  const rgba = new Uint8ClampedArray(320 * 240 * 4);
  const lut = new Uint32Array(65536);
  for (let c = 0; c < 65536; c++) {
    const r = (c >> 11) & 31, g = (c >> 5) & 63, b = c & 31;
    lut[c] = 0xff000000 | (((b << 3) | (b >> 2)) << 16) | (((g << 2) | (g >> 4)) << 8) | ((r << 3) | (r >> 2));
  }
  const rgba32 = new Uint32Array(rgba.buffer);

  let running = false;
  return {
    files,
    start(gameBytes, saveBytes) {
      if (running) X.web_quit();
      files.clear(); fds.clear();
      files.set("game.mlg", gameBytes);
      if (saveBytes) files.set("game.sav", saveBytes);
      running = true;
      return X.web_init(cstr("/game.mlg"), cstr("/game.sav"));
    },
    frame(buttons) { return X.web_frame(buttons >>> 0); },
    pixels() {
      const p = X.web_fb() >> 1;
      const fb = new Uint16Array(mem.buffer, p * 2, 320 * 240);
      for (let i = 0; i < 76800; i++) rgba32[i] = lut[fb[i]];
      return rgba;
    },
    audio(frames) {
      const p = X.web_audio(frames);
      return new Int16Array(mem.buffer, p, frames * 2);
    },
    quit() { if (running) { X.web_quit(); running = false; } },
  };
}
if (typeof module !== "undefined") module.exports = createMeloni;  // Node (Tests)
