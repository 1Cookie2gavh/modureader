// Stable inline runs let each page distribute its own spare vertical space.
// They are transparent to EPUB CFIs and are never recreated on a page turn.
const documents = new WeakMap()
const scrollLines = new WeakMap()
const excluded = 'script, style, template, table, pre, ruby, math, svg, figure'
const noteSelector = 'sup, sub, [role="doc-noteref"], [epub\\:type~="noteref"], img[zy-footnote], img.epub-footnote, img.epub-footnote1'
const isNote = el => el.closest(noteSelector)
const runStyle = 'display:inline!important;position:relative!important;top:0px!important;padding:0!important;margin:0!important;border:0!important;font:inherit!important;'

export function preparePageRuns(doc) {
  if (documents.has(doc)) return documents.get(doc)
  // ponytail: bound chapter preparation on mobile; complex publisher layouts keep native spacing.
  if (!doc.body || doc.body.textContent.length > 50000 || !globalThis.Intl?.Segmenter) return null
  const walker = doc.createTreeWalker(doc.body, 4), nodes = []
  for (let node = walker.nextNode(); node; node = walker.nextNode()) {
    if (!node.textContent.trim() || node.parentElement.closest(excluded) || isNote(node.parentElement)) continue
    nodes.push(node)
  }
  const graphemes = new Intl.Segmenter(undefined, { granularity: 'grapheme' })
  const words = new Intl.Segmenter(undefined, { granularity: 'word' })
  const runs = []
  for (const node of nodes) {
    const fragment = doc.createDocumentFragment()
    // Keep joined scripts/Latin words intact; CJK can break between graphemes.
    for (const word of words.segment(node.data)) {
      const segments = /[\p{Script=Han}\p{Script=Hiragana}\p{Script=Katakana}\p{Script=Hangul}]/u.test(word.segment)
        ? graphemes.segment(word.segment) : [word]
      for (const { segment } of segments) {
        const run = doc.createElementNS('http://www.w3.org/1999/xhtml', 'modu-page-run')
        run.__moduPageRun = true
        run.style.cssText = runStyle
        run.textContent = segment
        fragment.append(run)
        runs.push(run)
      }
    }
    node.replaceWith(fragment)
  }
  // Move atomic note markers with their text line without changing their font/baseline.
  const notes = [...doc.body.querySelectorAll(noteSelector)].filter(el => !el.parentElement.closest(noteSelector))
  const noteStyles = notes.map(el => [el, ['position', 'top'].map(name =>
    [name, el.style.getPropertyValue(name), el.style.getPropertyPriority(name)])])
  const state = { runs, notes, noteStyles }
  documents.set(doc, state)
  return state
}

export function resetPageAlignment(doc) {
  invalidateScrollLines(doc)
  const state = documents.get(doc)
  if (!state) return
  for (const run of state.runs) run.style.setProperty('top', '0px', 'important')
  for (const [el, styles] of state.noteStyles)
    for (const [name, value, priority] of styles) {
      if (value) el.style.setProperty(name, value, priority)
      else el.style.removeProperty(name)
    }
}

export function pageLineOffsets(rows, top, bottom, last) {
  if (!rows.length) return []
  const start = top - rows[0].top
  if (last) return rows.map(() => start)
  if (rows.length < 4) return null
  const extra = bottom - rows.at(-1).bottom - start
  const step = extra / (rows.length - 1)
  const typical = (rows.at(-1).top - rows[0].top) / (rows.length - 1)
  // Explicit page breaks/large illustrations must not stretch a sparse page.
  if (Math.abs(step) > Math.min(8, typical * .2)) return null
  if (rows.some((row, i) => i && row.top - rows[i - 1].bottom + step < 1)) return null
  return rows.map((_, i) => start + step * i)
}

export function alignPaginatedText(doc, { height, topMargin, bottomMargin, columnWidth, gap }, vertical) {
  if (vertical || doc.defaultView.getComputedStyle(doc.documentElement)
    .getPropertyValue('--modu-align-pages').trim() !== '1' ||
    !(height > topMargin + bottomMargin && columnWidth > 0)) return
  const state = preparePageRuns(doc)
  if (!state) return
  const stride = columnWidth + gap
  const pageOf = r => Math.max(0, Math.floor((r.left - gap / 2 + 1) / stride))
  const pages = new Map()
  const pageAt = index => {
    if (!pages.has(index)) pages.set(index, { runs: [], notes: [], unsafe: false })
    return pages.get(index)
  }
  // Read all geometry before writing offsets: no repeated forced layouts.
  for (const el of state.runs) {
    if (!el.textContent.trim()) continue
    const rects = [...el.getClientRects()].filter(r => r.width > 0 && r.height > 0)
    for (const r of rects) {
      const page = pageAt(pageOf(r))
      if (rects.length !== 1) page.unsafe = true
      else page.runs.push({ el, r })
    }
  }
  for (const el of doc.body.querySelectorAll('img, svg, table, pre, ruby, math, video, figure')) {
    if (isNote(el)) continue
    for (const r of el.getClientRects())
      if (r.width > 0 && r.height > 0) pageAt(pageOf(r)).unsafe = true
  }
  for (const el of state.notes) {
    const r = el.getBoundingClientRect()
    if (r.width > 0 && r.height > 0) pageAt(pageOf(r)).notes.push({ el, r,
      oldTop: parseFloat(doc.defaultView.getComputedStyle(el).top) || 0 })
  }
  const last = Math.max(...pages.keys())
  for (const [index, page] of pages) {
    if (page.unsafe || !page.runs.length) continue
    const rows = []
    for (const item of page.runs.sort((a, b) => a.r.top - b.r.top)) {
      let row = rows.at(-1)
      if (!row || item.r.top >= row.bottom - 2)
        rows.push(row = { top: item.r.top, bottom: item.r.bottom, runs: [] })
      row.bottom = Math.max(row.bottom, item.r.bottom)
      row.runs.push(item)
    }
    const offsets = pageLineOffsets(rows, topMargin, height - bottomMargin, index === last)
    if (!offsets) continue
    for (const { el, r, oldTop } of page.notes) {
      const distances = rows.map(row => Math.abs((row.top + row.bottom) / 2 - (r.top + r.bottom) / 2))
      const nearest = distances.indexOf(Math.min(...distances))
      el.style.setProperty('position', 'relative', 'important')
      el.style.setProperty('top', `${oldTop + offsets[nearest]}px`, 'important')
    }
    rows.forEach((row, i) => row.runs.forEach(({ el }) =>
      el.style.setProperty('top', `${offsets[i]}px`, 'important')))
  }
}

