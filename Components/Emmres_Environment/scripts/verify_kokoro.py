from importlib.metadata import version
from pathlib import Path
from kokoro_onnx import Kokoro
import sys
root = Path(sys.argv[1])
model = root / "models" / "voice" / "kokoro" / "kokoro-v1.0.int8.onnx"
voices = root / "models" / "voice" / "kokoro" / "voices-v1.0.bin"
print("kokoro-onnx", version("kokoro-onnx"))
k = Kokoro(str(model), str(voices))
print("voices", len(k.get_voices()))
