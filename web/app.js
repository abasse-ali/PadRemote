'use strict';
(() => {
  const $ = (s, r = document) => r.querySelector(s);
  const $$ = (s, r = document) => Array.from(r.querySelectorAll(s));

  // ================================================================ stockage
  const store = {
    get(k, d) {
      try { const v = localStorage.getItem('padremote.' + k); return v === null ? d : JSON.parse(v); } catch { return d; }
    },
    set(k, v) {
      try { localStorage.setItem('padremote.' + k, JSON.stringify(v)); } catch { /* stockage indisponible */ }
    },
  };

  const DEFAULTS = {
    sens: 1.5, accel: 0.6, tap: true, longpress: false,
    scroll: 1, natural: true, smooth: true, inertia: true, strip: true, haptic: true,
  };
  const S = Object.assign({}, DEFAULTS, store.get('settings', {}));
  const saveSettings = () => store.set('settings', S);

  // ================================================================== icônes
  const ICONS = {
    mouse: '<rect x="6" y="2.5" width="12" height="19" rx="6"/><path d="M12 6.5v3.5"/>',
    keyboard: '<rect x="2" y="5.5" width="20" height="13" rx="2.5"/><path d="M6 9.5h.01M10 9.5h.01M14 9.5h.01M18 9.5h.01M6 13h.01M18 13h.01M9 14.5h6"/>',
    music: '<path d="M9 18V5l12-2v13"/><circle cx="6" cy="18" r="3"/><circle cx="18" cy="16" r="3"/>',
    bolt: '<path d="M13 2 4 14h7l-1 8 9-12h-7l1-8z"/>',
    sliders: '<path d="M4 21v-7M4 10V3M12 21v-9M12 8V3M20 21v-5M20 12V3M1 14h6M9 8h6M17 16h6"/>',
    volDown: '<path d="M11 5 6 9H2v6h4l5 4V5z"/><path d="M15.5 8.5a5 5 0 0 1 0 7"/>',
    volUp: '<path d="M11 5 6 9H2v6h4l5 4V5z"/><path d="M15.5 8.5a5 5 0 0 1 0 7M19 5a10 10 0 0 1 0 14"/>',
    mute: '<path d="M11 5 6 9H2v6h4l5 4V5z"/><path d="m23 9-6 6M17 9l6 6"/>',
    prev: '<path d="M19 20 9 12l10-8v16zM5 19V5"/>',
    next: '<path d="m5 4 10 8-10 8V4zM19 5v14"/>',
    playpause: '<path d="m3 5 9 7-9 7V5zM16 5v14M21 5v14"/>',
    stop: '<rect x="5" y="5" width="14" height="14" rx="2"/>',
    chevL: '<path d="m15 18-6-6 6-6"/>',
    chevR: '<path d="m9 18 6-6-6-6"/>',
    chevU: '<path d="m18 15-6-6-6 6"/>',
    chevD: '<path d="m6 9 6 6 6-6"/>',
    lock: '<rect x="4" y="11" width="16" height="10" rx="2"/><path d="M8 11V7a4 4 0 0 1 8 0v4"/>',
    monitor: '<rect x="2" y="3" width="20" height="14" rx="2"/><path d="M8 21h8M12 17v4"/>',
    moon: '<path d="M21 12.8A9 9 0 1 1 11.2 3a7 7 0 0 0 9.8 9.8z"/>',
    restart: '<path d="M3 12a9 9 0 1 0 3-6.7L3 8"/><path d="M3 3v5h5"/>',
    power: '<path d="M18.4 6.6a9 9 0 1 1-12.8 0M12 2v10"/>',
    logout: '<path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4M16 17l5-5-5-5M21 12H9"/>',
    play: '<path d="m6 4 14 8-14 8V4z"/>',
    full: '<path d="M8 3H5a2 2 0 0 0-2 2v3M21 8V5a2 2 0 0 0-2-2h-3M3 16v3a2 2 0 0 0 2 2h3M16 21h3a2 2 0 0 0 2-2v-3"/>',
    backspace: '<path d="M21 4H8l-7 8 7 8h13a2 2 0 0 0 2-2V6a2 2 0 0 0-2-2z"/><path d="m18 9-6 6M12 9l6 6"/>',
    enter: '<path d="M9 10 4 15l5 5"/><path d="M20 4v7a4 4 0 0 1-4 4H4"/>',
    x: '<path d="M18 6 6 18M6 6l12 12"/>',
    back: '<path d="M11 17 6 12l5-5M18 17l-5-5 5-5"/>',
    fwd: '<path d="m13 17 5-5-5-5M6 17l5-5-5-5"/>',
  };
  const icon = n => `<svg viewBox="0 0 24 24" aria-hidden="true">${ICONS[n] || ''}</svg>`;

  // =================================================================== toast
  let toastTimer = 0;
  function toast(msg, ms = 1800) {
    const t = $('#toast');
    t.textContent = msg;
    t.classList.add('show');
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => t.classList.remove('show'), ms);
  }

  // ================================================================ haptique
  // iOS 18+ : un <input switch> déclenche un retour haptique quand on le bascule.
  const hapLabel = (() => {
    const wrap = document.createElement('div');
    wrap.style.cssText = 'position:fixed;left:-200px;top:0;width:1px;height:1px;overflow:hidden;opacity:0;pointer-events:none';
    wrap.innerHTML = '<input type="checkbox" switch id="hap-sw" tabindex="-1"><label for="hap-sw"></label>';
    document.body.appendChild(wrap);
    return wrap.querySelector('label');
  })();
  function haptic() {
    if (!S.haptic) return;
    if (navigator.vibrate) { navigator.vibrate(10); return; }
    const a = document.activeElement;
    if (a && a !== document.body) return; // ne pas fermer le clavier ouvert
    try { hapLabel.click(); } catch { /* ignoré */ }
  }

  // =============================================================== connexion
  const params = new URLSearchParams(location.search);
  let pin = params.get('k') || store.get('pin', '');
  if (params.get('k')) store.set('pin', pin);

  let ws = null;
  let authed = false;
  let retry = 0;
  let retryTimer = 0;
  let pingTimer = 0;
  let lastPong = 0;
  let pcName = '';
  let lastOfflineToast = 0;

  function setStatus(state, text) {
    document.body.classList.toggle('online', state === 'online');
    document.body.classList.toggle('offline', state === 'offline');
    $('#status-text').textContent = text;
    if (state !== 'online') { $('#latency').textContent = ''; $('#set-lat').textContent = '—'; }
  }

  function connect() {
    clearTimeout(retryTimer);
    if (ws && ws.readyState <= 1) return;
    if (!pin) { showLogin(); return; }
    setStatus('connecting', 'Connexion…');
    let sock;
    try {
      sock = new WebSocket(`${location.protocol === 'https:' ? 'wss' : 'ws'}://${location.host}/ws`);
    } catch {
      scheduleRetry();
      return;
    }
    ws = sock;
    sock.onopen = () => sock.send(JSON.stringify({ t: 'auth', pin }));
    sock.onmessage = ev => {
      if (ws !== sock) return;
      let m;
      try { m = JSON.parse(ev.data); } catch { return; }
      onMessage(m);
    };
    sock.onclose = () => {
      if (ws !== sock) return;
      dropConnection();
      scheduleRetry();
    };
  }

  function dropConnection() {
    ws = null;
    authed = false;
    clearInterval(pingTimer);
    resetMods(false);
    setStatus('offline', 'Hors ligne');
  }

  function scheduleRetry() {
    clearTimeout(retryTimer);
    if (!pin) return;
    retryTimer = setTimeout(connect, Math.min(5000, 400 * 2 ** retry++));
  }

  function onMessage(m) {
    switch (m.t) {
      case 'ok':
        authed = true;
        retry = 0;
        pcName = m.name || 'PC';
        setStatus('online', pcName);
        $('#set-pc').textContent = pcName;
        hideLogin();
        lastPong = performance.now();
        clearInterval(pingTimer);
        pingTimer = setInterval(ping, 2500);
        ping();
        break;
      case 'err':
        pin = '';
        store.set('pin', '');
        showLogin(m.e === 'blocked' ? 'Trop d’essais. Réessayez dans une minute.' : 'Code PIN incorrect.');
        break;
      case 'p': {
        const now = performance.now();
        lastPong = now;
        if (typeof m.i === 'number') {
          const ms = Math.max(1, Math.round(now - m.i)) + ' ms';
          $('#latency').textContent = ms;
          $('#set-lat').textContent = ms;
        }
        break;
      }
      case 'info':
        toast(m.m);
        break;
    }
  }

  function ping() {
    if (!ws || ws.readyState !== 1 || !authed) return;
    if (performance.now() - lastPong > 8000) {
      // connexion morte (iPhone en veille, Wi-Fi coupé…) : on repart de zéro
      const old = ws;
      dropConnection();
      try { old.close(); } catch { /* ignoré */ }
      retry = 0;
      connect();
      return;
    }
    ws.send(JSON.stringify({ t: 'p', i: performance.now() }));
  }

  function send(o) {
    if (ws && authed && ws.readyState === 1) {
      ws.send(JSON.stringify(o));
      return true;
    }
    const now = performance.now();
    if (now - lastOfflineToast > 2500) {
      lastOfflineToast = now;
      toast('Non connecté au PC');
    }
    return false;
  }

  function wake() {
    if (!ws || !authed) { retry = 0; connect(); } else ping();
  }
  document.addEventListener('visibilitychange', () => {
    if (document.visibilityState === 'visible') wake();
    else resetMods(true);
  });
  window.addEventListener('pageshow', wake);
  window.addEventListener('online', wake);

  // ============================================================ modificateurs
  // 0 = relâché, 1 = une fois (relâché après la prochaine touche/clic), 2 = verrouillé
  const mod = { ctrl: 0, alt: 0, shift: 0, win: 0 };

  function tapMod(m) {
    if (mod[m] === 0) {
      if (!send({ t: 'kd', k: m })) return;
      mod[m] = 1;
    } else if (mod[m] === 1) {
      mod[m] = 2;
    } else {
      mod[m] = 0;
      send({ t: 'ku', k: m });
    }
    renderMods();
  }
  function resetMods(notify) {
    for (const m in mod) {
      if (mod[m] && notify && authed) send({ t: 'ku', k: m });
      mod[m] = 0;
    }
    renderMods();
  }
  function afterAction() {
    let changed = false;
    for (const m in mod) {
      if (mod[m] === 1) { mod[m] = 0; send({ t: 'ku', k: m }); changed = true; }
    }
    if (changed) renderMods();
  }
  function renderMods() {
    for (const el of $$('[data-mod]')) {
      const s = mod[el.dataset.mod];
      el.classList.toggle('once', s === 1);
      el.classList.toggle('lock', s === 2);
    }
  }
  const cmdMod = () => mod.ctrl || mod.alt || mod.win;

  function key(k, mods = [], n = 1) {
    const ok = send(n > 1 ? { t: 'k', k, mods, n } : { t: 'k', k, mods });
    afterAction();
    return ok;
  }
  function typeText(s) {
    if (!s) return false;
    const ok = send({ t: 'txt', s });
    afterAction();
    return ok;
  }

  // ================================================================ boutons
  function mkKey(html, cls = 'key') {
    const b = document.createElement('button');
    b.type = 'button';
    b.className = cls;
    b.innerHTML = html;
    return b;
  }

  // instant : déclenche au toucher sans voler le focus (clavier iOS reste ouvert)
  // repeat  : répète tant que le doigt reste appuyé
  function press(el, fire, { repeat = false, instant = false } = {}) {
    if (repeat || instant) {
      el.classList.add('repeat');
      let t1 = 0;
      let t2 = 0;
      let active = false;
      const stop = () => {
        if (!active) return;
        active = false;
        clearTimeout(t1);
        clearInterval(t2);
        el.classList.remove('down');
      };
      el.addEventListener('touchstart', e => e.preventDefault(), { passive: false });
      el.addEventListener('pointerdown', e => {
        e.preventDefault();
        active = true;
        el.classList.add('down');
        haptic();
        fire();
        if (repeat) t1 = setTimeout(() => { t2 = setInterval(fire, 60); }, 400);
      });
      for (const ev of ['pointerup', 'pointercancel', 'pointerleave']) el.addEventListener(ev, stop);
    } else {
      el.addEventListener('click', () => { haptic(); fire(); });
    }
    return el;
  }

  function modKey(m, label) {
    const b = mkKey(label, 'key mod');
    b.dataset.mod = m;
    return press(b, () => tapMod(m), { instant: true });
  }

  // ================================================================== onglets
  const TABS = [
    ['mouse', 'Souris', 'mouse'],
    ['keys', 'Clavier', 'keyboard'],
    ['media', 'Médias', 'music'],
    ['shortcuts', 'Raccourcis', 'bolt'],
    ['settings', 'Réglages', 'sliders'],
  ];
  let current = 'mouse';

  function showView(v) {
    if (!TABS.some(t => t[0] === v)) v = 'mouse';
    current = v;
    for (const el of $$('.view')) el.classList.toggle('active', el.dataset.view === v);
    for (const el of $$('.tab')) el.classList.toggle('active', el.dataset.tab === v);
    if (v !== 'mouse' && document.activeElement === live) live.blur();
    store.set('view', v);
  }

  function buildTabs() {
    const bar = $('#tabbar');
    for (const [id, label, ic] of TABS) {
      const b = mkKey(`${icon(ic)}<span>${label}</span>`, 'tab');
      b.dataset.tab = id;
      b.addEventListener('click', () => { haptic(); showView(id); });
      bar.appendChild(b);
    }
  }

  // ============================================================= pavé tactile
  const pad = $('#pad');
  const MOVE_SLOP = 9;   // px avant de considérer qu'on n'est plus sur un « toucher »
  const TAP_MS = 280;
  const DOUBLE_MS = 300; // toucher puis glisser dans ce délai = glisser-déposer

  const P = {
    pts: new Map(), max: 0, t0: 0, moved: false, travel: 0, mode: null,
    lp: 0, lpDrag: false, dragging: false, cand: false, lastTap: 0,
    cent: { x: 0, y: 0 }, dist: 0, acc: 0, accD: 0, s3x: 0, s3y: 0, fired: false, zoom: 0, rect: null,
  };
  const pend = { x: 0, y: 0, v: 0, h: 0 };
  const vel = { v: 0, h: 0, t: 0 };
  const inert = { v: 0, h: 0, on: false, t: 0 };
  let raf = 0;

  function centroid() {
    let x = 0;
    let y = 0;
    for (const p of P.pts.values()) { x += p.x; y += p.y; }
    const n = P.pts.size || 1;
    return { x: x / n, y: y / n };
  }
  function spread() {
    const a = Array.from(P.pts.values());
    return a.length >= 2 ? Math.hypot(a[0].x - a[1].x, a[0].y - a[1].y) : 0;
  }
  function resetRefs() { P.cent = centroid(); P.dist = spread(); }

  function queue() { if (!raf) raf = requestAnimationFrame(flush); }

  function flush(ts) {
    raf = 0;
    if (inert.on) {
      const dt = Math.min(50, ts - inert.t || 16);
      inert.t = ts;
      pend.v += inert.v * dt;
      pend.h += inert.h * dt;
      const k = Math.pow(0.935, dt / 16.7);
      inert.v *= k;
      inert.h *= k;
      if (Math.abs(inert.v) < 0.04 && Math.abs(inert.h) < 0.04) inert.on = false;
    }
    if (pend.x || pend.y) {
      const x = Math.round(pend.x * 100) / 100;
      const y = Math.round(pend.y * 100) / 100;
      pend.x = 0;
      pend.y = 0;
      if (x || y) send({ t: 'm', x, y });
    }
    let v = 0;
    let h = 0;
    if (S.smooth) {
      if (Math.abs(pend.v) >= 4) { v = Math.round(pend.v); pend.v -= v; }
      if (Math.abs(pend.h) >= 4) { h = Math.round(pend.h); pend.h -= h; }
    } else {
      v = Math.trunc(pend.v / 120) * 120; pend.v -= v;
      h = Math.trunc(pend.h / 120) * 120; pend.h -= h;
    }
    if (v || h) send({ t: 's', v, h });
    if (inert.on) queue();
  }

  function moveBy(dx, dy, dt) {
    const speed = Math.hypot(dx, dy) / Math.max(dt, 4); // px/ms
    const gain = S.sens * (1 + S.accel * Math.min(speed, 2.5) * 1.3);
    pend.x += dx * gain;
    pend.y += dy * gain;
    queue();
  }

  function scrollBy(dx, dy) {
    const k = 2.2 * S.scroll * (S.natural ? 1 : -1);
    const v = dy * k;
    const h = -dx * k;
    pend.v += v;
    pend.h += h;
    queue();
    const now = performance.now();
    const dt = Math.max(8, now - vel.t);
    const a = dt > 80 ? 1 : 0.35;
    vel.v = vel.v * (1 - a) + (v / dt) * a;
    vel.h = vel.h * (1 - a) + (h / dt) * a;
    vel.t = now;
  }

  function startInertia() {
    if (!S.inertia || performance.now() - vel.t > 60) return;
    if (Math.hypot(vel.v, vel.h) < 0.25) return;
    inert.v = vel.v;
    inert.h = vel.h;
    inert.on = true;
    inert.t = performance.now();
    queue();
  }
  function stopInertia() {
    inert.on = false;
    vel.v = 0;
    vel.h = 0;
    vel.t = 0;
  }

  const dots = [];
  function drawDots() {
    const r = P.rect || pad.getBoundingClientRect();
    let i = 0;
    for (const p of P.pts.values()) {
      let d = dots[i];
      if (!d) {
        d = document.createElement('div');
        d.className = 'touchdot';
        pad.appendChild(d);
        dots.push(d);
      }
      d.style.display = '';
      d.style.transform = `translate(${p.x - r.left}px, ${p.y - r.top}px)`;
      i++;
    }
    for (; i < dots.length; i++) dots[i].style.display = 'none';
  }

  function startDrag() {
    send({ t: 'bd', b: 'l' });
    haptic();
    pad.classList.add('dragging');
  }

  pad.addEventListener('touchstart', e => {
    e.preventDefault();
    stopInertia();
    pad.classList.add('used');
    const now = performance.now();
    if (P.pts.size === 0) {
      P.rect = pad.getBoundingClientRect();
      Object.assign(P, {
        t0: now, max: 0, moved: false, travel: 0, mode: null, lpDrag: false, dragging: false,
        fired: false, s3x: 0, s3y: 0, zoom: 0, acc: 0, accD: 0,
      });
      P.cand = S.tap && now - P.lastTap < DOUBLE_MS;
    }
    for (const t of e.changedTouches) P.pts.set(t.identifier, { x: t.clientX, y: t.clientY, t: now });
    P.max = Math.max(P.max, P.pts.size);
    resetRefs();
    clearTimeout(P.lp);
    if (P.pts.size === 1 && P.max === 1 && S.longpress && !P.cand) {
      P.lp = setTimeout(() => {
        if (P.pts.size === 1 && P.max === 1 && !P.moved) { P.lpDrag = true; startDrag(); }
      }, 480);
    }
    drawDots();
  }, { passive: false });

  pad.addEventListener('touchmove', e => {
    e.preventDefault();
    const now = performance.now();
    let dx = 0;
    let dy = 0;
    let dt = 16;
    let hit = false;
    for (const t of e.changedTouches) {
      const p = P.pts.get(t.identifier);
      if (!p) continue;
      dx += t.clientX - p.x;
      dy += t.clientY - p.y;
      dt = now - p.t;
      p.x = t.clientX;
      p.y = t.clientY;
      p.t = now;
      hit = true;
    }
    if (!hit) return;
    const n = P.pts.size;
    if (n === 1) {
      if (P.max === 1) {
        P.travel += Math.hypot(dx, dy);
        if (!P.moved && P.travel > MOVE_SLOP) { P.moved = true; clearTimeout(P.lp); }
        if (P.cand && P.moved && !P.dragging) { P.dragging = true; startDrag(); }
        moveBy(dx, dy, dt);
      }
      // sinon : doigt restant après un geste à plusieurs doigts → ignoré
    } else if (n === 2) {
      twoFinger();
    } else {
      threeFinger();
    }
    drawDots();
  }, { passive: false });

  function twoFinger() {
    const c = centroid();
    const d = spread();
    const dcx = c.x - P.cent.x;
    const dcy = c.y - P.cent.y;
    const dd = d - P.dist;
    P.cent = c;
    P.dist = d;
    if (!P.mode) {
      P.acc += Math.hypot(dcx, dcy);
      P.accD += dd;
      const ad = Math.abs(P.accD);
      if (ad > 24 && ad > P.acc * 1.2) { P.mode = 'pinch'; P.moved = true; }
      else if ((P.acc > 12 && ad < P.acc * 0.8) || P.acc > 40) { P.mode = 'scroll'; P.moved = true; vel.t = 0; }
      return;
    }
    if (P.mode === 'scroll') {
      scrollBy(dcx, dcy);
    } else {
      P.zoom += dd;
      const step = 42;
      let z = 0;
      while (P.zoom >= step) { z++; P.zoom -= step; }
      while (P.zoom <= -step) { z--; P.zoom += step; }
      if (z) send({ t: 'z', n: z });
    }
  }

  function threeFinger() {
    const c = centroid();
    P.s3x += c.x - P.cent.x;
    P.s3y += c.y - P.cent.y;
    P.cent = c;
    if (P.fired || Math.hypot(P.s3x, P.s3y) < 55) return;
    P.fired = true;
    P.moved = true;
    haptic();
    if (Math.abs(P.s3y) > Math.abs(P.s3x)) {
      if (P.s3y < 0) key('tab', ['win']); // vers le haut : vue des tâches
      else key('d', ['win']);             // vers le bas : bureau
    } else {
      key('tab', ['alt']);                // gauche/droite : application précédente
    }
  }

  function padEnd(e, cancelled) {
    e.preventDefault();
    for (const t of e.changedTouches) P.pts.delete(t.identifier);
    if (P.pts.size) { resetRefs(); drawDots(); return; }
    clearTimeout(P.lp);
    const now = performance.now();
    if (P.dragging || P.lpDrag) {
      send({ t: 'bu', b: 'l' });
      afterAction();
      pad.classList.remove('dragging');
      P.lastTap = 0;
    } else if (!cancelled && S.tap && !P.moved && now - P.t0 < TAP_MS + (P.max > 1 ? 80 : 0)) {
      const b = P.max === 1 ? 'l' : P.max === 2 ? 'r' : 'm';
      send({ t: 'c', b });
      haptic();
      afterAction();
      P.lastTap = P.max === 1 ? now : 0;
    } else if (P.mode === 'scroll') {
      startInertia();
    }
    P.dragging = false;
    P.lpDrag = false;
    drawDots();
  }
  pad.addEventListener('touchend', e => padEnd(e, false), { passive: false });
  pad.addEventListener('touchcancel', e => padEnd(e, true), { passive: false });

  // ------------------------------------------------------- molette (bord droit)
  const strip = $('#strip');
  let stripId = null;
  let stripY = 0;
  strip.addEventListener('touchstart', e => {
    e.preventDefault();
    stopInertia();
    const t = e.changedTouches[0];
    stripId = t.identifier;
    stripY = t.clientY;
    strip.classList.add('active');
  }, { passive: false });
  strip.addEventListener('touchmove', e => {
    e.preventDefault();
    for (const t of e.changedTouches) {
      if (t.identifier !== stripId) continue;
      scrollBy(0, (t.clientY - stripY) * 1.4);
      stripY = t.clientY;
    }
  }, { passive: false });
  const stripEnd = e => {
    e.preventDefault();
    for (const t of e.changedTouches) {
      if (t.identifier !== stripId) continue;
      stripId = null;
      strip.classList.remove('active');
      startInertia();
    }
  };
  strip.addEventListener('touchend', stripEnd, { passive: false });
  strip.addEventListener('touchcancel', stripEnd, { passive: false });

  // ---------------------------------------------------------- boutons souris
  // Maintenir « Gauche » d'un doigt et bouger de l'autre = glisser-déposer.
  for (const b of $$('[data-btn]')) {
    let down = false;
    const up = () => {
      if (!down) return;
      down = false;
      b.classList.remove('down');
      send({ t: 'bu', b: b.dataset.btn });
      afterAction();
    };
    b.addEventListener('touchstart', e => e.preventDefault(), { passive: false });
    b.addEventListener('pointerdown', e => {
      e.preventDefault();
      if (down) return;
      down = true;
      b.classList.add('down');
      haptic();
      send({ t: 'bd', b: b.dataset.btn });
    });
    b.addEventListener('pointerup', up);
    b.addEventListener('pointercancel', up);
  }

  // ========================================================= saisie directe
  // Champ invisible : chaque frappe du clavier iOS est envoyée immédiatement au PC.
  const live = $('#live');
  const SENT = '​'.repeat(8); // sentinelle : permet d'intercepter « effacer » même champ vide
  let liveLast = SENT;

  function resetLive() {
    live.value = SENT;
    liveLast = SENT;
    try { live.setSelectionRange(SENT.length, SENT.length); } catch { /* ignoré */ }
  }
  resetLive();

  live.addEventListener('input', () => {
    const now = Array.from(live.value);
    const prev = Array.from(liveLast);
    let i = 0;
    const n = Math.min(now.length, prev.length);
    while (i < n && now[i] === prev[i]) i++;
    const del = prev.length - i;
    const add = now.slice(i).join('').replace(/​/g, '');
    if (del > 0) send({ t: 'k', k: 'backspace', n: del });
    if (add) {
      if (cmdMod() && Array.from(add).length === 1) send({ t: 'k', k: add.toLowerCase() }); // ex. Ctrl + C
      else send({ t: 'txt', s: add });
    }
    if (del > 0 || add) afterAction();
    if (!live.value.startsWith(SENT) || live.value.length > 48) resetLive();
    else liveLast = live.value;
  });

  const HW_KEYS = {
    Enter: 'enter', Tab: 'tab', Escape: 'esc', ArrowLeft: 'left', ArrowRight: 'right',
    ArrowUp: 'up', ArrowDown: 'down', Delete: 'delete', Home: 'home', End: 'end',
    PageUp: 'pageup', PageDown: 'pagedown',
  };
  live.addEventListener('keydown', e => {
    if (e.isComposing) return;
    const k = HW_KEYS[e.key];
    if (k) { e.preventDefault(); key(k); }
  });
  live.addEventListener('focus', () => { document.body.classList.add('kb-open'); resetLive(); });
  live.addEventListener('blur', () => document.body.classList.remove('kb-open'));

  function toggleKeyboard() {
    if (document.activeElement === live) { live.blur(); return; }
    if (current !== 'mouse') showView('mouse');
    live.focus();
  }
  const kbt = $('#kbtoggle');
  kbt.innerHTML = icon('keyboard');
  kbt.addEventListener('touchstart', e => e.preventDefault(), { passive: false });
  kbt.addEventListener('touchend', e => { e.preventDefault(); toggleKeyboard(); }, { passive: false });
  kbt.addEventListener('click', toggleKeyboard); // souris (test sur ordinateur)

  // Barre de touches affichée au-dessus du clavier iOS
  function buildKeybar() {
    const bar = $('#keybar');
    const plain = (label, k, repeat = false) =>
      press(mkKey(label, 'key small'), () => key(k), { instant: true, repeat });
    bar.append(
      plain('Échap', 'esc'),
      plain('Tab', 'tab'),
      modKey('ctrl', 'Ctrl'),
      modKey('alt', 'Alt'),
      modKey('shift', 'Maj'),
      modKey('win', 'Win'),
      press(mkKey(icon('chevD'), 'key small'), () => live.blur(), { instant: true }),
      plain('Suppr', 'delete', true),
      plain('Début', 'home'),
      plain(icon('chevL'), 'left', true),
      plain(icon('chevU'), 'up', true),
      plain(icon('chevD'), 'down', true),
      plain(icon('chevR'), 'right', true),
      plain('Fin', 'end'),
    );
  }

  // ================================================================ clavier
  function buildKeys() {
    const compose = $('#compose');
    const sendCompose = suffix => {
      const v = compose.value;
      if (!v) { toast('Rien à envoyer'); return; }
      if (typeText(v + suffix)) { compose.value = ''; toast('Texte envoyé au PC'); }
    };
    press($('#send-txt'), () => sendCompose(''));
    press($('#send-txt-enter'), () => sendCompose('\n'));
    $('#live-btn').addEventListener('click', () => { showView('mouse'); live.focus(); });

    $('#modgrid').append(modKey('ctrl', 'Ctrl'), modKey('alt', 'Alt'), modKey('shift', 'Maj'), modKey('win', 'Win'));

    const special = [
      ['Échap', 'esc'], ['Tab', 'tab'], [icon('backspace'), 'backspace', true], ['Suppr', 'delete', true],
      [`${icon('enter')}Entrée`, 'enter'], ['Espace', 'space', true], ['Inser', 'insert'], ['Impr. écran', 'printscreen'],
      ['Début', 'home'], ['Fin', 'end'], ['Page ↑', 'pageup', true], ['Page ↓', 'pagedown', true],
    ];
    const sg = $('#specialgrid');
    for (const [label, k, repeat] of special) {
      sg.appendChild(press(mkKey(label, 'key small'), () => key(k), { repeat: !!repeat }));
    }

    const ap = $('#arrowpad');
    for (const [cls, k, ic] of [['up', 'up', 'chevU'], ['left', 'left', 'chevL'], ['down', 'down', 'chevD'], ['right', 'right', 'chevR']]) {
      ap.appendChild(press(mkKey(icon(ic), 'key ' + cls), () => key(k), { repeat: true }));
    }

    const fg = $('#fgrid');
    for (let i = 1; i <= 12; i++) fg.appendChild(press(mkKey('F' + i, 'key small'), () => key('f' + i)));
  }

  // ================================================================= médias
  function buildMedia() {
    const round = (ic, k, { big = false, repeat = false, label = '' } = {}) => {
      const b = mkKey(icon(ic), 'round' + (big ? ' big' : ''));
      b.setAttribute('aria-label', label);
      return press(b, () => key(k), { repeat, instant: repeat });
    };
    $('#volrow').append(
      round('volDown', 'volume_down', { repeat: true, label: 'Volume −' }),
      round('mute', 'volume_mute', { label: 'Muet' }),
      round('volUp', 'volume_up', { repeat: true, label: 'Volume +' }),
    );
    $('#playrow').append(
      round('prev', 'media_prev', { label: 'Précédent' }),
      round('playpause', 'media_play_pause', { big: true, label: 'Lecture / pause' }),
      round('next', 'media_next', { label: 'Suivant' }),
      round('stop', 'media_stop', { label: 'Stop' }),
    );
    $('#slides').append(
      press(mkKey(`${icon('chevL')}Précédente`, 'key'), () => key('left')),
      press(mkKey(`${icon('chevR')}Suivante`, 'key next'), () => key('right')),
    );
    const tools = [
      [`${icon('play')}Démarrer`, 'f5', []], [`${icon('play')}Depuis ici`, 'f5', ['shift']],
      [`${icon('monitor')}Écran noir`, 'b', []], [`${icon('x')}Quitter`, 'esc', []],
    ];
    for (const [label, k, mods] of tools) $('#slidetools').appendChild(press(mkKey(label, 'key tall'), () => key(k, mods)));
    const video = [
      [`${icon('playpause')}Lecture`, 'space'], [`${icon('back')}−5 s`, 'left'],
      [`${icon('fwd')}+5 s`, 'right'], [`${icon('full')}Plein écran`, 'f'],
    ];
    for (const [label, k] of video) $('#videotools').appendChild(press(mkKey(label, 'key tall'), () => key(k)));
  }

  // ============================================================= raccourcis
  const KEYNAMES = {
    ctrl: 'Ctrl', alt: 'Alt', shift: 'Maj', win: 'Win', tab: 'Tab', esc: 'Échap', left: '←', right: '→',
    up: '↑', down: '↓', add: '+', subtract: '−', num0: '0',
  };
  const comboText = (k, mods) => [...mods, k].map(x => KEYNAMES[x] || x.toUpperCase()).join(' + ');

  const SHORTCUTS = [
    ['Édition', [
      ['Copier', 'c', ['ctrl']], ['Coller', 'v', ['ctrl']], ['Couper', 'x', ['ctrl']],
      ['Annuler', 'z', ['ctrl']], ['Rétablir', 'y', ['ctrl']], ['Tout sélect.', 'a', ['ctrl']],
      ['Enregistrer', 's', ['ctrl']], ['Rechercher', 'f', ['ctrl']], ['Imprimer', 'p', ['ctrl']],
    ]],
    ['Windows', [
      ['Bureau', 'd', ['win']], ['App précédente', 'tab', ['alt']], ['Vue des tâches', 'tab', ['win']],
      ['Démarrer', 'win', []], ['Recherche', 's', ['win']], ['Explorateur', 'e', ['win']],
      ['Fermer fenêtre', 'f4', ['alt']], ['Gest. des tâches', 'esc', ['ctrl', 'shift']], ['Capture', 's', ['win', 'shift']],
      ['Agrandir', 'up', ['win']], ['Réduire', 'down', ['win']], ['Paramètres', 'i', ['win']],
      ['Ancrer à gauche', 'left', ['win']], ['Ancrer à droite', 'right', ['win']], ['Presse-papiers', 'v', ['win']],
      ['Bureau virtuel ←', 'left', ['ctrl', 'win']], ['Bureau virtuel →', 'right', ['ctrl', 'win']], ['Projeter', 'p', ['win']],
    ]],
    ['Navigateur', [
      ['Précédent', 'left', ['alt']], ['Suivant', 'right', ['alt']], ['Actualiser', 'f5', []],
      ['Nouvel onglet', 't', ['ctrl']], ['Fermer onglet', 'w', ['ctrl']], ['Rouvrir onglet', 't', ['ctrl', 'shift']],
      ['Onglet suivant', 'tab', ['ctrl']], ['Onglet précédent', 'tab', ['ctrl', 'shift']], ['Barre d’adresse', 'l', ['ctrl']],
      ['Zoom +', 'add', ['ctrl']], ['Zoom −', 'subtract', ['ctrl']], ['Zoom 100 %', 'num0', ['ctrl']],
      ['Plein écran', 'f11', []], ['Nouvelle fenêtre', 'n', ['ctrl']], ['Historique', 'h', ['ctrl']],
    ]],
  ];

  const POWER = [
    ['Verrouiller', 'lock', 'lock', false],
    ['Éteindre l’écran', 'display_off', 'monitor', false],
    ['Veille', 'sleep', 'moon', true],
    ['Déconnexion', 'logoff', 'logout', true],
    ['Redémarrer', 'restart', 'restart', true],
    ['Arrêter', 'shutdown', 'power', true],
  ];

  function buildShortcuts() {
    const root = $('#shortcut-sections');
    for (const [title, items] of SHORTCUTS) {
      const h = document.createElement('h2');
      h.textContent = title;
      const grid = document.createElement('div');
      grid.className = 'grid g3';
      for (const [label, k, mods] of items) {
        const b = mkKey(`<span>${label}</span><small class="muted">${comboText(k, mods)}</small>`, 'key tall');
        grid.appendChild(press(b, () => key(k, mods)));
      }
      root.append(h, grid);
    }

    $('#urlform').addEventListener('submit', e => {
      e.preventDefault();
      const input = $('#url');
      let u = input.value.trim();
      if (!u) return;
      if (!/^https?:\/\//i.test(u)) u = 'https://' + u;
      if (send({ t: 'url', u })) { input.value = ''; input.blur(); }
    });

    const pg = $('#powergrid');
    for (const [label, action, ic, ask] of POWER) {
      const b = mkKey(`${icon(ic)}${label}`, 'key tall' + (action === 'shutdown' || action === 'restart' ? ' danger' : ''));
      pg.appendChild(press(b, () => {
        if (ask && !confirm(`${label} : confirmer sur le PC ?`)) return;
        send({ t: 'pw', a: action });
      }));
    }
  }

  // =============================================================== réglages
  const SETTINGS_UI = [
    ['Pavé tactile', [
      ['sens', 'Vitesse du curseur', 0.4, 4, 0.1, v => v.toFixed(1) + '×'],
      ['accel', 'Accélération', 0, 1.5, 0.05, v => Math.round(v * 100) + ' %'],
      ['tap', 'Toucher pour cliquer'],
      ['longpress', 'Appui long pour glisser'],
    ]],
    ['Défilement', [
      ['scroll', 'Vitesse de défilement', 0.3, 3, 0.1, v => v.toFixed(1) + '×'],
      ['natural', 'Défilement naturel (comme l’iPhone)'],
      ['smooth', 'Défilement fluide (sinon par crans)'],
      ['inertia', 'Inertie après le geste'],
      ['strip', 'Molette sur le bord droit'],
    ]],
    ['Général', [
      ['haptic', 'Retour haptique'],
    ]],
  ];

  function applySettings() {
    document.body.classList.toggle('nostrip', !S.strip);
  }

  function buildSettings() {
    const root = $('#settings-sections');
    for (const [title, rows] of SETTINGS_UI) {
      const h = document.createElement('h2');
      h.textContent = title;
      const card = document.createElement('div');
      card.className = 'card list';
      for (const [k, label, min, max, step, fmt] of rows) {
        if (fmt) {
          const row = document.createElement('label');
          row.className = 'li col';
          row.innerHTML = `<span class="lab"><span>${label}</span><span class="val"></span></span><input type="range" min="${min}" max="${max}" step="${step}">`;
          const input = row.querySelector('input');
          const val = row.querySelector('.val');
          input.value = S[k];
          val.textContent = fmt(+S[k]);
          input.addEventListener('input', () => {
            S[k] = +input.value;
            val.textContent = fmt(S[k]);
            saveSettings();
          });
          card.appendChild(row);
        } else {
          const row = document.createElement('label');
          row.className = 'li';
          row.innerHTML = `<span>${label}</span><input type="checkbox" switch>`;
          const input = row.querySelector('input');
          input.checked = !!S[k];
          input.addEventListener('change', () => {
            S[k] = input.checked;
            saveSettings();
            applySettings();
          });
          card.appendChild(row);
        }
      }
      root.append(h, card);
    }

    const h = document.createElement('h2');
    h.textContent = 'Gestes';
    const help = document.createElement('div');
    help.className = 'card help';
    help.innerHTML = [
      '<b>1 doigt</b> : déplacer le curseur · <b>toucher</b> : clic gauche · <b>2 touchers</b> : double-clic',
      '<b>Toucher puis glisser</b> : sélectionner / glisser-déposer',
      '<b>2 doigts</b> : défiler · <b>toucher</b> : clic droit · <b>pincer</b> : zoom (Ctrl + molette)',
      '<b>3 doigts</b> : <b>toucher</b> = clic milieu · ↑ vue des tâches · ↓ bureau · ←/→ app précédente',
      '<b>Bouton Gauche maintenu</b> + 1 doigt sur le pavé : glisser-déposer',
      '<b>Modificateurs</b> (Ctrl, Alt…) : 1 toucher = pour la prochaine touche ou le prochain clic, 2 touchers = verrouillé',
    ].join('<br>');
    root.append(h, help);

    $('#set-addr').textContent = location.host;
    $('#forget').addEventListener('click', () => {
      if (!confirm('Oublier le code PIN de ce PC ?')) return;
      pin = '';
      store.set('pin', '');
      const old = ws;
      dropConnection();
      if (old) { try { old.close(); } catch { /* ignoré */ } }
      showLogin();
    });
    $('#status').addEventListener('click', () => {
      if (authed) toast(`Connecté à ${pcName} (${location.host})`);
      else { retry = 0; connect(); }
    });
  }

  // =============================================================== connexion
  function showLogin(err = '') {
    $('#login').hidden = false;
    $('#login-err').textContent = err;
  }
  function hideLogin() {
    $('#login').hidden = true;
  }
  $('#loginform').addEventListener('submit', e => {
    e.preventDefault();
    const input = $('#pin');
    const v = input.value.trim();
    if (!/^\d{4,8}$/.test(v)) { $('#login-err').textContent = 'Le code PIN est composé de chiffres (6 en général).'; return; }
    pin = v;
    store.set('pin', v);
    input.blur();
    $('#login-err').textContent = '';
    const old = ws;
    ws = null;
    if (old) { try { old.close(); } catch { /* ignoré */ } }
    retry = 0;
    connect();
  });

  // ============================================================ affichage iOS
  const vv = window.visualViewport;
  function fit() {
    const root = document.documentElement.style;
    root.setProperty('--app-h', (vv ? vv.height : window.innerHeight) + 'px');
    root.setProperty('--vv-top', (vv ? vv.offsetTop : 0) + 'px');
    if (window.scrollY) window.scrollTo(0, 0);
  }
  if (vv) { vv.addEventListener('resize', fit); vv.addEventListener('scroll', fit); }
  window.addEventListener('resize', fit);
  fit();

  document.addEventListener('gesturestart', e => e.preventDefault());
  document.addEventListener('dblclick', e => e.preventDefault());
  document.addEventListener('contextmenu', e => e.preventDefault());
  document.addEventListener('touchstart', () => {}, { passive: true }); // active :active sur iOS

  // =================================================================== init
  buildTabs();
  buildKeybar();
  buildKeys();
  buildMedia();
  buildShortcuts();
  buildSettings();
  applySettings();
  showView(params.get('view') || store.get('view', 'mouse'));
  connect();
})();
