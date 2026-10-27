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
    }[kind]
    light, mid, dark = pal
    c = size / 2
    r = size * (0.30 if kind != "blob" else 0.34)
    defs = f'''<radialGradient id="b{kind}" cx="36%" cy="30%" r="80%"><stop offset="0" stop-color="{light}"/><stop offset=".55" stop-color="{mid}"/><stop offset="1" stop-color="{dark}"/></radialGradient>
    <filter id="gl{kind}" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="{size*0.04}"/></filter>'''
    parts = [f'<circle cx="{c}" cy="{c}" r="{r*1.15}" fill="{mid}" opacity=".45" filter="url(#gl{kind})"/>']
    n = {"spiky": 12, "blob": 0, "dart": 8, "spitter": 10, "mini": 8, "elite": 14}[kind]
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
    if kind == "elite":
        parts.insert(0, f'<circle cx="{c}" cy="{c}" r="{r*1.55}" fill="none" stroke="#FFE45C" stroke-width="{size*0.02}" stroke-dasharray="{size*0.05} {size*0.035}" opacity=".9"/>')
    return wrap("".join(parts), size, size, defs)


def boss(kind, size=512):
    base = {"sumo": "blob", "cowboy": "spiky", "royal": "elite"}[kind]
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
    else:
        extra = f'''<path d="M{c-110} {c-120} L{c-90} {c-215} L{c-45} {c-150} L{c} {c-235} L{c+45} {c-150} L{c+90} {c-215} L{c+110} {c-120} Z" fill="#FFD34D" stroke="#9A6A00" stroke-width="8"/>
        <circle cx="{c}" cy="{c-185}" r="16" fill="#FF3D6A"/><circle cx="{c-80}" cy="{c-160}" r="11" fill="#3FE6FF"/><circle cx="{c+80}" cy="{c-160}" r="11" fill="#3FE6FF"/>
        <path d="M{c+120} {c+40} L{c+215} {c+20} L{c+215} {c+140} Q{c+180} {c+210} {c+150} {c+215} Q{c+120} {c+150} {c+120} {c+40} Z" fill="#B0BCD0" stroke="#4A5670" stroke-width="8"/>'''
    return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {size} {size}" width="{size}" height="{size}">{inner}{extra}</svg>'


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


def backdrop(name, size=1024, seed=3):
    deep, mid, accent = ORGANS[name]
    rnd = random.Random(seed + len(name))
    defs = f'''<radialGradient id="cell" cx="40%" cy="35%" r="70%"><stop offset="0" stop-color="{accent}" stop-opacity=".22"/><stop offset=".7" stop-color="{accent}" stop-opacity=".08"/><stop offset="1" stop-color="{accent}" stop-opacity="0"/></radialGradient>
    <radialGradient id="nuc"><stop offset="0" stop-color="{accent}" stop-opacity=".3"/><stop offset="1" stop-color="{accent}" stop-opacity="0"/></radialGradient>
    <filter id="soft" x="-20%" y="-20%" width="140%" height="140%"><feGaussianBlur stdDeviation="3"/></filter>
    <filter id="blur" x="-30%" y="-30%" width="160%" height="160%"><feGaussianBlur stdDeviation="14"/></filter>'''
    parts = [f'<rect width="{size}" height="{size}" fill="{deep}"/>']
    # big soft blobs
    for i in range(10):
        x, y, r = rnd.uniform(0, size), rnd.uniform(0, size), rnd.uniform(120, 260)
        for dx in (-size, 0, size):
            for dy in (-size, 0, size):
                parts.append(f'<circle cx="{x+dx}" cy="{y+dy}" r="{r}" fill="{mid}" opacity=".35" filter="url(#blur)"/>')
    # cells with membrane rings (wrapped for tiling)
    for i in range(26):
        x, y, r = rnd.uniform(0, size), rnd.uniform(0, size), rnd.uniform(26, 70)
        for dx in (-size, 0, size):
            for dy in (-size, 0, size):
                cx, cy = x + dx, y + dy
                if -100 < cx < size + 100 and -100 < cy < size + 100:
                    parts.append(f'<g filter="url(#soft)"><circle cx="{cx}" cy="{cy}" r="{r}" fill="url(#cell)" stroke="{accent}" stroke-opacity=".18" stroke-width="3"/>'
                                 f'<circle cx="{cx+r*0.15}" cy="{cy+r*0.1}" r="{r*0.32}" fill="url(#nuc)"/></g>')
    # tiny particles
    for i in range(120):
        x, y = rnd.uniform(0, size), rnd.uniform(0, size)
        parts.append(f'<circle cx="{x}" cy="{y}" r="{rnd.uniform(1.2,3)}" fill="{accent}" opacity="{rnd.uniform(.12,.35)}"/>')
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


if __name__ == "__main__":
    items = []
    for e in ["happy", "fight", "joy", "hurt"]:
        items.append((f"nano-{e}", nano(e, 512)))
    items.append(("minibot", minibot()))
    items += skin_items()
    for k in ["spiky", "blob", "dart", "spitter", "mini", "elite"]:
        items.append((f"virus-{k}", virus(k, 256, seed=hash(k) % 100)))
    for k in ["sumo", "cowboy", "royal"]:
        items.append((f"boss-{k}", boss(k)))
    items += [("orb", orb()), ("orb-big", orb(96, "#FFE45C", "#FFFFE0")), ("coin", coin()), ("heart", heart()), ("chest", chest()),
              ("glow", glow()), ("glow-pink", glow(128, "#FF6BD5")), ("glow-gold", glow(128, "#FFE45C")), ("bolt", bolt()), ("bomb", bomb()), ("slime", slime())]
    for o in ORGANS:
        items.append((f"bg-{o}", backdrop(o)))
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
