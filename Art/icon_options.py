import sys, random
sys.path.insert(0, '.')
import art
def inner(svg): return svg[svg.index("<defs>"):svg.rindex("</svg>")]
def uniq(svg, tag):
    # make gradient/filter ids unique per embed
    import re
    ids = set(re.findall(r'id="([^"]+)"', svg))
    for i in sorted(ids, key=len, reverse=True):
        svg = svg.replace(f'id="{i}"', f'id="{i}{tag}"').replace(f'url(#{i})', f'url(#{i}{tag})').replace(f'href="#{i}"', f'href="#{i}{tag}"')
    return svg
N = lambda e, t: uniq(inner(art.nano(e, 512, True)), t)
V = lambda k, s, t, seed=4: uniq(inner(art.virus(k, s, seed=seed)), t)
B = lambda t: uniq(inner(art.minibot(128)), t)
X = lambda t: uniq(inner(art.vex(512)), t)
bubbles = lambda col, op: f'<g opacity="{op}">' + ''.join(f'<circle cx="{random.Random(i).uniform(0,1024)}" cy="{random.Random(i+99).uniform(0,1024)}" r="{random.Random(i+7).uniform(14,46)}" fill="none" stroke="{col}" stroke-width="5"/>' for i in range(9)) + '</g>'

def optA():
    d = '''<radialGradient id="bg" cx="70%" cy="25%" r="95%"><stop offset="0" stop-color="#7A1FA8"/><stop offset=".45" stop-color="#2A0F5A"/><stop offset="1" stop-color="#060A1C"/></radialGradient>
    <radialGradient id="rim" cx="25%" cy="75%" r="55%"><stop offset="0" stop-color="#2DE4FF" stop-opacity=".55"/><stop offset="1" stop-color="#2DE4FF" stop-opacity="0"/></radialGradient>
    <linearGradient id="beam" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#7CF6FF" stop-opacity=".2"/><stop offset="1" stop-color="#fff"/></linearGradient>
    <filter id="bb" x="-10%" y="-300%" width="120%" height="700%"><feGaussianBlur stdDeviation="16"/></filter>'''
    body = f'''<rect width="1024" height="1024" fill="url(#bg)"/><rect width="1024" height="1024" fill="url(#rim)"/>{bubbles("#FF8BE8", .18)}
    <g transform="translate(470 -10) scale(1.15)">{V("spiky", 512, "a")}</g>
    <g transform="rotate(-32 520 560)"><rect x="330" y="520" width="520" height="70" rx="35" fill="#7CF6FF" opacity=".85" filter="url(#bb)"/><rect x="330" y="536" width="520" height="38" rx="19" fill="url(#beam)"/></g>
    <g transform="translate(-90 300) scale(1.62)">{N("fight", "b")}</g>'''
    return art.wrap(body, 1024, 1024, d)

def optB():
    d = '''<linearGradient id="l" x1="0" y1="1" x2="1" y2="0"><stop offset="0" stop-color="#0A3A6A"/><stop offset=".499" stop-color="#062040"/><stop offset=".501" stop-color="#3A0A40"/><stop offset="1" stop-color="#7A1060"/></linearGradient>
    <linearGradient id="bolt" x1="0" y1="1" x2="1" y2="0"><stop offset="0" stop-color="#7CF6FF"/><stop offset="1" stop-color="#FF7BE0"/></linearGradient>
    <filter id="gl"><feGaussianBlur stdDeviation="12"/></filter>'''
    body = f'''<rect width="1024" height="1024" fill="url(#l)"/>
    <g transform="translate(500 30) scale(1.0)">{X("c")}</g>
    <path d="M0 1024 L1024 0" stroke="url(#bolt)" stroke-width="40" filter="url(#gl)" opacity=".9"/>
    <path d="M0 1024 L1024 0" stroke="#fff" stroke-width="10" opacity=".9"/>
    <g transform="translate(-60 360) scale(1.45)">{N("fight", "d")}</g>'''
    return art.wrap(body, 1024, 1024, d)

def optC():
    d = '''<radialGradient id="bg" cx="50%" cy="50%" r="70%"><stop offset="0" stop-color="#1B4E8C"/><stop offset=".55" stop-color="#0D1E48"/><stop offset="1" stop-color="#05081A"/></radialGradient>
    <radialGradient id="halo" cx="50%" cy="50%" r="50%"><stop offset=".55" stop-color="#2DE4FF" stop-opacity="0"/><stop offset=".72" stop-color="#2DE4FF" stop-opacity=".55"/><stop offset=".8" stop-color="#2DE4FF" stop-opacity="0"/></radialGradient>'''
    vs = ''.join(f'<g transform="translate({x} {y}) scale({s})">{V(k, 256, "v%d" % i, seed=i+3)}</g>' for i, (k, x, y, s) in enumerate([("spiky", -40, -40, 1.0), ("mini", 790, -30, .95), ("blob", 800, 780, 1.0), ("dart", -30, 800, .9)]))
    bots = ''.join(f'<g transform="translate({512+380*__import__("math").cos(a)-55} {520+380*__import__("math").sin(a)-55}) scale(.85)">{B("m%d" % i)}</g>' for i, a in enumerate([0.4, 1.95, 3.5, 5.05]))
    body = f'''<rect width="1024" height="1024" fill="url(#bg)"/>{vs}<circle cx="512" cy="520" r="470" fill="url(#halo)"/>{bots}
    <g transform="translate(112 130) scale(1.56)">{N("happy", "n")}</g>'''
    return art.wrap(body, 1024, 1024, d)

S = sys.argv[1]
for n, f in [("icon-a", optA), ("icon-b", optB), ("icon-c", optC)]:
    open(f"{S}/{n}.svg", "w").write(f())
