import argparse
from pathlib import Path
import soundfile as sf
from kokoro_onnx import Kokoro

ROOT = Path(__file__).resolve().parents[1]
MODEL = ROOT / "models" / "voice" / "kokoro" / "kokoro-v1.0.int8.onnx"
VOICES = ROOT / "models" / "voice" / "kokoro" / "voices-v1.0.bin"
# Expressive presets use stable voices plus pace. They are style presets, not guaranteed emotion control.
PRESETS = {
    "neutral": ("af_heart", 1.00),
    "warm": ("af_bella", 0.96),
    "bright": ("af_nova", 1.08),
    "calm": ("af_sarah", 0.88),
    "serious": ("am_michael", 0.90),
    "energetic": ("am_puck", 1.15),
    "narrator": ("bm_george", 0.92),
}
p=argparse.ArgumentParser(description="Offline Kokoro neural speech")
p.add_argument("text")
p.add_argument("-o","--output",default="speech.wav")
p.add_argument("--style",choices=PRESETS,default="neutral")
p.add_argument("--voice")
p.add_argument("--speed",type=float)
p.add_argument("--lang",default="en-us")
a=p.parse_args()
voice,speed=PRESETS[a.style]
voice=a.voice or voice; speed=a.speed or speed
k=Kokoro(str(MODEL),str(VOICES))
samples,rate=k.create(a.text,voice=voice,speed=speed,lang=a.lang)
sf.write(a.output,samples,rate)
print(a.output)
