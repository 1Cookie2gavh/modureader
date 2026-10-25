// Selection navigation is driven by a drag, never by a stationary highlight.
const same = (a, b) => a && b && a.startContainer === b.startContainer &&
  a.startOffset === b.startOffset && a.endContainer === b.endContainer && a.endOffset === b.endOffset;
const selected = doc => {
  const selection = doc.getSelection();
  return selection?.rangeCount && !selection.isCollapsed ? selection.getRangeAt(0) : null;
};

export function installSelectionNavigation(doc, { view, isInitialSelection = () => false,
  safeInsets = () => ({}),
  setTimer = setTimeout, clearTimer = clearTimeout } = {}) {
  const win = doc.defaultView, renderer = view.renderer;
  const container = renderer.shadowRoot?.querySelector('#container');
  let drag, timer, turning = false, frozen, disposed = false, generation = 0;
  const listeners = [];
  const frame = () => win.frameElement?.getBoundingClientRect() ?? { left: 0, top: 0,
    right: win.innerWidth, bottom: win.innerHeight };
  const viewport = () => container?.getBoundingClientRect();
  const safeViewport = rect => {
    const safe = safeInsets() ?? {};
    const inset = side => Number.isFinite(safe[side]) ? Math.max(0, safe[side]) : 0;
    return { left: Math.max(rect.left, inset('left')),
      right: Math.min(rect.right, (win.parent?.innerWidth ?? rect.right) - inset('right')),
      top: Math.max(rect.top, inset('top')),
      bottom: Math.min(rect.bottom, (win.parent?.innerHeight ?? rect.bottom) - inset('bottom')) };
  };
  const toScreen = point => { const rect = frame(); return { x: point.x + rect.left, y: point.y + rect.top }; };
  const toDocument = point => { const rect = frame(); return { x: point.x - rect.left, y: point.y - rect.top }; };
  const clear = () => { clearTimer(timer); timer = undefined; };
  const stop = () => {
    clear(); generation++; drag = undefined;
    doc.__moduSelectionDragging = false;
  };
  const reset = () => { stop(); frozen = undefined; };
  const allowed = () => !disposed && !view.isFixedLayout && !doc.__moduQuickMarkEnabled;
  const write = range => {
    if (!range || !range.startContainer.isConnected || !range.endContainer.isConnected) return;
    const writer = drag?.write ?? frozen?.write;
    if (writer) writer(range);
    else {
      if (same(range, selected(doc))) return;
      const selection = doc.getSelection();
      const backwards = drag?.backwards ?? frozen?.backwards;
      selection.setBaseAndExtent(
        backwards ? range.endContainer : range.startContainer,
        backwards ? range.endOffset : range.startOffset,
        backwards ? range.startContainer : range.endContainer,
        backwards ? range.startOffset : range.endOffset);
    }
  };
  const edge = point => {
    let rect = viewport();
    if (!rect || rect.width <= 0 || rect.height <= 0) return null;
    if (drag?.write) rect = safeViewport(rect);
    // Touch handles must reach an edge before entering the system gesture area.
    const sideEdge = drag?.write && !renderer.scrolled && !renderer.vertical &&
      Math.min(point.x - rect.left, rect.right - point.x) <= Math.min(40, (rect.right - rect.left) / 6);
    const horizontal = renderer.vertical || sideEdge;
    const position = horizontal ? point.x : point.y;
    const low = horizontal ? rect.left : rect.top, high = horizontal ? rect.right : rect.bottom;
    const across = horizontal ? point.y : point.x;
    if (across < (horizontal ? rect.top : rect.left) - 24 ||
        across > (horizontal ? rect.bottom : rect.right) + 24) return null;
    const band = Math.min(40, (high - low) / 6);
    const distance = Math.min(position - low, high - position);
    if (distance > band) return null;
    const physical = position < (low + high) / 2 ? -1 : 1;
    const css = win.getComputedStyle(doc.body);
    const reversed = horizontal && (sideEdge ? css.direction === 'rtl' : css.writingMode !== 'vertical-lr');
    return { direction: physical * (reversed ? -1 : 1), physical,
      speed: 40 + 180 * Math.max(0, Math.min(1, 1 - distance / band)) };
  };
  const atPageBoundary = (direction, includeBoundaryGlyph = false) => {
    const range = selected(doc), page = view.lastLocation?.range;
    if (!range || !page || page.startContainer.ownerDocument !== doc) return false;
    if (includeBoundaryGlyph) {
      const probe = range.cloneRange();
      if (direction > 0 && probe.endContainer.nodeType === 3) {
        const length = Array.from(probe.endContainer.data.slice(probe.endOffset))[0]?.length ?? 0;
        probe.setEnd(probe.endContainer, probe.endOffset + length);
      } else if (direction < 0 && probe.startContainer.nodeType === 3) {
        const length = Array.from(probe.startContainer.data.slice(0, probe.startOffset)).at(-1)?.length ?? 0;
        probe.setStart(probe.startContainer, probe.startOffset - length);
      }
      return direction > 0 ? probe.compareBoundaryPoints(win.Range.END_TO_END, page) >= 0
        : probe.compareBoundaryPoints(win.Range.START_TO_START, page) <= 0;
    }
    return direction > 0
      ? range.compareBoundaryPoints(win.Range.END_TO_END, page) >= 0
      : range.compareBoundaryPoints(win.Range.START_TO_START, page) <= 0;
  };
  const canTurn = direction => direction > 0
    ? renderer.page < renderer.pages - 2 : renderer.page > 1;
  // In a single-column page an explicit edge dwell selects up to its boundary;
  // caret hit-testing in margins need not land on the exact final glyph.
  const reachedBoundary = direction => atPageBoundary(direction) ||
    (!!drag?.write && !renderer.vertical && renderer.heads?.length === 1);
  const boundaryRange = direction => {
    const page = view.lastLocation?.range;
    if (!page || !drag?.anchor) return null;
    const range = doc.createRange();
    range.setStart(drag.anchor.node, drag.anchor.offset);
    range.collapse(true);
    if (direction > 0) range.setEnd(page.endContainer, page.endOffset);
    else range.setStart(page.startContainer, page.startOffset);
    return range.collapsed ? null : range;
  };
  const extend = point => {
    if (!drag?.anchor?.node.isConnected) { reset(); return; }
    if (drag?.extend) { drag.extend(point); return; }
    const position = doc.caretPositionFromPoint?.(point.x, point.y);
    const fallback = position ? null : doc.caretRangeFromPoint?.(point.x, point.y);
    const node = position?.offsetNode ?? fallback?.startContainer;
    const offset = position?.offset ?? fallback?.startOffset;
    if (node?.nodeType !== 3 || !doc.body.contains(node) || !Number.isInteger(offset) ||
        offset < 0 || offset > node.length ||
        node.parentElement.closest('button,input,textarea,select,[contenteditable],rt,script,style')) return;
    const range = doc.createRange();
    range.setStart(drag.anchor.node, drag.anchor.offset); range.collapse(true);
    drag.backwards = range.comparePoint(node, offset) < 0;
    if (drag.backwards) range.setStart(node, offset);
    else range.setEnd(node, offset);
    if (!range.collapsed) write(range);
  };
  const schedule = () => {
    if (timer !== undefined || turning || frozen || !drag?.moved || !drag.anchor || !allowed()) return;
    const range = selected(doc);
    if (!range || isInitialSelection(range)) return;
    const side = edge(drag.point);
    if (!side) return;
    if (!renderer.scrolled) {
      if ((side.direction < 0) !== drag.backwards) return;
      if (!canTurn(side.direction)) return;
      // Caret APIs may return the leading half of the last visible glyph.
      if (!atPageBoundary(side.direction) && drag.write && atPageBoundary(side.direction, true))
        write(boundaryRange(side.direction));
      if (!reachedBoundary(side.direction)) return;
      const token = generation, page = renderer.page;
      timer = setTimer(async () => {
        timer = undefined;
        if (token !== generation || !allowed() || !drag || renderer.scrolled ||
            renderer.page !== page || edge(drag.point)?.direction !== side.direction ||
            !reachedBoundary(side.direction) || !canTurn(side.direction)) return;
        const range = boundaryRange(side.direction);
        if (!range) return;
        frozen = { range: range.cloneRange(), backwards: side.direction < 0, write: drag.write, page };
        write(range);
        turning = true;
        try { await (side.direction > 0 ? renderer.next() : renderer.prev()); }
        catch { /* Preserve the selection if navigation fails. */ }
        finally {
          turning = false;
          if (drag) drag.scroll = container?.[renderer.scrollProp];
          const pageRange = view.lastLocation?.range;
          if (!disposed && frozen && renderer.page !== page && pageRange?.startContainer.ownerDocument === doc) {
            if (side.direction > 0) frozen.range.setEnd(pageRange.startContainer, pageRange.startOffset);
            else frozen.range.setStart(pageRange.endContainer, pageRange.endOffset);
          }
          if (frozen) frozen.landedPage = renderer.page;
          if (!disposed && frozen) write(frozen.range);
          if (!drag) doc.dispatchEvent(new win.Event('selectionchange'));
        }
      }, 750);
      return;
    }
    // Stay within this chapter's iframe: a DOM Range cannot span documents.
    timer = setTimer(() => {
      timer = undefined;
      if (!allowed() || !drag || !renderer.scrolled || !selected(doc)) { stop(); return; }
      const side = edge(drag.point), bounds = viewport(), chapter = frame();
      if (!side || !bounds) return;
      const horizontal = renderer.vertical;
      const remaining = side.physical > 0
        ? (horizontal ? chapter.right - bounds.right : chapter.bottom - bounds.bottom)
        : (horizontal ? bounds.left - chapter.left : bounds.top - chapter.top);
      const amount = Math.min(Math.max(0, remaining), side.speed * .032);
      if (amount < .1) return;
      renderer.scrollBy(horizontal ? side.physical * amount : 0, horizontal ? 0 : side.physical * amount);
      extend(toDocument(drag.hitPoint));
      doc.dispatchEvent(new win.Event('selectionchange'));
      schedule();
    }, 32);
  };
  const begin = ({ anchor, backwards = false, point, write: writer, extend: extender } = {}) => {
    reset();
    if (!allowed()) return;
    drag = { anchor, backwards, point: toScreen(point), hitPoint: toScreen(point), origin: toScreen(point),
      scroll: container?.[renderer.scrollProp], write: writer, extend: extender, moved: false };
  };
  const move = (point, pointer = point) => {
    if (!drag || !allowed()) return false;
    // The handle is below the glyph: detect the edge using the finger, while
    // keeping caret hit-testing at its original finger-to-text offset.
    const screen = toScreen(pointer);
    const moved = Math.hypot(screen.x - drag.origin.x, screen.y - drag.origin.y) >= 8;
    drag.point = screen;
    drag.hitPoint = toScreen(point);
    if (turning || frozen) {
      // Finish this contact before re-grabbing the endpoint on the new page.
      // Even moving inward must not teleport it to the old finger position.
      return true;
    }
    drag.moved ||= moved;
    if (drag.moved && selected(doc)) doc.__moduSelectionDragging = true;
    if (!edge(screen)) clear();
    if (drag.moved && drag.anchor && edge(screen) && (renderer.scrolled || drag.write)) {
      extend(point);
      schedule();
      return true;
    }
    schedule();
    return false;
  };
  const change = () => {
    if (!allowed()) { reset(); return; }
    if (drag?.anchor && !drag.anchor.node.isConnected) { reset(); return; }
    const range = selected(doc);
    if (frozen) {
      // Native selection engines may issue a late range update after the flip.
      if (range) write(frozen.range);
      else reset();
      return;
    }
    if (!range) { clear(); return; }
    if (!drag) return;
    if (!drag.anchor) {
      const selection = doc.getSelection();
      drag.anchor = { node: selection.anchorNode, offset: selection.anchorOffset };
    }
    drag.backwards = range.endContainer === drag.anchor.node && range.endOffset === drag.anchor.offset;
    if (drag.moved && !isInitialSelection(range)) doc.__moduSelectionDragging = true;
    schedule();
  };
  const on = (target, name, handler) => {
    target?.addEventListener(name, handler, true);
    listeners.push(() => target?.removeEventListener(name, handler, true));
  };
  on(doc, 'pointerdown', event => {
    if (event.composedPath().some(node => node?.hasAttribute?.('data-modu-selection-handles'))) return;
    if (event.isPrimary === false || event.button > 0 || event.target?.closest?.('a,button,input,textarea,select,[contenteditable]')) { reset(); return; }
    begin({ point: { x: event.clientX, y: event.clientY } });
  });
  on(doc, 'pointermove', event => {
    if (!drag || drag.write) return;
    if (move({ x: event.clientX, y: event.clientY })) event.preventDefault();
  });
  on(doc, 'pointerup', () => {
    if (drag?.write) return;
    const publish = doc.__moduSelectionDragging || frozen;
    stop();
    if (publish) doc.dispatchEvent(new win.Event('selectionchange'));
  });
  on(doc, 'pointercancel', () => { if (!drag?.write) stop(); });
  on(doc, 'touchstart', event => { if (event.touches.length > 1) reset(); });
  on(doc, 'selectionchange', change);
  on(doc, 'keydown', reset);
  on(win, 'blur', stop);
  on(win, 'resize', reset);
  on(doc, 'visibilitychange', reset);
  on(container, 'scroll', () => {
    if (!renderer.scrolled && drag?.moved && !turning && Number.isFinite(drag.scroll) &&
        container[renderer.scrollProp] !== drag.scroll) container[renderer.scrollProp] = drag.scroll;
  });
  on(renderer, 'relocate', event => {
    if (turning || (drag && event.detail.reason === 'scroll')) return;
    // A delayed anchor/snap on the landing page is not a new selection gesture.
    if (frozen && renderer.page === frozen.landedPage &&
        view.lastLocation?.range?.startContainer.ownerDocument === doc) return;
    reset();
  });
  const destroy = () => { disposed = true; reset(); listeners.forEach(remove => remove()); };
  on(win, 'pagehide', destroy);
  return { begin, move, stop, reset, destroy,
    handleBounds() {
      const rect = viewport(), offset = frame();
      if (!rect) return;
      const safe = safeViewport(rect);
      return { left: rect.left - offset.left, right: rect.right - offset.left,
        top: rect.top - offset.top, bottom: rect.bottom - offset.top,
        safe: {
          left: safe.left - offset.left, right: safe.right - offset.left,
          top: safe.top - offset.top, bottom: safe.bottom - offset.top,
        } };
    },
    handleBoundary(end) {
      if (frozen && renderer.page !== frozen.page && end !== frozen.backwards) return !end;
      // Re-grabbing clears the freeze, not the caret's visible side of a page break.
      const range = selected(doc), page = view.lastLocation?.range;
      if (!renderer.scrolled && range && page?.startContainer.ownerDocument === doc) {
        const caret = range.cloneRange();
        caret.collapse(!end);
        if (caret.comparePoint(end ? page.startContainer : page.endContainer,
            end ? page.startOffset : page.endOffset) === 0) return !end;
      }
    },
    get active() { return turning || !!drag?.moved || !!frozen; } };
}
