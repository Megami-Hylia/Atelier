import CryptoKit
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
        let size = CGSize(width: document.contents.width, height: document.contents.height)
        if view.drawableSize != size { view.drawableSize = size }
        view.requestFrame()
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
    private struct PendingSample {
        var value: PencilSample
        var estimateID: NSNumber?
        var expectingUpdates: Bool
        var force: Bool
    }
    private var pendingSamples: [PendingSample] = []
    private var sampler = StrokeInputSampler()
    private var maximumInputScale: Float = 1
    private var inputEventRevision: UInt64 = 0
    private var failedInputRevision: UInt64?
    private var effectiveInputScale: Float {
        let zoom = max(0.0001,Float(hypot(transform.a,transform.b)))
        return max(0.0001,Float(bounds.width)/Float(document?.contents.width ?? 1)*zoom)
    }
    private var activeSampleRevision: UInt64 = 0
    private var estimates: [NSNumber: (UUID, Int)] = [:]

    private var lastTool = PaintTool.paint
    private let cursor = CAShapeLayer()
    private var failedRevision: UInt64?
    private var failedStrokeID: UUID?

    init(frame: CGRect) {
        super.init(frame: frame, device: MTLCreateSystemDefaultDevice())
        do { painter = try MetalPainter() } catch { accessibilityLabel = error.localizedDescription }
        colorPixelFormat = .bgra8Unorm_srgb
        framebufferOnly = true; isPaused = true; enableSetNeedsDisplay = false; preferredFramesPerSecond = 60; autoResizeDrawable = false
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

    func requestFrame() { frameRequested = true; isPaused = false }

    func draw(in view: MTKView) {
        guard frameRequested || painter?.hasPendingLiveSamples == true else { isPaused = true; return }
        if frameInFlight { return }
        guard let document, let painter, let drawable = currentDrawable, let pass = currentRenderPassDescriptor else { return }
        if failedRevision == document.revision, failedStrokeID == active?.id, failedInputRevision == inputEventRevision { isPaused = true; return }
        do {
            let texture = try painter.render(document.contents, liveStroke: active, finished: false, waitForCompletion: false,
                                             documentRevision: document.revision, liveSampleRevision: activeSampleRevision,
                                             liveStableSampleCount: active?.samples.count ?? 0,
                                             predictedSamples: pendingSamples.map(\.value) + predictions)
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
                    self.isPaused = !(self.frameRequested || self.painter?.hasPendingLiveSamples == true)
                }
            }
            command.present(drawable); command.commit()
        } catch {
            painter.invalidateCache()
            failedRevision = document.revision; failedStrokeID = active?.id; failedInputRevision = inputEventRevision
            isPaused = true
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
    private func append(_ touches: [UITouch], finishing: Bool = false) {
        guard active != nil else { return }
        inputEventRevision &+= 1
        maximumInputScale = max(maximumInputScale,effectiveInputScale)
        for (offset,touch) in touches.enumerated() {
            let value = sample(touch)
            let expects = !touch.estimatedPropertiesExpectingUpdates.isEmpty
            let pending = PendingSample(value: value, estimateID: touch.estimationUpdateIndex,
                                        expectingUpdates: expects, force: finishing && offset == touches.count-1)
            if let last = pendingSamples.last, last.estimateID != nil, last.estimateID == pending.estimateID {
                pendingSamples[pendingSamples.count-1] = pending
            } else if pendingSamples.last?.value != value && (pendingSamples.last != nil || active?.samples.last != value) {
                pendingSamples.append(pending)
            }
        }
        flushPending(force: finishing)
    }
    private func flushPending(force: Bool) {
        while let first = pendingSamples.first, force || !first.expectingUpdates || pendingSamples.count > 32 {
            let point = pendingSamples.removeFirst()
            // Unsettled points are retained when the bounded provisional queue must be drained.
            if sampler.accept(point.value, screenScale: effectiveInputScale, force: point.force || point.expectingUpdates) {
                active?.samples.append(point.value)
                if point.expectingUpdates, let id = point.estimateID, let active {
                    estimates[id] = (active.id,active.samples.count-1)
                }
            }
        }
    }
    private func finishSamples() {
        guard var stroke = active else { return }
        let pinned = Set(estimates.values.filter { $0.0 == stroke.id }.map { $0.1 })
        let components = [stroke.brush] + (stroke.brush.secondaryBrushes ?? [])
        let sensitive = components.contains { brush in
            ["speedSize","speedOpacity","speedSpacing","wetPull","wetDilution","pressureBleed"].contains { abs(brush.value($0)) > 0.00001 }
        } || stroke.tool == .smudge
        if !sensitive {
            let result = StrokeGeometry.simplify(stroke.samples, tolerance: 0.15/maximumInputScale, pinned: pinned)
            if components.allSatisfy({ component in
                StrokeGeometry.equivalentTrajectory(stroke.samples,result.samples,brush: component,
                                                   stabilization: stroke.stabilizationAmount ?? 0,scale: stroke.inputScale ?? 1,
                                                   tolerance: 0.3/maximumInputScale,corrected: stroke.brushSettingsVersion == 1)
            }) {
                let indices = Dictionary(uniqueKeysWithValues: result.retainedIndices.enumerated().map { ($0.element,$0.offset) })
                for (key,value) in estimates where value.0 == stroke.id {
                    if let index = indices[value.1] { estimates[key] = (stroke.id,index) }
                }
                stroke.samples = result.samples
            }
        }
        active = stroke
    }
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard active == nil, let document, !document.selectedLayer.locked,
              let touch = touches.first(where: { $0.type == .pencil || (fingerPainting && touches.count == 1) }) else { return }
        activeTouch = touch; predictions = []; activeSampleRevision = 0; pendingSamples = []; sampler = StrokeInputSampler(); maximumInputScale = effectiveInputScale
        active = PaintStroke(brush: brush, tool: tool, color: paintColor, size: brushSize, opacity: paintOpacity,
                             samples: [], seed: brush.seed ^ UInt64(document.selectedLayer.strokes.count + 1), distanceDynamicsVersion: 1, curveVersion: 1, inputScale: effectiveInputScale,
                             stabilizationAmount: Float(UserDefaults.standard.double(forKey: "strokeStabilization")), brushSettingsVersion: 1)
        append(event?.coalescedTouches(for: touch) ?? [touch]); requestFrame()
    }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = activeTouch, touches.contains(touch) else { return }
        append(event?.coalescedTouches(for: touch) ?? [touch])
        predictions = (event?.predictedTouches(for: touch) ?? []).map(sample)
        requestFrame()
    }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = activeTouch, touches.contains(touch) else { return }
        append(event?.coalescedTouches(for: touch) ?? [touch], finishing: true); predictions = []
        finishSamples()
        if let active { document?.commit(active) }
        active = nil; activeTouch = nil; pendingSamples = []; requestFrame()
    }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = activeTouch, touches.contains(touch) else { return }
        if let id = active?.id { estimates = estimates.filter { $0.value.0 != id } }
        active = nil; activeTouch = nil; predictions = []; pendingSamples = []; requestFrame()
    }
    override func touchesEstimatedPropertiesUpdated(_ touches: Set<UITouch>) {
        inputEventRevision &+= 1
        for touch in touches {
            guard let index = touch.estimationUpdateIndex else { continue }
            let updated = sample(touch)
            if let pendingIndex = pendingSamples.firstIndex(where: { $0.estimateID == index }) {
                pendingSamples[pendingIndex].value = updated
                pendingSamples[pendingIndex].expectingUpdates = !touch.estimatedPropertiesExpectingUpdates.isEmpty
            } else if let (id,sampleIndex) = estimates[index] {
                if active?.id == id, active!.samples.indices.contains(sampleIndex) {
                    active!.samples[sampleIndex] = updated
                    if painter?.hasBakedSample(strokeID: id,index: sampleIndex) == true { activeSampleRevision &+= 1 }
                } else { document?.refine(strokeID: id,sampleIndex: sampleIndex,sample: updated) }
                if touch.estimatedPropertiesExpectingUpdates.isEmpty { estimates.removeValue(forKey: index) }
            }
        }
        flushPending(force: false)
        requestFrame()
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
    var lightOnDark = false
    @AppStorage("strokeStabilization") private var stabilization = 0.0
    @State private var preview: UIImage?
    @State private var error: String?
    var body: some View {
        Group {
            if let preview { Image(uiImage: preview).resizable().scaledToFit() }
            else if let error { Text(error).font(.caption2).foregroundStyle(.red) }
            else { ProgressView() }
        }
        .onChange(of: brush, initial: true) { _, _ in render() }
        .onChange(of: lightOnDark) { _, _ in render() }
        .onChange(of: stabilization) { _, _ in render() }
        .accessibilityLabel("Anteprima di \(brush.name)")
    }
    private func render() {
        do { preview = try BrushPreviewRenderer.shared.image(brush, lightOnDark: lightOnDark); error = nil }
        catch { self.error = error.localizedDescription; preview = nil }
    }
}