const interLineStops = (edges, target, min, max, shifts) => {
  let intervals = [[min, max]]
  for (const { top, bottom } of edges) for (const shift of shifts) {
    const a = top - shift - .5, b = bottom - shift + .5
    intervals = intervals.flatMap(([lo, hi]) => b <= lo || a >= hi ? [[lo, hi]]
      : [...(a >= lo ? [[lo, a]] : []), ...(b <= hi ? [[b, hi]] : [])])
  }
  return intervals.map(([lo, hi]) => Math.max(lo, Math.min(hi, target)))
}
const closestStop = (candidates, target) => candidates.length
  ? candidates.reduce((a, b) => Math.abs(a - target) < Math.abs(b - target) ? a : b) : target

// Select an inter-line stop before scrolling, keeping overlap at 100% steps.
export function safeScrollOffset(edges, target, current, viewport) {
  if (!edges.length || !Number.isFinite(target) || target === current) return target
  const forward = target > current
  const limit = Math.min(120, viewport * .15)
  const min = forward ? Math.max(current + 1, target - limit) : target
  const max = forward ? target : Math.min(current - 1, target + limit)
  if (min > max) return target
  const both = interLineStops(edges, target, min, max, [0, viewport])
  // ponytail: simultaneous gaps can be impossible at fixed height. Prioritize the
  // leading edge in the reading direction, without masking text or changing layout.
  return closestStop(both.length ? both : interLineStops(edges, target, min, max,
    [forward ? viewport : 0]), target)
}

export function settledScrollOffset(edges, target, previous, viewport) {
  if (!edges.length || !Number.isFinite(target) || target === previous) return target
  const limit = Math.min(48, viewport * .08), min = Math.max(0, target - limit), max = target + limit
  const both = interLineStops(edges, target, min, max, [0, viewport])
  return closestStop(both.length ? both : interLineStops(edges, target, min, max,
    [target > previous ? viewport : 0]), target)
}

export function invalidateScrollLines(doc) {
  const state = scrollLines.get(doc)
  if (state) state.dirty = true
}

// Cache document-local geometry, not absolute offsets: adjacent chapters can move.
export function prepareScrollLines(doc) {
  if (!doc?.body) return []
  let state = scrollLines.get(doc)
  if (!state) {
    state = { dirty: true, edges: [] }
    const Observer = doc.defaultView?.MutationObserver
    if (Observer) {
      state.observer = new Observer(() => { state.dirty = true })
      state.observer.observe(doc.body, { subtree: true, childList: true,
        characterData: true, attributes: true, attributeFilter: ['style', 'class', 'hidden', 'dir'] })
    }
    scrollLines.set(doc, state)
  }
  if (state.observer?.takeRecords().length) state.dirty = true
  if (!state.dirty) return state.edges
  const edges = []
  if (doc.body.textContent.length <= 300000) {
    const range = doc.createRange()
    const walker = doc.createTreeWalker(doc.body, 4)
    for (let node = walker.nextNode(); node; node = walker.nextNode()) {
      if (!node.textContent.trim() || node.parentElement.closest('script, style')) continue
      range.selectNodeContents(node)
      for (const rect of range.getClientRects()) {
        if (rect.height > 0 && rect.width > 0) edges.push({ top: rect.top, bottom: rect.bottom })
      }
    }
  }
  // Inline runs share line boxes; retain their union instead of per-glyph rects.
  const merged = []
  for (const edge of edges.sort((a, b) => a.top - b.top)) {
    const last = merged.at(-1)
    if (last && edge.top <= last.bottom) last.bottom = Math.max(last.bottom, edge.bottom)
    else merged.push(edge)
  }
  state.edges = merged
  state.dirty = false
  return merged
}

export function lineAlignedOffset(documents, target, current, viewport, settled = false) {
  const edges = []
  for (const { doc, offset } of documents) {
    const lines = prepareScrollLines(doc)
    for (const boundary of [target - offset, target + viewport - offset]) {
      let lo = 0, hi = lines.length
      while (lo < hi) {
        const mid = (lo + hi) >>> 1
        if (lines[mid].bottom < boundary - 120) lo = mid + 1
        else hi = mid
      }
      for (let i = lo; i < lines.length && lines[i].top <= boundary + 120; i++)
        edges.push({ top: lines[i].top + offset, bottom: lines[i].bottom + offset })
    }
  }
  return (settled ? settledScrollOffset : safeScrollOffset)(edges, target, current, viewport)
}
