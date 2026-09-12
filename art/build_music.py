"""Original 32-bar instrumental loops; deterministic synthesis, no sampled music.

Run with Blender's bundled Python (NumPy), then encode the WAVs with ffmpeg.
Reverb/delay tails wrap around the loop boundary to avoid a silent restart.
"""
from pathlib import Path
import wave
import numpy as np

RATE = 44100
OUT = Path(__file__).resolve().parents[1] / 'assets/audio'
RNG = np.random.default_rng(1209)

def hz(note):
    return 440 * 2 ** ((note - 69) / 12)

def voice(note, length, kind):
    t = np.arange(max(1, int(length * RATE))) / RATE
    f = hz(note)
    attack = 1 - np.exp(-t * 160)
    release = np.minimum(1, np.maximum(0, (length - t) / .09))
    if kind == 'mallet':
        y = (np.sin(2*np.pi*f*t) * np.exp(-t*4.0)
             + .25*np.sin(2*np.pi*f*2*t) * np.exp(-t*8)
             + .11*np.sin(2*np.pi*f*3*t) * np.exp(-t*15))
    elif kind == 'pluck':
        y = sum(np.sin(2*np.pi*f*k*t) / k**1.7 * np.exp(-t*(3+k)) for k in range(1, 7))
    elif kind == 'lead':
        phase = 2*np.pi*f*t + .014*np.sin(2*np.pi*5*t)
        y = (.85*np.sin(phase) + .22*np.sin(2*phase) + .10*np.sin(3*phase)) * np.exp(-t*2.2)
    elif kind == 'bass':
        y = (np.sin(2*np.pi*f*t) + .24*np.sin(2*np.pi*f*2*t)) * np.exp(-t*2)
    else:
        attack = np.minimum(1, t / .15)
        y = .5*(np.sin(2*np.pi*f*t) + np.sin(2*np.pi*f*1.002*t)) + .08*np.sin(2*np.pi*f*2*t)
    return y * attack * release

