"""Render original Chinese lines offline with MeloTTS via sherpa-onnx.

Install sherpa-onnx==1.13.8 and numpy into .tools/voice-venv. Download and
extract vits-melo-tts-zh_en.tar.bz2 from the sherpa-onnx tts-models release
into .tools/. Only generated WAVs ship with the game; no runtime TTS needed.
"""
from pathlib import Path
import argparse
import re
import wave
import numpy as np
import sherpa_onnx

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument('--model', type=Path, default=ROOT/'.tools/vits-melo-tts-zh_en')
args = parser.parse_args()
model = args.model
config = sherpa_onnx.OfflineTtsConfig(model=sherpa_onnx.OfflineTtsModelConfig(
    vits=sherpa_onnx.OfflineTtsVitsModelConfig(model=str(model/'model.onnx'),
        tokens=str(model/'tokens.txt'), lexicon=str(model/'lexicon.txt'),
        dict_dir=str(model/'dict'), noise_scale=.5, noise_scale_w=.65),
    num_threads=2, provider='cpu'))
tts = sherpa_onnx.OfflineTts(config)
out = ROOT/'assets/audio/voice'
out.mkdir(parents=True, exist_ok=True)
source = (ROOT/'scripts/gameplay_audio.gd').read_text()
lines = re.findall(r"'([a-z]+)': \['[a-z]+','([^']+)'\]", source)
for key, text in lines:
    audio = tts.generate(text, sid=0, speed=1.08)
    samples = np.asarray(audio.samples)
    audible = np.flatnonzero(np.abs(samples) > .006)
    if not len(audible): raise RuntimeError('Empty voice: '+key)
    pad = int(audio.sample_rate*.05)
    samples = samples[max(0,audible[0]-pad):audible[-1]+pad+1].copy()
    # Consistent peaks, short fades and a slight pitch lift for a playful voice.
    samples *= .78 / max(.01,np.max(np.abs(samples)))
    ramp = min(int(audio.sample_rate*.01), len(samples)//2)
    samples[:ramp] *= np.linspace(0,1,ramp)
    samples[-ramp:] *= np.linspace(1,0,ramp)
    rate = round(audio.sample_rate*1.10)
    with wave.open(str(out/(key+'.wav')), 'wb') as stream:
        stream.setnchannels(1)
        stream.setsampwidth(2)
        stream.setframerate(rate)
        stream.writeframes((samples*32767).astype('<i2').tobytes())
    print(key, text, round(len(samples)/rate,2), 'seconds', flush=True)
