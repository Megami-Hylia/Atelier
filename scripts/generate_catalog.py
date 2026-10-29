"""Generate Atelier's original offline brush configurations and mathematical textures.

No Procreate resources, names, or private parameters are read. Re-running is deterministic.
The PNGs are masks generated with standard-library math, not sampled artwork.
"""
from pathlib import Path
import hashlib
import json
import math
import random
import re
import struct
import zlib

ROOT = Path(__file__).resolve().parents[1]
RES = ROOT / "Atelier" / "Resources"
DEFAULTS = dict(
    spacing=.08, spacingJitter=0, jitterLateral=0, jitterLinear=0, fallOff=0,
    streamline=0, pressureSmoothing=0, stabilization=0, motionFiltering=0, motionExpression=0,
    taperStart=0, taperEnd=0, taperSize=1, taperOpacity=0, scatter=0, rotation=0,
    roundness=1, pressureRoundness=0, tiltRoundness=0, roundnessJitterX=0, roundnessJitterY=0,
    stampCount=1, countJitter=0, randomRotation=0, flipX=0, flipY=0,
    grainScale=1, grainDepth=0, grainMovement=0, grainRotation=0, grainContrast=1,
    grainBrightness=0, grainZoom=0, flow=1, opacity=1, accumulation=1, alphaThreshold=0,
    blendMode=0, dualEnabled=0, dualScale=1, dualRotation=0, dualOpacity=.5,
    wetDilution=0, wetCharge=1, wetAttack=1, wetPull=0, wetGrade=0,
    hueJitter=0, saturationJitter=0, brightnessJitter=0, strokeHue=0, stampHue=0,
    speedSize=0, speedOpacity=0, speedSpacing=0, sizeJitter=0, opacityJitter=0,
    pressureSize=.6, pressureOpacity=0, pressureFlow=0, pressureBleed=0, pressureCurve=1,
    tiltSize=0, tiltOpacity=0, tiltGradation=0, azimuth=0, barrelRoll=0,
    minSize=0, maxSize=1, minOpacity=0, maxOpacity=1, smudge=.5,
    previewSize=.5, previewPressure=1, previewWetMix=1, previewLength=1,
)

