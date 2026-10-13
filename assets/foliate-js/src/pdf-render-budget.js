// Start conservatively; measure this document on this device, not a model list.
export class PdfRenderBudget {
    constructor(device = globalThis.navigator ?? {}) {
        this.constrained = (device.deviceMemory > 0 && device.deviceMemory <= 4) ||
            (device.hardwareConcurrency > 0 && device.hardwareConcurrency <= 4)
        this.samples = 0
        this.elapsed = 0
    }
    record(milliseconds) {
        if (!Number.isFinite(milliseconds) || milliseconds < 0) return
        this.elapsed = this.samples ? this.elapsed * .5 + milliseconds * .5 : milliseconds
        this.samples++
    }
    get ahead() { return !this.constrained && this.samples >= 3 && this.elapsed < 150 ? 2 : 1 }
    get delay() { return this.elapsed > 350 ? 250 : 80 }
}
