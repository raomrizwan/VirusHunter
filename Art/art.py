"""Virus Hunter 2.0 art: SVG sources rendered to PNG with headless Chromium.
Run: python3 art.py  -> writes PNGs into ../VirusHunter/Assets.xcassets/*.imageset and Art/out
"""
import asyncio, json, math, os, random
from playwright.async_api import async_playwright

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "out")
ASSETS = os.path.join(HERE, "..", "VirusHunter", "Assets.xcassets")
os.makedirs(OUT, exist_ok=True)


def wrap(body, w, h=None, defs=""):
    h = h or w
    return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {w} {h}" width="{w}" height="{h}"><defs>{defs}</defs>{body}</svg>'


# ---------------------------------------------------------------- Nano (hero)
def nano(expr="happy", size=512, thrust=True):
    s = size / 512
    eyes = {
        "happy": '<ellipse cx="200" cy="232" rx="30" ry="40" fill="url(#eye)"/><ellipse cx="312" cy="232" rx="30" ry="40" fill="url(#eye)"/>'
                 '<circle cx="210" cy="215" r="11" fill="#fff"/><circle cx="322" cy="215" r="11" fill="#fff"/>',
        "fight": '<path d="M168 214 Q200 196 232 220 L230 262 Q200 270 172 256 Z" fill="url(#eye)"/><path d="M344 214 Q312 196 280 220 L282 262 Q312 270 340 256 Z" fill="url(#eye)"/>'
                 '<circle cx="212" cy="232" r="9" fill="#fff"/><circle cx="300" cy="232" r="9" fill="#fff"/>',
        "joy": '<path d="M170 240 Q200 196 230 240" stroke="#7CF6FF" stroke-width="16" fill="none" stroke-linecap="round"/>'
               '<path d="M282 240 Q312 196 342 240" stroke="#7CF6FF" stroke-width="16" fill="none" stroke-linecap="round"/>',
        "hurt": '<path d="M175 215 L225 250 M225 215 L175 250" stroke="#FF6B8B" stroke-width="16" stroke-linecap="round"/>'
                '<path d="M287 215 L337 250 M337 215 L287 250" stroke="#FF6B8B" stroke-width="16" stroke-linecap="round"/>',
    }[expr]
    mouth = {"happy": '<path d="M232 290 Q256 310 280 290" stroke="#7CF6FF" stroke-width="9" fill="none" stroke-linecap="round"/>',
             "fight": '<path d="M236 296 L276 296" stroke="#7CF6FF" stroke-width="9" stroke-linecap="round"/>',
             "joy": '<path d="M222 282 Q256 330 290 282 Z" fill="#7CF6FF"/>',
             "hurt": '<path d="M232 302 Q256 286 280 302" stroke="#FF6B8B" stroke-width="9" fill="none" stroke-linecap="round"/>'}[expr]
    flame = '''<g opacity=".95"><path d="M206 440 Q216 500 230 440 Z" fill="url(#flame)"/><path d="M282 440 Q296 500 306 440 Z" fill="url(#flame)"/></g>''' if thrust else ""
    defs = '''
    <radialGradient id="shell" cx="38%" cy="28%" r="80%"><stop offset="0" stop-color="#FFFFFF"/><stop offset=".55" stop-color="#E7EEF7"/><stop offset="1" stop-color="#9FB0C8"/></radialGradient>
    <linearGradient id="visor" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#1B2A4A"/><stop offset="1" stop-color="#0A1022"/></linearGradient>
    <radialGradient id="eye" cx="45%" cy="35%" r="70%"><stop offset="0" stop-color="#C9FFFF"/><stop offset=".5" stop-color="#3FE6FF"/><stop offset="1" stop-color="#0AA8D8"/></radialGradient>
    <linearGradient id="flame" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#FFFFFF"/><stop offset=".35" stop-color="#7CF6FF"/><stop offset="1" stop-color="#2D8CFF" stop-opacity="0"/></linearGradient>
    <linearGradient id="arm" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#C8D4E4"/><stop offset="1" stop-color="#FFFFFF"/></linearGradient>
    <filter id="glow" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="10"/></filter>
    '''
    body = f'''<g transform="scale({s})">
    <ellipse cx="256" cy="470" rx="110" ry="14" fill="#000" opacity=".25"/>
    {flame}
    <!-- antenna -->
    <path d="M300 92 Q318 52 336 44" stroke="#C8D4E4" stroke-width="10" fill="none" stroke-linecap="round"/>
    <circle cx="340" cy="42" r="16" fill="#3FE6FF"/><circle cx="340" cy="42" r="26" fill="#3FE6FF" opacity=".35" filter="url(#glow)"/>
    <!-- arms -->
    <ellipse cx="112" cy="330" rx="34" ry="54" fill="url(#arm)" transform="rotate(25 112 330)" stroke="#8FA2BD" stroke-width="4"/>
    <ellipse cx="400" cy="330" rx="34" ry="54" fill="url(#arm)" transform="rotate(-25 400 330)" stroke="#8FA2BD" stroke-width="4"/>
    <!-- body -->
    <path d="M170 330 Q170 440 256 446 Q342 440 342 330 Z" fill="url(#shell)" stroke="#8FA2BD" stroke-width="5"/>
    <path d="M196 372 L316 372" stroke="#2DD4FF" stroke-width="8" stroke-linecap="round" opacity=".8"/>
    <circle cx="256" cy="405" r="24" fill="#FF4D6D"/><path d="M256 391 V419 M242 405 H270" stroke="#fff" stroke-width="8" stroke-linecap="round"/>
    <!-- head -->
    <circle cx="256" cy="236" r="150" fill="url(#shell)" stroke="#8FA2BD" stroke-width="6"/>
    <circle cx="112" cy="236" r="24" fill="#2DD4FF" stroke="#8FA2BD" stroke-width="5"/>
    <circle cx="400" cy="236" r="24" fill="#2DD4FF" stroke="#8FA2BD" stroke-width="5"/>
    <rect x="146" y="166" width="220" height="166" rx="78" fill="url(#visor)"/>
    <rect x="146" y="166" width="220" height="166" rx="78" fill="none" stroke="#2DD4FF" stroke-opacity=".35" stroke-width="5"/>
    {eyes}{mouth}
    <path d="M176 186 Q226 160 300 172" stroke="#fff" stroke-opacity=".22" stroke-width="14" fill="none" stroke-linecap="round"/>
    <ellipse cx="196" cy="128" rx="54" ry="26" fill="#fff" opacity=".65" transform="rotate(-20 196 128)"/>
    </g>'''
    return wrap(body, size, size, defs)


def minibot(size=128):
    defs = '''<radialGradient id="m" cx="38%" cy="30%" r="80%"><stop offset="0" stop-color="#fff"/><stop offset="1" stop-color="#9FD9F0"/></radialGradient>
    <filter id="g" x="-60%" y="-60%" width="220%" height="220%"><feGaussianBlur stdDeviation="8"/></filter>'''
    body = '''<circle cx="64" cy="64" r="44" fill="#3FE6FF" opacity=".55" filter="url(#g)"/>
    <circle cx="64" cy="64" r="34" fill="url(#m)" stroke="#5FB6D8" stroke-width="3"/>
    <rect x="40" y="50" width="48" height="26" rx="13" fill="#0E1B33"/>
    <circle cx="54" cy="63" r="6" fill="#5FF2FF"/><circle cx="74" cy="63" r="6" fill="#5FF2FF"/>'''
    return wrap(body, size, size, defs)


# ---------------------------------------------------------------- Nano skins
# Each skin recolours the classic Nano / minibot SVG by swapping its palette.
SKINS = {
    "neon": {"#FFFFFF": "#FFE6F7", "#E7EEF7": "#FF9BDD", "#9FB0C8": "#B8378F", "#8FA2BD": "#8E2C73", "#C8D4E4": "#FFB8E8",
             "#3FE6FF": "#FF5FD8", "#2DD4FF": "#FF5FD8", "#C9FFFF": "#FFD6F5", "#0AA8D8": "#C2189A", "#7CF6FF": "#FF9BE6", "#2D8CFF": "#B01FFF",
             "#FF4D6D": "#3FE6FF", "#9FD9F0": "#FF9BDD", "#5FB6D8": "#B8378F", "#5FF2FF": "#FF7BE0"},
    "toxic": {"#FFFFFF": "#F4FFE4", "#E7EEF7": "#A8F06E", "#9FB0C8": "#4E9A2E", "#8FA2BD": "#3E7A24", "#C8D4E4": "#CFF7A8",
              "#3FE6FF": "#C6FF3D", "#2DD4FF": "#9BEA2A", "#C9FFFF": "#F2FFB8", "#0AA8D8": "#6DB816", "#7CF6FF": "#D9FF6B", "#2D8CFF": "#5CD62A",
              "#FF4D6D": "#FFB020", "#9FD9F0": "#A8F06E", "#5FB6D8": "#4E9A2E", "#5FF2FF": "#D9FF6B"},
    "stealth": {"#FFFFFF": "#6B7386", "#E7EEF7": "#353C4D", "#9FB0C8": "#161A24", "#8FA2BD": "#0B0D13", "#C8D4E4": "#4A5163",
                "#1B2A4A": "#140A0D", "#0A1022": "#050203",
                "#3FE6FF": "#FF3B4E", "#2DD4FF": "#FF3B4E", "#C9FFFF": "#FFC2C8", "#0AA8D8": "#B3121F", "#7CF6FF": "#FF7A85", "#2D8CFF": "#FF2A3A",
                "#FF4D6D": "#FF3B4E", "#9FD9F0": "#353C4D", "#5FB6D8": "#0B0D13", "#5FF2FF": "#FF5A68", "#0E1B33": "#050203"},
    "gold": {"#FFFFFF": "#FFF8D6", "#E7EEF7": "#FFD34D", "#9FB0C8": "#B07A06", "#8FA2BD": "#8A5E05", "#C8D4E4": "#FFE48A",
             "#3FE6FF": "#FFE45C", "#2DD4FF": "#FFC21F", "#2D8CFF": "#FF9A1F",
             "#9FD9F0": "#FFD34D", "#5FB6D8": "#B07A06"},
    "frost": {"#FFFFFF": "#F2FBFF", "#E7EEF7": "#BFE9FF", "#9FB0C8": "#5AA6D6", "#8FA2BD": "#3A7FB0", "#C8D4E4": "#DDF4FF",
              "#3FE6FF": "#E8FDFF", "#2DD4FF": "#9EEBFF", "#C9FFFF": "#FFFFFF", "#0AA8D8": "#4FB8E8", "#7CF6FF": "#D6FAFF", "#2D8CFF": "#7FD4FF",
              "#FF4D6D": "#5AA6D6", "#9FD9F0": "#BFE9FF", "#5FB6D8": "#3A7FB0", "#5FF2FF": "#D6FAFF"},
    "plasma": {"#FFFFFF": "#F3E6FF", "#E7EEF7": "#B57BFF", "#9FB0C8": "#5B21B6", "#8FA2BD": "#3B0F80", "#C8D4E4": "#D2B0FF",
               "#3FE6FF": "#FF8A3D", "#2DD4FF": "#FF7A1F", "#C9FFFF": "#FFE2C2", "#0AA8D8": "#D9480F", "#7CF6FF": "#FFB27A", "#2D8CFF": "#FF5F1F",
               "#FF4D6D": "#FFB020", "#9FD9F0": "#B57BFF", "#5FB6D8": "#3B0F80", "#5FF2FF": "#FFB27A"},
    "royal": {"#FFFFFF": "#FFF4F4", "#E7EEF7": "#E0213F", "#9FB0C8": "#7A0A1E", "#8FA2BD": "#4A0512", "#C8D4E4": "#FF8A9C",
              "#3FE6FF": "#FFD34D", "#2DD4FF": "#FFC21F", "#C9FFFF": "#FFF6C2", "#0AA8D8": "#C98A00", "#7CF6FF": "#FFE48A", "#2D8CFF": "#FF9A1F",
              "#FF4D6D": "#FFD34D", "#9FD9F0": "#E0213F", "#5FB6D8": "#7A0A1E", "#5FF2FF": "#FFE48A"},
}