# Each material has a distinct deposition model. Variants change shape, grain and at
# least three independent render inputs; they are not merely names or size offsets.
MATERIALS = [
    ("Pencils", "round", "paper", dict(flow=.28,grainDepth=.68,pressureOpacity=.75,tiltSize=.7),
     ["Graphite Core", "Tilt Shading", "Draft Point", "Soft Graphite", "Grain Sketch", "Crosshatch", "Broad Lead", "Contour Lead", "Dust Graphite", "Colored Core"]),
    ("Pens", "round", "none", dict(flow=.95,spacing=.06,streamline=.25,taperStart=.12,taperEnd=.2),
     ["Fine Nib", "Flexible Nib", "Technical Line", "Fountain Edge", "Drawing Pen", "Brush Pen", "Broad Pen", "Contour Pen", "Broken Ink", "Tinted Ink"]),
    ("Inks", "bristle", "paper", dict(flow=.78,grainDepth=.3,pressureFlow=.4,taperEnd=.2),
     ["Dense Ink", "Sumi Tilt", "Copper Point", "Diluted Ink", "Fibre Ink", "Rake Ink", "Ink Block", "Liner Wash", "Splatter Ink", "Chromatic Ink"]),
    ("Markers", "chisel", "paper", dict(flow=.32,grainDepth=.15,roundness=.48,azimuth=.65,accumulation=.6),
     ["Flat Marker", "Side Marker", "Detail Marker", "Soft Marker", "Dry Marker", "Parallel Marker", "Poster Marker", "Outline Marker", "Fleck Marker", "Blended Marker"]),
    ("Pastels", "fleck", "paper", dict(flow=.55,grainDepth=.72,spacing=.12,scatter=.3,pressureOpacity=.6),
     ["Soft Stick", "Side Pastel", "Pastel Point", "Velvet Pastel", "Tooth Pastel", "Rake Pastel", "Broad Pastel", "Chalk Contour", "Pastel Dust", "Pastel Blend"]),
    ("Oils", "bristle", "canvas", dict(flow=.82,grainDepth=.6,wetPull=.55,wetDilution=.05,wetAttack=.9,wetGrade=.4),
     ["Loaded Bristle", "Side Bristle", "Liner Oil", "Glaze Oil", "Scumble", "Comb Oil", "Flat Oil", "Contour Oil", "Dry Speck", "Oil Mixer"]),
    ("Paints", "bristle", "canvas", dict(flow=.72,grainDepth=.4,wetPull=.2,pressureFlow=.4),
     ["Studio Round", "Flat Sweep", "Detail Paint", "Soft Paint", "Dry Paint", "Rake Paint", "Wide Paint", "Edge Paint", "Stipple Paint", "Prism Paint"]),
    ("Gouache", "flat", "paper", dict(flow=.8,grainDepth=.42,wetDilution=.12,wetPull=.22,roundness=.7),
     ["Opaque Round", "Gouache Edge", "Gouache Point", "Thin Gouache", "Dry Gouache", "Gouache Comb", "Broad Gouache", "Gouache Contour", "Gouache Flecks", "Gouache Mix"]),
    ("Watercolors", "soft", "wash", dict(flow=.2,grainDepth=.55,wetDilution=.65,wetPull=.65,wetCharge=.65,wetAttack=.45,pressureFlow=.55),
     ["Water Wash", "Wet Edge", "Detail Water", "Pale Wash", "Granulated Wash", "Water Rake", "Broad Wash", "Water Contour", "Water Mist", "Pigment Mix"]),
    ("Charcoals", "fleck", "charcoal", dict(flow=.6,grainDepth=.82,scatter=.35,pressureOpacity=.65,tiltSize=.65),
     ["Vine Core", "Charcoal Side", "Charcoal Point", "Soft Coal", "Rough Coal", "Coal Rake", "Coal Block", "Coal Contour", "Coal Dust", "Tinted Coal"]),
    ("Basics", "round", "none", dict(flow=1,pressureSize=.45),
     ["Hard Round", "Soft Air", "Fine Round", "Soft Round", "Textured Round", "Double Round", "Flat Basic", "Smooth Liner", "Basic Scatter", "Color Round"]),
    ("Lettering", "chisel", "paper", dict(flow=.9,roundness=.3,azimuth=.8,streamline=.4,taperStart=.2,taperEnd=.3),
     ["Italic Nib", "Lettering Side", "Hairline", "Soft Script", "Dry Script", "Ribbon Pair", "Broad Letter", "Monoline", "Fleck Script", "Prism Script"]),
    ("Comics", "round", "none", dict(flow=1,taperStart=.1,taperEnd=.35,pressureSize=.9,streamline=.25),
     ["Panel Ink", "Manga Edge", "Detail Liner", "Tone Wash", "Rough Inker", "Speed Pair", "Black Block", "Even Contour", "Stipple Tone", "Color Panel"]),
    ("Design", "flat", "none", dict(flow=.9,roundness=.65,pressureSize=.2,streamline=.2),
     ["Plan Edge", "Side Fill", "Draft Line", "Soft Layout", "Paper Layout", "Parallel Guide", "Wide Layout", "Contour Guide", "Dot Layout", "Spectrum Guide"]),
    ("Grunge", "fleck", "noise", dict(flow=.6,grainDepth=.8,spacing=.25,scatter=.8,jitterLateral=.2,opacityJitter=.4),
     ["Broken Surface", "Scraped Edge", "Scratch Point", "Faded Surface", "Coarse Surface", "Scrape Rake", "Wide Scrape", "Grunge Contour", "Debris", "Rust Color"]),
    ("Street Art", "soft", "noise", dict(flow=.28,grainDepth=.5,spacing=.09,opacityJitter=.25),
     ["Spray Cap", "Spray Edge", "Needle Cap", "Mist Cap", "Dry Spray", "Twin Cap", "Wide Cap", "Spray Contour", "Paint Spit", "Neon Spray"]),
    ("Digital", "round", "none", dict(flow=1,spacing=.06,pressureSize=.35),
     ["Crisp Round", "Digital Edge", "Crisp Point", "Air Gradient", "Binary Grain", "Twin Light", "Crisp Block", "Vector Liner", "Crisp Scatter", "Hue Cycle"]),
    ("Creative", "bristle", "wash", dict(flow=.6,grainDepth=.5,wetPull=.2,scatter=.25),
     ["Organic Trace", "Ribbon Trace", "Etched Trace", "Dream Wash", "Woven Trace", "Twin Trace", "Broad Ribbon", "Echo Line", "Petal Scatter", "Prism Trail"]),
]

