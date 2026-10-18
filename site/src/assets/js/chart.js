/* Smart Money Concepts parity viewer.
   Draws, on the same AAPL 15 min bars, the labels, lines, boxes and candle colours that each platform
   exported: LuxAlgo's Pine script on TradingView, and the MQL5 port on MetaTrader 5.
   Nothing here computes structure: it only redraws what each platform produced. */
(function () {
  'use strict';

  var cache = {};
  function getJSON(url) {
    if (!cache[url]) {
      cache[url] = fetch(url).then(function (r) {
        if (!r.ok) throw new Error(url + ' ' + r.status);
        return r.json();
      });
    }
    return cache[url];
  }

  function decodeBars(b) {
    var n = b.o.length, t = new Array(n), acc = b.t[0];
    t[0] = acc;
    for (var i = 1; i < n; i++) { acc += b.t[i] * b.step; t[i] = acc; }
    return { n: n, t: t, o: b.o, h: b.h, l: b.l, c: b.c, step: b.step, symbol: b.symbol, tf: b.tf };
  }

  var DASH = { 0: [], 1: [4, 3], 2: [1, 2] };
  var SIZE = [9, 11, 13];
  var FONT = '"Trebuchet MS", "Segoe UI", Arial, sans-serif';
  var AXIS_W = 58, TIME_H = 24;
  var C = {
    bg: '#0b0f15', grid: 'rgba(255,255,255,0.045)', axis: '#7d8a9c', axisLine: 'rgba(255,255,255,0.08)',
    up: '#089981', down: '#f23645', cross: 'rgba(255,255,255,0.28)', amber: '#ffb020', magenta: '#ff3df0'
  };
  var MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  function rgba(hex) {
    var a = parseInt(hex.slice(0, 2), 16) / 255;
    if (!a) return null;
    return 'rgba(' + parseInt(hex.slice(2, 4), 16) + ',' + parseInt(hex.slice(4, 6), 16) + ',' +
      parseInt(hex.slice(6, 8), 16) + ',' + a.toFixed(3) + ')';
  }

  function niceStep(range, target) {
    var raw = range / target, p = Math.pow(10, Math.floor(Math.log10(raw))), m = raw / p;
    return (m < 1.5 ? 1 : m < 3 ? 2 : m < 7 ? 5 : 10) * p;
  }

  function fmtTime(t, withDay) {
    var d = new Date(t * 1000);
    var hh = ('0' + d.getUTCHours()).slice(-2), mm = ('0' + d.getUTCMinutes()).slice(-2);
    return withDay ? (d.getUTCDate() + ' ' + MONTHS[d.getUTCMonth()]) : hh + ':' + mm;
  }

  function Viewer(canvas, opts) {
    this.canvas = canvas;
    this.ctx = canvas.getContext('2d');
    this.opts = opts || {};
    this.side = this.opts.side || 'mt5';
    this.mode = this.opts.mode || 'normal';
    this.bars = null;
    this.parity = null;
    this.hover = null;
    this.pointers = {};
    this.listeners = [];
    var self = this;
    this._raf = 0;
    this._ro = new ResizeObserver(function () { self.resize(); });
    this._ro.observe(canvas);
    this._bind();
  }

  Viewer.load = function (base, cfg) {
    return Promise.all([getJSON(base + 'bars.json'), getJSON(base + 'parity-' + cfg + '.json')])
      .then(function (r) { return { bars: decodeBars(r[0]), parity: r[1] }; });
  };

  Viewer.prototype.on = function (fn) { this.listeners.push(fn); };
  Viewer.prototype._emit = function () {
    var s = this.stats();
    this.listeners.forEach(function (fn) { fn(s); });
  };

  Viewer.prototype.setData = function (bars, parity, keepView) {
    this.bars = bars;
    this.parity = parity;
    if (!keepView || this.from == null) this.reset(true);
    this.request();
  };

  Viewer.prototype.reset = function (silent) {
    var n = this.bars.n, show = this.opts.bars || 160, pad = this.opts.rightPad == null ? 26 : this.opts.rightPad;
    if (this.W) show = Math.min(show, Math.max(50, Math.floor((this.W - AXIS_W) / 4.2)));
    this._needsFit = !this.W;
    this.from = n - show;
    this.to = n + pad;
    if (!silent) this.request();
  };

  Viewer.prototype.setSide = function (side) { this.side = side; this.request(); };
  Viewer.prototype.setMode = function (mode) { this.mode = mode; this.request(); };

  Viewer.prototype.zoom = function (factor, anchorX) {
    if (!this.bars) return;
    var w = this.plotW || 1, span = this.to - this.from;
    var ax = anchorX == null ? w * 0.75 : anchorX;
    var at = this.from + ax / w * span;
    var next = Math.min(Math.max(span * factor, 24), this.bars.n + 80);
    this.from = at - ax / w * next;
    this.to = this.from + next;
    this._clamp();
    this.request();
  };

  Viewer.prototype._clamp = function () {
    var span = this.to - this.from, n = this.bars.n;
    if (this.from < -20) { this.from = -20; this.to = this.from + span; }
    if (this.to > n + 80) { this.to = n + 80; this.from = this.to - span; }
  };

  Viewer.prototype.resize = function () {
    var r = this.canvas.getBoundingClientRect(), dpr = Math.min(window.devicePixelRatio || 1, 2);
    if (!r.width || !r.height) return;
    this.W = r.width; this.H = r.height; this.dpr = dpr;
    this.canvas.width = Math.round(r.width * dpr);
    this.canvas.height = Math.round(r.height * dpr);
    if (this._needsFit && this.bars) this.reset(true);
    this.request();
  };

  Viewer.prototype.request = function () {
    var self = this;
    if (this._raf) return;
    this._raf = requestAnimationFrame(function () { self._raf = 0; self.draw(); self._emit(); });
  };

  Viewer.prototype._bind = function () {
    var self = this, cv = this.canvas;
    cv.addEventListener('pointerdown', function (e) {
      cv.setPointerCapture(e.pointerId);
      self.pointers[e.pointerId] = { x: e.offsetX, y: e.offsetY };
      self._drag = { x: e.offsetX, from: self.from, to: self.to };
      self._interacted();
    });
    cv.addEventListener('pointermove', function (e) {
      var ids = Object.keys(self.pointers);
      if (ids.length === 2 && self.pointers[e.pointerId]) {
        var other = self.pointers[ids[0] == e.pointerId ? ids[1] : ids[0]];
        var before = Math.abs(self.pointers[e.pointerId].x - other.x) || 1;
        var after = Math.abs(e.offsetX - other.x) || 1;
        self.pointers[e.pointerId] = { x: e.offsetX, y: e.offsetY };
        self.zoom(before / after, (e.offsetX + other.x) / 2);
        return;
      }
      if (self._drag && self.pointers[e.pointerId]) {
        var dx = e.offsetX - self._drag.x, bw = (self.plotW || 1) / (self._drag.to - self._drag.from);
        self.from = self._drag.from - dx / bw;
        self.to = self._drag.to - dx / bw;
        self._clamp();
      }
      self.hover = e.pointerType === 'mouse' ? { x: e.offsetX, y: e.offsetY } : null;
      self.request();
    });
    function up(e) {
      delete self.pointers[e.pointerId];
      self._drag = Object.keys(self.pointers).length ? self._drag : null;
    }
    cv.addEventListener('pointerup', up);
    cv.addEventListener('pointercancel', up);
    cv.addEventListener('pointerleave', function () { self.hover = null; self.request(); });
    cv.addEventListener('wheel', function (e) {
      if (!self.opts.wheel) return;
      e.preventDefault();
      self._interacted();
      self.zoom(Math.exp(e.deltaY * 0.0015), e.offsetX);
    }, { passive: false });
    cv.addEventListener('dblclick', function () { self.reset(); });
  };

  Viewer.prototype._interacted = function () {
    if (this.opts.onInteract) this.opts.onInteract();
  };

  Viewer.prototype.objects = function (side) {
    return this.parity ? this.parity[side || this.side] : null;
  };

  /* objects whose drawing overlaps the visible bars, with how many found their twin */
  Viewer.prototype.stats = function () {
    if (!this.parity) return null;
    var from = this.from, to = this.to, n = this.bars.n;
    function inView(a, b) { return Math.max(a, b) >= from - 1 && Math.min(a, b) <= to + 1; }
    function count(side) {
      var o = side, tot = 0, same = 0, price = 0, none = 0;
      o.labels.forEach(function (l) { if (inView(l[0], l[0])) { tot++; l[6] === 1 ? same++ : l[6] === 2 ? price++ : none++; } });
      o.lines.forEach(function (l) { if (inView(l[0], l[2])) { tot++; l[6] === 1 ? same++ : l[6] === 2 ? price++ : none++; } });
      o.boxes.forEach(function (b) { if (inView(b[0], b[2] < 0 ? n + 80 : b[2])) { tot++; b[6] === 1 ? same++ : b[6] === 2 ? price++ : none++; } });
      return { total: tot, same: same, priceOnly: price, unmatched: none };
    }
    var i0 = Math.max(0, Math.floor(from)), i1 = Math.min(n - 1, Math.ceil(to)), candles = 0, sameC = 0;
    var a = this.parity.tv.candles, b = this.parity.mt5.candles;
    for (var i = i0; i <= i1; i++) { candles++; if (a[i] === b[i]) sameC++; }
    return { side: this.side, tv: count(this.parity.tv), mt5: count(this.parity.mt5), candles: candles, sameCandles: sameC };
  };

  Viewer.prototype.draw = function () {
    var ctx = this.ctx, W = this.W, H = this.H, dpr = this.dpr;
    if (!W) return;
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    ctx.fillStyle = C.bg;
    ctx.fillRect(0, 0, W, H);
    if (!this.bars) return;

    var B = this.bars, P = this.parity, side = P ? P[this.side] : null, diff = this.mode === 'diff';
    var plotW = W - AXIS_W, plotH = H - TIME_H;
    this.plotW = plotW;
    var from = this.from, to = this.to, bw = plotW / (to - from);
    var i0 = Math.max(0, Math.floor(from)), i1 = Math.min(B.n - 1, Math.ceil(to));
    var lo = Infinity, hi = -Infinity;
    for (var i = i0; i <= i1; i++) { if (B.l[i] < lo) lo = B.l[i]; if (B.h[i] > hi) hi = B.h[i]; }
    if (!isFinite(lo)) { lo = B.l[B.n - 1]; hi = B.h[B.n - 1]; }
    var pad = (hi - lo) * 0.1 || 1;
    lo -= pad; hi += pad;
    var top = 8, ph = plotH - top;
    function X(p) { return (p - from + 0.5) * bw; }
    function Y(v) { return top + (hi - v) / (hi - lo) * ph; }

    // grid and price axis
    var step = niceStep(hi - lo, Math.max(3, Math.round(ph / 56)));
    var decimals = step < 0.1 ? 3 : step < 1 ? 2 : step < 10 ? 1 : 0;
    ctx.font = '11px "JetBrains Mono", ui-monospace, monospace';
    ctx.textBaseline = 'middle';
    ctx.textAlign = 'left';
    for (var v = Math.ceil(lo / step) * step; v <= hi; v += step) {
      var gy = Math.round(Y(v)) + 0.5;
      ctx.strokeStyle = C.grid; ctx.lineWidth = 1; ctx.setLineDash([]);
      ctx.beginPath(); ctx.moveTo(0, gy); ctx.lineTo(plotW, gy); ctx.stroke();
      ctx.fillStyle = C.axis;
      ctx.fillText(v.toFixed(decimals), plotW + 8, gy);
    }
    // time axis: a tick every ~110 px, the day written when it changes
    var every = Math.max(1, Math.round(110 / bw)), lastDay = -1;
    ctx.textAlign = 'center';
    for (i = i0 - (i0 % every); i <= i1; i += every) {
      if (i < 0) continue;
      var gx = Math.round(X(i)) + 0.5, day = Math.floor(B.t[i] / 86400);
      ctx.strokeStyle = C.grid;
      ctx.beginPath(); ctx.moveTo(gx, top); ctx.lineTo(gx, plotH); ctx.stroke();
      ctx.fillStyle = C.axis;
      ctx.fillText(fmtTime(B.t[i], day !== lastDay), gx, plotH + TIME_H / 2);
      lastDay = day;
    }
    ctx.strokeStyle = C.axisLine;
    ctx.beginPath(); ctx.moveTo(plotW + 0.5, 0); ctx.lineTo(plotW + 0.5, H); ctx.moveTo(0, plotH + 0.5); ctx.lineTo(W, plotH + 0.5); ctx.stroke();

    ctx.save();
    ctx.beginPath(); ctx.rect(0, 0, plotW, plotH); ctx.clip();

    // candles, coloured by each platform's own trend colours
    var pal = P ? P.palette : null, cs = side ? side.candles : null;
    var body = Math.max(1, Math.min(bw * 0.68, 14));
    for (i = i0; i <= i1; i++) {
      var o = B.o[i], c = B.c[i], col;
      var k = cs ? cs.charAt(i) : '-';
      col = k !== '-' && pal ? '#' + pal[+k] : (c >= o ? C.up : C.down);
      var cx = X(i);
      ctx.strokeStyle = col; ctx.fillStyle = col; ctx.lineWidth = 1;
      ctx.beginPath(); ctx.moveTo(Math.round(cx) + 0.5, Y(B.h[i])); ctx.lineTo(Math.round(cx) + 0.5, Y(B.l[i])); ctx.stroke();
      var y1 = Y(Math.max(o, c)), y2 = Y(Math.min(o, c));
      ctx.fillRect(Math.round(cx - body / 2), Math.round(y1), Math.max(1, Math.round(body)), Math.max(1, Math.round(y2 - y1)));
    }

    if (side) {
      var fade = diff ? 0.22 : 1;
      var visible = function (a, b) { return Math.max(a, b) >= from - 2 && Math.min(a, b) <= to + 2; };
      var marks = [];
      // boxes: order blocks, fair value gaps, premium / discount zones
      side.boxes.forEach(function (b) {
        var right = b[2] < 0 ? to + 2 : b[2];
        if (!visible(b[0], right)) return;
        var xa = X(b[0]), xb = b[2] < 0 ? plotW : X(b[2]), ya = Y(b[1]), yb = Y(b[3]);
        ctx.globalAlpha = diff && b[6] === 1 ? fade : 1;
        var bg = rgba(b[4]), br = rgba(b[5]);
        if (bg) { ctx.fillStyle = bg; ctx.fillRect(xa, ya, xb - xa, yb - ya); }
        if (br) { ctx.strokeStyle = br; ctx.lineWidth = 1; ctx.setLineDash([]); ctx.strokeRect(xa + 0.5, ya + 0.5, xb - xa - 1, yb - ya - 1); }
        if (diff && b[6] !== 1) marks.push({ x: (xa + xb) / 2, y: (ya + yb) / 2, m: b[6] });
      });
      // lines: structure, equal highs / lows, levels
      side.lines.forEach(function (l) {
        if (!visible(l[0], l[2])) return;
        ctx.globalAlpha = diff && l[6] === 1 ? fade : 1;
        ctx.strokeStyle = diff && l[6] !== 1 ? (l[6] === 2 ? C.amber : C.magenta) : '#' + l[4];
        ctx.lineWidth = diff && l[6] !== 1 ? 2 : 1;
        ctx.setLineDash(DASH[l[5]] || []);
        ctx.beginPath(); ctx.moveTo(X(l[0]), Math.round(Y(l[1])) + 0.5); ctx.lineTo(X(l[2]), Math.round(Y(l[3])) + 0.5); ctx.stroke();
      });
      ctx.setLineDash([]);
      // labels: BOS, CHoCH, EQH/EQL, HH/HL/LH/LL, strong / weak, zones, levels
      side.labels.forEach(function (l) {
        if (!visible(l[0], l[0])) return;
        var px = SIZE[l[5]] || 9, lx = X(l[0]), ly = Y(l[1]);
        ctx.globalAlpha = diff && l[6] === 1 ? fade : 1;
        ctx.font = px + 'px ' + FONT;
        ctx.fillStyle = diff && l[6] !== 1 ? (l[6] === 2 ? C.amber : C.magenta) : '#' + l[3];
        if (l[4] === 0) { ctx.textAlign = 'center'; ctx.textBaseline = 'bottom'; ctx.fillText(l[2], lx, ly - 2); }
        else if (l[4] === 1) { ctx.textAlign = 'center'; ctx.textBaseline = 'top'; ctx.fillText(l[2], lx, ly + 2); }
        else { ctx.textAlign = 'left'; ctx.textBaseline = 'middle'; ctx.fillText(l[2], lx + 4, ly); }
        if (diff && l[6] !== 1) marks.push({ x: lx, y: ly, m: l[6] });
      });
      ctx.globalAlpha = 1;
      marks.forEach(function (mk) {
        ctx.strokeStyle = mk.m === 2 ? C.amber : C.magenta; ctx.lineWidth = 1.5;
        ctx.beginPath(); ctx.arc(mk.x, mk.y, 9, 0, Math.PI * 2); ctx.stroke();
      });
    }

    // crosshair and bar readout
    if (this.hover && this.hover.x < plotW && this.hover.y < plotH) {
      var hi2 = Math.round(from + this.hover.x / bw - 0.5);
      ctx.strokeStyle = C.cross; ctx.setLineDash([3, 3]); ctx.lineWidth = 1;
      ctx.beginPath(); ctx.moveTo(this.hover.x + 0.5, 0); ctx.lineTo(this.hover.x + 0.5, plotH);
      ctx.moveTo(0, this.hover.y + 0.5); ctx.lineTo(plotW, this.hover.y + 0.5); ctx.stroke();
      ctx.setLineDash([]);
      if (hi2 >= 0 && hi2 < B.n) this._readout = { i: hi2, t: B.t[hi2], o: B.o[hi2], h: B.h[hi2], l: B.l[hi2], c: B.c[hi2] };
    } else {
      this._readout = null;
    }
    ctx.restore();

    // last price tag
    var last = B.c[B.n - 1], ly2 = Y(last);
    if (ly2 > 0 && ly2 < plotH) {
      ctx.fillStyle = B.c[B.n - 1] >= B.o[B.n - 1] ? C.up : C.down;
      ctx.fillRect(plotW + 1, ly2 - 9, AXIS_W - 1, 18);
      ctx.fillStyle = '#fff'; ctx.textAlign = 'left'; ctx.textBaseline = 'middle';
      ctx.font = '600 11px "JetBrains Mono", ui-monospace, monospace';
      ctx.fillText(last.toFixed(2), plotW + 7, ly2);
    }

    // legend, the way each platform names the study
    var legend = this.opts.legend ? this.opts.legend[this.side] : null;
    if (legend && W < 560) legend = this.side === 'tv' ? 'TradingView' : 'MetaTrader 5';
    ctx.textAlign = 'left'; ctx.textBaseline = 'top';
    ctx.font = '600 12px "Archivo", system-ui, sans-serif';
    ctx.fillStyle = '#e8ecf2';
    var head = (B.symbol || '') + ' · ' + (B.tf || '') + (legend ? '   ' : '');
    ctx.fillText(head, 12, 12);
    if (legend) {
      var hw = ctx.measureText(head).width;
      ctx.fillStyle = this.side === 'tv' ? '#5b8cff' : '#f0b90b';
      ctx.fillText(legend, 12 + hw, 12);
    }
    if (this._readout) {
      var r = this._readout;
      ctx.font = '11px "JetBrains Mono", ui-monospace, monospace';
      ctx.fillStyle = C.axis;
      ctx.fillText(fmtTime(r.t, true) + ' ' + fmtTime(r.t) + '  O ' + r.o.toFixed(2) + '  H ' + r.h.toFixed(2) +
        '  L ' + r.l.toFixed(2) + '  C ' + r.c.toFixed(2), 12, 30);
    }
  };

  Viewer.prototype.destroy = function () { this._ro.disconnect(); };

  window.SMCViewer = Viewer;
})();