def reskin(svg, skin):
    for old, new in SKINS[skin].items():
        svg = svg.replace(old, new)
    return svg


def skin_items():
    items = []
    for k in SKINS:
        for e in ["happy", "fight", "joy", "hurt"]:
            items.append((f"nano-{k}-{e}", reskin(nano(e, 512), k)))
        items.append((f"minibot-{k}", reskin(minibot(), k)))
    return items


# ---------------------------------------------------------------- viruses
def virus(kind, size=256, seed=1):
    rnd = random.Random(seed)
    pal = {
        "spiky": ("#B7FF5C", "#4CC21E", "#1F6B10"),
        "blob": ("#E3A0FF", "#A24BEB", "#4E1883"),
        "dart": ("#FFD08A", "#FF8A1F", "#9A3E00"),
        "spitter": ("#FFF27A", "#E8C619", "#7A6400"),
        "mini": ("#FF9AAE", "#FF3D6A", "#8A0F2E"),
        "elite": ("#8AF2FF", "#14B8E6", "#0A4F7A"),
        "brainv": ("#FFC9E6", "#FF6FB5", "#8A1D55"),
        "bone": ("#FFFFFF", "#E6DCC4", "#7A6E55"),
        "bomber": ("#FFB08A", "#FF5A1F", "#8A1A00"),
        "healer": ("#C8FFD8", "#3FE07A", "#0F6B33"),
        "sniper": ("#FF9AA0", "#E0202E", "#5E0710"),
        "spore": ("#F0E6FF", "#B9A2F5", "#5B4596"),
    }[kind]
    light, mid, dark = pal
    c = size / 2
    r = size * (0.30 if kind != "blob" else 0.34)
    defs = f'''<radialGradient id="b{kind}" cx="36%" cy="30%" r="80%"><stop offset="0" stop-color="{light}"/><stop offset=".55" stop-color="{mid}"/><stop offset="1" stop-color="{dark}"/></radialGradient>
    <filter id="gl{kind}" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="{size*0.04}"/></filter>'''
    parts = [f'<circle cx="{c}" cy="{c}" r="{r*1.15}" fill="{mid}" opacity=".45" filter="url(#gl{kind})"/>']
    n = {"spiky": 12, "blob": 0, "dart": 8, "spitter": 10, "mini": 8, "elite": 14, "brainv": 10, "bone": 10,
         "bomber": 6, "healer": 8, "sniper": 8, "spore": 16}[kind]
    for i in range(n):
        a = 2 * math.pi * i / n + rnd.uniform(-0.08, 0.08)
        L = r * (1.38 if kind != "dart" else 1.5)
        x1, y1 = c + math.cos(a) * r * 0.85, c + math.sin(a) * r * 0.85
        x2, y2 = c + math.cos(a) * L, c + math.sin(a) * L
        if kind == "dart":
            # triangular blades
            pa, pb = a - 0.18, a + 0.18
            parts.append(f'<path d="M{c+math.cos(pa)*r*0.9} {c+math.sin(pa)*r*0.9} L{x2} {y2} L{c+math.cos(pb)*r*0.9} {c+math.sin(pb)*r*0.9} Z" fill="{mid}" stroke="{dark}" stroke-width="{size*0.012}"/>')
        else:
            parts.append(f'<line x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}" stroke="{dark}" stroke-width="{size*0.035}" stroke-linecap="round"/>')
            parts.append(f'<circle cx="{x2}" cy="{y2}" r="{size*0.042}" fill="url(#b{kind})" stroke="{dark}" stroke-width="{size*0.012}"/>')
    if kind == "blob":
        pts = []
        for i in range(14):
            a = 2 * math.pi * i / 14
            rr = r * (1 + rnd.uniform(-0.07, 0.09))
            pts.append((c + math.cos(a) * rr, c + math.sin(a) * rr))
        d = f"M{pts[0][0]} {pts[0][1]} " + " ".join(f"Q{(pts[i][0]+pts[(i+1)%14][0])/2 + (pts[(i+1)%14][0]-c)*0.05} {(pts[i][1]+pts[(i+1)%14][1])/2 + (pts[(i+1)%14][1]-c)*0.05} {pts[(i+1)%14][0]} {pts[(i+1)%14][1]}" for i in range(14)) + " Z"
        parts.append(f'<path d="{d}" fill="url(#b{kind})" stroke="{dark}" stroke-width="{size*0.016}"/>')
    else:
        parts.append(f'<circle cx="{c}" cy="{c}" r="{r}" fill="url(#b{kind})" stroke="{dark}" stroke-width="{size*0.016}"/>')
    # spots
    for i in range(5):
        a = rnd.uniform(0, 2 * math.pi); d = rnd.uniform(0.35, 0.7) * r
        parts.append(f'<circle cx="{c+math.cos(a)*d}" cy="{c+math.sin(a)*d*0.9 + r*0.25}" r="{r*rnd.uniform(0.07,0.13)}" fill="{dark}" opacity=".28"/>')
    # face
    ey = c - r * 0.08
    ex = r * 0.36
    er = r * 0.2
    parts.append(f'<ellipse cx="{c-ex}" cy="{ey}" rx="{er}" ry="{er*1.15}" fill="#fff"/><ellipse cx="{c+ex}" cy="{ey}" rx="{er}" ry="{er*1.15}" fill="#fff"/>')
    parts.append(f'<circle cx="{c-ex+er*0.25}" cy="{ey+er*0.2}" r="{er*0.55}" fill="#1A1020"/><circle cx="{c+ex-er*0.25}" cy="{ey+er*0.2}" r="{er*0.55}" fill="#1A1020"/>')
    parts.append(f'<circle cx="{c-ex+er*0.05}" cy="{ey}" r="{er*0.18}" fill="#fff"/><circle cx="{c+ex-er*0.45}" cy="{ey}" r="{er*0.18}" fill="#fff"/>')
    # angry brows
    parts.append(f'<path d="M{c-ex-er*1.1} {ey-er*1.3} L{c-ex+er*0.9} {ey-er*0.55}" stroke="{dark}" stroke-width="{r*0.13}" stroke-linecap="round"/>')
    parts.append(f'<path d="M{c+ex+er*1.1} {ey-er*1.3} L{c+ex-er*0.9} {ey-er*0.55}" stroke="{dark}" stroke-width="{r*0.13}" stroke-linecap="round"/>')
    # mouth with teeth
    my = c + r * 0.42
    parts.append(f'<path d="M{c-r*0.32} {my} Q{c} {my+r*0.32} {c+r*0.32} {my} Z" fill="#3A0A1A"/>')
    parts.append(f'<path d="M{c-r*0.2} {my+r*0.02} L{c-r*0.12} {my+r*0.12} L{c-r*0.04} {my+r*0.03} M{c+r*0.04} {my+r*0.03} L{c+r*0.12} {my+r*0.12} L{c+r*0.2} {my+r*0.02}" fill="#fff"/>')
    # gloss
    parts.append(f'<ellipse cx="{c-r*0.38}" cy="{c-r*0.55}" rx="{r*0.32}" ry="{r*0.15}" fill="#fff" opacity=".45" transform="rotate(-30 {c-r*0.38} {c-r*0.55})"/>')
    if kind == "bomber":
        # fuse and spark on top, a hazard band across the body
        parts.append(f'<path d="M{c+r*0.15} {c-r*0.95} Q{c+r*0.45} {c-r*1.35} {c+r*0.2} {c-r*1.55}" stroke="#3A2A1A" stroke-width="{size*0.03}" fill="none" stroke-linecap="round"/>')
        parts.append(f'<circle cx="{c+r*0.2}" cy="{c-r*1.58}" r="{size*0.05}" fill="#FFE45C"/><circle cx="{c+r*0.2}" cy="{c-r*1.58}" r="{size*0.025}" fill="#fff"/>')
        parts.append(f'<path d="M{c-r*0.8} {c+r*0.72} Q{c} {c+r*0.95} {c+r*0.8} {c+r*0.72}" stroke="#FFE45C" stroke-width="{size*0.03}" fill="none" stroke-dasharray="{size*0.04} {size*0.03}"/>')
    if kind == "healer":
        # halo and a white cross
        parts.append(f'<ellipse cx="{c}" cy="{c-r*1.22}" rx="{r*0.55}" ry="{r*0.16}" fill="none" stroke="#FFF6A8" stroke-width="{size*0.025}"/>')
        cx, cy, k = c + r*0.62, c + r*0.62, r*0.15
        parts.append(f'<circle cx="{cx}" cy="{cy}" r="{k*2.2}" fill="#fff" stroke="{dark}" stroke-width="{size*0.01}"/>')
        parts.append(f'<path d="M{cx-k*1.3} {cy} H{cx+k*1.3} M{cx} {cy-k*1.3} V{cy+k*1.3}" stroke="#2BC864" stroke-width="{k*0.8}" stroke-linecap="round"/>')
    if kind == "sniper":
        # scope over one eye and a crosshair badge
        ex2, ey2 = c + r*0.36, c - r*0.08
        parts.append(f'<circle cx="{ex2}" cy="{ey2}" r="{r*0.34}" fill="none" stroke="#2A2A33" stroke-width="{size*0.03}"/>')
        parts.append(f'<path d="M{ex2+r*0.34} {ey2} L{c+r*1.05} {ey2-r*0.25}" stroke="#2A2A33" stroke-width="{size*0.03}" stroke-linecap="round"/>')
        parts.append(f'<path d="M{ex2-r*0.42} {ey2} H{ex2+r*0.42} M{ex2} {ey2-r*0.42} V{ey2+r*0.42}" stroke="#FF3D4A" stroke-width="{size*0.008}"/>')
    if kind == "spore":
        # fluffy puffs around the body
        for i in range(8):
            a = 2 * math.pi * i / 8 + 0.2
            parts.insert(1, f'<circle cx="{c+math.cos(a)*r*1.05}" cy="{c+math.sin(a)*r*1.05}" r="{r*0.28}" fill="{light}" opacity=".55"/>')
    if kind == "elite":
        parts.insert(0, f'<circle cx="{c}" cy="{c}" r="{r*1.55}" fill="none" stroke="#FFE45C" stroke-width="{size*0.02}" stroke-dasharray="{size*0.05} {size*0.035}" opacity=".9"/>')
    return wrap("".join(parts), size, size, defs)


