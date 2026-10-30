import Foundation

struct BrushParameter: Identifiable {
    let id: String
    let title: String
    let category: String
    let range: ClosedRange<Double>
    let defaultValue: Double
    let effect: String

    static let categories = ["Stroke Path", "Stabilization", "Taper", "Shape", "Grain", "Rendering", "Wet Mix", "Color Dynamics", "Dynamics", "Apple Pencil", "Properties", "Materials", "Preview", "About this Brush"]
    private static func p(_ id: String, _ title: String, _ category: String, _ range: ClosedRange<Double> = 0...1, _ value: Double = 0, _ effect: String) -> BrushParameter {
        BrushParameter(id: id, title: title, category: category, range: range, defaultValue: value, effect: effect)
    }
    static let all: [BrushParameter] = [
        p("spacing", "Spacing", "Stroke Path", 0.01...2, 0.08, "Distanza fra le impronte in proporzione al diametro."),
        p("spacingJitter", "Spacing Jitter", "Stroke Path", "Variazione ripetibile della distanza fra impronte."),
        p("jitterLateral", "Jitter Lateral", "Stroke Path", "Spostamento perpendicolare al percorso."),
        p("jitterLinear", "Jitter Linear", "Stroke Path", "Spostamento lungo il percorso."),
        p("fallOff", "Fall Off", "Stroke Path", "Riduzione del deposito con la lunghezza del tratto."),
        p("streamline", "StreamLine Amount", "Stabilization", "Filtraggio delle posizioni in ingresso."),
        p("pressureSmoothing", "StreamLine Pressure", "Stabilization", "Filtraggio della pressione fra campioni."),
        p("stabilization", "Stabilization Amount", "Stabilization", "Media delle posizioni durante il tratto."),
        p("motionFiltering", "Motion Filtering Amount", "Stabilization", "Ulteriore attenuazione delle deviazioni."),
        p("motionExpression", "Motion Filtering Expression", "Stabilization", "Recupero di una parte del movimento originale."),
        p("taperStart", "Start", "Taper", "Lunghezza relativa della punta iniziale."),
        p("taperEnd", "End", "Taper", "Lunghezza relativa della punta finale; aggiornata a fine tratto."),
        p("taperSize", "Size", "Taper", 0...1, 1, "Riduzione del diametro alle estremità."),
        p("taperOpacity", "Opacity", "Taper", "Riduzione dell'alpha alle estremità."),
        p("scatter", "Scatter", "Shape", "Rotazione casuale deterministica delle impronte."),
        p("rotation", "Rotation", "Shape", -1...1, 0, "Orientamento relativo alla tangente."),
        p("roundness", "Roundness", "Shape", 0.05...1, 1, "Schiacciamento dell'impronta."),
        p("pressureRoundness", "Pressure Roundness", "Shape", "Schiacciamento dipendente dalla pressione."),
        p("tiltRoundness", "Tilt Roundness", "Shape", "Schiacciamento dipendente dall'inclinazione."),
        p("roundnessJitterY", "Roundness Vertical Jitter", "Shape", "Variazione dell'altezza dell'impronta."),
        p("roundnessJitterX", "Roundness Horizontal Jitter", "Shape", "Variazione della larghezza dell'impronta."),
        p("stampCount", "Count", "Shape", 1...16, 1, "Numero di impronte per posizione."),
        p("countJitter", "Count Jitter", "Shape", "Variazione del numero di impronte."),
        p("randomRotation", "Randomized", "Shape", "Rotazione iniziale pseudocasuale per tratto."),
        p("flipX", "Flip X", "Shape", "Riflessione orizzontale della sorgente."),
        p("flipY", "Flip Y", "Shape", "Riflessione verticale della sorgente."),
        p("grainScale", "Scale", "Grain", 0.1...8, 1, "Scala spaziale della texture."),
        p("grainDepth", "Depth", "Grain", "Influenza della grana sul deposito."),
        p("grainMovement", "Movement", "Grain", "Scorrimento della texture rispetto al percorso."),
        p("grainRotation", "Rotation", "Grain", -1...1, 0, "Rotazione delle coordinate di texture."),
        p("grainContrast", "Contrast", "Grain", 0...2, 1, "Contrasto della maschera di grana."),
        p("grainBrightness", "Brightness", "Grain", -1...1, 0, "Luminosità della maschera di grana."),
        p("grainZoom", "Zoom", "Grain", "Influenza del diametro sulla scala della texture."),
        p("flow", "Flow", "Rendering", 0...1, 1, "Quantità di pigmento per impronta."),
        p("opacity", "Opacity", "Rendering", 0...1, 1, "Limite dell'opacità depositata."),
        p("accumulation", "Accumulation · Atelier", "Rendering", 0...1, 1, "Zero: una sola copertura. Uno: accumulo progressivo fino al limite di opacità."),
        p("alphaThreshold", "Alpha Threshold", "Rendering", "Elimina il deposito sotto la soglia; zero la disattiva."),
        p("blendMode", "Blend Mode", "Rendering", 0...2, 0, "0 normale, 1 multiply, 2 screen."),
        p("dualEnabled", "Dual Brush · Atelier", "Rendering", "Miscela una seconda impronta della stessa sorgente."),
        p("dualScale", "Dual Scale · Atelier", "Rendering", 0.1...2, 1, "Scala della seconda impronta."),
        p("dualRotation", "Dual Rotation · Atelier", "Rendering", -1...1, 0, "Rotazione della seconda impronta."),
        p("dualOpacity", "Dual Opacity · Atelier", "Rendering", 0...1, 0.5, "Peso della seconda impronta."),
        p("wetDilution", "Dilution", "Wet Mix", "Diluisce il pigmento nuovo."),
        p("wetCharge", "Charge", "Wet Mix", 0...1, 1, "Carica iniziale che si esaurisce lungo il percorso."),
        p("wetAttack", "Attack", "Wet Mix", 0...1, 1, "Intensità del deposito umido."),
        p("wetPull", "Pull", "Wet Mix", "Prelievo del colore già presente prima del tratto."),
        p("wetGrade", "Grade", "Wet Mix", "Contrasto del colore prelevato; modello semplificato."),
        p("hueJitter", "Hue", "Color Dynamics", "Deviazione cromatica per impronta."),
        p("saturationJitter", "Saturation", "Color Dynamics", "Deviazione della saturazione per impronta."),
        p("brightnessJitter", "Lightness / Darkness", "Color Dynamics", "Deviazione del valore per impronta."),
        p("strokeHue", "Stroke Hue", "Color Dynamics", "Deviazione cromatica costante lungo il tratto."),
        p("stampHue", "Stamp Hue · Atelier", "Color Dynamics", "Ulteriore modulazione cromatica dell'impronta."),
        p("speedSize", "Speed Size", "Dynamics", -1...1, 0, "Diametro in funzione della velocità."),
        p("speedOpacity", "Speed Opacity", "Dynamics", -1...1, 0, "Alpha in funzione della velocità."),
        p("speedSpacing", "Speed Spacing", "Dynamics", 0...2, 0, "Distanza fra impronte in funzione della velocità."),
        p("sizeJitter", "Jitter Size", "Dynamics", "Variazione pseudocasuale del diametro."),
        p("opacityJitter", "Jitter Opacity", "Dynamics", "Variazione pseudocasuale dell'alpha."),
        p("pressureSize", "Pressure Size", "Apple Pencil", 0...1, 0.6, "Risposta del diametro alla pressione."),
        p("pressureOpacity", "Pressure Opacity", "Apple Pencil", "Risposta dell'alpha alla pressione."),
        p("pressureFlow", "Pressure Flow", "Apple Pencil", "Risposta del flusso alla pressione."),
        p("pressureBleed", "Pressure Bleed", "Apple Pencil", "Influenza della pressione sul prelievo del pigmento."),
        p("pressureCurve", "Pressure Graph · exponent", "Apple Pencil", 0.2...3, 1, "Curva di potenza; non è un grafico multipunto."),
        p("tiltSize", "Tilt Size", "Apple Pencil", "Allargamento del segno con Pencil inclinata."),
        p("tiltOpacity", "Tilt Opacity", "Apple Pencil", "Variazione dell'alpha con Pencil inclinata."),
        p("tiltGradation", "Tilt Gradation", "Apple Pencil", "Gradazione del deposito in inclinazione."),
        p("azimuth", "Azimuth", "Apple Pencil", "Peso dell'azimut nell'orientamento della forma."),
        p("barrelRoll", "Barrel Roll", "Apple Pencil", "Peso della rotazione rilevata da Apple Pencil Pro."),
        p("minSize", "Minimum Size", "Properties", "Diametro minimo relativo."),
        p("maxSize", "Maximum Size", "Properties", 0...1, 1, "Diametro massimo relativo."),
        p("minOpacity", "Minimum Opacity", "Properties", "Limite minimo dell’opacità modulata; zero pigmento resta trasparente."),
        p("maxOpacity", "Maximum Opacity", "Properties", 0...1, 1, "Alpha massimo del tratto."),
        p("smudge", "Smudge Pull", "Properties", 0...1, 0.5, "Forza dello spostamento del colore con sfumino."),
        p("previewSize", "Size", "Preview", 0.1...1, 0.5, "Diametro del tratto nella miniatura."),
        p("previewPressure", "Pressure Scale", "Preview", 0...1, 1, "Ampiezza della pressione sintetica nella miniatura."),
        p("previewWetMix", "Wet Mix", "Preview", 0...1, 1, "Influenza del wet mix nella miniatura."),
        p("previewLength", "Length · Atelier", "Preview", 0.2...1, 1, "Estensione del percorso di anteprima.")
    ]

    private static func p(_ id: String, _ title: String, _ category: String, _ effect: String) -> BrushParameter {
        p(id, title, category, 0...1, 0, effect)
    }
}