VARIANTS = [
    (None, None, dict(pressureCurve=.9), "deposito di base del materiale; risposta progressiva alla pressione"),
    ("chisel", None, dict(roundness=.25,tiltSize=.85,tiltRoundness=.5,azimuth=.8,barrelRoll=.7), "bordo schiacciato e ombreggiatura sensibile a inclinazione e azimut"),
    ("round", None, dict(maxSize=.25,flow=.95,spacing=.035,pressureSize=.75,taperEnd=.25), "punta fine continua con uscita rastremata"),
    ("soft", None, dict(flow=.16,opacity=.55,pressureOpacity=.8,grainDepth=.12,wetDilution=.3), "deposito morbido e trasparente per velature"),
    ("fleck", "paper", dict(grainDepth=.9,grainScale=1.7,grainContrast=1.45,flow=.45,sizeJitter=.15), "grana marcata con interruzioni del deposito"),
    ("bristle", None, dict(roundness=.65,spacing=.17,dualEnabled=1,dualScale=.65,dualRotation=.15,dualOpacity=.6), "impronta a setole combinata con una seconda impronta"),
    ("flat", None, dict(roundness=.8,maxSize=1,pressureSize=.2,flow=.8,spacing=.055), "campitura larga con pressione poco influente"),
    ("round", None, dict(streamline=.65,stabilization=.35,pressureSize=.05,spacing=.04,taperEnd=.08), "linea di contorno stabilizzata a spessore quasi costante"),
    ("fleck", "noise", dict(spacing=.7,spacingJitter=.45,jitterLateral=.6,jitterLinear=.3,scatter=1,stampCount=3,countJitter=.7,flow=.65), "spruzzi separati con impronte multiple e jitter deterministico"),
    (None, None, dict(hueJitter=.18,saturationJitter=.2,brightnessJitter=.1,strokeHue=.08,wetPull=.45,wetDilution=.25), "variazioni cromatiche e prelievo del pigmento preesistente"),
]

# Explicit designs for profiles whose shared role templates previously produced
# near-duplicates. IDs remain stable; pressure curves are not used as cosmetic
# differentiators when a max-size clamp makes the curve inert.
SPECIAL_PROFILES = {
    ("basics", 1): dict(shape="soft", grain="none",
        parameters=dict(flow=.07, opacity=1, spacing=.04, roundness=1,
                        tiltSize=0, tiltRoundness=0, azimuth=0, barrelRoll=0,
                        pressureOpacity=.8, grainDepth=0),
        reason="aerografo morbido rotondo; elimina l’impronta a scalpello incoerente con il nome"),
    ("basics", 6): dict(
        shape="flat", grain="none",
        parameters=dict(roundness=.65, pressureSize=.55, maxSize=.9, minSize=.02,
                        flow=.55, spacing=.09, accumulation=.55, wetAttack=0),
        reason="piatto di uso generale a spessore sensibile alla pressione, rapporto di forma medio e deposito progressivo"),
    ("design", 6): dict(
        shape="flat", grain="none",
        parameters=dict(roundness=.28, pressureSize=.15, tiltSize=.65, tiltRoundness=.3,
                        azimuth=1, barrelRoll=.75, flow=.22, spacing=.18,
                        accumulation=.65, wetAttack=0, maxSize=1),
        reason="piatto stretto da layout, orientamento da azimut e roll, allargamento inclinando la Pencil e impronte più distanziate"),
    ("digital", 6): dict(
        shape="flat", grain="none",
        parameters=dict(roundness=1, pressureSize=0, minSize=1, maxSize=1,
                        flow=1, opacity=1, spacing=.035, alphaThreshold=.45,
                        taperStart=0, taperEnd=0, taperSize=0, wetAttack=0,
                        pressureCurve=1),
        reason="campitura rettangolare dura a dimensione costante; soglia alpha binaria, senza aggancio a una griglia di pixel"),
    ("pens", 2): dict(
        shape="round", grain="none",
        parameters=dict(pressureSize=0, minSize=.13, maxSize=.13,
                        spacing=.035, flow=.95, wetAttack=0,
                        taperStart=0, taperEnd=0, taperSize=0, taperOpacity=0,
                        streamline=.2, pressureCurve=1),
        reason="linea tecnica fine a spessore costante, continua, senza rastremazione né variazione dimensionale da pressione"),
    ("comics", 2): dict(
        shape="round", grain="none",
        parameters=dict(pressureSize=1, minSize=.015, maxSize=.65, pressureCurve=1.15,
                        spacing=.045, flow=.9, wetAttack=0, pressureOpacity=.3,
                        pressureFlow=.4, streamline=.35, taperStart=.12,
                        taperEnd=.4, taperSize=1, taperOpacity=.25),
        reason="liner per fumetto con escursione reale del diametro da pressione e punte lunghe; il limite massimo non blocca l'intero corpo del tratto"),
    ("digital", 0): dict(
        parameters=dict(alphaThreshold=.5),
        reason="impronta rotonda con bordo binario e dimensione da pressione; nessuna quantizzazione delle coordinate su griglia"),
    ("digital", 2): dict(
        shape="flat", grain="none",
        parameters=dict(roundness=1, minSize=.2, maxSize=.2, pressureSize=0,
                        pressureCurve=1, spacing=.45, flow=1, opacity=1,
                        alphaThreshold=.55, wetAttack=0, taperStart=0,
                        taperEnd=0, taperSize=0),
        reason="piccole impronte rettangolari dure a dimensione costante e passo ampio; bordo binario, senza motore a griglia pixel"),
    ("digital", 4): dict(
        parameters=dict(alphaThreshold=.5, flow=1, opacity=1, wetAttack=0),
        reason="grana e forma frammentata convertite in deposito ad alpha binario; non è un algoritmo di dithering cromatico"),
    ("digital", 8): dict(
        shape="flat", grain="none",
        parameters=dict(roundness=.9, pressureSize=0, minSize=.4, maxSize=.4,
                        flow=1, opacity=1, alphaThreshold=.6, grainDepth=0,
                        wetAttack=0, pressureCurve=1),
        reason="spruzzi geometrici di impronte rettangolari dure, con conteggio e posizioni casuali deterministiche; nessuna griglia pixel"),
}