@MainActor
final class BrushPreviewRenderer {
    static let shared = BrushPreviewRenderer()
    private let cache = NSCache<NSString, UIImage>()
    private var painter: MetalPainter?
    private init() { cache.countLimit = 96; cache.totalCostLimit = 12 * 1024 * 1024 }

    func image(_ brush: BrushPreset, lightOnDark: Bool) throws -> UIImage {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let key = (SHA256.hash(data: try encoder.encode(brush)).map { String(format: "%02x", $0) }.joined() + (lightOnDark ? ":dark" : ":light") + ":\(UserDefaults.standard.double(forKey: "strokeStabilization"))") as NSString
        if let image = cache.object(forKey: key) { return image }
        if painter == nil { painter = try MetalPainter() }
        guard let painter else { throw RenderError.unavailable }
        var content = DocumentContents(width: 320, height: 90)
        if lightOnDark { content.background = SIMD4(0, 0, 0, 0) }
        let length = Float(brush.value("previewLength", 1))
        var samples = PencilSample.demo(width: 320 * length, height: 90, count: 60)
        let pressure = Float(brush.value("previewPressure", 1))
        for i in samples.indices { samples[i].pressure = min(1, samples[i].pressure * pressure) }
        var previewBrush = brush
        let wetPreview = brush.value("previewWetMix", 1)
        for key in ["wetDilution", "wetPull", "wetAttack", "wetGrade"] {
            let definition = BrushParameter.all.first { $0.id == key }
            previewBrush.parameters[key] = brush.value(key, definition?.defaultValue ?? 0) * wetPreview
        }
        previewBrush.parameters["wetCharge"] = 1 - (1 - brush.value("wetCharge", 1)) * wetPreview
        content.layers[0].strokes = [PaintStroke(brush: previewBrush, tool: .paint,
            color: lightOnDark ? SIMD4(1, 1, 1, 1) : SIMD4(0.08, 0.08, 0.08, 1),
            size: Float(brush.value("previewSize", 0.5)) * 64, opacity: 1, samples: samples, seed: brush.seed, distanceDynamicsVersion: 1, curveVersion: 1, inputScale: 1, stabilizationAmount: Float(UserDefaults.standard.double(forKey: "strokeStabilization")), brushSettingsVersion: 1)]
        let image = try painter.image(content)
        cache.setObject(image, forKey: key, cost: 320 * 90 * 4 + key.length * 2)
        return image
    }
}
