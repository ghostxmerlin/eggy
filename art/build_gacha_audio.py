"""Original synthesized capsule charge, opening and rarity stingers (standard library only)."""
from pathlib import Path
import math, random, struct, wave
ROOT = Path(__file__).resolve().parents[1] / 'assets/audio'
RATE = 22050
for name, duration in [('charge',1.25),('open',.7),('rare',1.8)]:
    rng = random.Random(612)
    samples = bytearray()
    for i in range(int(duration*RATE)):
        t = i/RATE
        if name == 'charge':
            envelope = math.sin(math.pi*t/duration)**.65
            phase = 2*math.pi*(180*t+340*t*t)
            value = (.14*math.sin(phase)+.055*math.sin(phase*2.01))*envelope
        elif name == 'open':
            value = .19*rng.uniform(-1,1)*math.exp(-t*19)+.20*math.sin(2*math.pi*(80*t-28*t*t))*math.exp(-t*10)
            for j,f in enumerate([784,1046.5,1568]):
                a = t-j*.055
                if a > 0: value += .075*math.sin(2*math.pi*f*a)*math.exp(-a*9)
        else:
            value = 0
            for j,f in enumerate([523.25,659.25,784,1046.5,1318.5]):
                a=t-j*.11
                if a > 0: value += .085*(math.sin(2*math.pi*f*a)+.18*math.sin(2*math.pi*f*2.01*a))*min(1,a*90)*math.exp(-a*2.9)
            value *= min(1,(duration-t)*4)
        samples += struct.pack('<h',int(max(-.95,min(.95,value))*32767))
    with wave.open(str(ROOT / ('gacha_'+name+'.wav')),'wb') as stream:
        stream.setnchannels(1); stream.setsampwidth(2); stream.setframerate(RATE); stream.writeframes(samples)
