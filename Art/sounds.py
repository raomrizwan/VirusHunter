"""Synthesized sound effects for Virus Hunter 2.0 (44.1 kHz mono 16-bit WAV)."""
import numpy as np, wave, os
SR = 44100
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "VirusHunter", "Resources", "Sounds")
os.makedirs(OUT, exist_ok=True)
rng = np.random.default_rng(3)

def t(d): return np.linspace(0, d, int(SR * d), False)
def env(n, a=0.005, r=None):
    e = np.ones(n); ai = max(1, int(a * SR)); e[:ai] = np.linspace(0, 1, ai)
    rr = n - ai if r is None else int(r * SR)
    e[-rr:] *= np.linspace(1, 0, rr) ** 2
    return e
def sweep(f0, f1, d, shape="sine"):
    tt = t(d); f = np.geomspace(f0, f1, len(tt)); ph = 2 * np.pi * np.cumsum(f) / SR
    if shape == "sine": return np.sin(ph)
    if shape == "square": return np.sign(np.sin(ph)) * 0.6
    if shape == "saw": return (2 * ((ph / (2 * np.pi)) % 1) - 1) * 0.7
    if shape == "tri": return 2 * np.abs(2 * ((ph / (2 * np.pi)) % 1) - 1) - 1
def noise(d): return rng.uniform(-1, 1, int(SR * d))
def lp(x, k=8):
    return np.convolve(x, np.ones(k) / k, mode="same")
def save(name, x, vol=0.8):
    x = x / (np.max(np.abs(x)) + 1e-9) * vol
    with wave.open(os.path.join(OUT, name + ".wav"), "w") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((x * 32767).astype(np.int16).tobytes())

save("shoot", sweep(1400, 700, 0.07, "tri") * env(int(SR*0.07)), 0.35)
save("hit", lp(noise(0.05), 4) * env(int(SR*0.05)) + 0.5*sweep(500, 260, 0.05) * env(int(SR*0.05)), 0.4)
pop = sweep(300, 900, 0.09) * env(int(SR*0.09)); pop[:len(pop)] += 0.4 * lp(noise(0.09), 6) * env(int(SR*0.09))
save("kill", pop, 0.5)
save("pickup", sweep(1500, 2400, 0.06, "sine") * env(int(SR*0.06)), 0.35)
c1 = sweep(1046, 1046, 0.08) * env(int(SR*0.08)); c2 = sweep(1568, 1568, 0.12) * env(int(SR*0.12))
save("coin", np.concatenate([c1, c2]), 0.45)
notes = [523, 659, 784, 1046]
lv = np.concatenate([sweep(f, f, 0.09, "tri") * env(int(SR*0.09)) for f in notes] + [sweep(1318, 1318, 0.35, "tri") * env(int(SR*0.35))])
save("levelup", lv, 0.6)
save("hurt", sweep(320, 90, 0.22, "saw") * env(int(SR*0.22)) + 0.3 * lp(noise(0.22), 10) * env(int(SR*0.22)), 0.6)
zap = (lp(noise(0.18), 2) * 0.6 + sweep(2200, 400, 0.18, "square") * 0.5) * env(int(SR*0.18))
save("zap", zap, 0.45)
boom = lp(noise(0.5), 30) * env(int(SR*0.5), 0.002) + 0.8 * sweep(120, 40, 0.5) * env(int(SR*0.5), 0.002)
save("bomb", boom, 0.8)
al = np.concatenate([sweep(440, 440, 0.25, "saw") * env(int(SR*0.25)), sweep(330, 330, 0.25, "saw") * env(int(SR*0.25))] * 2)
save("warning", lp(al, 6), 0.6)
win = np.concatenate([sweep(f, f, 0.14, "tri") * env(int(SR*0.14)) for f in [523, 659, 784, 1046, 784, 1046]] + [sweep(1568, 1568, 0.6, "tri") * env(int(SR*0.6))])
save("victory", win, 0.65)
lose = np.concatenate([sweep(f, f * 0.97, 0.22, "tri") * env(int(SR*0.22)) for f in [392, 349, 311, 262]])
save("defeat", lose, 0.6)
save("tap", sweep(900, 1200, 0.035) * env(int(SR*0.035)), 0.35)
st = lp(noise(0.35), 40) * env(int(SR*0.35), 0.002) + sweep(90, 45, 0.35) * env(int(SR*0.35), 0.002)
save("stomp", st, 0.8)
print("ok", sorted(os.listdir(OUT)))
