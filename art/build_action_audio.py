"""Original cartoon action cues. Python standard library; no sample recordings."""
from pathlib import Path
import math
import random
import struct
import wave

ROOT = Path(__file__).resolve().parents[1] / 'assets/audio/actions'
ROOT.mkdir(parents=True, exist_ok=True)
RATE = 22050
DURATIONS = {'jump': .28, 'land': .19, 'bump': .22, 'knockdown': .48,
             'fall': .65, 'roll': .52, 'dive': .36, 'swing': .32, 'hit': .28,
             'freeze': .66, 'thaw': .32, 'fear': .62, 'pickup': .3, 'item': .32}
for name, duration in DURATIONS.items():
    rng = random.Random(name)
    values = []
    for i in range(int(duration * RATE)):
        t, p = i / RATE, i / (duration * RATE)
        noise = rng.uniform(-1, 1)
        envelope = min(1, t * 160) * (1 - p) ** 1.7
        if name == 'jump':
            value = math.sin(2*math.pi*(300*t+1000*t*t)) + .25*math.sin(2*math.pi*950*t)
        elif name in ('land', 'bump', 'hit', 'knockdown'):
            hz = {'land': 130, 'bump': 210, 'hit': 160, 'knockdown': 95}[name]
            value = math.sin(2*math.pi*(hz*t-45*t*t)) * math.exp(-p*3)
            value += noise * (.7 if name == 'hit' else .38) * math.exp(-p*7)
            if name == 'knockdown': value += .35*math.sin(2*math.pi*55*t)*math.exp(-p*2)
        elif name == 'fall':
            value = math.sin(2*math.pi*(560*t-300*t*t)) * .7
        elif name in ('roll', 'dive', 'swing', 'item'):
            hz = {'roll': 100, 'dive': 240, 'swing': 420, 'item': 600}[name]
            value = noise * math.sin(math.pi*p) + .48*math.sin(2*math.pi*(hz*t+120*t*t))
            if name == 'roll': value *= .7+.3*math.sin(2*math.pi*19*t)
        elif name in ('freeze', 'thaw', 'pickup'):
            value = 0
            for j, hz in enumerate([1046.5, 1568, 2093, 2637]):
                a = t-j*.035
                if a >= 0: value += .45*math.sin(2*math.pi*hz*a)*math.exp(-a*10)
            value += noise*.12*math.exp(-p*8)
        else:  # resonant, short, playful roar
            value = .6*math.sin(2*math.pi*(115*t-30*t*t))+.32*math.sin(2*math.pi*230*t)
            value += noise*.2
            value *= .75+.25*math.sin(2*math.pi*24*t)
        values.append(value*envelope)
    peak = max(abs(v) for v in values)
    pcm = b''.join(struct.pack('<h', round(v / peak * .62 * 32767)) for v in values)
    with wave.open(str(ROOT / (name+'.wav')), 'wb') as stream:
        stream.setnchannels(1)
        stream.setsampwidth(2)
        stream.setframerate(RATE)
        stream.writeframes(pcm)
print('Generated', len(DURATIONS), 'action cues')