def boss(kind, size=512):
    base = {"sumo": "blob", "cowboy": "spiky", "royal": "elite", "brain": "brainv", "marrow": "bone"}[kind]
    inner = virus(base, size, seed=7)
    inner = inner[inner.index("<defs>"):inner.rindex("</svg>")]
    c = size / 2
    extra = ""
    if kind == "sumo":
        extra = f'''<path d="M{c-150} {c+120} Q{c} {c+190} {c+150} {c+120} L{c+130} {c+170} Q{c} {c+230} {c-130} {c+170} Z" fill="#F2F2F2" stroke="#9A9A9A" stroke-width="6"/>
        <path d="M{c-60} {c+150} L{c-40} {c+230} M{c} {c+158} L{c} {c+240} M{c+60} {c+150} L{c+40} {c+230}" stroke="#F2F2F2" stroke-width="18" stroke-linecap="round"/>
        <path d="M{c-110} {c-150} Q{c} {c-205} {c+110} {c-150}" stroke="#E23B3B" stroke-width="26" fill="none" stroke-linecap="round"/>
        <circle cx="{c}" cy="{c-196}" r="28" fill="#2A1A10"/>'''
    elif kind == "cowboy":
        extra = f'''<ellipse cx="{c}" cy="{c-120}" rx="210" ry="40" fill="#8B5A2B" stroke="#4A2C10" stroke-width="8"/>
        <path d="M{c-100} {c-125} Q{c-95} {c-240} {c} {c-215} Q{c+95} {c-240} {c+100} {c-125} Z" fill="#A86B32" stroke="#4A2C10" stroke-width="8"/>
        <path d="M{c-98} {c-150} Q{c} {c-130} {c+98} {c-150}" stroke="#2A1A0A" stroke-width="16" fill="none"/>
        <path d="M{c-70} {c+150} L{c} {c+215} L{c+70} {c+150}" fill="#E23B3B" stroke="#7A1010" stroke-width="6"/>'''
    elif kind == "brain":
        # brain folds on top and a glowing third eye
        folds = "".join(f'<path d="M{c-120+i*40} {c-60} Q{c-100+i*40} {c-130} {c-80+i*40} {c-70} Q{c-60+i*40} {c-140} {c-40+i*40} {c-80}" '
                        f'stroke="#8A1D55" stroke-width="10" fill="none" stroke-linecap="round" opacity=".75"/>' for i in range(5))
        extra = f'''<path d="M{c-150} {c-40} Q{c-150} {c-200} {c} {c-205} Q{c+150} {c-200} {c+150} {c-40} Q{c} {c-80} {c-150} {c-40} Z" fill="#FF9ACB" stroke="#8A1D55" stroke-width="8"/>
        {folds}
        <ellipse cx="{c}" cy="{c-150}" rx="30" ry="22" fill="#FFFFFF" stroke="#8A1D55" stroke-width="6"/><circle cx="{c}" cy="{c-150}" r="13" fill="#B23CFF"/><circle cx="{c+4}" cy="{c-154}" r="4" fill="#fff"/>
        <circle cx="{c}" cy="{c-150}" r="44" fill="#E05CFF" opacity=".25"/>'''
    elif kind == "marrow":
        # bone horns, a cracked skull plate and bone spikes
        extra = f'''<path d="M{c-120} {c-90} Q{c-210} {c-170} {c-190} {c-250} Q{c-150} {c-170} {c-80} {c-130} Z" fill="#F6F1E4" stroke="#7A6E55" stroke-width="8"/>
        <path d="M{c+120} {c-90} Q{c+210} {c-170} {c+190} {c-250} Q{c+150} {c-170} {c+80} {c-130} Z" fill="#F6F1E4" stroke="#7A6E55" stroke-width="8"/>
        <path d="M{c-110} {c-100} Q{c} {c-170} {c+110} {c-100} L{c+90} {c-60} Q{c} {c-110} {c-90} {c-60} Z" fill="#FFFFFF" stroke="#7A6E55" stroke-width="7"/>
        <path d="M{c-20} {c-150} L{c} {c-120} L{c-15} {c-95} M{c+30} {c-140} L{c+18} {c-112}" stroke="#7A6E55" stroke-width="6" fill="none" stroke-linecap="round"/>
        <rect x="{c-150}" y="{c+120}" width="300" height="34" rx="17" fill="#F6F1E4" stroke="#7A6E55" stroke-width="7"/>
        <circle cx="{c-150}" cy="{c+120}" r="24" fill="#F6F1E4" stroke="#7A6E55" stroke-width="7"/><circle cx="{c-150}" cy="{c+154}" r="24" fill="#F6F1E4" stroke="#7A6E55" stroke-width="7"/>
        <circle cx="{c+150}" cy="{c+120}" r="24" fill="#F6F1E4" stroke="#7A6E55" stroke-width="7"/><circle cx="{c+150}" cy="{c+154}" r="24" fill="#F6F1E4" stroke="#7A6E55" stroke-width="7"/>'''
    else:
        extra = f'''<path d="M{c-110} {c-120} L{c-90} {c-215} L{c-45} {c-150} L{c} {c-235} L{c+45} {c-150} L{c+90} {c-215} L{c+110} {c-120} Z" fill="#FFD34D" stroke="#9A6A00" stroke-width="8"/>
        <circle cx="{c}" cy="{c-185}" r="16" fill="#FF3D6A"/><circle cx="{c-80}" cy="{c-160}" r="11" fill="#3FE6FF"/><circle cx="{c+80}" cy="{c-160}" r="11" fill="#3FE6FF"/>
        <path d="M{c+120} {c+40} L{c+215} {c+20} L{c+215} {c+140} Q{c+180} {c+210} {c+150} {c+215} Q{c+120} {c+150} {c+120} {c+40} Z" fill="#B0BCD0" stroke="#4A5670" stroke-width="8"/>'''
    return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {size} {size}" width="{size}" height="{size}">{inner}{extra}</svg>'


# ---------------------------------------------------------------- boss variants (city 2+)
BOSS_BASE = {"sumo": "blob", "cowboy": "spiky", "royal": "elite", "brain": "brainv", "marrow": "bone"}
BASE_PAL = {"blob": ("#E3A0FF", "#A24BEB", "#4E1883"), "spiky": ("#B7FF5C", "#4CC21E", "#1F6B10"),
            "elite": ("#8AF2FF", "#14B8E6", "#0A4F7A"), "brainv": ("#FFC9E6", "#FF6FB5", "#8A1D55"),
            "bone": ("#FFFFFF", "#E6DCC4", "#7A6E55")}
VARIANT_PAL = {
    "frost": ("#F0FDFF", "#7FD8FF", "#1E5F96"),
    "toxic": ("#E2FF8A", "#7BE02B", "#2C640A"),
    "inferno": ("#FFE08A", "#FF6A1F", "#8A1A00"),
    "shadow": ("#A898D8", "#4A2E7A", "#140826"),
    "mega": ("#FFB4B4", "#E0303A", "#5E0A12"),
}
BOSS_VARIANTS = ["frost", "toxic", "inferno", "shadow", "mega"]


def boss_variant(kind, variant, size=512):
    """A boss in a city variant: its own colors plus the variant's look (ice, slime, fire, smoke, armor)."""
    svg = boss(kind, size)
    for old, new in zip(BASE_PAL[BOSS_BASE[kind]], VARIANT_PAL[variant]):
        svg = svg.replace(old, new)
    light, mid, dark = VARIANT_PAL[variant]
    c = size / 2
    rnd = random.Random(hash((kind, variant)) % 1000)
    back, front, defs = [], [], ""
    if variant == "frost":
        # ice crystals fanning out behind, icicles below, sparkles
        for i in range(9):
            a = -math.pi / 2 + (i - 4) * 0.36
            L = 215 + rnd.uniform(-10, 25)
            x, y = c + math.cos(a) * L, c + math.sin(a) * L
            pa, pb = a - 0.09, a + 0.09
            back.append(f'<path d="M{c+math.cos(pa)*120} {c+math.sin(pa)*120} L{x} {y} L{c+math.cos(pb)*120} {c+math.sin(pb)*120} Z" fill="#DDF7FF" stroke="#4FB4E8" stroke-width="5" opacity=".95"/>')
        for i in range(7):
            x = c - 120 + i * 40; L = 40 + rnd.uniform(0, 35)
            front.append(f'<path d="M{x-12} {c+128} L{x} {c+128+L} L{x+12} {c+128} Z" fill="#E8FBFF" stroke="#4FB4E8" stroke-width="4"/>')
        for (x, y) in [(c-170, c-40), (c+175, c+10), (c-140, c+150), (c+150, c-150)]:
            front.append(f'<path d="M{x} {y-18} L{x} {y+18} M{x-18} {y} L{x+18} {y} M{x-12} {y-12} L{x+12} {y+12} M{x+12} {y-12} L{x-12} {y+12}" stroke="#FFFFFF" stroke-width="5" stroke-linecap="round"/>')
    elif variant == "toxic":
        # slime drips, bubbles and a gas cloud
        back.append(f'<ellipse cx="{c}" cy="{c+40}" rx="235" ry="215" fill="#9CFF3A" opacity=".18"/>')
        for i in range(6):
            x = c - 110 + i * 44; L = 35 + rnd.uniform(0, 45)
            front.append(f'<path d="M{x-14} {c+105} Q{x-14} {c+105+L} {x} {c+115+L} Q{x+14} {c+105+L} {x+14} {c+105} Z" fill="#7BE02B" stroke="#2C640A" stroke-width="4"/>')
            front.append(f'<circle cx="{x}" cy="{c+130+L}" r="9" fill="#9CFF3A" stroke="#2C640A" stroke-width="3"/>')
        for _ in range(7):
            x, y, rr = c + rnd.uniform(-200, 200), c + rnd.uniform(-210, -60), rnd.uniform(8, 18)
            front.append(f'<circle cx="{x}" cy="{y}" r="{rr}" fill="#C8FF6A" opacity=".75" stroke="#2C640A" stroke-width="3"/>')
    elif variant == "inferno":
        # a crown of flames behind and embers around
        defs = '<radialGradient id="fl" cx="50%" cy="80%" r="80%"><stop offset="0" stop-color="#FFF4A0"/><stop offset=".5" stop-color="#FF9A1F"/><stop offset="1" stop-color="#E02A0A"/></radialGradient>'
        for i in range(11):
            a = -math.pi / 2 + (i - 5) * 0.3
            L = 230 + rnd.uniform(-20, 30)
            x, y = c + math.cos(a) * L, c + math.sin(a) * L
            bx1, by1 = c + math.cos(a - 0.22) * 110, c + math.sin(a - 0.22) * 110
            bx2, by2 = c + math.cos(a + 0.22) * 110, c + math.sin(a + 0.22) * 110
            back.append(f'<path d="M{bx1} {by1} Q{x-30} {(by1+y)/2} {x} {y} Q{x+30} {(by2+y)/2} {bx2} {by2} Z" fill="url(#fl)" opacity=".95"/>')
        for _ in range(9):
            x, y = c + rnd.uniform(-220, 220), c + rnd.uniform(-230, 220)
            front.append(f'<circle cx="{x}" cy="{y}" r="{rnd.uniform(4, 9)}" fill="#FFD25C"/>')
    elif variant == "shadow":
        # smoke wisps behind, glowing red eyes, a dark veil
        for i in range(8):
            a = 2 * math.pi * i / 8 + 0.3
            x, y = c + math.cos(a) * 175, c + math.sin(a) * 175
            back.append(f'<circle cx="{x}" cy="{y}" r="{70 + rnd.uniform(-10, 20)}" fill="#2A1A48" opacity=".55"/>')
        back.append(f'<path d="M{c-200} {c+200} Q{c-230} {c+260} {c-150} {c+250} Q{c-80} {c+290} {c} {c+250} Q{c+80} {c+290} {c+150} {c+250} Q{c+230} {c+260} {c+200} {c+200}" fill="#1E1036" opacity=".7"/>')
        r = size * (0.34 if BOSS_BASE[kind] == "blob" else 0.30)
        ey, ex, er = c - r * 0.08, r * 0.36, r * 0.2
        for sx in (-1, 1):
            front.append(f'<circle cx="{c+sx*ex}" cy="{ey+er*0.2}" r="{er*0.9}" fill="#FF2A4A" opacity=".55"/>')
            front.append(f'<circle cx="{c+sx*ex}" cy="{ey+er*0.2}" r="{er*0.45}" fill="#FFE0E6"/>')
    elif variant == "mega":
        # armor: shoulder plates, a spiked collar and bolts
        for sx in (-1, 1):
            x = c + sx * 170
            front.append(f'<path d="M{x-sx*40} {c-40} Q{x+sx*60} {c-60} {x+sx*55} {c+40} Q{x+sx*10} {c+60} {x-sx*40} {c+30} Z" fill="#9AA4B8" stroke="#3A4256" stroke-width="8"/>')
            for k in range(3):
                front.append(f'<path d="M{x+sx*(5+k*18)} {c-48+k*4} L{x+sx*(18+k*22)} {c-95+k*6} L{x+sx*(28+k*18)} {c-44+k*4} Z" fill="#D8DEEA" stroke="#3A4256" stroke-width="5"/>')
            front.append(f'<circle cx="{x}" cy="{c}" r="8" fill="#3A4256"/>')
        front.append(f'<path d="M{c-110} {c+140} Q{c} {c+185} {c+110} {c+140} L{c+100} {c+170} Q{c} {c+215} {c-100} {c+170} Z" fill="#9AA4B8" stroke="#3A4256" stroke-width="7"/>')
        for k in range(5):
            x = c - 80 + k * 40
            front.append(f'<path d="M{x-10} {c+175+abs(k-2)*-6} L{x} {c+205} L{x+10} {c+175+abs(k-2)*-6} Z" fill="#D8DEEA" stroke="#3A4256" stroke-width="4"/>')
    head, rest = svg.split("<defs>", 1)
    d, body = rest.split("</defs>", 1)
    body = body.replace("</svg>", "")
    return f'{head}<defs>{d}{defs}</defs>{"".join(back)}{body}{"".join(front)}</svg>'


