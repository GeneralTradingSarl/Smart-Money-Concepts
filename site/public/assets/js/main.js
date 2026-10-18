(function () {
  'use strict';
  var reduce = window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches;

  function fill(tpl, v) {
    return tpl.replace(/\{(\w+)\}/g, function (_, k) { return v[k] != null ? v[k] : ''; });
  }

  function initViewer(root) {
    var canvas = root.querySelector('canvas');
    var stat = root.querySelector('[data-stat]');
    var sideBtns = root.querySelectorAll('[data-side]');
    var blinkBtn = root.querySelector('[data-blink]');
    var diffBtn = root.querySelector('[data-diff]');
    var cfgSel = root.querySelector('[data-cfg]');
    var cfgName = root.querySelector('[data-cfg-name]');
    var base = root.getAttribute('data-base') || '/assets/data/';
    var timer = 0, onScreen = true, wantBlink = root.hasAttribute('data-autoblink') && !reduce;

    var viewer = new window.SMCViewer(canvas, {
      bars: +root.getAttribute('data-bars') || 160,
      wheel: root.hasAttribute('data-wheel'),
      legend: { tv: root.getAttribute('data-legend-tv'), mt5: root.getAttribute('data-legend-mt5') }
    });

    function setSide(s) {
      viewer.setSide(s);
      sideBtns.forEach(function (b) { b.setAttribute('aria-pressed', String(b.getAttribute('data-side') === s)); });
    }
    function blink(on) {
      wantBlink = on;
      if (blinkBtn) blinkBtn.setAttribute('aria-pressed', String(on));
      clearInterval(timer);
      if (on && onScreen) timer = setInterval(function () { setSide(viewer.side === 'tv' ? 'mt5' : 'tv'); }, 650);
    }

    viewer.on(function (s) {
      if (!s || !stat) return;
      var side = s[s.side];
      var txt = fill(root.getAttribute('data-t-stat'), { n: side.total, same: side.same });
      if (side.priceOnly) txt += ' · ' + fill(root.getAttribute('data-t-price'), { n: side.priceOnly });
      if (side.unmatched) txt += ' · ' + side.unmatched + ' ≠';
      stat.textContent = txt;
    });

    function load(cfg, keep) {
      root.classList.add('is-loading');
      return window.SMCViewer.load(base, cfg).then(function (d) {
        viewer.setData(d.bars, d.parity, keep);
        root.classList.remove('is-loading');
        root.classList.add('is-ready');
        if (cfgName) cfgName.textContent = d.parity.name;
      }).catch(function () {
        root.classList.remove('is-loading');
        root.classList.add('is-error');
      });
    }

    sideBtns.forEach(function (b) {
      b.addEventListener('click', function () { blink(false); setSide(b.getAttribute('data-side')); });
    });
    if (blinkBtn) blinkBtn.addEventListener('click', function () { blink(!wantBlink); });
    if (diffBtn) diffBtn.addEventListener('click', function () {
      var on = diffBtn.getAttribute('aria-pressed') !== 'true';
      diffBtn.setAttribute('aria-pressed', String(on));
      viewer.setMode(on ? 'diff' : 'normal');
    });
    if (cfgSel) cfgSel.addEventListener('change', function () { load(cfgSel.value, false); });
    root.querySelectorAll('[data-zoom]').forEach(function (b) {
      b.addEventListener('click', function () {
        var z = b.getAttribute('data-zoom');
        if (z === 'reset') viewer.reset(); else viewer.zoom(z === 'in' ? 0.7 : 1.4);
      });
    });

    if ('IntersectionObserver' in window) {
      new IntersectionObserver(function (es) {
        onScreen = es[0].isIntersecting;
        if (wantBlink) blink(true); else clearInterval(timer);
      }).observe(root);
    }

    load(root.getAttribute('data-config') || 'B').then(function () { if (wantBlink) blink(true); });
  }

  function lazyViewers() {
    var roots = document.querySelectorAll('[data-viewer]');
    if (!roots.length) return;
    if (!window.SMCViewer) return;
    roots.forEach(function (r) {
      if (!('IntersectionObserver' in window) || r.hasAttribute('data-eager')) return initViewer(r);
      var io = new IntersectionObserver(function (es) {
        if (es[0].isIntersecting) { io.disconnect(); initViewer(r); }
      }, { rootMargin: '400px' });
      io.observe(r);
    });
  }

  function copy(text) {
    if (navigator.clipboard && window.isSecureContext) return navigator.clipboard.writeText(text);
    var ta = document.createElement('textarea');
    ta.value = text; ta.setAttribute('readonly', ''); ta.style.position = 'fixed'; ta.style.opacity = '0';
    document.body.appendChild(ta); ta.select();
    try { document.execCommand('copy'); } finally { document.body.removeChild(ta); }
    return Promise.resolve();
  }

  document.addEventListener('click', function (e) {
    var b = e.target.closest('[data-copy]');
    if (!b) return;
    copy(b.getAttribute('data-copy')).then(function () {
      var label = b.querySelector('[data-copy-label]') || b;
      var was = label.textContent;
      b.classList.add('is-copied');
      label.textContent = b.getAttribute('data-copied') || 'Copied';
      setTimeout(function () { b.classList.remove('is-copied'); label.textContent = was; }, 1600);
    });
  });

  var menu = document.querySelector('[data-menu]');
  if (menu) menu.addEventListener('click', function () {
    var open = document.body.classList.toggle('nav-open');
    menu.setAttribute('aria-expanded', String(open));
  });
  document.querySelectorAll('.nav-links a').forEach(function (a) {
    a.addEventListener('click', function () { document.body.classList.remove('nav-open'); });
  });

  lazyViewers();
})();
