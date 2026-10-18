// Only attached to cropped image/PDF frames, never ordinary ebook chapters.
export function attachPdfZoomInput(doc, { active, zoom, setZoom, pan, boxMode, box, onGesture = () => {} }) {
    const stop = e => { e.preventDefault(); e.stopImmediatePropagation() }
    const point = e => {
        const ts = [...e.touches]
        return ts.length ? { x: ts.reduce((s, t) => s + t.screenX, 0) / ts.length,
            y: ts.reduce((s, t) => s + t.screenY, 0) / ts.length,
            n: ts.length, distance: ts.length === 2 ? Math.hypot(
                ts[0].screenX - ts[1].screenX, ts[0].screenY - ts[1].screenY) : 0 } : null
    }
    let last, start, dragging = false, suppress = 0, mouse, outline
    doc.addEventListener('touchstart', e => {
        if (!active()) return
        last = point(e); start = { ...last, at: Date.now() }
        if (last?.n === 2) { dragging = true; onGesture(); stop(e) }
    }, { capture: true, passive: false })
    doc.addEventListener('touchmove', e => {
        const p = point(e)
        if (!active() || !p || !last) return
        if (!dragging && zoom() > 1 && doc.getSelection()?.type !== 'Range' &&
            Date.now() - start.at < 350 && Math.hypot(p.x - start.x, p.y - start.y) > 8) dragging = true
        if (dragging) {
            onGesture()
            if (p.n === last.n) {
                if (p.n === 2 && last.distance > 0) setZoom(zoom() * p.distance / last.distance)
                pan(last.x - p.x, last.y - p.y)
            }
            stop(e)
        }
        last = p
    }, { capture: true, passive: false })
    for (const type of ['touchend', 'touchcancel']) doc.addEventListener(type, e => {
        if (dragging) { stop(e); suppress = Date.now() + 400 }
        last = point(e)
        if (!last || type === 'touchcancel') dragging = false
    }, { capture: true, passive: false })
    doc.addEventListener('mousedown', e => {
        if (!active() || e.button !== 0 || (!boxMode() && zoom() <= 1)) return
        if (!boxMode() && doc.getSelection()?.type === 'Range') return
        mouse = { x: e.clientX, y: e.clientY, sx: e.screenX, sy: e.screenY, box: boxMode() }
        if (mouse.box) {
            outline = doc.createElement('div')
            Object.assign(outline.style, {position:'fixed', pointerEvents:'none', zIndex:'2147483647',
                border:'2px solid #007b83', background:'rgba(0,123,131,.12)'})
            doc.body.append(outline)
        }
        if (mouse.box) { onGesture(); stop(e) }
    }, { capture: true })
    doc.addEventListener('mousemove', e => {
        if (!mouse) return
        if (!e.buttons) { outline?.remove(); outline=null; mouse=null; return }
        if (!mouse.moved && Math.hypot(e.clientX-mouse.x, e.clientY-mouse.y) <= 8) return
        mouse.moved = true
        onGesture()
        if (mouse.box) Object.assign(outline.style, {left:`${Math.min(mouse.x,e.clientX)}px`,
            top:`${Math.min(mouse.y,e.clientY)}px`, width:`${Math.abs(mouse.x-e.clientX)}px`,
            height:`${Math.abs(mouse.y-e.clientY)}px`})
        else { pan(mouse.sx-e.screenX, mouse.sy-e.screenY); mouse.sx=e.screenX; mouse.sy=e.screenY }
        stop(e)
    }, { capture: true })
    doc.addEventListener('mouseup', e => {
        if (!mouse) return
        if (mouse.box && Math.abs(mouse.x-e.clientX) * (doc.scale || 1) > 12 &&
            Math.abs(mouse.y-e.clientY) * (doc.scale || 1) > 12)
            box({x:Math.min(mouse.x,e.clientX),y:Math.min(mouse.y,e.clientY),
                width:Math.abs(mouse.x-e.clientX),height:Math.abs(mouse.y-e.clientY)})
        const consumed = mouse.moved || mouse.box
        outline?.remove(); outline=null; mouse=null
        if (consumed) { suppress=Date.now()+400; stop(e) }
    }, { capture: true })
    doc.defaultView?.addEventListener('blur', () => { outline?.remove(); outline=null; mouse=null; last=null; dragging=false })
    doc.addEventListener('click', e => { if (Date.now()<suppress) stop(e) }, {capture:true})
}