# ---------------------------------------------------------------- city strains (regular viruses, city 2+)
STRAIN_PAL = {
    "horned": ("#FF9A8A", "#E0343A", "#6A0A10"),
    "crystal": ("#E6FFFF", "#5FE3F0", "#0E6A80"),
    "armored": ("#E4E8F0", "#9AA4B8", "#3A4256"),
    "punk": ("#FFB0F0", "#F03CC8", "#6A0A5A"),
    "cyclops": ("#FFE0A0", "#FFA024", "#7A3A00"),
    "zombie": ("#D8E8C0", "#8FA878", "#3A4A2A"),
    "gold": ("#FFF6B0", "#F2C230", "#7A5A00"),
    "ninja": ("#8A8AA0", "#3A3A4E", "#101018"),
    "pirate": ("#B0FFE8", "#20C8A0", "#0A5A48"),
}
STRAINS = list(STRAIN_PAL)
STRAIN_KINDS = ["spiky", "blob", "dart", "spitter", "mini", "elite"]
KIND_PAL = {"spiky": ("#B7FF5C", "#4CC21E", "#1F6B10"), "blob": ("#E3A0FF", "#A24BEB", "#4E1883"),
            "dart": ("#FFD08A", "#FF8A1F", "#9A3E00"), "spitter": ("#FFF27A", "#E8C619", "#7A6400"),
            "mini": ("#FF9AAE", "#FF3D6A", "#8A0F2E"), "elite": ("#8AF2FF", "#14B8E6", "#0A4F7A")}


def recolor(svg, old, new):
    for o, n in zip(old, new):
        svg = svg.replace(o, n)
    return svg


def add_layers(svg, back=(), front=(), defs=""):
    head, rest = svg.split("<defs>", 1)
    d, body = rest.split("</defs>", 1)
    body = body.replace("</svg>", "")
    return f'{head}<defs>{d}{defs}</defs>{"".join(back)}{body}{"".join(front)}</svg>'


def strain_virus(kind, strain, size=256):
    """A regular virus in a city strain: new colors plus a look of its own (horns, crystals, helmet...)."""
    svg = recolor(virus(kind, size, seed=hash(kind) % 100), KIND_PAL[kind], STRAIN_PAL[strain])
    light, mid, dark = STRAIN_PAL[strain]
    c = size / 2
    r = size * (0.30 if kind != "blob" else 0.34)
    ey, ex, er = c - r * 0.08, r * 0.36, r * 0.2
    w = size * 0.014
    back, front = [], []
    if strain == "horned":
        for sx in (-1, 1):
            front.append(f'<path d="M{c+sx*r*0.35} {c-r*0.8} Q{c+sx*r*0.75} {c-r*1.25} {c+sx*r*0.55} {c-r*1.55} Q{c+sx*r*0.95} {c-r*1.2} {c+sx*r*0.7} {c-r*0.65} Z" fill="#2A0A10" stroke="#FFD0C0" stroke-width="{w}"/>')
    elif strain == "crystal":
        for a in (-2.1, -1.57, -1.04, 2.4, 0.75):
            x, y = c + math.cos(a) * r * 1.3, c + math.sin(a) * r * 1.3
            bx, by = c + math.cos(a) * r * 0.7, c + math.sin(a) * r * 0.7
            nx, ny = -math.sin(a) * r * 0.16, math.cos(a) * r * 0.16
            front.append(f'<path d="M{bx+nx} {by+ny} L{x} {y} L{bx-nx} {by-ny} Z" fill="#F0FFFF" stroke="#0E6A80" stroke-width="{w}" opacity=".95"/>')
    elif strain == "armored":
        front.append(f'<path d="M{c-r*0.95} {ey-er*0.9} Q{c} {c-r*1.45} {c+r*0.95} {ey-er*0.9} L{c+r*0.85} {ey-er*1.6} Q{c} {c-r*1.2} {c-r*0.85} {ey-er*1.6} Z" fill="#C8D0DE" stroke="#3A4256" stroke-width="{w}"/>')
        front.append(f'<path d="M{c} {c-r*1.28} V{ey-er*1.9}" stroke="#3A4256" stroke-width="{w*1.5}"/>')
        for sx in (-1, 1):
            front.append(f'<circle cx="{c+sx*r*0.6}" cy="{ey-er*1.45}" r="{r*0.06}" fill="#3A4256"/>')
    elif strain == "punk":
        for i in range(5):
            x = c - r * 0.4 + i * r * 0.2
            h = r * (0.55 + 0.15 * (2 - abs(i - 2)))
            front.append(f'<path d="M{x-r*0.1} {c-r*0.9} L{x} {c-r*0.9-h} L{x+r*0.1} {c-r*0.9} Z" fill="#7CFF3A" stroke="#1F5A0A" stroke-width="{w}"/>')
    elif strain == "cyclops":
        front.append(f'<ellipse cx="{c}" cy="{ey}" rx="{r*0.75}" ry="{er*1.6}" fill="{mid}"/>')
        front.append(f'<circle cx="{c}" cy="{ey}" r="{er*1.45}" fill="#fff" stroke="{dark}" stroke-width="{w}"/><circle cx="{c+er*0.2}" cy="{ey+er*0.2}" r="{er*0.8}" fill="#1A1020"/><circle cx="{c-er*0.15}" cy="{ey-er*0.25}" r="{er*0.28}" fill="#fff"/>')
        front.append(f'<path d="M{c-er*1.7} {ey-er*1.9} L{c+er*1.7} {ey-er*1.5}" stroke="{dark}" stroke-width="{r*0.13}" stroke-linecap="round"/>')
    elif strain == "zombie":
        front.append(f'<path d="M{c-r*0.7} {c+r*0.1} L{c-r*0.1} {c-r*0.5}" stroke="#3A4A2A" stroke-width="{w}" fill="none"/>')
        for k in range(4):
            t = k / 3
            x, y = c - r * 0.7 + t * r * 0.6, c + r * 0.1 - t * r * 0.6
            front.append(f'<path d="M{x-r*0.08} {y-r*0.08} L{x+r*0.08} {y+r*0.08}" stroke="#3A4A2A" stroke-width="{w}"/>')
        front.append(f'<rect x="{c+r*0.25}" y="{c+r*0.05}" width="{r*0.4}" height="{r*0.18}" rx="{r*0.04}" fill="#F2E6C8" stroke="#3A4A2A" stroke-width="{w*0.7}" transform="rotate(-20 {c+r*0.45} {c+r*0.14})"/>')
    elif strain == "gold":
        front.append(f'<path d="M{c-r*0.45} {c-r*0.85} L{c-r*0.5} {c-r*1.3} L{c-r*0.22} {c-r*1.05} L{c} {c-r*1.4} L{c+r*0.22} {c-r*1.05} L{c+r*0.5} {c-r*1.3} L{c+r*0.45} {c-r*0.85} Z" fill="#FFE45C" stroke="#7A5A00" stroke-width="{w}"/>')
        front.append(f'<circle cx="{c}" cy="{c-r*1.12}" r="{r*0.08}" fill="#FF3D6A"/>')
    elif strain == "ninja":
        front.append(f'<rect x="{c-r*1.0}" y="{ey-er*1.15}" width="{r*2.0}" height="{er*2.3}" rx="{er*0.6}" fill="#C8202A" opacity=".92"/>')
        front.append(f'<ellipse cx="{c-ex}" cy="{ey}" rx="{er*0.9}" ry="{er*0.7}" fill="#fff"/><ellipse cx="{c+ex}" cy="{ey}" rx="{er*0.9}" ry="{er*0.7}" fill="#fff"/>')
        front.append(f'<circle cx="{c-ex+er*0.2}" cy="{ey+er*0.1}" r="{er*0.45}" fill="#1A1020"/><circle cx="{c+ex-er*0.2}" cy="{ey+er*0.1}" r="{er*0.45}" fill="#1A1020"/>')
        front.append(f'<path d="M{c+r*0.95} {ey} Q{c+r*1.3} {ey-er} {c+r*1.45} {ey+er*0.5} M{c+r*0.95} {ey+er*0.5} Q{c+r*1.3} {ey+er*1.5} {c+r*1.4} {ey+er*2.2}" stroke="#C8202A" stroke-width="{w*2}" fill="none" stroke-linecap="round"/>')
    elif strain == "pirate":
        front.append(f'<path d="M{c-r*0.95} {c-r*0.55} Q{c} {c-r*1.35} {c+r*0.95} {c-r*0.55} Q{c} {c-r*0.85} {c-r*0.95} {c-r*0.55} Z" fill="#E0303A" stroke="#5E0A12" stroke-width="{w}"/>')
        for k in range(4):
            front.append(f'<circle cx="{c-r*0.45+k*r*0.3}" cy="{c-r*0.85}" r="{r*0.05}" fill="#fff"/>')
        front.append(f'<circle cx="{c+ex}" cy="{ey+er*0.1}" r="{er*1.15}" fill="#14141C"/><path d="M{c+ex-er} {ey-er*0.6} L{c-r*0.2} {c-r*0.75} M{c+ex+er} {ey-er*0.6} L{c+r*0.95} {c-r*0.4}" stroke="#14141C" stroke-width="{w}"/>')
    return add_layers(svg, back, front)


