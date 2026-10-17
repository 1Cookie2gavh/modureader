// Chapter Range rects are relative to the iframe viewport. Annotation SVGs
// live in the parent document. Convert through their actual transforms rather
// than assuming both origins coincide (preloaded chapters have their own padding).
export const annotationPointMapper = (doc, svg) => {
    const frame = doc.defaultView?.frameElement
    const matrix = svg.getScreenCTM?.()
    if (!frame || !matrix) return ({ x, y }) => ({ x, y })
    const inverse = matrix.inverse()
    if (![inverse.a, inverse.b, inverse.c, inverse.d, inverse.e, inverse.f].every(Number.isFinite))
        return ({ x, y }) => ({ x, y }) // Hidden/collapsed cached frame; redraw on activation.
    if (svg.ownerDocument === doc) return ({ x, y }) => ({
        x: inverse.a * x + inverse.c * y + inverse.e,
        y: inverse.b * x + inverse.d * y + inverse.f,
    })
    const bounds = frame.getBoundingClientRect()
    const scaleX = frame.offsetWidth ? bounds.width / frame.offsetWidth : 1
    const scaleY = frame.offsetHeight ? bounds.height / frame.offsetHeight : 1
    return ({ x, y }) => {
        const screenX = bounds.left + (frame.clientLeft + x) * scaleX
        const screenY = bounds.top + (frame.clientTop + y) * scaleY
        return { x: inverse.a * screenX + inverse.c * screenY + inverse.e,
            y: inverse.b * screenX + inverse.d * screenY + inverse.f }
    }
}

export const annotationRect = (rect, map, zoom = 1) => {
    const a = map({ x: rect.left * zoom, y: rect.top * zoom })
    const b = map({ x: rect.right * zoom, y: rect.bottom * zoom })
    const left = Math.min(a.x, b.x), top = Math.min(a.y, b.y)
    const right = Math.max(a.x, b.x), bottom = Math.max(a.y, b.y)
    return { left, top, right, bottom, width: right - left, height: bottom - top }
}

// Inline page runs and their text return duplicate native rects. Paint text
// fragments only, merging neighbours so highlights/underlines stay continuous.
export const annotationRangeRects = (range, textOnly = false) => {
    const doc = range.startContainer?.ownerDocument
    if (!textOnly && !doc?.querySelector('modu-page-run')?.__moduPageRun)
        return Array.from(range.getClientRects())
    const root = range.commonAncestorContainer
    const walker = doc.createTreeWalker(root, 4 | 8)
    const rects = []
    for (let node = root.nodeType === 3 || root.nodeType === 4 ? root : walker.nextNode();
        node; node = walker.nextNode()) {
        if (!range.intersectsNode(node)) continue
        const part = doc.createRange()
        part.selectNodeContents(node)
        if (part.compareBoundaryPoints(0, range) < 0) part.setStart(range.startContainer, range.startOffset)
        if (part.compareBoundaryPoints(2, range) > 0) part.setEnd(range.endContainer, range.endOffset)
        if (!part.collapsed) for (const r of part.getClientRects())
            if (r.width > 0 && r.height > 0) rects.push(annotationRect(r, p => p))
    }
    const merged = []
    for (const r of rects.sort((a, b) => a.top - b.top || a.left - b.left)) {
        const last = merged.at(-1)
        if (last && Math.abs(last.top - r.top) < .5 && Math.abs(last.bottom - r.bottom) < .5
            && r.left >= last.left && r.left <= last.right + .5) {
            last.right = Math.max(last.right, r.right)
            last.width = last.right - last.left
        } else merged.push(r)
    }
    return merged
}
