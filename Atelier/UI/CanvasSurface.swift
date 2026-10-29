import SwiftUI
import MetalKit

struct CanvasSurface: UIViewRepresentable {
    @ObservedObject var document: PaintDocument
    var brush: BrushPreset
    var tool: PaintTool
    var color: SIMD4<Float>
    var brushSize: Float
    var opacity: Float
    var fingerPainting = false
    var onToolChange: ((PaintTool) -> Void)? = nil
    var onPalette: (() -> Void)? = nil
    var onClipboard: (() -> Void)? = nil
    var onQuickMenu: (() -> Void)? = nil

    func makeUIView(context: Context) -> PencilCanvas {
        let view = PencilCanvas(frame: .zero)
        updateUIView(view, context: context)
        return view
    }
    func updateUIView(_ view: PencilCanvas, context: Context) {
        view.document = document; view.brush = brush; view.tool = tool; view.paintColor = color
        view.brushSize = brushSize; view.paintOpacity = opacity; view.fingerPainting = fingerPainting
        view.onToolChange = onToolChange; view.onPalette = onPalette; view.onClipboard = onClipboard; view.onQuickMenu = onQuickMenu
        view.drawableSize = CGSize(width: document.contents.width, height: document.contents.height)
        view.setNeedsDisplay()
    }
}

@MainActor final class PencilCanvas: MTKView, MTKViewDelegate, UIPencilInteractionDelegate, UIGestureRecognizerDelegate {
    var document: PaintDocument?
    var brush = BrushPreset.fallback
    var tool = PaintTool.paint
    var paintColor = SIMD4<Float>(0.05, 0.05, 0.05, 1)
    var brushSize: Float = 24
    var paintOpacity: Float = 1
    var fingerPainting = false
    var onToolChange: ((PaintTool) -> Void)?
    var onPalette: (() -> Void)?
    var onClipboard: (() -> Void)?
    var onQuickMenu: (() -> Void)?
    private var frameInFlight = false
    private var frameRequested = false
    private var painter: MetalPainter?
    private var active: PaintStroke?
    private weak var activeTouch: UITouch?
    private var predictions: [PencilSample] = []
    private var estimates: [NSNumber: (UUID, Int)] = [:]
    private var lastTool = PaintTool.paint
    private let cursor = CAShapeLayer()
    private var failedRevision: UInt64?
    private var failedStrokeID: UUID?
    private var failedSampleCount = 0

