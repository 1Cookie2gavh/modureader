// Mobile WebViews may send selectionchange without pointercancel/pointerup when the
// native long-press handles take ownership. Observe the selection itself.
export function installSettledSelection(doc, { getRange, onSelection, beforeSelection, delay = 200 }) {
  let timer, generation = 0, disposed = false;
  let previous, pending;
  const same = (a, b) => a && b && a.startContainer === b.startContainer &&
    a.startOffset === b.startOffset && a.endContainer === b.endContainer &&
    a.endOffset === b.endOffset;
  const cancel = () => { generation++; clearTimeout(timer); timer = undefined; pending = undefined; };
  const schedule = () => {
    const next = getRange();
    if (doc.__moduSelectionDragging) { cancel(); return; }
    // Repeated native menu/selection notifications must not postpone the same range forever.
    if (same(pending, next)) return;
    cancel();
    if (!next) { previous = undefined; return; }
    pending = next.cloneRange();
    const scheduled = generation;
    timer = setTimeout(async () => {
      let range = getRange();
      if (!range || doc.__moduQuickMarkEnabled || doc.__moduSelectionDragging) { pending = undefined; return; }
      try { await beforeSelection?.(); } catch { /* Keep the native range on failure. */ }
      if (disposed || generation !== scheduled) return;
      pending = undefined;
      range = getRange();
      if (!range || doc.__moduQuickMarkEnabled || same(previous, range)) return;
      previous = range.cloneRange();
      onSelection();
    }, delay);
  };
  const start = () => { cancel(); previous = undefined; };
  const menu = e => { e.preventDefault(); schedule(); };
  const listeners = [
    ['pointerdown', start], ['touchstart', start], ['selectionchange', schedule],
    ['pointerup', schedule], ['touchend', schedule], ['contextmenu', menu],
  ];
  for (const [name, handler] of listeners) doc.addEventListener(name, handler);
  return () => {
    disposed = true;
    cancel();
    for (const [name, handler] of listeners) doc.removeEventListener(name, handler);
  };
}
