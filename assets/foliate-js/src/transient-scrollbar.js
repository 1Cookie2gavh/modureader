// Shared by reader shadow roots and isolated web panels. No app bridge/network.
(() => {
  globalThis.moduAttachScrollbar = (scroller, host, options = {}) => {
    const doc = scroller.ownerDocument;
    const win = doc.defaultView;
    const root = scroller === doc.scrollingElement || scroller === doc.documentElement;
    const events = root ? doc : scroller;
    const track = doc.createElement('div');
    const thumb = doc.createElement('div');
    track.dataset.moduScrollbar = '';
    thumb.setAttribute('role', 'scrollbar');
    thumb.setAttribute('aria-label', 'Scroll');
    thumb.tabIndex = 0;
    track.style.cssText = 'position:fixed;z-index:2147483646;pointer-events:none;opacity:0;';
    thumb.style.cssText = 'position:absolute;background:rgba(80,105,129,.46);border-radius:4px;touch-action:none;user-select:none;';
    track.append(thumb);
    host.append(track);
    for (const type of ['touchstart', 'touchmove', 'touchend']) {
      thumb.addEventListener(type, e => e.stopPropagation(), {passive: true});
    }
    let timer, drag = null, metrics = null;
    const hide = () => {
      if (drag) return;
      track.style.opacity = '0';
      thumb.style.pointerEvents = 'none';
      thumb.tabIndex = -1;
    };
    const update = () => {
      const viewport = scroller.clientHeight;
      const extent = scroller.scrollHeight;
      const range = extent - viewport;
      if (options.enabled?.() === false || range <= 1 || viewport <= 0) {
        metrics = null;
        hide();
        return;
      }
      const r = root ? {top: 0, left: 0, right: win.innerWidth, bottom: win.innerHeight}
        : scroller.getBoundingClientRect();
      const start = Math.max(0, r.top) + 2;
      const end = Math.min(win.innerHeight, r.bottom) - 2;
      const length = Math.max(0, end - start);
      const size = Math.min(length, Math.max(48, length * viewport / extent));
      const travel = length - size;
      const offset = Math.min(range, Math.max(0, scroller.scrollTop));
      metrics = {range, travel, offset};
      Object.assign(track.style,
        {left: `${Math.min(win.innerWidth, r.right) - 14}px`, top: `${start}px`, width: '14px', height: `${length}px`});
      const position = travel * offset / range;
      Object.assign(thumb.style,
        {left: '4px', top: `${position}px`, width: '8px', height: `${size}px`});
      track.style.transition = options.reducedMotion?.() || win.matchMedia?.('(prefers-reduced-motion: reduce)').matches
        ? 'none' : 'opacity 180ms';
      thumb.setAttribute('aria-orientation', 'vertical');
      thumb.setAttribute('aria-valuemin', '0');
      thumb.setAttribute('aria-valuemax', String(Math.round(range)));
      thumb.setAttribute('aria-valuenow', String(Math.round(offset)));
    };
    const show = () => {
      update();
      if (!metrics) return;
      clearTimeout(timer);
      track.style.opacity = '1';
      thumb.style.pointerEvents = 'auto';
      thumb.tabIndex = 0;
      timer = setTimeout(hide, 1200);
    };
    const moveTo = value => {
      if (!metrics) return;
      const next = Math.max(0, Math.min(metrics.range, value));
      scroller.scrollTop = next;
      show();
    };
    thumb.addEventListener('pointerdown', e => {
      update();
      if (e.button !== 0 || !metrics) return;
      e.preventDefault(); e.stopPropagation();
      drag = {id: e.pointerId, start: e.clientY, ...metrics};
      thumb.setPointerCapture(e.pointerId);
      show();
    });
    thumb.addEventListener('pointermove', e => {
      if (!drag || drag.id !== e.pointerId) return;
      e.preventDefault(); e.stopPropagation();
      const delta = e.clientY - drag.start;
      moveTo(drag.offset + delta * drag.range / Math.max(1, drag.travel));
    });
    const finish = e => {
      if (!drag || drag.id !== e.pointerId) return;
      e.stopPropagation(); drag = null; show();
    };
    thumb.addEventListener('pointerup', finish);
    thumb.addEventListener('pointercancel', finish);
    thumb.addEventListener('lostpointercapture', finish);
    thumb.addEventListener('click', e => { e.preventDefault(); e.stopPropagation(); });
    thumb.addEventListener('keydown', e => {
      if (!metrics) return;
      const delta = {ArrowDown: 40, ArrowRight: 40, ArrowUp: -40, ArrowLeft: -40,
        PageDown: 300, PageUp: -300}[e.key];
      if (delta == null && e.key !== 'Home' && e.key !== 'End') return;
      e.preventDefault(); e.stopPropagation();
      moveTo(e.key === 'Home' ? 0 : e.key === 'End' ? metrics.range : metrics.offset + delta);
    });
    const onScroll = e => { if (root || e.target === scroller) show(); };
    events.addEventListener('scroll', onScroll, {passive: true});
    win.addEventListener('resize', update);
    const observer = typeof win.ResizeObserver === 'function' ? new win.ResizeObserver(update) : null;
    observer?.observe(scroller);
    update(); hide();
    return {update, destroy() {
      clearTimeout(timer); drag = null;
      events.removeEventListener('scroll', onScroll);
      win.removeEventListener('resize', update);
      observer?.disconnect(); track.remove();
    }};
  };
  globalThis.moduAttachDocumentScrollbars = (doc, options = {}) => {
    const root = doc.scrollingElement || doc.documentElement;
    const bars = new Map([[root, globalThis.moduAttachScrollbar(root, doc.documentElement, options)]]);
    const onScroll = e => {
      for (const [node, bar] of bars) {
        if (!node.isConnected) { bar.destroy(); bars.delete(node); }
        else bar.update();
      }
      const element = e.target;
      if (element.nodeType !== 1 || element === root || element.scrollHeight <= element.clientHeight + 1) return;
      if (!bars.has(element)) {
        bars.set(element, globalThis.moduAttachScrollbar(element, doc.documentElement, options));
      }
    };
    doc.addEventListener('scroll', onScroll, true);
    return {destroy() {
      doc.removeEventListener('scroll', onScroll, true);
      for (const bar of bars.values()) bar.destroy();
      bars.clear();
    }};
  };
})();
