// ONE 2.0 film kiti — ortak çekirdek.
//
// Tüm filmler aynı dilden konuşsun diye: tek eğri, token renkleri, kelime
// kelime yükselen başlık, harf harf yazma, tek çizgi motifi. Bir sahne
// dosyası bu betiği yükler, öğelerini kurar ve `window.render(t)`'yi
// tanımlar. `render(t)` zamandan saf olmalı: aynı t, aynı kare.
// Kurallar: ../STYLE.md

(function () {
  const Q = new URLSearchParams(location.search);
  const W = +(Q.get('w') || 1080), H = +(Q.get('h') || 1920);
  const u = Math.min(W, H) / 1080;

  // Token'lar: docs/one2/design-system/tokens.json, gece teması
  const C = {
    ground: '#000000', surface: '#141416', raised: '#1E1E21', line: '#26262A', lineStrong: '#66666E',
    ink: '#F4F4F5', inkMuted: '#A3A3AA', inkFaint: '#85858D', primary: '#E8E8EA', onPrimary: '#111113',
    brand: '#9AA6FF', onBrand: '#0F1218', sabah: '#F2B84B', aksam: '#7D8BE0',
    score: ['#5B6CCB', '#8F99D0', '#9A9C94', '#E9B650', '#F08A2E'],
    onScore: ['#FFFFFF', '#15181D', '#15181D', '#15181D', '#15181D'],
    huzur: '#6FA684', onEmo: '#15181D',
  };

  // 72 BPM: kesmeler vuruşta
  const BEAT = 60 / 72;

  // Tek eğri: cubic-bezier(0.2, 0.8, 0.2, 1)
  function bezier(x1, y1, x2, y2) {
    const bx = t => 3*x1*t*(1-t)*(1-t) + 3*x2*t*t*(1-t) + t*t*t;
    const by = t => 3*y1*t*(1-t)*(1-t) + 3*y2*t*t*(1-t) + t*t*t;
    return x => {
      if (x <= 0) return 0; if (x >= 1) return 1;
      let lo = 0, hi = 1;
      for (let i = 0; i < 28; i++) { const m = (lo + hi) / 2; if (bx(m) < x) lo = m; else hi = m; }
      return by((lo + hi) / 2);
    };
  }
  const EASE = bezier(0.2, 0.8, 0.2, 1);
  const clamp = v => Math.max(0, Math.min(1, v));
  const prog = (t, a, d) => EASE(clamp((t - a) / d));
  const lerp = (a, b, m) => a + (b - a) * m;
  const vis = (t, a, b, fin = 0.35, fout = 0.28) => prog(t, a, fin) * (1 - prog(t, b, fout));
  function mixHex(a, b, m) {
    const pa = [1, 3, 5].map(i => parseInt(a.slice(i, i + 2), 16));
    const pb = [1, 3, 5].map(i => parseInt(b.slice(i, i + 2), 16));
    return '#' + pa.map((v, i) => Math.round(lerp(v, pb[i], m)).toString(16).padStart(2, '0')).join('');
  }

  // Sahne
  const stage = document.getElementById('stage');
  stage.style.width = W + 'px'; stage.style.height = H + 'px';
  const NS = 'http://www.w3.org/2000/svg';
  function svg(tag, attrs = {}, parent) {
    const e = document.createElementNS(NS, tag);
    for (const k in attrs) e.setAttribute(k, attrs[k]);
    if (parent) parent.appendChild(e);
    return e;
  }
  function layerSVG() { return svg('svg', { width: W, height: H, viewBox: `0 0 ${W} ${H}` }, stage); }
  function div(cls, style = {}, html = '', parent = stage) {
    const e = document.createElement('div');
    e.className = cls; Object.assign(e.style, style); e.innerHTML = html;
    parent.appendChild(e); return e;
  }
  function place(el, x, y, extra = '') { el.style.transform = `translate(${x}px, ${y}px) translate(-50%, -50%) ${extra}`; }
  function show(el, o) { el.style.opacity = o; el.style.visibility = o > 0.001 ? 'visible' : 'hidden'; }

  // Başlık: kelimeler sırayla yükselir (70ms arayla), çıkışta birlikte söner.
  function headline(text, { size = 60, cls = 'headline', width = 940, color } = {}) {
    const el = div('abs ' + cls, { fontSize: size*u + 'px', lineHeight: 1.2, width: width*u + 'px' });
    if (color) el.style.color = color;
    el.innerHTML = text.split(' ').map(w => `<span class="w">${w}</span>`).join(' ');
    return { el, words: [...el.querySelectorAll('.w')] };
  }
  function wordsAt(h, t, tin, tout, x, y, { stagger = 0.07, rise = 28 } = {}) {
    place(h.el, x, y);
    let any = false;
    h.words.forEach((w, i) => {
      const p = prog(t, tin + i * stagger, 0.55);
      const q = tout == null ? 0 : prog(t, tout, 0.28);
      const o = p * (1 - q);
      if (o > 0.001) any = true;
      w.style.opacity = o;
      w.style.transform = `translateY(${(1 - p) * rise*u - q * 14*u}px)`;
    });
    h.el.style.visibility = any ? 'visible' : 'hidden';
  }
  function label(text, size = 22) { return div('abs label', { fontSize: size*u + 'px', whiteSpace: 'nowrap' }, text); }

  // Ses olayları: kit/synth.py okur. Aileler: key, paper, seal.
  const EVENTS = [];

  // Yazma: harf harf, marka renginde imleç. Kalan metin görünmez durur,
  // böylece ortalanmış satır yazılırken kaymaz.
  function typer(text, cls, style, parent) {
    const el = div('abs ' + cls, style, '', parent);
    el.innerHTML = `<span class="tx"></span><span class="caret"></span><span style="visibility:hidden" class="gh"></span>`;
    const caret = el.querySelector('.caret');
    caret.style.width = Math.max(2, 3*u) + 'px'; caret.style.height = '1.05em'; caret.style.marginLeft = 2*u + 'px';
    return { el, tx: el.querySelector('.tx'), gh: el.querySelector('.gh'), caret, text };
  }
  function registerTyping(ty, t0, cps) {
    ty.t0 = t0; ty.cps = cps;
    [...ty.text].forEach((ch, i) => { if (ch !== ' ') EVENTS.push({ type: 'key', t: t0 + i / cps }); });
  }
  function typeAt(ty, t) {
    const n = Math.max(0, Math.min(ty.text.length, Math.floor((t - ty.t0) * ty.cps) + 1));
    const shown = t < ty.t0 ? '' : ty.text.slice(0, n);
    ty.tx.textContent = shown; ty.gh.textContent = ty.text.slice(shown.length);
    const done = t - (ty.t0 + ty.text.length / ty.cps);
    ty.caret.style.opacity = t < ty.t0 - 0.3 ? 0 : (done > 0 ? (Math.floor(done / 0.5) % 2 === 0 ? 1 : 0) : 1);
  }

  // Tek çizgi motifi: N noktalı biçimler arasında nokta nokta geçiş.
  const N = 240;
  const shapeOf = f => Array.from({ length: N }, (_, i) => f(i / (N - 1)));
  const line = (x0, y0, x1, y1) => shapeOf(s => [lerp(x0, x1, s), lerp(y0, y1, s)]);
  const arc = (cx, y, half, bulge) => shapeOf(s => [cx + lerp(-half, half, s), y - bulge * Math.sin(Math.PI * s)]);
  const morph = (A, B, m) => A.map((p, i) => [lerp(p[0], B[i][0], m), lerp(p[1], B[i][1], m)]);
  // Yuvarlak köşeli dikdörtgen, açık bir yayla eşlenecek biçimde: yayın ortası
  // alt kenarın ortasına oturur, iki kol yanlardan yükselip üst ortada buluşur.
  // Böylece yay ↔ çerçeve geçişi düğüm atmadan açılır ve kapanır.
  function roundRect(x, y, w, h, r) {
    const segs = [];
    const straight = (x0, y0, x1, y1) => ({ len: Math.hypot(x1 - x0, y1 - y0), at: s => [lerp(x0, x1, s), lerp(y0, y1, s)] });
    const corner = (cx, cy, a0) => ({ len: Math.PI * r / 2, at: s => { const a = a0 + s * Math.PI / 2; return [cx + r * Math.cos(a), cy + r * Math.sin(a)]; } });
    segs.push(straight(x + w/2, y + h, x + r, y + h));
    segs.push(corner(x + r, y + h - r, Math.PI / 2));
    segs.push(straight(x, y + h - r, x, y + r));
    segs.push(corner(x + r, y + r, Math.PI));
    segs.push(straight(x + r, y, x + w - r, y));
    segs.push(corner(x + w - r, y + r, -Math.PI / 2));
    segs.push(straight(x + w, y + r, x + w, y + h - r));
    segs.push(corner(x + w - r, y + h - r, 0));
    segs.push(straight(x + w - r, y + h, x + w/2, y + h));
    const total = segs.reduce((a, s) => a + s.len, 0);
    return shapeOf(s => {
      let d = (s < 0.5 ? 0.5 - s : 1.5 - s) * total;
      for (const g of segs) { if (d <= g.len || g === segs[segs.length - 1]) return g.at(Math.min(1, d / g.len)); d -= g.len; }
    });
  }
  function subPath(pts, a = 0, b = 1) {
    if (b - a < 0.002) return '';
    const fa = a * (N - 1), fb = b * (N - 1);
    const at = f => { const i = Math.min(N - 2, Math.floor(f)), r = f - i; return [lerp(pts[i][0], pts[i+1][0], r), lerp(pts[i][1], pts[i+1][1], r)]; };
    const out = [at(fa)];
    for (let i = Math.ceil(fa); i < fb; i++) out.push(pts[i]);
    out.push(at(fb));
    return 'M' + out.map(p => p[0].toFixed(2) + ' ' + p[1].toFixed(2)).join(' L');
  }

  function fontsReady() {
    return Promise.all([
      '500 40px "Plus Jakarta Sans"', '600 40px "Plus Jakarta Sans"', '700 40px "Plus Jakarta Sans"', '800 40px "Plus Jakarta Sans"',
      '400 40px "Literata"', '500 40px "Literata"', 'italic 400 40px "Literata"', '400 40px "IBM Plex Mono"', '500 40px "IBM Plex Mono"',
    ].map(f => document.fonts.load(f, 'ağışüçöİĞŞÜÇÖ ONE 07:12'))).then(() => document.fonts.ready);
  }

  window.ONE = {
    W, H, u, C, BEAT, EASE, clamp, prog, lerp, vis, mixHex, stage, svg, layerSVG, div, place, show,
    headline, wordsAt, label, EVENTS, typer, registerTyping, typeAt,
    N, shapeOf, line, arc, morph, roundRect, subPath, fontsReady,
  };
  window.EVENTS = EVENTS;
  window.fontsReady = fontsReady;
})();