# ---------------------------------------------------------------- mini bosses (mid-run)
MINI_BOSSES = {
    "queen": ("blob", ("#FFC8F0", "#E04BC8", "#5A0A50")),
    "turret": ("elite", ("#E4E8F0", "#7A869C", "#2A3244")),
    "rhino": ("spiky", ("#E8C8A0", "#A8743A", "#4A2A0A")),
    "magnet": ("spitter", ("#FFB0B0", "#E0303A", "#5E0A12")),
}


def mini_boss(name, size=384):
    base, pal = MINI_BOSSES[name]
    svg = recolor(virus(base, size, seed=11), KIND_PAL[base], pal)
    c = size / 2
    r = size * (0.30 if base != "blob" else 0.34)
    back, front = [], []
    if name == "queen":
        # tiara and egg sacs full of minis
        front.append(f'<path d="M{c-r*0.5} {c-r*0.82} L{c-r*0.4} {c-r*1.25} L{c-r*0.18} {c-r*1.0} L{c} {c-r*1.4} L{c+r*0.18} {c-r*1.0} L{c+r*0.4} {c-r*1.25} L{c+r*0.5} {c-r*0.82} Z" fill="#FFE45C" stroke="#7A5A00" stroke-width="5"/>')
        for a in (0.5, 1.2, 1.95, 2.65):
            x, y = c + math.cos(a) * r * 1.05, c + math.sin(a) * r * 1.05
            front.append(f'<circle cx="{x}" cy="{y}" r="{r*0.22}" fill="#FFE0F6" stroke="#5A0A50" stroke-width="4" opacity=".95"/><circle cx="{x}" cy="{y}" r="{r*0.1}" fill="#FF3D6A"/>')
    elif name == "turret":
        # four cannon barrels and a radar dish
        for a in (0, math.pi / 2, math.pi, 3 * math.pi / 2):
            ca, sa = math.cos(a + math.pi / 4), math.sin(a + math.pi / 4)
            x1, y1, x2, y2 = c + ca * r * 0.8, c + sa * r * 0.8, c + ca * r * 1.45, c + sa * r * 1.45
            back.append(f'<line x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}" stroke="#2A3244" stroke-width="{r*0.34}" stroke-linecap="round"/><line x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}" stroke="#9AA6BC" stroke-width="{r*0.22}" stroke-linecap="round"/>')
            back.append(f'<circle cx="{x2}" cy="{y2}" r="{r*0.08}" fill="#FF5A3A"/>')
        front.append(f'<path d="M{c-r*0.35} {c-r*1.0} Q{c} {c-r*1.45} {c+r*0.35} {c-r*1.0} Z" fill="#C8D0DE" stroke="#2A3244" stroke-width="5"/><line x1="{c}" y1="{c-r*0.95}" x2="{c}" y2="{c-r*1.35}" stroke="#2A3244" stroke-width="5"/><circle cx="{c}" cy="{c-r*1.38}" r="7" fill="#FF5A3A"/>')
    elif name == "rhino":
        # big horn and armored brow
        front.append(f'<path d="M{c-r*0.3} {c-r*0.7} Q{c-r*0.1} {c-r*1.7} {c+r*0.35} {c-r*1.75} Q{c+r*0.1} {c-r*1.3} {c+r*0.3} {c-r*0.7} Z" fill="#F6F1E4" stroke="#4A2A0A" stroke-width="6"/>')
        front.append(f'<path d="M{c-r*0.8} {c-r*0.35} Q{c} {c-r*0.75} {c+r*0.8} {c-r*0.35} L{c+r*0.7} {c-r*0.55} Q{c} {c-r*0.95} {c-r*0.7} {c-r*0.55} Z" fill="#6A4A2A" stroke="#2A1A0A" stroke-width="5"/>')
        for sx in (-1, 1):
            front.append(f'<ellipse cx="{c+sx*r*0.18}" cy="{c+r*0.2}" rx="{r*0.07}" ry="{r*0.05}" fill="#2A1A0A"/>')
    elif name == "magnet":
        # horseshoe magnet on the head and field lines
        front.append(f'<path d="M{c-r*0.5} {c-r*0.75} V{c-r*1.2} Q{c-r*0.5} {c-r*1.7} {c} {c-r*1.7} Q{c+r*0.5} {c-r*1.7} {c+r*0.5} {c-r*1.2} V{c-r*0.75} H{c+r*0.22} V{c-r*1.2} Q{c+r*0.22} {c-r*1.45} {c} {c-r*1.45} Q{c-r*0.22} {c-r*1.45} {c-r*0.22} {c-r*1.2} V{c-r*0.75} Z" fill="#E0303A" stroke="#5E0A12" stroke-width="5"/>')
        front.append(f'<rect x="{c-r*0.5}" y="{c-r*0.95}" width="{r*0.28}" height="{r*0.2}" fill="#E8ECF4" stroke="#5E0A12" stroke-width="4"/><rect x="{c+r*0.22}" y="{c-r*0.95}" width="{r*0.28}" height="{r*0.2}" fill="#E8ECF4" stroke="#5E0A12" stroke-width="4"/>')
        for k in (1.2, 1.45):
            back.append(f'<circle cx="{c}" cy="{c}" r="{r*k}" fill="none" stroke="#5FB8FF" stroke-width="4" stroke-dasharray="14 12" opacity=".7"/>')
    return add_layers(svg, back, front)


# ---------------------------------------------------------------- allies + mission props
def ally(name, size=256):
    """Dr. Leuko's white blood cell helpers: a friendly round cell with a role badge."""
    c = size / 2
    r = size * 0.3
    accent = {"medic": "#FF4D6A", "guardian": "#4FA8FF", "hunter": "#7CFF5A"}[name]
    defs = f'''<radialGradient id="wb{name}" cx="36%" cy="30%" r="80%"><stop offset="0" stop-color="#FFFFFF"/><stop offset=".6" stop-color="#E4E8FF"/><stop offset="1" stop-color="#9AA2D8"/></radialGradient>
    <filter id="wg{name}" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="{size*0.04}"/></filter>'''
    p = [f'<circle cx="{c}" cy="{c}" r="{r*1.2}" fill="{accent}" opacity=".35" filter="url(#wg{name})"/>']
    # soft wobbly membrane bumps
    for i in range(10):
        a = 2 * math.pi * i / 10
        p.append(f'<circle cx="{c+math.cos(a)*r*0.92}" cy="{c+math.sin(a)*r*0.92}" r="{r*0.28}" fill="url(#wb{name})" stroke="#7A82B8" stroke-width="{size*0.01}"/>')
    p.append(f'<circle cx="{c}" cy="{c}" r="{r}" fill="url(#wb{name})" stroke="#7A82B8" stroke-width="{size*0.014}"/>')
    # friendly face
    ey, ex, er = c - r * 0.1, r * 0.34, r * 0.19
    for sx in (-1, 1):
        p.append(f'<ellipse cx="{c+sx*ex}" cy="{ey}" rx="{er*0.8}" ry="{er}" fill="#1A1A3A"/><circle cx="{c+sx*ex-er*0.25}" cy="{ey-er*0.35}" r="{er*0.3}" fill="#fff"/>')
        p.append(f'<ellipse cx="{c+sx*r*0.58}" cy="{c+r*0.2}" rx="{r*0.13}" ry="{r*0.08}" fill="#FF8AA8" opacity=".6"/>')
    p.append(f'<path d="M{c-r*0.25} {c+r*0.3} Q{c} {c+r*0.55} {c+r*0.25} {c+r*0.3}" stroke="#1A1A3A" stroke-width="{size*0.02}" fill="none" stroke-linecap="round"/>')
    if name == "medic":
        p.append(f'<path d="M{c-r*0.55} {c-r*0.62} Q{c} {c-r*1.25} {c+r*0.55} {c-r*0.62} Z" fill="#fff" stroke="#C8CCE8" stroke-width="{size*0.01}"/>')
        k = r * 0.13
        p.append(f'<path d="M{c-k*1.4} {c-r*0.82} H{c+k*1.4} M{c} {c-r*0.82-k*1.4} V{c-r*0.82+k*1.4}" stroke="{accent}" stroke-width="{k*0.9}" stroke-linecap="round"/>')
    elif name == "guardian":
        x, y = c + r * 0.75, c + r * 0.45
        p.append(f'<path d="M{x-r*0.38} {y-r*0.38} H{x+r*0.38} V{y+r*0.05} Q{x+r*0.38} {y+r*0.42} {x} {y+r*0.55} Q{x-r*0.38} {y+r*0.42} {x-r*0.38} {y+r*0.05} Z" fill="{accent}" stroke="#1A4A8A" stroke-width="{size*0.014}"/>')
        p.append(f'<path d="M{x} {y-r*0.25} V{y+r*0.35}" stroke="#fff" stroke-width="{size*0.014}"/>')
        p.append(f'<path d="M{c-r*0.6} {c-r*0.75} Q{c} {c-r*1.2} {c+r*0.6} {c-r*0.75}" stroke="{accent}" stroke-width="{size*0.03}" fill="none" stroke-linecap="round"/>')
    else:
        p.append(f'<rect x="{c-r*0.72}" y="{ey-er*0.9}" width="{r*1.44}" height="{er*1.8}" rx="{er*0.8}" fill="{accent}" opacity=".55" stroke="#1F6A10" stroke-width="{size*0.01}"/>')
        x, y = c + r * 0.8, c - r * 0.75
        p.append(f'<circle cx="{x}" cy="{y}" r="{r*0.22}" fill="none" stroke="{accent}" stroke-width="{size*0.014}"/><path d="M{x-r*0.32} {y} H{x+r*0.32} M{x} {y-r*0.32} V{y+r*0.32}" stroke="{accent}" stroke-width="{size*0.01}"/>')
    return wrap("".join(p), size, size, defs)