def make(theme, bpm):
    beat = 60 / bpm
    n = round(32 * 4 * beat * RATE)
    dry = np.zeros((n, 2), dtype=np.float64)
    tonal = np.zeros_like(dry)

    def add(samples, at, gain, pan=0, musical=True):
        index = (round(at * beat * RATE) + np.arange(len(samples))) % n
        target = tonal if musical else dry
        gains = np.array([np.sqrt((1-pan)/2), np.sqrt((1+pan)/2)])
        target[index] += samples[:, None] * gains * gain

    def note(midi, at, duration, kind, gain, pan=0):
        add(voice(midi, duration*beat, kind), at, gain, pan)

    race = theme == 'race'
    harmony = [(48, [60,64,67,71]), (45,[60,64,67,69]), (41,[60,64,65,69]), (43,[59,62,67,69]),
               (48,[60,64,67,71]), (45,[60,64,67,69]), (41,[60,65,69,72]), (43,[59,62,67,71])]
    bridge = [(50,[62,65,69,72]), (43,[59,62,67,71]), (40,[59,64,67,71]), (45,[60,64,67,69]),
              (41,[60,64,65,69]), (50,[60,62,65,69]), (43,[59,62,67,69]), (43,[59,62,67,71])]
    # (beat, pitch, duration): two answering phrases followed by a contrasting bridge.
    melody = [
        [(0,76,.6),(1,79,.4),(1.75,81,.6),(2.75,79,.8)],
        [(.25,76,.6),(1.25,72,.5),(2,74,.4),(3,76,.8)],
        [(0,77,.6),(.75,76,.4),(1.5,74,.6),(2.5,72,1.0)],
        [(0,74,.5),(1,79,.7),(2.25,74,.4),(3,71,.6)],
        [(0,76,.6),(.75,79,.4),(1.5,84,.7),(2.75,83,.7)],
        [(0,81,.6),(1,79,.4),(1.75,76,.5),(2.75,72,.8)],
        [(.25,74,.5),(1,77,.5),(2,76,.5),(2.75,74,.5)],
        [(0,71,.5),(.75,74,.5),(1.5,79,.7),(3,72,.7)],
    ]
    bridge_melody = [
        [(0,77,.8),(1.5,81,.6),(2.5,84,1)], [(0,83,.6),(1,79,.5),(2,74,1.5)],
        [(.5,79,.6),(1.5,76,.5),(2.5,83,1)], [(0,81,1),(1.5,79,.5),(2.5,76,1)],
        [(0,77,.6),(1,81,.5),(2,79,.5),(3,77,.6)], [(0,74,1),(1.5,77,.5),(2.5,81,.8)],
        [(0,79,.7),(1.5,74,.6),(2.5,71,.7)], [(0,74,.5),(1,76,.5),(2,74,.5),(3,71,.5)],
    ]
    for bar in range(32):
        base = bar*4
        section = bar//8
        root, chord = (bridge if section == 2 else harmony)[bar%8]
        for j, pitch in enumerate(chord):
            note(pitch, base, 3.9, 'pad', .019 if race else .025, (j-1.5)*.3)
        for step in range(8):
            pitch = chord[[0,2,1,3,2,1,3,2][step]]
            note(pitch + (12 if race else 0), base+step*.5+.02, .65, 'pluck', .035 if race else .060, (-1 if step%2 else 1)*.45)
        for at in ([0, .75, 1.5, 2, 2.75, 3.5] if race else [0, 1.5, 2.5]):
            note(root-12 if race else root, base+at, .65, 'bass', .14 if race else .12)
        phrase = (bridge_melody if section == 2 else melody)[bar%8]
        for at, pitch, duration in phrase:
            note(pitch, base+at, duration+.2, 'lead' if race else 'mallet', .145 if race else .19, -.1)
            if section == 3:
                note(pitch-12, base+at, duration+.1, 'mallet', .048, .25)
        # Soft synthesized percussion: kick, snare/clap, alternating closed hats.
        for at in ([0,1,2,3] if race else [0,2]):
            t = np.arange(int(.27*RATE))/RATE
            kick = np.sin(2*np.pi*(48*t + 3.8*(1-np.exp(-t*30))))*np.exp(-t*19)
            add(kick, base+at, .25 if race else .17, musical=False)
        for at in [1,3]:
            t = np.arange(int(.16*RATE))/RATE
            noise = RNG.uniform(-1,1,len(t))
            soft = np.convolve(noise, np.ones(4)/4, mode='same')
            snare = (soft*.7 + np.sin(2*np.pi*185*t)*.18)*np.exp(-t*28)*(1-np.exp(-t*600))
            add(snare, base+at, .19 if race else .085, .12, musical=False)
        for step in range(8):
            t = np.arange(int(.075*RATE))/RATE
            noise = RNG.uniform(-1,1,len(t))
            hat = np.diff(noise, prepend=0)*np.exp(-t*65)
            add(hat, base+step*.5, (.027 if race else .014)*(1 if step%2 else .65), -.25, musical=False)
        if race and bar%8 == 7:
            for step in range(4):
                note([74,76,79,83][step], base+3+step*.25, .25, 'pluck', .065, .25)

    # Circular, filtered early reflections keep both the phrase and reverb seamless.
    mix = dry + tonal
    for delay, gain in [(beat*.75,.13),(.113,.08),(.181,.055),(.293,.035)]:
        reflected = np.roll(tonal[:, ::-1], round(delay*RATE), axis=0)
        reflected = (reflected + np.roll(reflected, 1, axis=0) + np.roll(reflected, 2, axis=0))/3
        mix += reflected*gain
    mix -= mix.mean(axis=0)
    mix = np.tanh(mix*1.2)
    mix *= .82 / np.max(np.abs(mix))
    pcm = (mix*32767).astype('<i2')
    path = OUT / f'bgm_{theme}.wav'
    with wave.open(str(path),'wb') as f:
        f.setnchannels(2); f.setsampwidth(2); f.setframerate(RATE); f.writeframes(pcm.tobytes())
    print(f'{theme}: {n/RATE:.2f}s, peak={abs(mix).max():.3f}, RMS={np.sqrt(np.mean(mix**2)):.3f}, seam={abs(mix[0]-mix[-1]).max():.5f}')

if __name__ == '__main__':
    make('island', 112)
    make('race', 144)