def png(path, size, values):
    def chunk(kind, payload):
        return struct.pack(">I", len(payload)) + kind + payload + struct.pack(">I", zlib.crc32(kind + payload) & 0xffffffff)
    raw = b"".join(b"\0" + bytes(values[y*size:(y+1)*size]) for y in range(size))
    path.write_bytes(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB",size,size,8,0,0,0,0)) + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b""))


def assets():
    size=128
    for shape in ["round","soft","flat","bristle","fleck","chisel"]:
        pixels=[]; rng=random.Random(2401)
        for y in range(size):
            for x in range(size):
                u=(x+.5)/size*2-1; v=(y+.5)/size*2-1; r=math.hypot(u,v)
                edge=max(0,min(1,(1-r)*32))
                if shape=="round": value=edge
                elif shape=="soft": value=max(0,1-r*r)**2
                elif shape=="flat": value=max(0,min(1,(1-abs(u))*24))*max(0,min(1,(.65-abs(v))*32))
                elif shape=="chisel": value=max(0,min(1,(.92-abs(u+.25*v))*28))*max(0,min(1,(.38-abs(v))*32))
                elif shape=="bristle": value=edge*(.15+.85*max(0,math.sin((u+.06*math.sin(v*8))*47))**.4)
                else: value=edge*(1 if rng.random()>.46 else .04)*(.4+.6*rng.random())
                pixels.append(round(max(0,min(1,value))*255))
        png(RES/f"BrushShape-{shape}.png",size,pixels)
    for grain in ["none","paper","canvas","charcoal","wash","noise"]:
        pixels=[]; rng=random.Random(8703)
        for y in range(size):
            for x in range(size):
                u=x/size*math.tau; v=y/size*math.tau; n=rng.random()
                if grain=="none": value=1
                elif grain=="paper": value=.55+.3*n+.1*math.sin(u*17)*math.sin(v*13)
                elif grain=="canvas": value=.35+.25*(1+math.sin(u*16))*.5+.25*(1+math.sin(v*16))*.5+.15*n
                elif grain=="charcoal": value=n**1.5
                elif grain=="wash": value=.58+.2*math.sin(u*2+math.sin(v*3))+.15*math.sin(u*5-v*2)+.07*n
                else: value=n
                pixels.append(round(max(0,min(1,value))*255))
        png(RES/f"BrushGrain-{grain}.png",size,pixels)


def app_icon():
    size=1024
    folder=ROOT/"Atelier"/"Assets.xcassets"/"AppIcon.appiconset"
    folder.mkdir(parents=True,exist_ok=True)
    def distance(x,y,ax,ay,bx,by):
        t=max(0,min(1,((x-ax)*(bx-ax)+(y-ay)*(by-ay))/((bx-ax)**2+(by-ay)**2)))
        return math.hypot(x-ax-t*(bx-ax),y-ay-t*(by-ay))
    pixels=bytearray()
    for y in range(size):
        pixels.append(0)
        for x in range(size):
            # Original geometric letterform. Rounded app mask is applied by iPadOS.
            d=min(distance(x,y,295,744,508,270),distance(x,y,508,270,735,744))
            a=max(0,min(1,39.5-d))
            gold=max(0,min(1,27.5-distance(x,y,379,567,651,567)))
            base=(24,28,35); ivory=(239,233,219); accent=(209,157,82)
            rgb=[round(base[i]*(1-a)+ivory[i]*a) for i in range(3)]
            rgb=[round(rgb[i]*(1-gold)+accent[i]*gold) for i in range(3)]
            pixels.extend((*rgb,255))
    def chunk(kind,payload):
        return struct.pack(">I",len(payload))+kind+payload+struct.pack(">I",zlib.crc32(kind+payload)&0xffffffff)
    data=b"\x89PNG\r\n\x1a\n"+chunk(b"IHDR",struct.pack(">IIBBBBB",size,size,8,6,0,0,0))+chunk(b"IDAT",zlib.compress(bytes(pixels),9))+chunk(b"IEND",b"")
    (folder/"AtelierIcon.png").write_bytes(data)
    (folder/"Contents.json").write_text(json.dumps({"images":[{"filename":"AtelierIcon.png","idiom":"universal","platform":"ios","size":"1024x1024"}],"info":{"author":"Atelier","version":1}},indent=2)+"\n",encoding="utf-8")
    (folder.parent/"Contents.json").write_text('{"info":{"author":"Atelier","version":1}}\n',encoding="utf-8")


def make_brush(id_,name,set_id,shape,grain,parameters,description,index):
    params=DEFAULTS|parameters
    return dict(id=id_,name=name,setID=set_id,shape=shape,grain=grain,
                seed=int.from_bytes(hashlib.sha256(id_.encode()).digest()[:8],"little"),
                parameters={k:round(v,5) for k,v in params.items()},author="Atelier",notes=description,
                rationale=description)


def generate():
    RES.mkdir(parents=True, exist_ok=True)
    libraries=[dict(id="atelier",name="Atelier Library"),dict(id="classic",name="Classic · basi funzionali")]
    sets=[]; brushes=[]
    for material_index,(name,shape,grain,base,names) in enumerate(MATERIALS):
        set_id=name.lower().replace(" ","-")
        sets.append(dict(id=set_id,libraryID="atelier",name=name))
        for index,(new_shape,new_grain,changes,reason) in enumerate(VARIANTS):
            parameters=base|changes
            # Continuous differences reflect material response, not cosmetic IDs.
            parameters["pressureCurve"]=round(.75+material_index*.06+index*.025,3)
            parameters["grainScale"]=round(parameters.get("grainScale",1)+material_index*.055,3)
            special=SPECIAL_PROFILES.get((set_id,index),{})
            parameters.update(special.get("parameters",{}))
            configured_shape=special.get("shape",new_shape or shape)
            configured_grain=special.get("grain",new_grain or grain)
            brush=make_brush(f"atelier-{set_id}-{index+1:02}",names[index],set_id,configured_shape,configured_grain,parameters,f"{name}: {special.get('reason',reason)}.",index)
            brushes.append(brush)
    sets.append(dict(id="classic-foundations",libraryID="classic",name="Foundations"))
    basics=[
        ("Graphite Foundation","round","paper",dict(flow=.25,grainDepth=.7,pressureOpacity=.8)),
        ("Tilt Shader Foundation","fleck","paper",dict(flow=.25,grainDepth=.7,tiltSize=1,tiltRoundness=.7,azimuth=1)),
        ("Ink Foundation","round","none",dict(flow=1,spacing=.045,pressureSize=.8,taperEnd=.3)),
        ("Calligraphy Foundation","chisel","none",dict(flow=1,roundness=.2,azimuth=1,barrelRoll=1,streamline=.4)),
        ("Flat Marker Foundation","flat","paper",dict(flow=.32,roundness=.4,grainDepth=.15,azimuth=.8)),
        ("Soft Air Foundation","soft","none",dict(flow=.07,spacing=.04,pressureOpacity=.8,maxSize=1)),
        ("Hard Round Foundation","round","none",dict(flow=1,spacing=.05,pressureSize=.2)),
        ("Pastel Foundation","fleck","paper",dict(flow=.6,grainDepth=.85,scatter=.2,pressureOpacity=.7)),
        ("Charcoal Foundation","fleck","charcoal",dict(flow=.65,grainDepth=.9,tiltSize=.8,scatter=.3)),
        ("Dry Bristle Foundation","bristle","canvas",dict(flow=.45,grainDepth=.85,roundness=.7,pressureFlow=.7)),
        ("Oil Foundation","bristle","canvas",dict(flow=.9,grainDepth=.5,wetPull=.7,wetCharge=.9,wetGrade=.5)),
        ("Watercolor Foundation","soft","wash",dict(flow=.16,grainDepth=.55,wetDilution=.7,wetCharge=.6,wetPull=.65,wetAttack=.45)),
    ]
    for index,(name,shape,grain,parameters) in enumerate(basics):
        brushes.append(make_brush(f"classic-foundation-{index+1:02}",name,"classic-foundations",shape,grain,parameters,"Base funzionale originale; nessuna corrispondenza parametrica proprietaria dimostrata.",index))
    catalog=dict(schemaVersion=1,libraries=libraries,sets=sets,brushes=brushes,recentIDs=[],selectedID=brushes[0]["id"])
    (RES/"BrushCatalog.json").write_text(json.dumps(catalog,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    assets()
    app_icon()
    validate(catalog)
    lines=["# Catalogo preset originali Atelier", "", "Generato deterministicamente da `scripts/generate_catalog.py`. 180 preset in 18 set e 12 basi funzionali separate; non costituiscono la libreria Classic completa. Configurazioni e 12 texture PNG incluse nel bundle e disponibili offline. Ogni riga corrisponde a una configurazione distinta; la differenza visiva richiede ancora la tavola prodotta dal renderer Metal.", "", "| Set | Preset | Forma / grana | Comportamento configurato |", "|---|---|---|---|"]
    names={s["id"]:s["name"] for s in sets}
    for b in brushes: lines.append(f'| {names[b["setID"]]} | {b["name"]} | {b["shape"]} / {b["grain"]} | {b["notes"]} |')
    (ROOT/"PRESET_CATALOG.md").write_text("\n".join(lines)+"\n",encoding="utf-8")
    print(f"PASS: {len(brushes)} distinct presets, 18 x 10 + 12 foundations; 12 original PNG masks")


def validate(catalog):
    brushes=catalog["brushes"]
    assert len(brushes)==192
    assert len({b["id"] for b in brushes})==192
    assert len({json.dumps({"shape":b["shape"],"grain":b["grain"],"parameters":b["parameters"]},sort_keys=True) for b in brushes})==192
    assert all(sum(b["setID"]==s["id"] for b in brushes)==10 for s in catalog["sets"] if s["libraryID"]=="atelier")
    assert all(set(b["parameters"])==set(DEFAULTS) for b in brushes)
    assert all(math.isfinite(v) for b in brushes for v in b["parameters"].values())
    assert all(0<=b["seed"]<2**64 for b in brushes)
    assert json.loads(json.dumps(catalog))==catalog
    by_id={b["id"]:b for b in brushes}
    # Check meaningful design differences rather than only JSON/hash uniqueness.
    flats=[by_id[f"atelier-{category}-07"] for category in ["basics","design","digital"]]
    assert len({b["parameters"]["roundness"] for b in flats})==3
    assert flats[1]["parameters"]["azimuth"]==1 and flats[1]["parameters"]["tiltSize"]>0
    assert flats[2]["parameters"]["alphaThreshold"]>0 and flats[2]["parameters"]["minSize"]==flats[2]["parameters"]["maxSize"]
    technical=by_id["atelier-pens-03"]["parameters"]
    comic=by_id["atelier-comics-03"]["parameters"]
    point=by_id["atelier-digital-03"]["parameters"]
    assert technical["minSize"]==technical["maxSize"] and technical["taperEnd"]==0
    assert comic["pressureSize"]==1 and comic["maxSize"]>.5 and comic["taperEnd"]>.3
    assert by_id["atelier-digital-03"]["shape"]=="flat" and point["alphaThreshold"]>0
    assert all("pixel" not in b["name"].lower() for b in brushes if b["setID"]=="digital")
    assert all(by_id[f"atelier-digital-{index:02}"]["parameters"]["alphaThreshold"]>0 for index in [1,3,5,7,9])
    assert by_id["atelier-watercolors-09"]["name"]=="Water Mist"


if __name__=="__main__":
    generate()