def bed(size=256):
    """Patient Zero's hospital bed for Hospital Defense (seen from above)."""
    c = size / 2
    p = [f'<ellipse cx="{c}" cy="{c+8}" rx="{size*0.42}" ry="{size*0.46}" fill="#3FFF9A" opacity=".18"/>']
    p.append(f'<rect x="{c-62}" y="{c-100}" width="124" height="200" rx="16" fill="#C8D0E0" stroke="#5A6680" stroke-width="6"/>')
    p.append(f'<rect x="{c-54}" y="{c-92}" width="108" height="184" rx="12" fill="#F4F7FF"/>')
    p.append(f'<rect x="{c-40}" y="{c-86}" width="80" height="34" rx="12" fill="#FFFFFF" stroke="#C8D0E0" stroke-width="3"/>')
    p.append(f'<circle cx="{c}" cy="{c-50}" r="24" fill="#B8E6A0" stroke="#5A8A40" stroke-width="4"/>')
    p.append(f'<circle cx="{c-8}" cy="{c-54}" r="3.5" fill="#2A3A20"/><circle cx="{c+8}" cy="{c-54}" r="3.5" fill="#2A3A20"/><path d="M{c-8} {c-40} Q{c} {c-45} {c+8} {c-40}" stroke="#2A3A20" stroke-width="3" fill="none"/>')
    p.append(f'<rect x="{c-54}" y="{c-26}" width="108" height="118" rx="10" fill="#7FC8FF" stroke="#3A78B0" stroke-width="4"/>')
    p.append(f'<path d="M{c-54} {c-8} H{c+54}" stroke="#FFFFFF" stroke-width="8"/>')
    k = 12
    p.append(f'<circle cx="{c+44}" cy="{c+78}" r="18" fill="#fff" stroke="#E0303A" stroke-width="3"/><path d="M{c+44-k} {c+78} H{c+44+k} M{c+44} {c+78-k} V{c+78+k}" stroke="#E0303A" stroke-width="6"/>')
    return wrap("".join(p), size, size)


# ---------------------------------------------------------------- pickups / fx
def orb(size=96, color="#3FE6FF", core="#E8FFFF"):
    defs = f'''<radialGradient id="o" cx="40%" cy="35%" r="70%"><stop offset="0" stop-color="{core}"/><stop offset=".6" stop-color="{color}"/><stop offset="1" stop-color="{color}" stop-opacity=".2"/></radialGradient>
    <filter id="og" x="-60%" y="-60%" width="220%" height="220%"><feGaussianBlur stdDeviation="7"/></filter>'''
    c = size / 2
    body = f'''<circle cx="{c}" cy="{c}" r="{size*0.34}" fill="{color}" opacity=".6" filter="url(#og)"/>
    <path d="M{c} {size*0.16} L{size*0.78} {c} L{c} {size*0.84} L{size*0.22} {c} Z" fill="url(#o)" stroke="#fff" stroke-opacity=".7" stroke-width="2"/>
    <path d="M{c} {size*0.22} L{size*0.62} {c*0.95} L{c} {c*0.95}Z" fill="#fff" opacity=".55"/>'''
    return wrap(body, size, size, defs)


def coin(size=96):
    defs = '''<radialGradient id="c" cx="38%" cy="32%" r="80%"><stop offset="0" stop-color="#FFF6B0"/><stop offset=".6" stop-color="#FFC92E"/><stop offset="1" stop-color="#C77A00"/></radialGradient>'''
    body = '''<circle cx="48" cy="48" r="38" fill="url(#c)" stroke="#9A5A00" stroke-width="4"/>
    <circle cx="48" cy="48" r="28" fill="none" stroke="#FFF1A0" stroke-width="3" opacity=".7"/>
    <path d="M36 38 Q48 22 60 38 Q48 54 36 70 M60 70 Q48 54 36 38" stroke="#9A5A00" stroke-width="5" fill="none" stroke-linecap="round" transform="translate(0 -8) scale(1 1.1)"/>'''
    return wrap(body, 96, 96, defs)


def heart(size=96):
    defs = '''<radialGradient id="h" cx="35%" cy="30%" r="80%"><stop offset="0" stop-color="#FFB3C2"/><stop offset=".6" stop-color="#FF3D6A"/><stop offset="1" stop-color="#A3002A"/></radialGradient>'''
    body = '<path d="M48 82 C10 58 10 26 30 20 C40 17 46 24 48 30 C50 24 56 17 66 20 C86 26 86 58 48 82 Z" fill="url(#h)" stroke="#7A0020" stroke-width="3"/><ellipse cx="34" cy="32" rx="9" ry="5" fill="#fff" opacity=".6"/>'
    return wrap(body, 96, 96, defs)


def chest(size=128):
    defs = '''<linearGradient id="ch" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#7CF6FF"/><stop offset="1" stop-color="#1680C8"/></linearGradient>
    <filter id="cg" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="8"/></filter>'''
    body = '''<circle cx="64" cy="64" r="48" fill="#FFE45C" opacity=".5" filter="url(#cg)"/>
    <rect x="22" y="48" width="84" height="56" rx="10" fill="url(#ch)" stroke="#0A3A6A" stroke-width="5"/>
    <path d="M22 60 Q22 28 64 28 Q106 28 106 60 Z" fill="url(#ch)" stroke="#0A3A6A" stroke-width="5"/>
    <rect x="56" y="54" width="16" height="22" rx="4" fill="#FFE45C" stroke="#9A6A00" stroke-width="3"/>
    <path d="M30 40 Q50 30 64 31" stroke="#fff" stroke-width="5" opacity=".6" fill="none" stroke-linecap="round"/>'''
    return wrap(body, 128, 128, defs)


def glow(size=128, color="#7CF6FF"):
    defs = f'''<radialGradient id="g"><stop offset="0" stop-color="#fff"/><stop offset=".25" stop-color="{color}"/><stop offset="1" stop-color="{color}" stop-opacity="0"/></radialGradient>'''
    return wrap(f'<circle cx="{size/2}" cy="{size/2}" r="{size/2}" fill="url(#g)"/>', size, size, defs)


def bolt(color="#7CF6FF"):
    defs = f'''<linearGradient id="bl" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="{color}" stop-opacity="0"/><stop offset=".6" stop-color="{color}"/><stop offset="1" stop-color="#fff"/></linearGradient>
    <filter id="bg" x="-20%" y="-100%" width="140%" height="300%"><feGaussianBlur stdDeviation="4"/></filter>'''
    body = f'<rect x="4" y="12" width="88" height="16" rx="8" fill="{color}" opacity=".7" filter="url(#bg)"/><rect x="8" y="15" width="84" height="10" rx="5" fill="url(#bl)"/><circle cx="88" cy="20" r="7" fill="#fff"/>'
    return wrap(body, 96, 40, defs)


def bomb(size=96):
    defs = '''<radialGradient id="bm" cx="35%" cy="30%" r="80%"><stop offset="0" stop-color="#FFC2F0"/><stop offset=".6" stop-color="#E03BC0"/><stop offset="1" stop-color="#6A0A58"/></radialGradient>'''
    body = '''<circle cx="48" cy="52" r="32" fill="url(#bm)" stroke="#4A0040" stroke-width="4"/>
    <path d="M48 40 V64 M36 52 H60" stroke="#fff" stroke-width="8" stroke-linecap="round"/>
    <path d="M48 20 Q56 10 64 14" stroke="#FFE45C" stroke-width="5" fill="none" stroke-linecap="round"/><circle cx="66" cy="13" r="6" fill="#FFE45C"/>'''
    return wrap(body, 96, 96, defs)


def slime(size=64):
    defs = '''<radialGradient id="sl" cx="40%" cy="35%" r="70%"><stop offset="0" stop-color="#FFFFB0"/><stop offset=".6" stop-color="#C8E619"/><stop offset="1" stop-color="#5A7000"/></radialGradient>'''
    return wrap('<circle cx="32" cy="32" r="20" fill="url(#sl)" stroke="#3A4A00" stroke-width="3"/><circle cx="25" cy="25" r="6" fill="#fff" opacity=".6"/>', 64, 64, defs)


# ---------------------------------------------------------------- organ backgrounds (tileable 1024)
ORGANS = {
    "lungs": ("#2A0E1E", "#5A1A3A", "#FF7AA8"),
    "heart": ("#2A0608", "#6A0E14", "#FF4D4D"),
    "stomach": ("#0C2010", "#1E4A1C", "#9CFF5C"),
    "brain": ("#170E2E", "#36206A", "#B98AFF"),
    "marrow": ("#2A1C08", "#5A3E12", "#FFC86B"),
    "endless": ("#06121E", "#0E2A44", "#3FE6FF"),
}


# Second look for each organ (cities 2+ alternate): a sicker, more infected palette.
ORGANS_ALT = {
    "lungs": ("#1E0A26", "#4A1A5A", "#E07CFF"),
    "heart": ("#200414", "#5A0A30", "#FF5A9A"),
    "stomach": ("#1A1E06", "#46480E", "#E8FF4A"),
    "brain": ("#0A1430", "#173A6A", "#6AC8FF"),
    "marrow": ("#2A0E06", "#5A2410", "#FF8A4A"),
}


