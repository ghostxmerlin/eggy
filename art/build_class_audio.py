"""Original layered class cues: metal transients, crystalline frost, shadow and bow strings.
No extracted game recordings. Deterministic PCM, standard Python only.
"""
from pathlib import Path
import math
import random
import struct
import wave

ROOT = Path(__file__).resolve().parents[1] / 'assets/audio/classes'
ROOT.mkdir(parents=True, exist_ok=True)
GROUPS = {
    'metal': ['mortal', 'storm', 'charge', 'reflect', 'raptor', 'impact_metal'],
    'frost': ['frostbolt', 'lance', 'nova', 'block', 'trap', 'freeze', 'thaw', 'impact_frost'],
    'shadow': ['sinister', 'eviscerate', 'kidney', 'shadowstep', 'stealth', 'impact_shadow'],
    'arrow': ['arcane', 'aimed', 'disengage', 'impact_arrow'],
    'magic': ['blink', 'stun', 'immune', 'shout'],
}
RATE = 22050
for family, names in GROUPS.items():
    for variant, name in enumerate(names):
        duration = 1.2 if name in ('storm', 'shout', 'block') else .85 if name in ('aimed', 'frostbolt') else .42
        rng = random.Random(name)
        samples = []
        smooth_noise = 0
        for i in range(int(RATE*duration)):
            t = i/RATE
            p = t/duration
            noise = rng.uniform(-1, 1)
            smooth_noise = smooth_noise*.82+noise*.18
            envelope = min(1, t*180)*(1-p)**1.5
            pulse = math.exp(-t*18)
            freq = 110+variant*23
            if family == 'metal':
                value = .55*math.sin(math.tau*(freq*t-30*t*t))*math.exp(-t*9)
                value += sum(.15*math.sin(math.tau*f*t)*math.exp(-t*(4+j*2)) for j, f in enumerate([780+variant*70, 1237, 2163]))
                value += .6*noise*pulse+.6*smooth_noise*math.sin(math.pi*p)
                if name == 'storm': value *= .4+.6*abs(math.sin(t*math.pi*8))
            elif family == 'frost':
                value = .25*smooth_noise+.2*noise*math.exp(-t*12)
                for j, f in enumerate([1174+variant*45, 1760, 2349, 3136]):
                    a = t-j*.035
                    if a >= 0: value += .24*math.sin(math.tau*(f*a+80*a*a))*math.exp(-a*7)
            elif family == 'shadow':
                value = .6*smooth_noise*math.sin(math.pi*p)+.4*noise*pulse
                value += .4*math.sin(math.tau*(95*t-24*t*t))+.15*math.sin(math.tau*317*t)*math.exp(-t*6)
                value *= .7+.3*math.sin(t*math.tau*17)
            elif family == 'arrow':
                value = .45*noise*math.exp(-t*28)+.45*smooth_noise*math.sin(math.pi*p)
                value += .35*math.sin(math.tau*(390*t-180*t*t))*math.exp(-t*10)
                value += .2*math.sin(math.tau*(910+variant*65)*t)*math.exp(-t*18)
            else:
                value = sum(.2*math.sin(math.tau*(f*t+180*t*t))*math.exp(-t*4) for f in [220, 330, 440])
                value += .3*smooth_noise
                if name == 'shout': value = .65*math.sin(math.tau*(98*t-16*t*t))+.4*smooth_noise+.2*math.sin(math.tau*196*t)
            samples.append(value*envelope)
        peak = max(abs(x) for x in samples)
        pcm = b''.join(struct.pack('<h', round(x/peak*.65*32767)) for x in samples)
        with wave.open(str(ROOT/(name+'.wav')), 'wb') as audio:
            audio.setnchannels(1)
            audio.setsampwidth(2)
            audio.setframerate(RATE)
            audio.writeframes(pcm)
print('Generated', sum(map(len, GROUPS.values())), 'class sound cues')
