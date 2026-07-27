// Kiosk Toast — domain-aware, animated notifications
// Uses Motion One (window.Motion) for orchestrated entrance/exit + spring physics.
// Falls back to plain CSS transitions if Motion is not available.
//
// Public API (window.toast):
//   toast.show(opts)            — full control
//   toast.success / .error / .warning / .info(opts | string)
//   toast.saved()               — tiny "guardado" check, 1.1s
//   toast.product({ id, name, image, qty, qtyDelta, total, removed, unit, cartTotal })
//   toast.setProductCartTotal(productId, cartTotal) — update cart total on a live toast in-place
//   toast.stockError({ id, name, image, available, requested, mode })
//   toast.dismiss(id)
//
// Backwards compatibility: window.growl(html, opts) is preserved.
//
// Lifecycle: works with Turbolinks. Container is created lazily and the live
// registry is reset on every visit so we don't try to update detached nodes.

(function () {
  'use strict';

  var CONTAINER_ID = 'toast-container';
  var DEFAULT_DURATION = 4000;

  function M() { return window.Motion || null; }

  var liveToasts = Object.create(null); // id -> { el, timer, opts, expiresAt, createdAt }

  // ---------- container ----------

  function ensureContainer() {
    var c = document.getElementById(CONTAINER_ID);
    if (c) return c;
    c = document.createElement('div');
    c.id = CONTAINER_ID;
    c.setAttribute('role', 'region');
    c.setAttribute('aria-label', 'Notificaciones');
    document.body.appendChild(c);
    return c;
  }

  // ---------- helpers ----------

  function nextId() {
    return 't_' + Math.random().toString(36).slice(2, 9);
  }

  function escapeHtml(s) {
    if (s == null) return '';
    return String(s)
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&#39;');
  }

  function prefersReducedMotion() {
    return window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  }

  function isMobile() {
    return window.matchMedia && window.matchMedia('(max-width: 600px)').matches;
  }

  // ---------- timers / progress bar ----------

  function clearTimer(entry) {
    if (entry.timer) {
      clearTimeout(entry.timer);
      entry.timer = null;
    }
  }

  function startTimer(entry) {
    clearTimer(entry);
    if (entry.opts.sticky) return;
    var duration = entry.opts.duration || DEFAULT_DURATION;
    entry.expiresAt = Date.now() + duration;
    var bar = entry.el.querySelector('.toast-progress-bar');
    if (bar) {
      bar.style.transition = 'none';
      bar.style.transform = 'scaleX(1)';
      // force reflow
      // eslint-disable-next-line no-unused-expressions
      bar.offsetWidth;
      bar.style.transition = 'transform ' + duration + 'ms linear';
      bar.style.transform = 'scaleX(0)';
    }
    entry.timer = setTimeout(function () { dismissEntry(entry); }, duration);
  }

  // ---------- SVG icons (animated per type) ----------

  function svgFor(type) {
    switch (type) {
      case 'success':
      case 'cupon':
        return '<svg class="toast-svg toast-svg-check" viewBox="0 0 28 28" aria-hidden="true">' +
          '<circle class="toast-svg-circle" cx="14" cy="14" r="12" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="square"/>' +
          '<path class="toast-svg-check-path" d="M8 14.5l4 4 8-9" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="square" stroke-linejoin="miter"/>' +
          '</svg>';

      case 'cart-add':
        return '<svg class="toast-svg toast-svg-plus" viewBox="0 0 28 28" aria-hidden="true">' +
          '<circle class="toast-svg-circle" cx="14" cy="14" r="12" fill="currentColor" opacity="0.12"/>' +
          '<circle class="toast-svg-circle" cx="14" cy="14" r="12" fill="none" stroke="currentColor" stroke-width="2"/>' +
          '<path class="toast-svg-plus-h" d="M7 14h14" stroke="currentColor" stroke-width="2.8" stroke-linecap="square"/>' +
          '<path class="toast-svg-plus-v" d="M14 7v14" stroke="currentColor" stroke-width="2.8" stroke-linecap="square"/>' +
          '</svg>';

      case 'cart-decrement':
        return '<svg class="toast-svg toast-svg-minus" viewBox="0 0 28 28" aria-hidden="true">' +
          '<circle class="toast-svg-circle" cx="14" cy="14" r="12" fill="currentColor" opacity="0.12"/>' +
          '<circle class="toast-svg-circle" cx="14" cy="14" r="12" fill="none" stroke="currentColor" stroke-width="2"/>' +
          '<path class="toast-svg-minus-h" d="M7 14h14" stroke="currentColor" stroke-width="2.8" stroke-linecap="square"/>' +
          '</svg>';

      case 'error':
      case 'stock-error':
      case 'cupon-error':
        return '<svg class="toast-svg toast-svg-cross" viewBox="0 0 28 28" aria-hidden="true">' +
          '<circle class="toast-svg-circle" cx="14" cy="14" r="12" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="square"/>' +
          '<path class="toast-svg-cross-1" d="M9 9l10 10" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="square"/>' +
          '<path class="toast-svg-cross-2" d="M19 9L9 19" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="square"/>' +
          '</svg>';

      case 'warning':
        return '<svg class="toast-svg toast-svg-warn" viewBox="0 0 28 28" aria-hidden="true">' +
          '<path class="toast-svg-tri" d="M14 3L26 24H2z" fill="none" stroke="currentColor" stroke-width="2" stroke-linejoin="miter"/>' +
          '<path class="toast-svg-bang" d="M14 11v6" stroke="currentColor" stroke-width="2.4" stroke-linecap="square"/>' +
          '<circle class="toast-svg-dot" cx="14" cy="20.5" r="1.4" fill="currentColor"/>' +
          '</svg>';

      case 'info':
        return '<svg class="toast-svg toast-svg-info" viewBox="0 0 28 28" aria-hidden="true">' +
          '<circle class="toast-svg-circle" cx="14" cy="14" r="12" fill="none" stroke="currentColor" stroke-width="2"/>' +
          '<circle class="toast-svg-dot" cx="14" cy="9" r="1.6" fill="currentColor"/>' +
          '<path class="toast-svg-bar" d="M14 13v8" stroke="currentColor" stroke-width="2.4" stroke-linecap="square"/>' +
          '</svg>';

      case 'cart-remove':
        return '<svg class="toast-svg toast-svg-cart-out" viewBox="0 0 28 28" aria-hidden="true">' +
          '<path class="toast-svg-cart" d="M3 6h3l3 12h13l3-9H8" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="square" stroke-linejoin="miter"/>' +
          '<circle cx="11" cy="23" r="1.6" fill="currentColor"/>' +
          '<circle cx="20" cy="23" r="1.6" fill="currentColor"/>' +
          '<path class="toast-svg-arrow" d="M14 9v6M11 12l3 3 3-3" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="square" stroke-linejoin="miter"/>' +
          '</svg>';

      case 'saved':
        return '<svg class="toast-svg toast-svg-saved" viewBox="0 0 16 16" aria-hidden="true">' +
          '<path class="toast-svg-check-path" d="M3 8.5l3.2 3.2L13 5" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="square" stroke-linejoin="miter"/>' +
          '</svg>';

      default:
        return '';
    }
  }

  // ---------- markup ----------

  function buildBody(opts) {
    var parts = [];
    parts.push('<span class="toast-accent" aria-hidden="true"></span>');

    var iconHtml = '';
    if (opts.image) {
      iconHtml = '<div class="toast-thumb">' +
        '<img src="' + escapeHtml(opts.image) + '" alt="" onerror="this.parentNode.classList.add(\'no-img\')">' +
        '<span class="toast-thumb-badge">' + svgFor(opts.type) + '</span>' +
        '</div>';
    } else if (opts.icon !== false) {
      var svg = svgFor(opts.type);
      if (svg) iconHtml = '<div class="toast-icon">' + svg + '</div>';
    }
    if (iconHtml) parts.push(iconHtml);

    var body = ['<div class="toast-body">'];
    if (opts.eyebrow) body.push('<div class="toast-eyebrow">' + escapeHtml(opts.eyebrow) + '</div>');
    if (opts.title)   body.push('<div class="toast-title">'   + escapeHtml(opts.title)   + '</div>');
    if (opts.html)         body.push('<div class="toast-message">' + opts.html + '</div>');
    else if (opts.message) body.push('<div class="toast-message">' + escapeHtml(opts.message) + '</div>');

    if (opts.qty != null || opts.total != null) {
      body.push('<div class="toast-meta">');
      if (opts.qty != null) {
        var unit = opts.unit ? ' <span class="toast-meta-unit">' + escapeHtml(opts.unit) + '</span>' : '';
        var deltaHtml = '';
        if (opts.qtyDelta && opts.qtyDelta !== 0) {
          var sign = opts.qtyDelta > 0 ? '+' : '';
          deltaHtml = ' <span class="toast-meta-delta ' + (opts.qtyDelta > 0 ? 'pos' : 'neg') + '">' +
                      sign + opts.qtyDelta + '</span>';
        }
        body.push('<span class="toast-meta-qty"><span class="toast-meta-num">' +
                  escapeHtml(String(opts.qty)) + '</span>' + unit + deltaHtml + '</span>');
      }
      if (opts.total != null) {
        body.push('<span class="toast-meta-total">' + escapeHtml(String(opts.total)) + '</span>');
      }
      body.push('</div>');
    }

    if (opts.cartTotal != null) {
      body.push('<div class="toast-cart-total">' +
        '<span class="toast-cart-total-label">Total del d&#237;a</span>' +
        '<span class="toast-cart-total-value" data-cart-total>' + escapeHtml(String(opts.cartTotal)) + '</span>' +
        '</div>');
    }

    if (opts.action && opts.action.label) {
      body.push('<button type="button" class="toast-action">' + escapeHtml(opts.action.label) + '</button>');
    }
    body.push('</div>');
    parts.push(body.join(''));

    if (!opts.sticky && opts.progress !== false) {
      parts.push('<span class="toast-progress"><span class="toast-progress-bar"></span></span>');
    }

    parts.push('<button type="button" class="toast-close" aria-label="Cerrar">' +
      '<svg width="14" height="14" viewBox="0 0 14 14"><path d="M3 3l8 8M11 3l-8 8" ' +
      'stroke="currentColor" stroke-width="1.6" stroke-linecap="square" fill="none"/></svg>' +
      '</button>');

    return parts.join('');
  }

  // ---------- entrance / exit choreography ----------

  function animateIn(entry) {
    var el = entry.el;
    var Motion = M();
    if (prefersReducedMotion() || !Motion) {
      el.classList.add('toast-visible');
      return;
    }

    var animate = Motion.animate;
    var spring = Motion.spring;
    var stagger = Motion.stagger;
    var fromRight = !isMobile();

    el.style.opacity = '0';
    el.style.transform = fromRight ? 'translateX(40px) scale(0.96)' : 'translateY(-30px) scale(0.96)';

    animate(
      el,
      {
        opacity: [0, 1],
        transform: [
          fromRight ? 'translateX(40px) scale(0.96)' : 'translateY(-30px) scale(0.96)',
          'translateX(0px) scale(1)'
        ]
      },
      { easing: spring({ stiffness: 220, damping: 20, mass: 0.9 }) }
    );

    var accent = el.querySelector('.toast-accent');
    if (accent) {
      animate(accent, { transform: ['scaleY(0)', 'scaleY(1)'] },
        { duration: 0.45, easing: [0.22, 1, 0.36, 1] });
    }

    var bodyChildren = el.querySelectorAll('.toast-body > *');
    if (bodyChildren.length) {
      animate(bodyChildren,
        { opacity: [0, 1], transform: ['translateY(6px)', 'translateY(0)'] },
        { delay: stagger(0.04, { start: 0.08 }), duration: 0.35, easing: [0.22, 1, 0.36, 1] }
      );
    }

    animateIcon(el, entry.opts.type);

    var thumb = el.querySelector('.toast-thumb');
    if (thumb) {
      animate(thumb,
        { transform: ['scale(0.6)', 'scale(1)'], opacity: [0, 1] },
        { duration: 0.5, easing: spring({ stiffness: 320, damping: 16 }) }
      );
    }
  }

  function animateIcon(el, type) {
    var Motion = M();
    if (!Motion || prefersReducedMotion()) return;
    var animate = Motion.animate;
    var spring = Motion.spring;

    // Checkmark draws itself (success / cart-add / saved)
    var checkPath = el.querySelector('.toast-svg-check-path');
    if (checkPath) {
      var len = (checkPath.getTotalLength && checkPath.getTotalLength()) || 30;
      checkPath.style.strokeDasharray = len;
      checkPath.style.strokeDashoffset = len;
      animate(checkPath, { strokeDashoffset: [len, 0] },
        { duration: 0.55, delay: 0.18, easing: [0.65, 0, 0.35, 1] });
    }

    // Circle pop for success/error/info
    var circ = el.querySelector('.toast-svg-circle');
    if (circ) {
      animate(circ, { transform: ['scale(0)', 'scale(1)'], transformOrigin: '14px 14px' },
        { duration: 0.45, easing: spring({ stiffness: 280, damping: 18 }) });
    }

    // Error: cross draws then wobble
    var c1 = el.querySelector('.toast-svg-cross-1');
    var c2 = el.querySelector('.toast-svg-cross-2');
    if (c1 && c2) {
      [c1, c2].forEach(function (p, i) {
        var l = (p.getTotalLength && p.getTotalLength()) || 14;
        p.style.strokeDasharray = l;
        p.style.strokeDashoffset = l;
        animate(p, { strokeDashoffset: [l, 0] },
          { duration: 0.25, delay: 0.2 + i * 0.05, easing: 'ease-out' });
      });
      var svg = el.querySelector('.toast-svg-cross');
      if (svg) {
        animate(svg, { transform: ['translateX(0)', 'translateX(-3px)', 'translateX(3px)', 'translateX(-2px)', 'translateX(0)'] },
          { duration: 0.5, delay: 0.45, easing: 'ease-in-out' });
      }
    }

    // Warning: triangle pop + bang flash
    var tri = el.querySelector('.toast-svg-tri');
    if (tri) {
      animate(tri, { transform: ['scale(0.6)', 'scale(1)'], transformOrigin: '14px 14px' },
        { duration: 0.4, easing: spring({ stiffness: 260, damping: 14 }) });
    }
    var bang = el.querySelector('.toast-svg-warn .toast-svg-bang');
    var dot = el.querySelector('.toast-svg-warn .toast-svg-dot');
    if (bang) {
      animate(bang, { opacity: [0, 1], transform: ['scaleY(0)', 'scaleY(1)'], transformOrigin: '14px 14px' },
        { duration: 0.3, delay: 0.25 });
    }
    if (dot) animate(dot, { opacity: [0, 1] }, { duration: 0.2, delay: 0.45 });

    // Cart-remove arrow nudge down
    var arrow = el.querySelector('.toast-svg-arrow');
    if (arrow) {
      animate(arrow, { transform: ['translateY(-3px)', 'translateY(2px)', 'translateY(0)'] },
        { duration: 0.5, delay: 0.2, easing: spring({ stiffness: 300, damping: 12 }) });
    }

    // Cart-add: plus strokes pop in (rotate + scale)
    var plusH = el.querySelector('.toast-svg-plus-h');
    var plusV = el.querySelector('.toast-svg-plus-v');
    if (plusH && plusV) {
      animate(plusH, { transform: ['scaleX(0)', 'scaleX(1)'], transformOrigin: '14px 14px' },
        { duration: 0.35, delay: 0.18, easing: spring({ stiffness: 320, damping: 14 }) });
      animate(plusV, { transform: ['scaleY(0)', 'scaleY(1)'], transformOrigin: '14px 14px' },
        { duration: 0.35, delay: 0.28, easing: spring({ stiffness: 320, damping: 14 }) });
      var plusSvg = el.querySelector('.toast-svg-plus');
      if (plusSvg) {
        animate(plusSvg, { transform: ['rotate(-90deg) scale(0.6)', 'rotate(0deg) scale(1)'], transformOrigin: '14px 14px' },
          { duration: 0.55, easing: spring({ stiffness: 220, damping: 16 }) });
      }
    }

    // Cart-decrement: minus stroke contracts in then little shake
    var minusH = el.querySelector('.toast-svg-minus-h');
    if (minusH) {
      animate(minusH, { transform: ['scaleX(0)', 'scaleX(1.15)', 'scaleX(1)'], transformOrigin: '14px 14px' },
        { duration: 0.5, delay: 0.15, easing: spring({ stiffness: 280, damping: 14 }) });
      var minusSvg = el.querySelector('.toast-svg-minus');
      if (minusSvg) {
        animate(minusSvg, { transform: ['translateX(-2px)', 'translateX(2px)', 'translateX(-1px)', 'translateX(0)'] },
          { duration: 0.4, delay: 0.4, easing: 'ease-in-out' });
      }
    }
  }

  function animateOut(entry, done) {
    var el = entry.el;
    var Motion = M();
    if (prefersReducedMotion() || !Motion) {
      el.classList.add('toast-leave-fallback');
      setTimeout(done, 200);
      return;
    }
    var fromRight = !isMobile();
    Motion.animate(
      el,
      {
        opacity: [1, 0],
        transform: ['translateX(0) scale(1)',
          fromRight ? 'translateX(40px) scale(0.94)' : 'translateY(-20px) scale(0.94)']
      },
      { duration: 0.22, easing: [0.4, 0, 1, 1] }
    ).finished.then(done, done);
  }

  // ---------- dismissal ----------

  function dismissEntry(entry) {
    if (!entry || entry.dismissing) return;
    entry.dismissing = true;
    clearTimer(entry);
    delete liveToasts[entry.opts.id];
    var el = entry.el;
    var h = el.offsetHeight;
    el.style.height = h + 'px';
    el.style.overflow = 'hidden';
    animateOut(entry, function () {
      var Motion = M();
      var marginTop = getComputedStyle(el).marginTop;
      var marginBottom = getComputedStyle(el).marginBottom;
      function remove() { if (el.parentNode) el.parentNode.removeChild(el); }
      if (Motion && !prefersReducedMotion()) {
        Motion.animate(el,
          { height: [h + 'px', '0px'], marginTop: [marginTop, '0px'], marginBottom: [marginBottom, '0px'] },
          { duration: 0.18, easing: [0.4, 0, 1, 1] }
        ).finished.then(remove, remove);
      } else {
        remove();
      }
    });
  }

  function pruneOverflow() {
    var max = isMobile() ? 3 : 5;
    var ids = Object.keys(liveToasts);
    if (ids.length <= max) return;
    ids.sort(function (a, b) { return liveToasts[a].createdAt - liveToasts[b].createdAt; });
    while (ids.length > max) {
      dismissEntry(liveToasts[ids.shift()]);
    }
  }

  // ---------- swipe-to-dismiss (mobile) ----------

  function attachSwipe(entry) {
    if (!('ontouchstart' in window)) return;
    var el = entry.el;
    var startX = 0, currentX = 0, dragging = false, width = 0;

    el.addEventListener('touchstart', function (e) {
      dragging = true;
      startX = e.touches[0].clientX;
      width = el.offsetWidth;
      el.style.transition = 'none';
      clearTimer(entry);
    }, { passive: true });

    el.addEventListener('touchmove', function (e) {
      if (!dragging) return;
      currentX = e.touches[0].clientX - startX;
      el.style.transform = 'translateX(' + currentX + 'px)';
      el.style.opacity = String(Math.max(0.3, 1 - Math.abs(currentX) / width));
    }, { passive: true });

    el.addEventListener('touchend', function () {
      if (!dragging) return;
      dragging = false;
      el.style.transition = '';
      if (Math.abs(currentX) > width * 0.4) {
        dismissEntry(entry);
      } else {
        el.style.transform = '';
        el.style.opacity = '';
        startTimer(entry);
      }
      currentX = 0;
    });
  }

  // ---------- click / hover handlers ----------

  function attachHandlers(entry) {
    var el = entry.el;
    el.addEventListener('mouseenter', function () {
      clearTimer(entry);
      var bar = el.querySelector('.toast-progress-bar');
      if (bar) {
        var rect = bar.getBoundingClientRect();
        var parent = bar.parentNode.getBoundingClientRect();
        var ratio = parent.width > 0 ? rect.width / parent.width : 0;
        bar.style.transition = 'none';
        bar.style.transform = 'scaleX(' + ratio + ')';
      }
    });
    el.addEventListener('mouseleave', startTimer.bind(null, entry));

    el.addEventListener('click', function (e) {
      if (e.target.closest('.toast-action')) {
        if (entry.opts.action && typeof entry.opts.action.onClick === 'function') {
          entry.opts.action.onClick(entry);
        }
        if (entry.opts.action && entry.opts.action.dismissOnClick !== false) {
          dismissEntry(entry);
        }
        return;
      }
      if (e.target.closest('.toast-close')) { dismissEntry(entry); return; }
      if (typeof entry.opts.onClick === 'function') entry.opts.onClick(entry);
      if (entry.opts.dismissOnClick !== false) dismissEntry(entry);
    });

    attachSwipe(entry);
  }

  // ---------- show / update ----------

  function show(opts) {
    opts = opts || {};
    opts.type = opts.type || 'info';
    opts.id = opts.id || nextId();

    var existing = liveToasts[opts.id];
    if (existing && existing.el && existing.el.parentNode) {
      return updateExisting(existing, opts);
    }

    var container = ensureContainer();
    var el = document.createElement('div');
    el.className = 'toast toast-' + opts.type;
    if (opts.sticky) el.classList.add('toast-sticky');
    if (opts.compact) el.classList.add('toast-compact');
    el.setAttribute('role', opts.type === 'error' ? 'alert' : 'status');
    el.setAttribute('aria-live', opts.type === 'error' ? 'assertive' : 'polite');
    el.dataset.toastId = opts.id;
    el.innerHTML = buildBody(opts);
    container.insertBefore(el, container.firstChild);

    var entry = { el: el, opts: opts, timer: null, createdAt: Date.now() };
    liveToasts[opts.id] = entry;

    attachHandlers(entry);
    pruneOverflow();
    animateIn(entry);
    startTimer(entry);
    return opts.id;
  }

  function updateExisting(entry, newOpts) {
    var merged = Object.assign({}, entry.opts, newOpts);
    entry.opts = merged;

    entry.el.className = 'toast toast-' + merged.type;
    if (merged.sticky) entry.el.classList.add('toast-sticky');
    entry.el.innerHTML = buildBody(merged);
    attachHandlers(entry);

    animateIcon(entry.el, merged.type);

    var Motion = M();
    var num = entry.el.querySelector('.toast-meta-num');
    if (num && Motion && !prefersReducedMotion()) {
      Motion.animate(num,
        { transform: ['scale(1)', 'scale(1.45)', 'scale(1)'] },
        { duration: 0.55, easing: Motion.spring({ stiffness: 360, damping: 12 }) });
      num.classList.add('flash');
      setTimeout(function () { num.classList.remove('flash'); }, 600);
    }

    if (Motion && !prefersReducedMotion()) {
      Motion.animate(entry.el,
        { transform: ['scale(1)', 'scale(1.025)', 'scale(1)'] },
        { duration: 0.35, easing: Motion.spring({ stiffness: 320, damping: 14 }) });
    }

    startTimer(entry);
    return merged.id;
  }

  function shortcut(type) {
    return function (opts) {
      if (typeof opts === 'string') opts = { message: opts };
      opts.type = type;
      return show(opts);
    };
  }

  // ---------- public API ----------

  var toast = {
    show: show,
    success: shortcut('success'),
    error: shortcut('error'),
    warning: shortcut('warning'),
    info: shortcut('info'),
    dismiss: function (id) { var e = liveToasts[id]; if (e) dismissEntry(e); },

    saved: function () {
      return show({
        id: '__saved__',
        type: 'saved',
        compact: true,
        progress: false,
        duration: 1100,
        message: 'Guardado'
      });
    },

    product: function (p) {
      var id = 'producto_' + p.id;
      var removed = !!p.removed || (p.qty === 0);
      var decrement = !removed && p.qtyDelta != null && p.qtyDelta < 0;
      var type = removed ? 'cart-remove' : (decrement ? 'cart-decrement' : 'cart-add');
      var eyebrow;
      if (removed) {
        eyebrow = 'ELIMINADO DEL CARRITO';
      } else if (decrement) {
        var n = Math.abs(p.qtyDelta);
        eyebrow = n === 1 ? 'QUITASTE 1 UNIDAD' : ('QUITASTE ' + n + ' UNIDADES');
      } else if (p.qtyDelta && p.qtyDelta > 1) {
        eyebrow = 'AGREGASTE +' + p.qtyDelta;
      } else {
        eyebrow = p.qty === 1 ? 'AGREGADO AL CARRITO' : 'SUMASTE 1 UNIDAD';
      }
      return show({
        id: id,
        type: type,
        eyebrow: eyebrow,
        title: p.name,
        image: p.image,
        qty: p.qty,
        qtyDelta: p.qtyDelta,
        unit: p.unit || (p.qty === 1 ? 'unidad' : 'unidades'),
        total: p.total,
        duration: 3500
      });
    },

    setProductCartTotal: function (productId, cartTotal) {
      var toastId = 'producto_' + productId;
      var entry = liveToasts[toastId];
      if (!entry || !entry.el) return;
      var valueEl = entry.el.querySelector('[data-cart-total]');
      if (valueEl) {
        valueEl.textContent = cartTotal;
        entry.opts.cartTotal = cartTotal;
      } else {
        // Toast was rendered without the row (empty pedido) — inject it now
        var body = entry.el.querySelector('.toast-body');
        if (body) {
          var div = document.createElement('div');
          div.className = 'toast-cart-total';
          div.innerHTML = '<span class="toast-cart-total-label">Total del d\u00eda</span>' +
            '<span class="toast-cart-total-value" data-cart-total>' + escapeHtml(String(cartTotal)) + '</span>';
          body.appendChild(div);
          entry.opts.cartTotal = cartTotal;
        }
      }
    },

    stockError: function (p) {
      var available = (p.available == null) ? 0 : p.available;
      var msg;
      if (p.mode === 'sin_stock' || available <= 0) {
        msg = 'Sin stock disponible';
      } else {
        msg = 'Solo quedan <strong>' + escapeHtml(String(available)) + '</strong> disponibles' +
              (p.requested ? ' (pediste ' + escapeHtml(String(p.requested)) + ')' : '');
      }
      return show({
        id: 'stock_error_' + (p.id || p.name),
        type: 'stock-error',
        eyebrow: 'STOCK',
        title: p.name,
        html: msg,
        image: p.image,
        duration: 4500
      });
    }
  };

  // ---------- legacy growl shim ----------

  function growlShim(message, options) {
    if (!message) return;
    options = options || {};
    var typeMap = {
      success: 'success',
      error: 'error',
      warning: 'warning',
      info: 'info',
      message: 'saved'
    };
    var type = typeMap[options.style] || 'info';

    if (options.style === 'message' && /^\s*<i[^>]+fa-(save|check)/i.test(message)) {
      return toast.saved();
    }

    return show({
      type: type,
      html: message,
      duration: options.lifespan != null ? options.lifespan : DEFAULT_DURATION,
      onClick: options.onClick,
      sticky: options.lifespan === 0
    });
  }

  window.toast = toast;
  window.growl = growlShim;

  // ---------- Turbolinks lifecycle ----------
  function resetAll() {
    Object.keys(liveToasts).forEach(function (id) {
      clearTimer(liveToasts[id]);
      delete liveToasts[id];
    });
  }
  document.addEventListener('turbolinks:before-render', resetAll);
  document.addEventListener('turbolinks:before-cache', resetAll);
})();