def backdrop(name, size=1024, seed=3, alt=False):
    deep, mid, accent = (ORGANS_ALT if alt else ORGANS)[name]
    rnd = random.Random(seed + len(name) + (101 if alt else 0))
    defs = f'''<radialGradient id="cell" cx="40%" cy="35%" r="70%"><stop offset="0" stop-color="{accent}" stop-opacity=".22"/><stop offset=".7" stop-color="{accent}" stop-opacity=".08"/><stop offset="1" stop-color="{accent}" stop-opacity="0"/></radialGradient>
    <radialGradient id="nuc"><stop offset="0" stop-color="{accent}" stop-opacity=".3"/><stop offset="1" stop-color="{accent}" stop-opacity="0"/></radialGradient>
    <radialGradient id="spark"><stop offset="0" stop-color="#FFFFFF" stop-opacity=".9"/><stop offset=".3" stop-color="{accent}" stop-opacity=".6"/><stop offset="1" stop-color="{accent}" stop-opacity="0"/></radialGradient>
    <filter id="soft" x="-20%" y="-20%" width="140%" height="140%"><feGaussianBlur stdDeviation="3"/></filter>
    <filter id="blur" x="-30%" y="-30%" width="160%" height="160%"><feGaussianBlur stdDeviation="14"/></filter>'''
    parts = [f'<rect width="{size}" height="{size}" fill="{deep}"/>']

    def tiled(make, x, y, margin=160):
        # Draws an element at every wrapped copy that touches the tile, so the texture tiles seamlessly.
        for dx in (-size, 0, size):
            for dy in (-size, 0, size):
                cx, cy = x + dx, y + dy
                if -margin < cx < size + margin and -margin < cy < size + margin:
                    parts.append(make(cx, cy))

    # big soft blobs for depth
    for i in range(10):
        x, y, r = rnd.uniform(0, size), rnd.uniform(0, size), rnd.uniform(120, 260)
        tiled(lambda cx, cy, r=r: f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="{mid}" opacity=".4" filter="url(#blur)"/>', x, y, 300)

    if name == "lungs":
        # bronchi branches and grape-like alveoli clusters
        for i in range(5):
            x, y, a = rnd.uniform(0, size), rnd.uniform(0, size), rnd.uniform(0, 6.3)
            L = rnd.uniform(160, 260)
            def br(cx, cy, a=a, L=L):
                x2, y2 = cx + math.cos(a) * L, cy + math.sin(a) * L
                out = f'<path d="M{cx} {cy} Q{cx+math.cos(a+0.4)*L*0.6} {cy+math.sin(a+0.4)*L*0.6} {x2} {y2}" stroke="{accent}" stroke-opacity=".16" stroke-width="16" fill="none" stroke-linecap="round"/>'
                for s2 in (-0.6, 0.6):
                    out += f'<path d="M{x2} {y2} L{x2+math.cos(a+s2)*L*0.4} {y2+math.sin(a+s2)*L*0.4}" stroke="{accent}" stroke-opacity=".13" stroke-width="9" stroke-linecap="round"/>'
                return out
            tiled(br, x, y, 300)
        for i in range(16):
            x, y, r = rnd.uniform(0, size), rnd.uniform(0, size), rnd.uniform(14, 26)
            offs = [(rnd.uniform(-1.3, 1.3) * r, rnd.uniform(-1.3, 1.3) * r) for _ in range(6)]
            tiled(lambda cx, cy, r=r, offs=offs: "".join(f'<circle cx="{cx+ox}" cy="{cy+oy}" r="{r}" fill="url(#cell)" stroke="{accent}" stroke-opacity=".22" stroke-width="2.5"/>' for ox, oy in offs), x, y)
    elif name == "heart":
        # vessels and red blood cell discs
        for i in range(4):
            y0, amp, ph = rnd.uniform(0, size), rnd.uniform(30, 70), rnd.uniform(0, 6)
            d = "M0 " + " ".join(f"L{x} {y0 + math.sin(x / size * 2 * math.pi * 2 + ph) * amp}" for x in range(0, size + 1, 32))
            for dy in (-size, 0, size):
                parts.append(f'<path d="{d}" transform="translate(0 {dy})" stroke="{accent}" stroke-opacity=".12" stroke-width="34" fill="none"/>')
        for i in range(34):
            x, y, r, rot = rnd.uniform(0, size), rnd.uniform(0, size), rnd.uniform(14, 24), rnd.uniform(0, 180)
            tiled(lambda cx, cy, r=r, rot=rot: f'<g transform="rotate({rot} {cx} {cy})"><ellipse cx="{cx}" cy="{cy}" rx="{r}" ry="{r*0.62}" fill="{accent}" opacity=".22"/><ellipse cx="{cx}" cy="{cy}" rx="{r*0.5}" ry="{r*0.28}" fill="{deep}" opacity=".35"/></g>', x, y)
    elif name == "stomach":
        # folds of villi and acid bubbles
        for i in range(22):
            x, y, h, rot = rnd.uniform(0, size), rnd.uniform(0, size), rnd.uniform(40, 80), rnd.uniform(-30, 30)
            tiled(lambda cx, cy, h=h, rot=rot: f'<path d="M{cx-12} {cy+h/2} V{cy-h/2+12} Q{cx} {cy-h/2-6} {cx+12} {cy-h/2+12} V{cy+h/2}" transform="rotate({rot} {cx} {cy})" fill="{accent}" opacity=".13" stroke="{accent}" stroke-opacity=".22" stroke-width="2"/>', x, y)
        for i in range(30):
            x, y, r = rnd.uniform(0, size), rnd.uniform(0, size), rnd.uniform(5, 18)
            tiled(lambda cx, cy, r=r: f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="none" stroke="{accent}" stroke-opacity=".3" stroke-width="2"/><circle cx="{cx-r*0.35}" cy="{cy-r*0.35}" r="{r*0.2}" fill="#fff" opacity=".25"/>', x, y)
    elif name == "brain":
        # neuron network with glowing synapses
        pts = [(rnd.uniform(0, size), rnd.uniform(0, size)) for _ in range(22)]
        for i, (x, y) in enumerate(pts):
            near = sorted(range(len(pts)), key=lambda j: (pts[j][0] - x) ** 2 + (pts[j][1] - y) ** 2)[1:3]
            for j in near:
                x2, y2 = pts[j]
                tiled(lambda cx, cy, ddx=x2 - x, ddy=y2 - y: f'<path d="M{cx} {cy} Q{cx+ddx*0.5+20} {cy+ddy*0.5-20} {cx+ddx} {cy+ddy}" stroke="{accent}" stroke-opacity=".2" stroke-width="3" fill="none"/>', x, y, 400)
            tiled(lambda cx, cy: f'<circle cx="{cx}" cy="{cy}" r="16" fill="{accent}" opacity=".18"/><circle cx="{cx}" cy="{cy}" r="26" fill="url(#spark)" opacity=".5"/>', x, y)
    elif name == "marrow":
        # spongy bone lattice and marrow cells
        pts = [(rnd.uniform(0, size), rnd.uniform(0, size)) for _ in range(26)]
        for i, (x, y) in enumerate(pts):
            near = sorted(range(len(pts)), key=lambda j: (pts[j][0] - x) ** 2 + (pts[j][1] - y) ** 2)[1:4]
            for j in near:
                x2, y2 = pts[j]
                tiled(lambda cx, cy, ddx=x2 - x, ddy=y2 - y: f'<line x1="{cx}" y1="{cy}" x2="{cx+ddx}" y2="{cy+ddy}" stroke="{accent}" stroke-opacity=".17" stroke-width="13" stroke-linecap="round"/>', x, y, 400)
        for i in range(18):
            x, y, r = rnd.uniform(0, size), rnd.uniform(0, size), rnd.uniform(14, 30)
            tiled(lambda cx, cy, r=r: f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="url(#cell)" stroke="{accent}" stroke-opacity=".2" stroke-width="2"/><circle cx="{cx}" cy="{cy}" r="{r*0.35}" fill="url(#nuc)"/>', x, y)
    else:
        # Endless: a lab simulation grid with floating cells
        for k in range(0, size, 64):
            parts.append(f'<path d="M{k} 0 V{size} M0 {k} H{size}" stroke="{accent}" stroke-opacity=".07" stroke-width="2"/>')
        for i in range(20):
            x, y, r = rnd.uniform(0, size), rnd.uniform(0, size), rnd.uniform(26, 70)
            tiled(lambda cx, cy, r=r: f'<g filter="url(#soft)"><circle cx="{cx}" cy="{cy}" r="{r}" fill="url(#cell)" stroke="{accent}" stroke-opacity=".18" stroke-width="3"/><circle cx="{cx+r*0.15}" cy="{cy+r*0.1}" r="{r*0.32}" fill="url(#nuc)"/></g>', x, y)
    # tiny particles
    for i in range(140):
        x, y = rnd.uniform(0, size), rnd.uniform(0, size)
        parts.append(f'<circle cx="{x}" cy="{y}" r="{rnd.uniform(1.2,3.2)}" fill="{accent}" opacity="{rnd.uniform(.15,.4)}"/>')
    return wrap("".join(parts), size, size, defs)


# ---------------------------------------------------------------- icon
def icon(size=1024):
    n = nano("fight", 512, True)
    n_inner = n[n.index("<defs>"):n.rindex("</svg>")]
    v = virus("spiky", 512, seed=4)
    v_inner = v[v.index("<defs>"):v.rindex("</svg>")]
    m = virus("mini", 256, seed=5)
    m_inner = m[m.index("<defs>"):m.rindex("</svg>")]
    b = minibot(128)
    b_inner = b[b.index("<defs>"):b.rindex("</svg>")]
    defs = '''<radialGradient id="ibg" cx="40%" cy="40%" r="80%"><stop offset="0" stop-color="#173A66"/><stop offset=".6" stop-color="#0B1B36"/><stop offset="1" stop-color="#050B18"/></radialGradient>
    <radialGradient id="ig" cx="30%" cy="70%" r="60%"><stop offset="0" stop-color="#2DD4FF" stop-opacity=".45"/><stop offset="1" stop-color="#2DD4FF" stop-opacity="0"/></radialGradient>
    <linearGradient id="beam" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#7CF6FF" stop-opacity=".1"/><stop offset="1" stop-color="#fff"/></linearGradient>
    <filter id="bb" x="-10%" y="-200%" width="120%" height="500%"><feGaussianBlur stdDeviation="10"/></filter>'''
    body = f'''<rect width="1024" height="1024" fill="url(#ibg)"/><rect width="1024" height="1024" fill="url(#ig)"/>
    <g opacity=".22">{''.join(f'<circle cx="{random.Random(i).uniform(0,1024)}" cy="{random.Random(i+99).uniform(0,1024)}" r="{random.Random(i+7).uniform(20,60)}" fill="none" stroke="#7CF6FF" stroke-width="4"/>' for i in range(10))}</g>
    <g transform="translate(560 90) scale(.95)">{v_inner}</g>
    <g transform="translate(800 560) scale(.8)">{m_inner}</g>
    <g transform="rotate(-28 520 520)"><rect x="380" y="430" width="430" height="44" rx="22" fill="#7CF6FF" opacity=".7" filter="url(#bb)"/><rect x="380" y="440" width="430" height="24" rx="12" fill="url(#beam)"/></g>
    <g transform="translate(40 330) scale(1.25)">{n_inner}</g>
    <g transform="translate(70 170) scale(.9)">{b_inner}</g>
    <g transform="translate(150 850) scale(.75)">{b_inner}</g>'''
    return wrap(body, 1024, 1024, defs)


async def render(items):
    async with async_playwright() as p:
        b = await p.chromium.launch(executable_path=os.environ.get("CHROMIUM") or None)
        pg = await b.new_page(device_scale_factor=1)
        for name, svg in items:
            w = int(svg.split('width="')[1].split('"')[0]); h = int(svg.split('height="')[1].split('"')[0])
            await pg.set_viewport_size({"width": w, "height": h})
            await pg.set_content(f'<html><body style="margin:0;background:transparent">{svg}</body></html>')
            await pg.locator("svg").first.screenshot(path=os.path.join(OUT, name + ".png"), omit_background=True)
        await b.close()


def imageset(name, png, scale=3):
    d = os.path.join(ASSETS, f"{name}.imageset")
    os.makedirs(d, exist_ok=True)
    fn = f"{name}@{scale}x.png" if scale else f"{name}.png"
    os.replace(png, os.path.join(d, fn)) if False else __import__("shutil").copy(png, os.path.join(d, fn))
    json.dump({"images": [{"idiom": "universal", "filename": fn, "scale": f"{scale}x"}], "info": {"author": "xcode", "version": 1}}, open(os.path.join(d, "Contents.json"), "w"))


# ---------------------------------------------------------------- story portraits
def leuko(size=512):
    """Dr. Leuko: a friendly white blood cell commander with glasses, headset and a red-cross cap."""
    defs = '''<radialGradient id="lk" cx="38%" cy="30%" r="80%"><stop offset="0" stop-color="#FFFFFF"/><stop offset=".6" stop-color="#EDE8FF"/><stop offset="1" stop-color="#B8AEE0"/></radialGradient>
    <radialGradient id="lkn" cx="40%" cy="35%" r="70%"><stop offset="0" stop-color="#E7B8FF"/><stop offset="1" stop-color="#9B5BD6"/></radialGradient>
    <filter id="lkg" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="14"/></filter>'''
    # bumpy cell outline
    pts = []
    for i in range(18):
        a = 2 * math.pi * i / 18
        r = 175 + (12 if i % 2 else -6)
        pts.append((256 + math.cos(a) * r, 270 + math.sin(a) * r))
    d = f"M{pts[0][0]} {pts[0][1]} " + " ".join(
        f"Q{256 + math.cos(2*math.pi*(i+0.5)/18)*205} {270 + math.sin(2*math.pi*(i+0.5)/18)*205} {pts[(i+1)%18][0]} {pts[(i+1)%18][1]}" for i in range(18)) + " Z"
    body = f'''<circle cx="256" cy="270" r="200" fill="#B8AEE0" opacity=".35" filter="url(#lkg)"/>
    <path d="{d}" fill="url(#lk)" stroke="#8C7FC4" stroke-width="7"/>
    <ellipse cx="330" cy="395" rx="40" ry="26" fill="url(#lkn)" opacity=".5"/><ellipse cx="380" cy="360" rx="22" ry="17" fill="url(#lkn)" opacity=".4"/>
    <!-- cap -->
    <path d="M150 150 Q256 60 362 150 L350 178 Q256 140 162 178 Z" fill="#FFFFFF" stroke="#8C7FC4" stroke-width="6"/>
    <rect x="236" y="96" width="40" height="40" rx="6" fill="#FF4D6D"/><path d="M256 104 V128 M244 116 H268" stroke="#fff" stroke-width="7" stroke-linecap="round"/>
    <!-- glasses + eyes -->
    <circle cx="206" cy="250" r="42" fill="#fff" stroke="#3A2E6E" stroke-width="9"/><circle cx="306" cy="250" r="42" fill="#fff" stroke="#3A2E6E" stroke-width="9"/>
    <path d="M248 250 H264" stroke="#3A2E6E" stroke-width="9"/>
    <circle cx="212" cy="256" r="17" fill="#2A1E52"/><circle cx="300" cy="256" r="17" fill="#2A1E52"/>
    <circle cx="218" cy="249" r="6" fill="#fff"/><circle cx="306" cy="249" r="6" fill="#fff"/>
    <path d="M176 198 Q206 184 236 198 M276 198 Q306 184 336 198" stroke="#3A2E6E" stroke-width="8" fill="none" stroke-linecap="round"/>
    <!-- smile -->
    <path d="M220 320 Q256 350 292 320" stroke="#3A2E6E" stroke-width="9" fill="none" stroke-linecap="round"/>
    <circle cx="170" cy="310" r="16" fill="#FF9AC8" opacity=".55"/><circle cx="342" cy="310" r="16" fill="#FF9AC8" opacity=".55"/>
    <!-- headset -->
    <path d="M96 260 Q96 120 256 112" stroke="#2DD4FF" stroke-width="12" fill="none" stroke-linecap="round" opacity="0"/>
    <rect x="70" y="232" width="34" height="62" rx="14" fill="#2DD4FF" stroke="#0A6F8E" stroke-width="5"/>
    <path d="M90 292 Q110 360 182 352" stroke="#0A6F8E" stroke-width="7" fill="none" stroke-linecap="round"/>
    <circle cx="186" cy="352" r="11" fill="#2DD4FF" stroke="#0A6F8E" stroke-width="4"/>'''
    return wrap(body, size, size, defs)


def vex(size=512):
    """King Vex: the dark virus mastermind with a spiked crown, cape and one glowing eye."""
    c = 256
    defs = '''<radialGradient id="vx" cx="36%" cy="30%" r="80%"><stop offset="0" stop-color="#C77DFF"/><stop offset=".55" stop-color="#6A1B9A"/><stop offset="1" stop-color="#2A0638"/></radialGradient>
    <linearGradient id="vc" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#E0213F"/><stop offset="1" stop-color="#6E0618"/></linearGradient>
    <radialGradient id="ve" cx="50%" cy="50%" r="50%"><stop offset="0" stop-color="#FFFFFF"/><stop offset=".35" stop-color="#FFE45C"/><stop offset="1" stop-color="#FF3D00"/></radialGradient>
    <filter id="vg" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="16"/></filter>'''
    parts = [f'<circle cx="{c}" cy="290" r="210" fill="#B23CFF" opacity=".35" filter="url(#vg)"/>',
             # cape
             f'<path d="M90 300 Q60 470 120 500 L392 500 Q452 470 422 300 Q256 380 90 300 Z" fill="url(#vc)" stroke="#3A0010" stroke-width="7"/>',
             f'<path d="M120 300 Q256 360 392 300 L380 330 Q256 390 132 330 Z" fill="#F2F2F2" stroke="#9A9A9A" stroke-width="4"/>']
    for i in range(14):
        a = 2 * math.pi * i / 14
        x1, y1 = c + math.cos(a) * 130, 280 + math.sin(a) * 130
        x2, y2 = c + math.cos(a) * 190, 280 + math.sin(a) * 190
        if math.sin(a) < -0.55:  # crown sits on top
            continue
        parts.append(f'<line x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}" stroke="#2A0638" stroke-width="16" stroke-linecap="round"/>')
        parts.append(f'<circle cx="{x2}" cy="{y2}" r="19" fill="url(#vx)" stroke="#2A0638" stroke-width="5"/>')
    parts.append(f'<circle cx="{c}" cy="280" r="150" fill="url(#vx)" stroke="#2A0638" stroke-width="8"/>')
    # crown
    parts.append('<path d="M146 168 L130 50 L194 118 L226 30 L256 110 L286 30 L318 118 L382 50 L366 168 Q256 136 146 168 Z" fill="#1A1A1A" stroke="#FFD34D" stroke-width="8"/>')
    parts.append('<circle cx="256" cy="140" r="16" fill="#FF3D6A"/><circle cx="190" cy="148" r="10" fill="#3FE6FF"/><circle cx="322" cy="148" r="10" fill="#3FE6FF"/>')
    # eyes: one big glowing, one scarred slit
    parts.append('<circle cx="300" cy="262" r="46" fill="url(#ve)"/><circle cx="300" cy="262" r="62" fill="#FFB000" opacity=".35" filter="url(#vg)"/>')
    parts.append('<ellipse cx="300" cy="262" rx="9" ry="30" fill="#1A0010"/>')
    parts.append('<path d="M180 262 Q210 248 240 262" stroke="#FFE45C" stroke-width="10" fill="none" stroke-linecap="round"/>')
    parts.append('<path d="M176 222 L246 246 M250 214 L350 226" stroke="#14001C" stroke-width="14" stroke-linecap="round"/>')
    # grin
    parts.append('<path d="M186 330 Q256 392 330 322 Q256 352 186 330 Z" fill="#14001C"/>')
    parts.append('<path d="M206 338 L216 356 L228 342 M246 348 L256 366 L266 348 M286 342 L298 356 L308 334" fill="#fff" stroke="#fff" stroke-width="3"/>')
    parts.append('<ellipse cx="200" cy="200" rx="40" ry="18" fill="#fff" opacity=".25" transform="rotate(-30 200 200)"/>')
    return wrap("".join(parts), size, size, defs)


if __name__ == "__main__":
    items = []
    for e in ["happy", "fight", "joy", "hurt"]:
        items.append((f"nano-{e}", nano(e, 512)))
    items.append(("minibot", minibot()))
    items += skin_items()
    for k in ["spiky", "blob", "dart", "spitter", "mini", "elite", "bomber", "healer", "sniper", "spore"]:
        items.append((f"virus-{k}", virus(k, 256, seed=hash(k) % 100)))
    for k in ["sumo", "cowboy", "royal", "brain", "marrow"]:
        items.append((f"boss-{k}", boss(k)))
        for v in BOSS_VARIANTS:
            items.append((f"boss-{k}-{v}", boss_variant(k, v)))
    for k in STRAIN_KINDS:
        for st in STRAINS:
            items.append((f"virus-{k}-{st}", strain_virus(k, st)))
    for m in MINI_BOSSES:
        items.append((f"miniboss-{m}", mini_boss(m)))
    for a in ["medic", "guardian", "hunter"]:
        items.append((f"ally-{a}", ally(a)))
    items.append(("bed", bed()))
    items += [("orb", orb()), ("orb-big", orb(96, "#FFE45C", "#FFFFE0")), ("coin", coin()), ("heart", heart()), ("chest", chest()),
              ("glow", glow()), ("glow-pink", glow(128, "#FF6BD5")), ("glow-gold", glow(128, "#FFE45C")), ("bolt", bolt()), ("bomb", bomb()), ("slime", slime())]
    for o in ORGANS:
        items.append((f"bg-{o}", backdrop(o)))
        if o in ORGANS_ALT:
            items.append((f"bg-{o}-2", backdrop(o, alt=True)))
    items += [("dr-leuko", leuko()), ("king-vex", vex())]
    items.append(("icon", icon()))
    asyncio.run(render(items))
    for name, _ in items:
        png = os.path.join(OUT, name + ".png")
        if name == "icon":
            d = os.path.join(ASSETS, "AppIcon.appiconset"); os.makedirs(d, exist_ok=True)
            __import__("shutil").copy(png, os.path.join(d, "icon.png"))
            json.dump({"images": [{"filename": "icon.png", "idiom": "universal", "platform": "ios", "size": "1024x1024"}], "info": {"author": "xcode", "version": 1}}, open(os.path.join(d, "Contents.json"), "w"))
        elif name.startswith("bg-"):
            imageset(name, png, 2)
        else:
            imageset(name, png, 3)
    print("rendered", len(items))


def bodymap():
    W, H = 600, 1000
    defs = '''<linearGradient id="skin" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#2DD4FF" stop-opacity=".30"/><stop offset="1" stop-color="#2D6BFF" stop-opacity=".14"/></linearGradient>
    <filter id="bglow" x="-20%" y="-20%" width="140%" height="140%"><feGaussianBlur stdDeviation="9"/></filter>
    <pattern id="grid" width="24" height="24" patternUnits="userSpaceOnUse"><path d="M24 0H0V24" fill="none" stroke="#7CF6FF" stroke-opacity=".12" stroke-width="1"/></pattern>'''
    body = '''M300 40 C352 40 380 80 380 128 C380 176 352 214 300 214 C248 214 220 176 220 128 C220 80 248 40 300 40 Z
    M262 222 L338 222 L345 252 C420 262 462 290 470 350 L500 560 C504 590 476 600 466 574 L420 380 L410 470 C414 540 420 600 412 640
    L402 950 C400 980 352 984 350 952 L322 660 L278 660 L250 952 C248 984 200 980 198 950 L188 640 C180 600 186 540 190 470 L180 380
    L134 574 C124 600 96 590 100 560 L130 350 C138 290 180 262 255 252 Z'''
    parts = f'''<path d="{body}" fill="#2DD4FF" opacity=".35" filter="url(#bglow)"/>
    <path d="{body}" fill="url(#skin)" stroke="#7CF6FF" stroke-opacity=".75" stroke-width="3"/>
    <path d="{body}" fill="url(#grid)"/>
    <path d="M300 230 V650" stroke="#7CF6FF" stroke-opacity=".18" stroke-width="2" stroke-dasharray="6 8"/>'''
    return wrap(parts, W, H, defs)