    init(frame: CGRect) {
        super.init(frame: frame, device: MTLCreateSystemDefaultDevice())
        do { painter = try MetalPainter() } catch { accessibilityLabel = error.localizedDescription }
        colorPixelFormat = .bgra8Unorm_srgb
        framebufferOnly = true; isPaused = true; enableSetNeedsDisplay = true; autoResizeDrawable = false
        delegate = self; isMultipleTouchEnabled = true
        accessibilityLabel = "Canvas di pittura"; accessibilityHint = "Disegna con Apple Pencil. Due dita per spostare, pizzica per lo zoom."
        let pencil = UIPencilInteraction(); pencil.delegate = self; addInteraction(pencil)
        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(zoom(_:)))
        let pan = UIPanGestureRecognizer(target: self, action: #selector(pan(_:))); pan.minimumNumberOfTouches = 2; pan.maximumNumberOfTouches = 2
        let rotation = UIRotationGestureRecognizer(target: self, action: #selector(rotate(_:)))
        for gesture in [pinch, pan, rotation] { gesture.delegate = self; gesture.allowedTouchTypes = [NSNumber(value: UITouch.TouchType.direct.rawValue)]; addGestureRecognizer(gesture) }
        let clipboardSwipe = UISwipeGestureRecognizer(target: self, action: #selector(showClipboard))
        clipboardSwipe.direction = .down; clipboardSwipe.numberOfTouchesRequired = 3
        let quickSwipe = UISwipeGestureRecognizer(target: self, action: #selector(showQuickMenu))
        quickSwipe.direction = .down; quickSwipe.numberOfTouchesRequired = 4
        clipboardSwipe.require(toFail: quickSwipe)
        for swipe in [clipboardSwipe, quickSwipe] {
            swipe.allowedTouchTypes = [NSNumber(value: UITouch.TouchType.direct.rawValue)]
            addGestureRecognizer(swipe)
            pinch.require(toFail: swipe); rotation.require(toFail: swipe)
        }
        let undo = UITapGestureRecognizer(target: self, action: #selector(undoTap)); undo.numberOfTouchesRequired = 2
        let redo = UITapGestureRecognizer(target: self, action: #selector(redoTap)); redo.numberOfTouchesRequired = 3
        undo.require(toFail: redo); addGestureRecognizer(undo); addGestureRecognizer(redo)
        let hover = UIHoverGestureRecognizer(target: self, action: #selector(hover(_:)))
        hover.allowedTouchTypes = [NSNumber(value: UITouch.TouchType.pencil.rawValue)]; addGestureRecognizer(hover)
        cursor.strokeColor = UIColor.gray.cgColor; cursor.fillColor = UIColor.clear.cgColor; cursor.lineWidth = 1
        cursor.isHidden = true; layer.addSublayer(cursor)
        NotificationCenter.default.addObserver(self, selector: #selector(memoryWarning), name: UIApplication.didReceiveMemoryWarningNotification, object: nil)
    }
    required init(coder: NSCoder) { fatalError("init(coder:) is not used") }
    deinit { NotificationCenter.default.removeObserver(self) }
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView) {
        if frameInFlight { frameRequested = true; return }
        guard let document, let painter, let drawable = currentDrawable, let pass = currentRenderPassDescriptor else { return }
        if failedRevision == document.revision, failedStrokeID == active?.id, failedSampleCount == (active?.samples.count ?? 0) { return }
        do {
            var temporary = active
            temporary?.samples.append(contentsOf: predictions)
            let texture = try painter.render(document.contents, liveStroke: temporary, finished: false, waitForCompletion: false)
            failedRevision = nil
            guard let command = painter.queue.makeCommandBuffer(), let encoder = command.makeRenderCommandEncoder(descriptor: pass) else { return }
            encoder.setRenderPipelineState(painter.screenPipeline); encoder.setFragmentTexture(texture, index: 0)
            encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4); encoder.endEncoding()
            frameInFlight = true
            frameRequested = false
            command.addCompletedHandler { [weak self] completed in
                let error = completed.error?.localizedDescription
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.frameInFlight = false
                    if let error { self.painter?.invalidateCache(); self.document?.errorMessage = error }
                    if self.frameRequested { self.setNeedsDisplay() }
                }
            }
            command.present(drawable); command.commit()
        } catch {
            failedRevision = document.revision; failedStrokeID = active?.id; failedSampleCount = active?.samples.count ?? 0
            document.errorMessage = error.localizedDescription
        }
    }

    private func sample(_ touch: UITouch) -> PencilSample {
        let point = touch.preciseLocation(in: self)
        let width = Float(document?.contents.width ?? 1), height = Float(document?.contents.height ?? 1)
        return PencilSample(x: Float(point.x / max(1, bounds.width)) * width,
                            y: Float(point.y / max(1, bounds.height)) * height,
                            pressure: touch.type == .pencil && touch.maximumPossibleForce > 0 ? pow(Float(min(1, max(0, touch.force / touch.maximumPossibleForce))), Float(UserDefaults.standard.object(forKey: "pencilPressureExponent") as? Double ?? 1)) : 1,
                            altitude: Float(touch.altitudeAngle), azimuth: Float(touch.azimuthAngle(in: self)),
                            roll: Float(touch.rollAngle), time: touch.timestamp, isPencil: touch.type == .pencil)
    }
    private func append(_ touches: [UITouch]) {
        guard var active else { return }
        for touch in touches {
            let s = sample(touch)
            if active.samples.last?.time == s.time { continue }
            active.samples.append(s)
            if let index = touch.estimationUpdateIndex, !touch.estimatedPropertiesExpectingUpdates.isEmpty {
                estimates[index] = (active.id, active.samples.count - 1)
            }
        }
        self.active = active
    }
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard active == nil, let document, !document.selectedLayer.locked,
              let touch = touches.first(where: { $0.type == .pencil || (fingerPainting && touches.count == 1) }) else { return }
        activeTouch = touch; predictions = []
        active = PaintStroke(brush: brush, tool: tool, color: paintColor, size: brushSize, opacity: paintOpacity,
                             samples: [], seed: brush.seed ^ UInt64(document.selectedLayer.strokes.count + 1))
        append(event?.coalescedTouches(for: touch) ?? [touch]); setNeedsDisplay()
    }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = activeTouch, touches.contains(touch) else { return }
        append(event?.coalescedTouches(for: touch) ?? [touch])
        predictions = (event?.predictedTouches(for: touch) ?? []).map(sample)
        setNeedsDisplay()
    }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = activeTouch, touches.contains(touch) else { return }
        append(event?.coalescedTouches(for: touch) ?? [touch]); predictions = []
        if let active { document?.commit(active) }
        active = nil; activeTouch = nil; setNeedsDisplay()
    }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = activeTouch, touches.contains(touch) else { return }
        if let id = active?.id { estimates = estimates.filter { $0.value.0 != id } }
        active = nil; activeTouch = nil; predictions = []; setNeedsDisplay()
    }
    override func touchesEstimatedPropertiesUpdated(_ touches: Set<UITouch>) {
        for touch in touches {
            guard let index = touch.estimationUpdateIndex, let (id, sampleIndex) = estimates[index] else { continue }
            let updated = sample(touch)
            if active?.id == id, active!.samples.indices.contains(sampleIndex) { active!.samples[sampleIndex] = updated }
            else { document?.refine(strokeID: id, sampleIndex: sampleIndex, sample: updated) }
            if touch.estimatedPropertiesExpectingUpdates.isEmpty { estimates.removeValue(forKey: index) }
        }
        setNeedsDisplay()
    }
    func pencilInteractionDidTap(_ interaction: UIPencilInteraction) { perform(UIPencilInteraction.preferredTapAction) }
    func pencilInteraction(_ interaction: UIPencilInteraction, didReceiveSqueeze squeeze: UIPencilInteraction.Squeeze) {
        if squeeze.phase == .ended { perform(UIPencilInteraction.preferredSqueezeAction) }
    }
    private func perform(_ action: UIPencilPreferredAction) {
        switch action {
        case .switchEraser: onToolChange?(tool == .erase ? lastTool : .erase); if tool != .erase { lastTool = tool }
        case .switchPrevious: let previous = lastTool; lastTool = tool; onToolChange?(previous)
        case .showColorPalette, .showContextualPalette, .showInkAttributes: onPalette?()
        default: break
        }
    }
    @objc private func zoom(_ gesture: UIPinchGestureRecognizer) {
        let scale = hypot(transform.a, transform.b)
        let factor = min(8, max(0.25, scale * gesture.scale)) / max(0.001, scale)
        transform = transform.scaledBy(x: factor, y: factor); gesture.scale = 1
    }
    @objc private func pan(_ gesture: UIPanGestureRecognizer) {
        let p = gesture.translation(in: superview); transform.tx += p.x; transform.ty += p.y; gesture.setTranslation(.zero, in: superview)
    }
    @objc private func rotate(_ gesture: UIRotationGestureRecognizer) { transform = transform.rotated(by: gesture.rotation); gesture.rotation = 0 }
    @objc private func showClipboard() { onClipboard?() }
    @objc private func showQuickMenu() { onQuickMenu?() }
    @objc private func undoTap() { document?.undo() }
    @objc private func redoTap() { document?.redo() }
    @objc private func hover(_ gesture: UIHoverGestureRecognizer) {
        cursor.isHidden = (UserDefaults.standard.object(forKey: "brushCursor") as? Bool == false) || gesture.state == .ended || gesture.state == .cancelled
        let p = gesture.location(in: self)
        let radius = CGFloat(brushSize) * bounds.width / CGFloat(document?.contents.width ?? 1) / 2
        cursor.path = UIBezierPath(ovalIn: CGRect(x: p.x - radius, y: p.y - radius, width: radius * 2, height: radius * 2)).cgPath
    }
    @objc private func memoryWarning() { failedRevision = nil; painter = nil; do { painter = try MetalPainter() } catch { document?.errorMessage = error.localizedDescription } }
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        !(gestureRecognizer is UITapGestureRecognizer) && !(otherGestureRecognizer is UITapGestureRecognizer)
    }
}

struct BrushPreview: View {
    let brush: BrushPreset
    @State private var preview: UIImage?
    @State private var error: String?
    var body: some View {
        Group {
            if let preview { Image(uiImage: preview).resizable().scaledToFit() }
            else if let error { Text(error).font(.caption2).foregroundStyle(.red) }
            else { ProgressView() }
        }
        .onChange(of: brush, initial: true) { _, _ in render() }
        .accessibilityLabel("Anteprima di \(brush.name)")
    }
    private func render() {
        do {
            let painter = try MetalPainter()
            var content = DocumentContents(width: 320, height: 90)
            let length = Float(brush.value("previewLength", 1))
            var samples = PencilSample.demo(width: 320 * length, height: 90, count: 60)
            let pressure = Float(brush.value("previewPressure", 1))
            for i in samples.indices { samples[i].pressure = min(1, samples[i].pressure * pressure) }
            var previewBrush = brush
            if brush.value("previewWetMix", 1) < 0.5 {
                previewBrush.parameters["wetDilution"] = 0; previewBrush.parameters["wetPull"] = 0; previewBrush.parameters["wetCharge"] = 1
            }
            content.layers[0].strokes = [PaintStroke(brush: previewBrush, tool: .paint, color: SIMD4(0.08, 0.08, 0.08, 1),
                                                   size: Float(brush.value("previewSize", 0.5)) * 64, opacity: 1, samples: samples, seed: brush.seed)]
            preview = try painter.image(content); error = nil
        } catch { self.error = error.localizedDescription; preview = nil }
    }
}
